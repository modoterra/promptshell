#!/bin/sh

set -eu

repo_raw_base=${PSH_RAW_BASE:-https://raw.githubusercontent.com/modoterra/promptshell/main}
install_name=${PSH_INSTALL_NAME:-psh}

if [ -z "${PSH_INSTALL_DIR:-}" ]; then
  if [ -z "${HOME:-}" ]; then
    printf 'psh install: HOME is required unless PSH_INSTALL_DIR is set\n' >&2
    exit 2
  fi

  install_dir=$HOME/.local/bin
else
  install_dir=$PSH_INSTALL_DIR
fi

target=$install_dir/$install_name
tmp=$(mktemp)

cleanup() {
  rm -f "$tmp"
}

trap cleanup EXIT HUP INT TERM

script_dir=
if [ -f "$0" ]; then
  script_dir=$(CDPATH= cd "$(dirname "$0")" 2>/dev/null && pwd || printf '')
fi

local_psh=$script_dir/bin/psh.sh

if [ -n "$script_dir" ] && [ -f "$local_psh" ]; then
  cp "$local_psh" "$tmp"
else
  source_url=$repo_raw_base/bin/psh.sh

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$source_url" -o "$tmp"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$tmp" "$source_url"
  else
    printf 'psh install: curl or wget is required\n' >&2
    exit 2
  fi
fi

mkdir -p "$install_dir"

if command -v install >/dev/null 2>&1; then
  install -m 0755 "$tmp" "$target"
else
  cp "$tmp" "$target"
  chmod 0755 "$target"
fi

printf 'psh install: installed %s\n' "$target"

case :$PATH: in
  *:"$install_dir":*) ;;
  *)
    printf 'psh install: add %s to PATH to run `psh` directly\n' "$install_dir"
    ;;
esac
