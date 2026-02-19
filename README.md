# tuliprox VPN (Unraid-ready)

> [!NOTE]
> Credits to the tuliprox team and all contributors. Access the tuliprox documentation [here](https://github.com/euzu/tuliprox)

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


## EPG Scraper (built-in)

The container includes an optional EPG scraper powered by [iptv-org/epg](https://github.com/iptv-org/epg). When enabled, it clones and installs the scraper at runtime (nothing is bundled in the image), scrapes TV guide data directly from broadcaster websites (100+ supported), and serves `guide.xml` locally on port `3002`.

### Environment variables

- **`EPG_SCRAPER_ENABLED`** — Default: `false`. Set to `true` to enable.
- **`EPG_GRAB_DAYS`** — Default: `3`. Days of EPG data to fetch per run.
- **`EPG_GRAB_INTERVAL`** — Default: `86400`. Re-scrape interval in seconds (24h).
- **`EPG_SERVE_PORT`** — Default: `3002`. Port to serve `guide.xml` on.

### How it works

1. On first start, `iptv-org/epg` is cloned into `/app/epg-scraper` (not persisted — re-cloned if missing).
2. A default DStv ZA `channels.xml` is copied to `/app/epg/channels.xml` if none exists.
3. An initial grab runs immediately, then repeats every `EPG_GRAB_INTERVAL` seconds.
4. `guide.xml` is served at `http://localhost:3002/guide.xml`.

### Referencing in source.yml

```yaml
epg:
  sources:
    - url: http://127.0.0.1:3002/guide.xml
```

### channels.xml

Edit `/app/epg/channels.xml` to control which channels are scraped. Find your provider's site and channel IDs at https://github.com/iptv-org/epg/tree/master/sites.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<channels>
  <channel site="example.com" site_id="channel_id" lang="en" xmltv_id="">Channel Name</channel>
</channels>
```


## Volumes

- **`/app/config`**
- **`/app/data`**
- **`/app/backup`**
- **`/app/downloads`**
- **`/app/epg`** — EPG scraper output (only needed when `EPG_SCRAPER_ENABLED=true`)

On container start, an s6 init step will ensure these directories exist and will `chown -R` them to the runtime `PUID`/`PGID`.


## Ports

- **`8901/tcp`** — Tuliprox web UI and API (M3U, Xtream, EPG)
- **`5004/tcp`** — HDHomeRun emulation (Plex/Emby/Jellyfin DVR discovery)
- **`8118/tcp`** — Privoxy HTTP proxy (optional, only when `PRIVOXY_ENABLED=true`)
- **`3002/tcp`** — EPG scraper guide server (optional, only when `EPG_SCRAPER_ENABLED=true`)


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

When using providers (PIA/SURFSHARK/VYPRVPN/IPVANISH/NORDVPN/PROTONVPN), configs are downloaded on first container start and staged into the config volume at:

- `/app/config/openvpn/<provider>/`

**Configs are persisted across restarts** — the download only happens once (when the provider directory doesn't exist yet).

You can set `OPENVPN_CONFIG` to a filename in that provider folder (with or without `.ovpn`).

Provider scripts live in the image at:

- `/etc/openvpn/<provider>/update.sh`

#### Force re-download of provider configs

To re-download configs (e.g. after a provider updates their servers), either:

**Option A** — set the env var (re-downloads on next start, then resets):
```yaml
- OPENVPN_FORCE_UPDATE=true
```

**Option B** — delete the staged provider directory from your config volume:
```sh
rm -rf ./data/config/openvpn/nordvpn   # replace nordvpn with your provider
docker compose restart
```

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

- **`LOCAL_NETWORK`** ⚠️ **Required when `VPN_ENABLED=true` if you want to access the web UI or any LAN service**
  - Comma-separated CIDRs that should be routed **outside** the VPN tunnel via your local gateway.
  - When OpenVPN connects it takes over the default route — without this, all traffic (including port 8901) goes through the tunnel and your host machine can no longer reach the container.
  - Set this to your LAN subnet. Common values:
    ```
    LOCAL_NETWORK=192.168.0.0/24
    LOCAL_NETWORK=192.168.1.0/24
    LOCAL_NETWORK=10.0.0.0/24
    ```
  - Multiple subnets (comma-separated):
    ```
    LOCAL_NETWORK=192.168.0.0/24,10.0.0.0/8
    ```
  - Set in your `.env` file:
    ```sh
    LOCAL_NETWORK=192.168.0.0/24
    ```
  - **If the tuliprox web UI (port 8901) stops responding after VPN connects, this is the fix.**


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
