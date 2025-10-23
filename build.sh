#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./build.sh [--help]

  --help   Show this message.

The script builds both the primary firmware and the CI snippet (studio-rpc-usb-uart).
It expects:
  * a Python venv at .venv (created with `uv venv` or similar)
  * Zephyr SDK installed (override ZEPHYR_SDK_INSTALL_DIR if not /root/zephyr-sdk-0.17.4)

Artifacts:
  Primary build UF2    -> build/default/zephyr/zmk.uf2
  Snippet build UF2    -> build/studio-rpc-usb-uart/zephyr/zmk.uf2
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ $# -gt 0 ]]; then
  echo "error: unknown option '$1'" >&2
  usage
  exit 1
fi

REPO_ROOT="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_ACTIVATE="$REPO_ROOT/.venv/bin/activate"

if [[ ! -f "$VENV_ACTIVATE" ]]; then
  echo "error: Python venv not found at $VENV_ACTIVATE" >&2
  echo "       create it with 'uv venv .venv' before running this script." >&2
  exit 1
fi

source "$VENV_ACTIVATE"

export ZEPHYR_TOOLCHAIN_VARIANT="${ZEPHYR_TOOLCHAIN_VARIANT:-zephyr}"
export ZEPHYR_SDK_INSTALL_DIR="${ZEPHYR_SDK_INSTALL_DIR:-/root/zephyr-sdk-0.17.4}"
export CCACHE_DIR="${CCACHE_DIR:-$REPO_ROOT/.ccache}"
export CCACHE_TEMPDIR="${CCACHE_TEMPDIR:-$CCACHE_DIR/tmp}"
mkdir -p "$CCACHE_DIR"
mkdir -p "$CCACHE_TEMPDIR"

if [[ ! -d "$ZEPHYR_SDK_INSTALL_DIR" ]]; then
  echo "error: Zephyr SDK directory '$ZEPHYR_SDK_INSTALL_DIR' not found." >&2
  echo "       set ZEPHYR_SDK_INSTALL_DIR to your SDK path before running." >&2
  exit 1
fi

if ! command -v west >/dev/null 2>&1; then
  echo "error: 'west' not found in PATH; install it with 'uv pip install west' inside the venv." >&2
  exit 1
fi

PRISTINE_FLAG="-p"

log_step() {
  echo
  echo "==> $*"
}

build_once() {
  local build_dir="$1"
  shift
  local cmake_args=("$@")

  log_step "west build $PRISTINE_FLAG -d $build_dir -b efogtech_trackball_0 $REPO_ROOT/zmk/app -- ${cmake_args[*]}"
  west build "$PRISTINE_FLAG" \
    -d "$build_dir" \
    -b efogtech_trackball_0 \
    "$REPO_ROOT/zmk/app" \
    -- -DBOARD_ROOT="$REPO_ROOT" -DZMK_CONFIG="$REPO_ROOT/config" "${cmake_args[@]}"
}

build_once "$REPO_ROOT/build/default"
build_once "$REPO_ROOT/build/studio-rpc-usb-uart" -DSNIPPET=studio-rpc-usb-uart

echo
echo "Primary UF2: $REPO_ROOT/build/default/zephyr/zmk.uf2"
echo "Snippet UF2: $REPO_ROOT/build/studio-rpc-usb-uart/zephyr/zmk.uf2"
