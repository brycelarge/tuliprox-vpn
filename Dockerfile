# ── Single fetch stage: clone once, copy into build stages ──────────────────
FROM alpine:3.21 AS source

ARG TULIPROX_REF=develop

RUN apk add --no-cache git

WORKDIR /src
RUN git clone --depth 1 --branch "${TULIPROX_REF}" https://github.com/euzu/tuliprox.git .


# ── Rust binary build ────────────────────────────────────────────────────────
FROM rust:bookworm AS rust-build

ARG RUST_TARGET=x86_64-unknown-linux-musl

ENV RUSTFLAGS='-C target-feature=+crt-static'

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        pkg-config \
        musl-tools \
        libssl-dev \
        && rm -rf /var/lib/apt/lists/*

RUN rustup update && rustup target add "${RUST_TARGET}"

WORKDIR /src
COPY --from=source /src .

RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/src/target \
    cargo build -p tuliprox --target "${RUST_TARGET}" --release && \
    cp /src/target/${RUST_TARGET}/release/tuliprox /tuliprox


# ── Frontend (WASM/trunk) build ──────────────────────────────────────────────
FROM rust:bookworm AS web-build

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        pkg-config \
        libssl-dev \
        binaryen \
        && rm -rf /var/lib/apt/lists/*

RUN rustup target add wasm32-unknown-unknown

# Install trunk + wasm-bindgen from pre-built binaries (avoids OOM from compiling)
ARG TRUNK_VERSION=0.21.8
ARG WASM_BINDGEN_VERSION=0.2.100

RUN set -eux; \
    ARCH="$(uname -m)"; \
    case "${ARCH}" in \
        x86_64)  TB_ARCH="x86_64-unknown-linux-gnu"; WB_ARCH="x86_64-unknown-linux-musl" ;; \
        aarch64) TB_ARCH="aarch64-unknown-linux-gnu"; WB_ARCH="aarch64-unknown-linux-musl" ;; \
        *) echo "Unsupported arch: ${ARCH}"; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/trunk-rs/trunk/releases/download/v${TRUNK_VERSION}/trunk-${TB_ARCH}.tar.gz" \
        | tar -xz -C /usr/local/bin trunk; \
    curl -fsSL "https://github.com/rustwasm/wasm-bindgen/releases/download/${WASM_BINDGEN_VERSION}/wasm-bindgen-${WASM_BINDGEN_VERSION}-${WB_ARCH}.tar.gz" \
        | tar -xz --strip-components=1 -C /usr/local/bin "wasm-bindgen-${WASM_BINDGEN_VERSION}-${WB_ARCH}/wasm-bindgen"; \
    chmod +x /usr/local/bin/trunk /usr/local/bin/wasm-bindgen

WORKDIR /src
COPY --from=source /src .

WORKDIR /src/frontend
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    trunk build --release


# ── Resource (ffmpeg ts) build ───────────────────────────────────────────────
FROM alpine:3.21 AS resource-build

RUN apk add --no-cache ffmpeg

WORKDIR /src
COPY --from=source /src/resources ./resources

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

COPY --from=rust-build /tuliprox /app/tuliprox
COPY --from=web-build /src/frontend/dist /app/web
COPY --from=resource-build /src/resources /app/resources

COPY scripts/healthcheck.sh /usr/local/bin/healthcheck.sh

COPY root/ /
COPY scripts/ /scripts/

RUN chmod +x /app/tuliprox && \
    chmod +x /scripts/*.sh && \
    chmod +x /usr/local/bin/healthcheck.sh && \
    find /etc/openvpn -name 'update.sh' -exec chmod +x {} + && \
    find /etc/openvpn -name 'map.sh' -exec chmod +x {} + && \
    find /etc/openvpn -name 'up.sh' -exec chmod +x {} + && \
    find /etc/s6-overlay/s6-rc.d -name 'run' -exec chmod +x {} + && \
    find /etc/s6-overlay/s6-rc.d -name 'up' -exec chmod +x {} +

EXPOSE 8901/tcp

EXPOSE 8118/tcp

VOLUME ["/app/config", "/app/data", "/app/backup", "/app/downloads"]

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh
