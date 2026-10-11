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
                echo "  -t, --token-file FILE   Path to file containing service account token"
                echo "  -h, --help              Show this help"
                echo ""
                echo "Environment variables:"
                echo "  GRAFANA_TOKEN_FILE      Path to token file"
                echo "  GRAFANA_TOKEN           Token directly (not recommended)"
              }

              GRAFANA_TOKEN="''${GRAFANA_TOKEN:-}"
              TOKEN_FILE="''${GRAFANA_TOKEN_FILE:-}"
              URL=""

              while [[ $# -gt 0 ]]; do
                case "$1" in
                  -t|--token-file)
                    TOKEN_FILE="$2"
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

              # Read token from file if specified
              if [[ -n "$TOKEN_FILE" ]] && [[ -f "$TOKEN_FILE" ]]; then
                GRAFANA_TOKEN="$(cat "$TOKEN_FILE")"
              fi

              # Append auth_token to URL if token provided
              if [[ -n "$GRAFANA_TOKEN" ]]; then
                if [[ "$URL" == *"?"* ]]; then
                  URL="$URL&auth_token=$GRAFANA_TOKEN"
                else
                  URL="$URL?auth_token=$GRAFANA_TOKEN"
                fi
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

            tokenFile = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = "/etc/gf-playlist-token";
              description = "Path to file containing Grafana service account token";
            };
          };

          config = lib.mkIf cfg.enable {
            assertions = [
              {
                assertion = cfg.url != "";
                message = "services.grafana-playlist-viewer.url must be set";
              }
            ];

            environment.systemPackages = [
              (pkgs.symlinkJoin {
                name = "grafana-playlist-viewer";
                paths = [
                  (pkgs.writeShellApplication {
                    name = "grafana-playlist-viewer";

                    runtimeInputs = [ pkgs.firefox ];

                    text = ''
                      PROFILE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/grafana-playlist-viewer"
                      mkdir -p "$PROFILE_DIR"

                      # Read token from file
                      GRAFANA_TOKEN=""
                      ${lib.optionalString (cfg.tokenFile != null) ''
                      if [ -f "${cfg.tokenFile}" ]; then
                        GRAFANA_TOKEN="$(cat "${cfg.tokenFile}")"
                      fi
                      ''}

                      # Build URL with auth_token parameter
                      GRAFANA_URL="${cfg.url}"
                      if [ -n "$GRAFANA_TOKEN" ]; then
                        if [[ "$GRAFANA_URL" == *"?"* ]]; then
                          GRAFANA_URL="$GRAFANA_URL&auth_token=$GRAFANA_TOKEN"
                        else
                          GRAFANA_URL="$GRAFANA_URL?auth_token=$GRAFANA_TOKEN"
                        fi
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
                  (pkgs.makeDesktopItem {
                    name = "grafana-playlist-viewer";
                    desktopName = "Grafana Playlist Viewer";
                    comment = "Borderless Firefox kiosk for Grafana playlists";
                    exec = "grafana-playlist-viewer";
                    icon = "grafana";
                    categories = [ "Utility" "Network" ];
                    terminal = false;
                  })
                ];
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
