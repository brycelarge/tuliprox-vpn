# Built-in OpenVPN providers

This image ships provider helper scripts under `/etc/openvpn/<provider>/`.

These scripts download OpenVPN configuration bundles from the provider and normalize them (line endings, deprecated options, auth-user-pass path, etc.).

## Providers

- `pia`
- `surfshark`
- `vyprvpn`
- `ipvanish`
- `nordvpn`
- `protonvpn`

## Usage

### 1) Enable VPN and pick a provider

Set:

- `VPN_ENABLED=true`
- `OPENVPN_PROVIDER` = `PIA` | `SURFSHARK` | `VYPRVPN` | `IPVANISH` | `NORDVPN` | `PROTONVPN` | `CUSTOM`

On container start, the service `init-openvpn-config` will:

- Run `/etc/openvpn/<provider>/update.sh` (if present)
- Stage the downloaded configs into:
  - `/app/config/openvpn/<provider>/`
- Generate a `list.txt` of available `.ovpn` files

### 2) Select a config

Set `OPENVPN_CONFIG` to the desired filename.

- You may specify with or without `.ovpn`
- For providers, config files are searched inside `/app/config/openvpn/<provider>/`
- For `CUSTOM`, config files are searched in `/app/config/openvpn/`

`OPENVPN_PROTOCOL` influences selection when a provider uses `_udp` / `_tcp` suffixes.

### 3) Credentials

If you provide:

- `OPENVPN_USERNAME`
- `OPENVPN_PASSWORD`

Then credentials are written to:

- `/app/config/openvpn/custom-openvpn-credentials.txt` (CUSTOM)
- `/app/config/openvpn/<provider>-openvpn-credentials.txt` (providers)

The `.ovpn` will be rewritten to reference the correct credentials file.

## Surfshark friendly mapping (optional)

You can generate a friendly-name mapping file:

```sh
/etc/openvpn/surfshark/map.sh
```

This writes:

- `/app/config/openvpn/surfshark_map.json`

If present, `OPENVPN_CONFIG` can be a friendly key like `za_johannesburg` and it will be mapped to Surfshark’s internal connection name.
