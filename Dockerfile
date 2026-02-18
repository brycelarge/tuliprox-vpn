FROM rust:bookworm AS rust-build

ARG TULIPROX_REF=develop
ARG RUST_TARGET=x86_64-unknown-linux-musl

ENV RUSTFLAGS='-C target-feature=+crt-static'

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        pkg-config \
        musl-tools \
        libssl-dev \
        && rm -rf /var/lib/apt/lists/*

RUN rustup update && rustup target add "${RUST_TARGET}"

WORKDIR /src
RUN git clone --depth 1 --branch "${TULIPROX_REF}" https://github.com/euzu/tuliprox.git .

RUN cargo build -p tuliprox --target "${RUST_TARGET}" --release


FROM rust:bookworm AS web-build

ARG TULIPROX_REF=develop

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        pkg-config \
        libssl-dev \
        binaryen \
        && rm -rf /var/lib/apt/lists/*

RUN rustup target add wasm32-unknown-unknown
RUN cargo install --locked trunk@0.21.8 wasm-bindgen-cli@0.2.100

WORKDIR /src
RUN git clone --depth 1 --branch "${TULIPROX_REF}" https://github.com/euzu/tuliprox.git .

WORKDIR /src/frontend
RUN trunk build --release


FROM alpine:3.21 AS resource-build

ARG TULIPROX_REF=develop

RUN apk add --no-cache \
        ffmpeg \
        git

WORKDIR /src
RUN git clone --depth 1 --branch "${TULIPROX_REF}" https://github.com/euzu/tuliprox.git .

WORKDIR /src/resources
RUN for img in channel_unavailable user_connections_exhausted provider_connections_exhausted user_account_expired panel_api_provisioning; do \
      if [ ! -f "/src/resources/${img}.jpg" ]; then \
        echo "[resource-build] skipping missing /src/resources/${img}.jpg"; \
        continue; \
      fi; \
      ffmpeg -y -nostdin -loop 1 -i "/src/resources/${img}.jpg" \
        -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 \
        -c:v libx264 -r 30 -g 30 -keyint_min 30 -sc_threshold 0 -pix_fmt yuv420p -preset veryfast -crf 23 \
        -c:a aac -b:a 128k -ac 2 \
        -t 10 -muxrate 2000k \
        -f mpegts "/src/resources/${img}.ts" || exit 1; \
    done


FROM brycelarge/alpine-baseimage:3.21

ARG RUST_TARGET=x86_64-unknown-linux-musl

ENV TZ=UTC \
    CONFIG_DIR=/config

RUN apk add --no-cache \
        bash \
        ca-certificates \
        curl \
        dos2unix \
        ffmpeg \
        iproute2 \
        iptables \
        jq \
        moreutils \
        openvpn \
        privoxy \
        python3 \
        speedtest-cli \
        shadow \
        tzdata \
        unzip && \
    addgroup --system tuliprox && \
    adduser \
        --disabled-password \
        --home /app \
        --ingroup tuliprox \
        --no-create-home \
        --system \
        tuliprox && \
    mkdir -p \
        /app/config \
        /app/data \
        /app/backup \
        /app/downloads \
        /app/resources \
        /app/web && \
    chown -R tuliprox:tuliprox /app

WORKDIR /app

COPY --from=rust-build "/src/target/${RUST_TARGET}/release/tuliprox" /app/tuliprox
COPY --from=web-build /src/frontend/dist /app/web
COPY --from=resource-build /src/resources /app/resources

COPY scripts/healthcheck.sh /usr/local/bin/healthcheck.sh

COPY root/ /
COPY scripts/ /scripts/

RUN chmod +x /app/tuliprox && \
    chmod +x /scripts/*.sh && \
    chmod +x /usr/local/bin/healthcheck.sh && \
    find /etc/openvpn -name 'update.sh' -exec chmod +x {} + && \
    find /etc/openvpn -name 'map.sh' -exec chmod +x {} +

EXPOSE 8901/tcp

EXPOSE 8118/tcp

VOLUME ["/app/config", "/app/data", "/app/backup", "/app/downloads"]

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh
