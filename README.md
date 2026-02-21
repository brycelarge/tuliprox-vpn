# tuliprox VPN (Unraid-ready)

> [!NOTE]
> Credits to the tuliprox team and all contributors. Access the tuliprox documentation [here](https://github.com/euzu/tuliprox)

This repo builds a `tuliprox-vpn` container image that:

- Runs on **Alpine** (`brycelarge/alpine-baseimage:3.21`)
- Uses **s6-overlay** to supervise the `tuliprox` process
- Includes an **OpenVPN client** (CUSTOM configs or built-in providers) — sourced from [`brycelarge/openvpn-buildtools`](https://github.com/brycelarge/openvpn-buildtools)
- Includes optional **Privoxy** (HTTP proxy) for VPN-routed traffic
- Includes built-in **speed testing** tooling
- Supports Unraid-style runtime user mapping via **`PUID` / `PGID` / `UMASK`**
- Published automatically to `ghcr.io/brycelarge/tuliprox-vpn` via GitHub Actions

Upstream project: https://github.com/euzu/tuliprox


## What’s in the image

- **Binary**: `/app/tuliprox`
- **Web UI**: `/app/web` (built via `trunk`, copied from `frontend/dist`)
- **Resources**: `/app/resources` (includes generated `.ts` assets built in the image)
- **Config path**: `/app/config`

The container runs:

```sh
/app/tuliprox -s -p /app/config
```

You can append extra args via `TULIPROX_ARGS`.


## Environment variables

- **`PUID`**
  - Default: `133`
  - The container will adjust the internal `tuliprox` user to this UID at startup.

- **`PGID`**
  - Default: `144`
  - The container will adjust the internal `tuliprox` group to this GID at startup.

- **`UMASK`**
  - Default: `022`
  - Applied before launching `tuliprox` so newly created files follow your desired permissions.

- **`TZ`**
  - Default: `UTC`

- **`TULIPROX_ARGS`**
  - Optional. Appended to the default args (`-s -p /app/config`).


## Volumes

- **`/app/config`**
- **`/app/data`**
- **`/app/backup`**
- **`/app/downloads`**

On container start, an s6 init step will ensure these directories exist and will `chown -R` them to the runtime `PUID`/`PGID`.


## Ports

- **`8901/tcp`** — Tuliprox web UI and API (M3U, Xtream, EPG)
- **`5004/tcp`** — HDHomeRun emulation (Plex/Emby/Jellyfin DVR discovery)
- **`8118/tcp`** — Privoxy HTTP proxy (optional, only when `PRIVOXY_ENABLED=true`)


## VPN (OpenVPN) + Privoxy

OpenVPN and Privoxy support is provided by **[brycelarge/openvpn-buildtools](https://github.com/brycelarge/openvpn-buildtools)**.

For full documentation on environment variables, supported providers, custom configs, `LOCAL_NETWORK`, Privoxy, and more — see the [openvpn-buildtools README](https://github.com/brycelarge/openvpn-buildtools#readme).

> ⚠️ The container requires `--cap-add=NET_ADMIN` and `--device=/dev/net/tun` when `VPN_ENABLED=true`.
>
> ⚠️ Set `LOCAL_NETWORK` to your LAN subnet (e.g. `192.168.1.0/24`) or the web UI on port `8901` will be unreachable once the VPN connects.


## Speed test

The image includes a simple wrapper:

```sh
/scripts/speedtest.sh
```

By default it runs `speedtest-cli --simple`.


## Healthcheck

The image defines a Docker healthcheck:

```sh
/usr/local/bin/healthcheck.sh
```

Which runs:

```sh
/app/tuliprox -p /app/config --healthcheck
```


## Image

```
ghcr.io/brycelarge/tuliprox-vpn:latest   # master branch
ghcr.io/brycelarge/tuliprox-vpn:next     # develop branch
```

Builds are published automatically via GitHub Actions on push to `master` / `develop` and on version tags.


## Build locally

```sh
docker build -t tuliprox-vpn .
```

### Build script (latest + next)

This repo includes a build script.

Build both tags locally:

```sh
./scripts/build.sh
```

Build/push both tags to a repo:

```sh
./scripts/build.sh -p
```

Build only `latest` (master):

```sh
./scripts/build.sh -l
```

Build only `next` (develop):

```sh
./scripts/build.sh -n
```

### Build args

- **`TULIPROX_REF`** (default: `master`)
  - Git ref to build from the upstream repo.

- **`RUST_TARGET`** (default: `x86_64-unknown-linux-musl`)


## Run (plain Docker)

```sh
docker run --rm -it \
  -p 8901:8901 \
  -p 5004:5004 \
  -e TZ=Europe/Paris \
  -e PUID=99 \
  -e PGID=100 \
  -e UMASK=022 \
  -v $(pwd)/config:/app/config \
  -v $(pwd)/data:/app/data \
  -v $(pwd)/backup:/app/backup \
  -v $(pwd)/downloads:/app/downloads \
  --name tuliprox \
  tuliprox-s6
```


## Local development (docker compose)

A `docker-compose.yml` is included for local testing.

### 1. Create your `.env` file

Copy the example and fill in your credentials:

```sh
cp .env.example .env
```

Edit `.env`:

```sh
OPENVPN_USERNAME=your_service_username
OPENVPN_PASSWORD=your_service_password
OPENVPN_PROVIDER=NORDVPN
OPENVPN_CONFIG=us9196.nordvpn.com.udp

# ⚠️ Set this to your LAN subnet — required for web UI access when VPN is enabled
LOCAL_NETWORK=192.168.0.0/24
```

> The `.env` file is gitignored — never commit credentials.

For NordVPN, service credentials are found at:
https://my.nordaccount.com/dashboard/nordvpn/manual-configuration/

### 2. Configure `docker-compose.yml`

Key variables to set directly in `docker-compose.yml`:

| Variable | Default | Description |
|---|---|---|
| `VPN_ENABLED` | `false` | Set `true` to enable OpenVPN |
| `OPENVPN_PROVIDER` | `CUSTOM` | `NORDVPN`, `PIA`, `SURFSHARK`, `IPVANISH`, `VYPRVPN`, `PROTONVPN`, `CUSTOM` |
| `OPENVPN_CONFIG` | _(first .ovpn found)_ | Specific config filename |
| `OPENVPN_FORCE_UPDATE` | `false` | Set `true` to re-download provider configs |
| `PRIVOXY_ENABLED` | `false` | Enable Privoxy HTTP proxy on port 8118 |

### 3. Start

```sh
docker compose up -d
docker compose logs -f
```

### 4. Stop

```sh
docker compose down
```

### Notes

- Volumes are written to `./data/` (gitignored).
- Requires `NET_ADMIN` cap and `/dev/net/tun` device when `VPN_ENABLED=true` (already set in `docker-compose.yml`).
- The image is `linux/amd64` only — on Apple Silicon it runs under emulation.


## First boot

On first boot, if `/app/config/config.yml`, `source.yml`, or `api-proxy.yml` are missing, the container copies defaults from `/app/defaults/` automatically. The `api-proxy.yml` host IP is auto-detected from the container's LAN interface.

Edit the generated files in your config volume to suit your setup.


## Accessing playlists

After configuring `api-proxy.yml` with your credentials:

- **M3U**: `http://<host>:8901/get.php?username=<user>&password=<pass>`
- **Xtream Codes**: host `http://<host>:8901`, username/password as configured
- **EPG (XMLTV)**: `http://<host>:8901/xmltv.php?username=<user>&password=<pass>`
- **HDHomeRun discovery**: `http://<host>:5004/discover.json`


## api-proxy.yml

Required for playlist access. Minimum config:

```yaml
server:
  - name: default
    protocol: http
    host: 192.168.1.x   # your Unraid/host LAN IP
    port: '8901'
    timezone: UTC
    message: tuliprox

user:
  - target: my_target
    credentials:
      - username: myuser
        password: mypass
        proxy: reverse
        server: default
```

Usernames must be unique across all targets. The `target` name must match a target defined in `source.yml`.


## Unraid

See `UNRAID.md`.
