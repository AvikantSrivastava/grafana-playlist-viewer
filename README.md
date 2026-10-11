# grafana-playlist-viewer

Borderless Firefox kiosk for displaying Grafana playlists and dashboards.

## Installation

### NixOS Module

Add to your `flake.nix` inputs:

```nix
{
  inputs.grafana-playlist-viewer.url = "github:AvikantSrivastava/grafana-playlist-viewer";
}
```

Then in your NixOS configuration:

```nix
{ config, pkgs, ... }:
let
  flake = builtins.getFlake "github:AvikantSrivastava/grafana-playlist-viewer";
in
{
  imports = [ flake.nixosModules.default ];

  services.grafana-playlist-viewer = {
    enable = true;
    url = "http://localhost:3001/d/ad2lg4r/cpu?orgId=1&kiosk=tv";
    tokenFile = "/etc/gf-playlist-token";  # default
  };
}
```

### Service Account Token Setup

1. In Grafana, go to **Administration** → **Users and access** → **Service accounts**
2. Click **Add service account**, name it `kiosk-viewer`, set role to `Viewer`
3. Click on the account, then **Add service account token**
4. Copy the generated token

Create the token file:

```bash
echo "glsa_xxxxxxxxxxxx" | sudo tee /etc/gf-playlist-token
sudo chmod 640 /etc/gf-playlist-token
sudo chown root:users /etc/gf-playlist-token
```

### Rebuild

```bash
sudo nixos-rebuild switch
```

## Usage

After installation, run from rofi or terminal:

```bash
grafana-playlist-viewer
```

## Standalone Usage (without NixOS module)

```bash
# Basic usage (no auth)
nix run github:AvikantSrivastava/grafana-playlist-viewer -- "http://grafana:3000/d/dashboard"

# With service account token
nix run github:AvikantSrivastava/grafana-playlist-viewer -- \
  -t /etc/gf-playlist-token \
  "http://grafana:3000/d/dashboard"

# Using environment variables
GRAFANA_TOKEN_FILE=/etc/gf-playlist-token \
nix run github:AvikantSrivastava/grafana-playlist-viewer -- "http://grafana:3000/d/dashboard"
```

## Options

### CLI Options

| Option | Description |
|--------|-------------|
| `-t, --token-file FILE` | Path to file containing service account token |
| `-h, --help` | Show help |

### Environment Variables

| Variable | Description |
|----------|-------------|
| `GRAFANA_TOKEN_FILE` | Path to token file |
| `GRAFANA_TOKEN` | Token directly (not recommended) |

### NixOS Module Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable the viewer |
| `url` | string | - | Grafana URL to display |
| `tokenFile` | path | `"/etc/gf-playlist-token"` | Path to service account token file |

## Tips

- Add `?kiosk=tv` to your Grafana URL for a cleaner display
- Firefox profile is stored in `~/.local/state/grafana-playlist-viewer/`
- Press `F11` or `Esc` to exit kiosk mode
