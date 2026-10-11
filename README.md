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
    username = "admin";
    passwordFile = "/etc/gf-playlist-passwd";  # default
  };
}
```

### Password Setup

Create the password file:

```bash
echo "your-grafana-password" | sudo tee /etc/gf-playlist-passwd
sudo chmod 600 /etc/gf-playlist-passwd
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
# Basic usage
nix run github:AvikantSrivastava/grafana-playlist-viewer -- "http://grafana:3000/d/dashboard"

# With authentication
nix run github:AvikantSrivastava/grafana-playlist-viewer -- \
  -u admin \
  -p /etc/gf-playlist-passwd \
  "http://grafana:3000/d/dashboard"

# Using environment variables
GRAFANA_USER=admin \
GRAFANA_PASSWORD_FILE=/etc/gf-playlist-passwd \
nix run github:AvikantSrivastava/grafana-playlist-viewer -- "http://grafana:3000/d/dashboard"
```

## Options

### CLI Options

| Option | Description |
|--------|-------------|
| `-u, --user USER` | Grafana username (default: admin) |
| `-p, --password-file FILE` | Path to file containing password |
| `-h, --help` | Show help |

### Environment Variables

| Variable | Description |
|----------|-------------|
| `GRAFANA_USER` | Grafana username |
| `GRAFANA_PASSWORD_FILE` | Path to password file |
| `GRAFANA_PASSWORD` | Password directly (not recommended) |

### NixOS Module Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable the viewer |
| `url` | string | - | Grafana URL to display |
| `username` | string | `"admin"` | Grafana username |
| `passwordFile` | path | `"/etc/gf-playlist-passwd"` | Path to password file |

## Tips

- Add `?kiosk=tv` to your Grafana URL for a cleaner display
- Firefox profile is stored in `~/.local/state/grafana-playlist-viewer/`
- Press `F11` or `Esc` to exit kiosk mode
