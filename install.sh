#!/bin/bash

set -euo pipefail

REPO="e7d/gnome-displays"
VERSION="${GNOME_DISPLAYS_VERSION:-latest}"

if [[ "$VERSION" == "latest" ]]; then
  RELEASE_URL="https://github.com/$REPO/releases/latest/download"
else
  RELEASE_URL="https://github.com/$REPO/releases/download/v${VERSION#v}"
fi
SCRIPT_URL="$RELEASE_URL/gnome-displays.sh"
SUMS_URL="$RELEASE_URL/SHA256SUMS"

INSTALL_DIR="${GNOME_DISPLAYS_INSTALL_DIR:-$HOME/.local/bin}"
INSTALL_PATH="$INSTALL_DIR/gnome-displays"

bold() { printf '\033[1m%s\033[0m\n' "$1"; }
err() { echo "$@" >&2; }
die() {
  err "Error: $*"
  exit 1
}
have() { command -v "$1" &>/dev/null; }

# under `curl | bash`, stdin is the script itself, so prompts must use the tty
if [[ -r /dev/tty ]]; then
  TTY=/dev/tty
else
  TTY=""
fi

confirm() {
  [[ -n "$TTY" ]] || return 1
  local reply
  read -rp "$1" reply <"$TTY"
  [[ "$reply" =~ ^[Yy]$ ]]
}

fetch() {
  if have curl; then
    curl -fsSL "$1"
  else
    wget -qO- "$1"
  fi
}

verify_checksum() {
  local file="$1"
  if ! have sha256sum; then
    err "Note: sha256sum unavailable; skipping checksum verification."
    return 0
  fi
  local sums expected actual
  if ! sums=$(fetch "$SUMS_URL" 2>/dev/null); then
    err "Note: could not fetch SHA256SUMS; skipping checksum verification."
    return 0
  fi
  expected=$(echo "$sums" | awk '$2 == "gnome-displays.sh" { print $1 }')
  [[ -n "$expected" ]] || die "gnome-displays.sh not listed in SHA256SUMS."
  actual=$(sha256sum "$file" | cut -d' ' -f1)
  [[ "$actual" == "$expected" ]] ||
    die "Checksum mismatch (expected $expected, got $actual)."
}

warn_missing_dependencies() {
  local deps=(jq gdctl gawk column gdbus systemctl) missing=() dep
  for dep in "${deps[@]}"; do
    have "$dep" || missing+=("$dep")
  done
  [[ ${#missing[@]} -eq 0 ]] && return 0
  err ""
  err "Missing dependencies: ${missing[*]}"
  err "Install them with your package manager for full functionality."
}

warn_path() {
  case ":$PATH:" in
  *":$INSTALL_DIR:"*) return 0 ;;
  esac
  err ""
  err "Note: $INSTALL_DIR is not on your PATH. Add it, e.g.:"
  err "  fish:     fish_add_path $INSTALL_DIR"
  err "  bash/zsh: export PATH=\"$INSTALL_DIR:\$PATH\""
}

main() {
  have curl || have wget || die "Need curl or wget to download."

  echo "Installing gnome-displays ($VERSION) from $SCRIPT_URL"

  local tmp
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' EXIT

  fetch "$SCRIPT_URL" >"$tmp" || die "Download failed (no release for '$VERSION'?)."
  [[ -s "$tmp" ]] || die "Download was empty."
  head -n1 "$tmp" | grep -q '^#!' || die "Download does not look like a script."
  verify_checksum "$tmp"

  mkdir -p "$INSTALL_DIR"
  install -m 755 "$tmp" "$INSTALL_PATH"
  bold "Installed $("$INSTALL_PATH" version)"

  warn_path
  warn_missing_dependencies

  if confirm "Install the auto-apply service now? [y/N]: "; then
    "$INSTALL_PATH" service --install
  else
    echo ""
    echo "To enable auto-apply later: gnome-displays service --install"
  fi

  echo ""
  echo "Done. Try: gnome-displays help"
}

main "$@"
