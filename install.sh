#!/usr/bin/env bash
#
# install.sh — idempotent installer for cryo.
#
# Remote (no clone needed):
#   curl -fsSL https://raw.githubusercontent.com/nadimtuhin/cryo/main/install.sh | bash
#
set -euo pipefail

REPO_URL="https://github.com/nadimtuhin/cryo.git"
RAW_URL="https://raw.githubusercontent.com/nadimtuhin/cryo/main"
DEST_DIR="/usr/local/bin"
DEST="$DEST_DIR/cryo"

# ── colors ───────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'
c_red()   { echo -e "${RED}$*${NC}" >&2; }
c_green() { echo -e "${GREEN}$*${NC}"; }
c_bold()  { echo -e "${BOLD}$*${NC}"; }

die() { c_red "error: $*"; exit 1; }

# ── checks ───────────────────────────────────────────────
check_env() {
  if [ "$(id -u)" -ne 0 ] && [ ! -w "$DEST_DIR" ]; then
    die "Write access to $DEST_DIR is required. Please run with sudo or as administrator."
  fi
}

install() {
  c_bold "Installing cryo..."
  
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

main() {
  case "${1:-}" in
    --uninstall|-u)
      check_env
      uninstall
      ;;
    --help|-h)
      echo "Usage: install.sh [--uninstall]"
      ;;
    "")
      check_env
      install
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
}
main "$@"
