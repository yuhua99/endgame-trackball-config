#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./build.sh [-o DIR] [-t TARGET] [--help]

  -o, --output DIR   Move the UF2 artifact to DIR after build completes.
  -t, --target NAME  Build only the named target (primary|studio). Defaults to primary.
  --help             Show this message.

The script builds a single west target per invocation.
It expects:
  * a Python venv at .venv (created with `uv venv` or similar)
  * Zephyr SDK installed (override ZEPHYR_SDK_INSTALL_DIR if not /root/zephyr-sdk-0.17.4)

Targets:
  primary  -> build/default/zephyr/zmk.uf2
  studio   -> build/studio-rpc-usb-uart/zephyr/zmk.uf2 (uses SNIPPET=studio-rpc-usb-uart)
EOF
}

OUTPUT_DIR=""
TARGET="primary"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -o|--output)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "error: '--output' expects a directory path." >&2
        usage
        exit 1
      fi
      OUTPUT_DIR="$2"
      shift 2
      ;;
    -t|--target)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "error: '--target' expects a name." >&2
        usage
        exit 1
      fi
      TARGET="$2"
      shift 2
      ;;
    *)
      echo "error: unknown option '$1'" >&2
      usage
      exit 1
      ;;
  esac
done

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

PRIMARY_BUILD_DIR="$REPO_ROOT/build/default"
PRIMARY_UF2="$PRIMARY_BUILD_DIR/zephyr/zmk.uf2"

case "$TARGET" in
  primary)
    BUILD_DIR="$PRIMARY_BUILD_DIR"
    UF2_PATH="$PRIMARY_UF2"
    CMAKE_ARGS=()
    ;;
  studio)
    BUILD_DIR="$REPO_ROOT/build/studio-rpc-usb-uart"
    UF2_PATH="$BUILD_DIR/zephyr/zmk.uf2"
    CMAKE_ARGS=(-DSNIPPET=studio-rpc-usb-uart)
    ;;
  *)
    echo "error: unknown target '$TARGET' (expected primary or studio)" >&2
    exit 1
    ;;
esac

build_once "$BUILD_DIR" "${CMAKE_ARGS[@]}"

if [[ -n "$OUTPUT_DIR" ]]; then
  mkdir -p "$OUTPUT_DIR"
  DEST="$OUTPUT_DIR/$(basename "$UF2_PATH")"
  log_step "Moving UF2 to $DEST"
  mv "$UF2_PATH" "$DEST"
  UF2_PATH="$DEST"
fi

echo
echo "Target: $TARGET"
echo "UF2: $UF2_PATH"
