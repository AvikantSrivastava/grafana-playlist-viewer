{
  description = "grafana-playlist-viewer - Borderless Firefox kiosk for Grafana playlists";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      pkgsFor = system: nixpkgs.legacyPackages.${system};
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = self.packages.${system}.grafana-playlist-viewer;

          grafana-playlist-viewer = pkgs.writeShellApplication {
            name = "grafana-playlist-viewer";

            runtimeInputs = [ pkgs.firefox ];

            text = ''
              usage() {
                echo "Usage: grafana-playlist-viewer [OPTIONS] <URL>"
                echo ""
                echo "Options:"
                echo "  -u, --user USER         Grafana username (default: admin)"
                echo "  -p, --password-file FILE  Path to file containing password"
                echo "  -h, --help              Show this help"
                echo ""
                echo "Environment variables:"
                echo "  GRAFANA_USER            Grafana username"
                echo "  GRAFANA_PASSWORD_FILE   Path to password file"
                echo "  GRAFANA_PASSWORD        Password (not recommended, use file instead)"
              }

              GRAFANA_USER="''${GRAFANA_USER:-admin}"
              GRAFANA_PASSWORD="''${GRAFANA_PASSWORD:-}"
              PASSWORD_FILE="''${GRAFANA_PASSWORD_FILE:-}"
              URL=""

              while [[ $# -gt 0 ]]; do
                case "$1" in
                  -u|--user)
                    GRAFANA_USER="$2"
                    shift 2
                    ;;
                  -p|--password-file)
                    PASSWORD_FILE="$2"
                    shift 2
                    ;;
                  -h|--help)
                    usage
                    exit 0
                    ;;
                  -*)
                    echo "Unknown option: $1" >&2
                    usage >&2
                    exit 1
                    ;;
                  *)
                    URL="$1"
                    shift
                    ;;
                esac
              done

              if [[ -z "$URL" ]]; then
                echo "Error: URL is required" >&2
                usage >&2
                exit 1
              fi

              # Read password from file if specified
              if [[ -n "$PASSWORD_FILE" ]] && [[ -f "$PASSWORD_FILE" ]]; then
                GRAFANA_PASSWORD="$(cat "$PASSWORD_FILE")"
              fi

              # Build URL with auth if password provided
              if [[ -n "$GRAFANA_PASSWORD" ]]; then
                URL="''${URL//:\/\/://$GRAFANA_USER:$GRAFANA_PASSWORD@}"
              fi

              PROFILE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/grafana-playlist-viewer"
              mkdir -p "$PROFILE_DIR"

              # Create Firefox user.js for kiosk-like behavior
              cat > "$PROFILE_DIR/user.js" << 'EOF'
              user_pref("browser.shell.checkDefaultBrowser", false);
              user_pref("browser.sessionstore.resume_from_crash", false);
              user_pref("browser.startup.homepage_override.mstone", "ignore");
              user_pref("browser.tabs.warnOnClose", false);
              user_pref("browser.warnOnQuit", false);
              user_pref("toolkit.startup.max_resumed_crashes", -1);
              user_pref("browser.cache.disk.enable", false);
              user_pref("browser.cache.memory.enable", true);
              user_pref("browser.chrome.toolbar_tips", false);
              user_pref("browser.fullscreen.autohide", true);
              user_pref("full-screen-api.ignore-widgets", true);
              user_pref("full-screen-api.warning.timeout", 0);
              user_pref("privacy.trackingprotection.enabled", false);
              user_pref("network.cookie.cookieBehavior", 0);
              user_pref("dom.webnotifications.enabled", false);
              user_pref("permissions.default.desktop-notification", 2);
              user_pref("app.update.enabled", false);
              user_pref("app.update.auto", false);
              EOF

              exec firefox --kiosk --profile "$PROFILE_DIR" --no-remote "$URL"
            '';
          };
        });

      nixosModules.default = { config, lib, pkgs, ... }:
        let
          cfg = config.services.grafana-playlist-viewer;
        in
        {
          options.services.grafana-playlist-viewer = {
            enable = lib.mkEnableOption "grafana-playlist-viewer kiosk";

            url = lib.mkOption {
              type = lib.types.str;
              example = "https://grafana.example.com/playlists/play/1";
              description = "Grafana playlist URL to display";
            };

            username = lib.mkOption {
              type = lib.types.str;
              default = "admin";
              description = "Grafana username for authentication";
            };

            passwordFile = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = "/etc/gf-playlist-passwd";
              description = "Path to file containing Grafana password";
            };
          };

          config = lib.mkIf cfg.enable {
            assertions = [
              {
                assertion = cfg.url != "";
                message = "services.grafana-playlist-viewer.url must be set";
              }
            ];

            # Create password file with secure permissions
            environment.etc."gf-playlist-passwd" = lib.mkIf (cfg.passwordFile == "/etc/gf-playlist-passwd") {
              mode = "0600";
              text = ""; # Placeholder - user must populate this file
            };

            environment.systemPackages = [
              (pkgs.writeShellApplication {
                name = "grafana-playlist-viewer";

                runtimeInputs = [ pkgs.firefox ];

                text = ''
                  PROFILE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/grafana-playlist-viewer"
                  mkdir -p "$PROFILE_DIR"

                  # Read password from file
                  GRAFANA_PASSWORD=""
                  ${lib.optionalString (cfg.passwordFile != null) ''
                  if [ -f "${cfg.passwordFile}" ]; then
                    GRAFANA_PASSWORD="$(cat "${cfg.passwordFile}")"
                  fi
                  ''}

                  # Build URL with auth
                  GRAFANA_URL="${cfg.url}"
                  if [ -n "$GRAFANA_PASSWORD" ]; then
                    GRAFANA_URL=$(echo "${cfg.url}" | sed "s|://|://${cfg.username}:$GRAFANA_PASSWORD@|")
                  fi

                  # Create Firefox user.js for kiosk-like behavior
                  cat > "$PROFILE_DIR/user.js" << 'EOF'
                  user_pref("browser.shell.checkDefaultBrowser", false);
                  user_pref("browser.sessionstore.resume_from_crash", false);
                  user_pref("browser.startup.homepage_override.mstone", "ignore");
                  user_pref("browser.tabs.warnOnClose", false);
                  user_pref("browser.warnOnQuit", false);
                  user_pref("toolkit.startup.max_resumed_crashes", -1);
                  user_pref("browser.cache.disk.enable", false);
                  user_pref("browser.cache.memory.enable", true);
                  user_pref("browser.chrome.toolbar_tips", false);
                  user_pref("browser.fullscreen.autohide", true);
                  user_pref("full-screen-api.ignore-widgets", true);
                  user_pref("full-screen-api.warning.timeout", 0);
                  user_pref("privacy.trackingprotection.enabled", false);
                  user_pref("network.cookie.cookieBehavior", 0);
                  user_pref("dom.webnotifications.enabled", false);
                  user_pref("permissions.default.desktop-notification", 2);
                  user_pref("app.update.enabled", false);
                  user_pref("app.update.auto", false);
                  EOF

                  exec firefox --kiosk --profile "$PROFILE_DIR" --no-remote "$GRAFANA_URL"
                '';
              })
            ];
          };
        };

      devShells = forAllSystems (system:
        let pkgs = pkgsFor system;
        in {
          default = pkgs.mkShell {
            buildInputs = [
              pkgs.firefox
              pkgs.shellcheck
            ];
          };
        });
    };
}
