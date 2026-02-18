# Unraid Deployment (Community Apps)

This container is intended to behave like typical Unraid/LSIO-style containers.


## Installing via Community Apps (easiest)

1. In Unraid, go to the **Apps** tab (install Community Apps plugin if not already installed)
2. Search for **tuliprox-vpn**
3. Click **Install** and fill in your VPN credentials and `LOCAL_NETWORK`
4. Click **Apply**

> If the app isn't showing yet, you can install it manually by adding the template URL directly:
> **Apps → Settings → Add another template repository** → paste:
> ```
> https://raw.githubusercontent.com/brycelarge/unraid-templates/main
> ```
> Then search for **tuliprox-vpn**.


## Manual template fields

### Repository

Set to your published image name, e.g.

- `ghcr.io/<you>/tuliprox:latest`

For you:

- `ghcr.io/brycelarge/tuliprox-vpn:latest`


### Network / Ports

| Container Port | Protocol | Description |
|---|---|---|
| `8901` | TCP | Tuliprox web UI, M3U, Xtream Codes, EPG |
| `5004` | TCP | HDHomeRun emulation (Plex/Emby/Jellyfin DVR) |
| `8118` | TCP | Privoxy HTTP proxy (optional) |


### Path mappings

Map these as **Paths** (not Variables):

- **`/app/config`**
  - Suggested host path: `/mnt/user/appdata/tuliprox/config`

- **`/app/data`**
  - Suggested host path: `/mnt/user/appdata/tuliprox/data`

- **`/app/backup`**
  - Suggested host path: `/mnt/user/appdata/tuliprox/backup`

- **`/app/downloads`**
  - Suggested host path: `/mnt/user/appdata/tuliprox/downloads`

If using OpenVPN, place your `.ovpn` files under:

- `/mnt/user/appdata/tuliprox/config/openvpn`


## Variables (Unraid)

Add these as **Variables** in the template.

- **`PUID`**
  - Default: `99` (typical Unraid `nobody`)
  - Description: UID the process should run as.

- **`PGID`**
  - Default: `100` (typical Unraid `users`)
  - Description: GID the process should run as.

- **`UMASK`**
  - Default: `022`
  - Description: Permissions mask for newly created files.

- **`TZ`**
  - Default: `UTC`

- **`TULIPROX_ARGS`** (optional)
  - Description: Extra CLI args appended to `tuliprox`.


## VPN (OpenVPN)

### Required “Extra Parameters”

If you enable the VPN, set Unraid template “Extra Parameters” to:

```sh
--cap-add=NET_ADMIN --device=/dev/net/tun
```

### Variables

- **`VPN_ENABLED`**
  - Default: `false`
  - Set to `true` to enable OpenVPN.

- **`OPENVPN_PROVIDER`**
  - Default: `CUSTOM`
  - Supported: `CUSTOM`, `PIA`, `SURFSHARK`, `VYPRVPN`, `IPVANISH`, `NORDVPN`, `PROTONVPN`

- **`OPENVPN_CONFIG`**
  - Optional.
  - Example: `my.ovpn` (with or without `.ovpn`).
  - If omitted, the first `*.ovpn` file in `/app/config/openvpn` will be used.

When using providers (PIA/SURFSHARK/VYPRVPN/IPVANISH/NORDVPN/PROTONVPN), configs are downloaded on container start and staged into:

- `/mnt/user/appdata/tuliprox/config/openvpn/<provider>/`

- **`OPENVPN_USERNAME`** / **`OPENVPN_PASSWORD`**
  - Optional (only required if your `.ovpn` uses `auth-user-pass`).

- **`OPENVPN_OPTIONS`**
  - Optional extra flags passed to `openvpn`.

- **`NAME_SERVERS`**
  - Optional comma-separated DNS servers.

- **`LOCAL_NETWORK`**
  - Optional comma-separated CIDRs to route outside the tunnel.

- **`PRIVOXY_ENABLED`**
  - Default: `false`
  - Only works when `VPN_ENABLED=true`.

- **`PRIVOXY_PORT`**
  - Default: `8118`

- **`PRIVOXY_STARTUP_DELAY_SECS`**
  - Default: `10`


## Speed test

Exec into the container and run:

```sh
/scripts/speedtest.sh
```


## What happens on container start

- An s6 oneshot init service adjusts the internal `tuliprox` user/group to match `PUID`/`PGID`.
- It ensures the `/app/*` mapped directories exist.
- It recursively `chown`s the mapped directories so you don’t fight permissions on Unraid.
- `UMASK` is applied right before `tuliprox` is exec’d.


## Quick verification (permissions)

After starting, you should see the mapped folders owned by your configured IDs (e.g. `99:100`).


## Example Unraid settings (typical)

- **PUID**: `99`
- **PGID**: `100`
- **UMASK**: `022`
- **Host Port**: `8901`


## Notes

- If your mapped directories contain a large amount of data, the startup `chown -R` can take time.
- If you want to disable recursive chown or make it conditional, tell me and I’ll add a toggle like `CHOWN_ON_START=true/false`.
