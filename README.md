# tuliprox (s6 / Unraid-ready)

This repo builds a `tuliprox-vpn` container image that:

- Runs on **Alpine** (`brycelarge/alpine-baseimage:3.21`)
- Uses **s6-overlay** to supervise the `tuliprox` process
- Includes an **OpenVPN client** (CUSTOM configs or built-in providers)
- Includes optional **Privoxy** (HTTP proxy) for VPN-routed traffic
- Includes built-in **speed testing** tooling
- Supports Unraid-style runtime user mapping via **`PUID` / `PGID` / `UMASK`**

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

- **`8901/tcp`**


## VPN (OpenVPN)

This image can optionally run an OpenVPN client inside the container.

Required docker run flags:

```sh
--cap-add=NET_ADMIN --device=/dev/net/tun
```

Environment variables:

- **`VPN_ENABLED`**
  - Default: `false`
  - Set to `true` to enable OpenVPN.

- **`OPENVPN_PROVIDER`**
  - Default: `CUSTOM`
  - Supported:
    - `CUSTOM`
    - `PIA`
    - `SURFSHARK`
    - `VYPRVPN`
    - `IPVANISH`
    - `NORDVPN`
    - `PROTONVPN`

- **`OPENVPN_CONFIG`**
  - The config filename (with or without `.ovpn`).
  - If omitted, the first `*.ovpn` found in `/app/config/openvpn` is used.

When using providers (PIA/SURFSHARK/VYPRVPN/IPVANISH/NORDVPN/PROTONVPN), configs are downloaded on container start and staged into:

- `/app/config/openvpn/<provider>/`

You can set `OPENVPN_CONFIG` to a filename in that provider folder (with or without `.ovpn`).

Provider scripts live in the image at:

- `/etc/openvpn/<provider>/update.sh`

For full details, see:

- `/etc/openvpn/README.md`

For Surfshark, you can optionally generate a friendly-name mapping file:

```sh
/etc/openvpn/surfshark/map.sh
```

Which writes `/app/config/openvpn/surfshark_map.json`. If present, `OPENVPN_CONFIG` can be a friendly key like `za_johannesburg`.

- **`OPENVPN_USERNAME`** / **`OPENVPN_PASSWORD`**
  - Optional.
  - If your `.ovpn` uses `auth-user-pass`, credentials will be written to `/app/config/openvpn/openvpn-credentials.txt`.

- **`OPENVPN_OPTIONS`**
  - Optional extra OpenVPN CLI flags appended to the openvpn command.

- **`NAME_SERVERS`**
  - Optional comma-separated DNS servers (overwrites `/etc/resolv.conf`).

- **`LOCAL_NETWORK`**
  - Optional comma-separated CIDRs that should be routed outside the VPN tunnel (so you can still reach LAN services).


## Privoxy

Privoxy is optional and only runs when:

- `VPN_ENABLED=true`
- `PRIVOXY_ENABLED=true`

Ports:

- `8118/tcp`

Environment variables:

- **`PRIVOXY_ENABLED`**
  - Default: `false`

- **`PRIVOXY_PORT`**
  - Default: `8118`

- **`PRIVOXY_STARTUP_DELAY_SECS`**
  - Default: `10`
  - Delay before starting privoxy (gives OpenVPN time to come up).

Logs:

- `/app/config/logs/privoxy`


### Custom OpenVPN config (Unraid-friendly)

Mount your `.ovpn` files into:

- `/app/config/openvpn`

Example:

```sh
docker run --rm -it \
  --cap-add=NET_ADMIN --device=/dev/net/tun \
  -e VPN_ENABLED=true \
  -e OPENVPN_PROVIDER=CUSTOM \
  -e OPENVPN_CONFIG=my.ovpn \
  -e OPENVPN_USERNAME='user' \
  -e OPENVPN_PASSWORD='pass' \
  -v $(pwd)/config:/app/config \
  -p 8901:8901 \
  ghcr.io/brycelarge/tuliprox-vpn:latest
```


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


## Build

```sh
docker build -t tuliprox-s6 .
```

### Build script (latest + next)

This repo includes a build script similar to the HAProxy project.

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


## Unraid

See `UNRAID.md`.
