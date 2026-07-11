#!/usr/bin/env bash
#
# install.sh — idempotent installer for cryo.
#
# Remote (no clone needed):
#   curl -fsSL https://raw.githubusercontent.com/nadimtuhin/cryo/main/install.sh | bash
#
set -euo pipefail

RAW_URL="https://raw.githubusercontent.com/nadimtuhin/cryo/main"
DEST_DIR="/usr/local/bin"
DEST="$DEST_DIR/cryo"

# Fall back to ~/.local/bin if /usr/local/bin isn't writable and we're not root
if [ "$(id -u)" -ne 0 ] && [ ! -w "$DEST_DIR" ]; then
  DEST_DIR="$HOME/.local/bin"
  DEST="$DEST_DIR/cryo"
  mkdir -p "$DEST_DIR"
fi

# ── colors ───────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'
c_red()   { echo -e "${RED}$*${NC}" >&2; }
c_green() { echo -e "${GREEN}$*${NC}"; }
c_bold()  { echo -e "${BOLD}$*${NC}"; }

die() { c_red "error: $*"; exit 1; }

install() {
  c_bold "Installing cryo to $DEST..."
  
  # Download from raw GitHub url
  local tmp
  tmp=$(mktemp "/tmp/cryo-install-XXXXXX")
  
  if curl -fsSL "$RAW_URL/cryo" -o "$tmp"; then
    mv "$tmp" "$DEST"
    chmod +x "$DEST"
    c_green "Successfully installed cryo to $DEST"
  else
    rm -f "$tmp"
    die "Failed to download cryo from $RAW_URL/cryo"
  fi
}

uninstall() {
  if [ -f "$DEST" ]; then
    rm -f "$DEST"
    c_green "Removed $DEST"
  else
    echo "cryo is not installed at $DEST."
  fi
}

PLIST_LABEL="com.nadimtuhin.cryo"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"
LOG_PATH="$HOME/.local/logs/cryo.log"

install_daemon() {
  [ "$(uname)" = "Darwin" ] || die "daemon install only supports macOS (launchd)"
  [ -x "$DEST" ] || die "cryo not installed at $DEST — run install.sh first"
  mkdir -p "$(dirname "$LOG_PATH")" "$(dirname "$PLIST_PATH")"
  cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key><string>$PLIST_LABEL</string>
	<key>ProgramArguments</key><array><string>$DEST</string></array>
	<key>RunAtLoad</key><true/>
	<key>KeepAlive</key><true/>
	<key>ProcessType</key><string>Background</string>
	<key>StandardOutPath</key><string>$LOG_PATH</string>
	<key>StandardErrorPath</key><string>$LOG_PATH</string>
</dict>
</plist>
EOF
  launchctl unload "$PLIST_PATH" 2>/dev/null || true
  launchctl load "$PLIST_PATH" || die "launchctl load failed"
  c_green "cryo daemon installed and running (launchd: $PLIST_LABEL)"
  c_bold "Logs: $LOG_PATH"
}

uninstall_daemon() {
  [ -f "$PLIST_PATH" ] || { echo "cryo daemon is not installed."; return; }
  launchctl unload "$PLIST_PATH" 2>/dev/null || true
  rm -f "$PLIST_PATH"
  c_green "Removed cryo daemon ($PLIST_LABEL)"
}

main() {
  case "${1:-}" in
    --uninstall|-u)
      uninstall
      ;;
    --daemon)
      install_daemon
      ;;
    --uninstall-daemon)
      uninstall_daemon
      ;;
    --help|-h)
      echo "Usage: install.sh [--uninstall|--daemon|--uninstall-daemon]"
      echo "  (no args)          install cryo binary"
      echo "  --uninstall        remove cryo binary"
      echo "  --daemon           run cryo continuously via launchd (macOS, auto-restart)"
      echo "  --uninstall-daemon stop and remove the launchd daemon"
      ;;
    "")
      install
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
}
main "$@"
