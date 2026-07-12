#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/tests"
TEST_EXECUTABLE="$BUILD_DIR/MenuBarBridgeSmoke"
HELPER_EXECUTABLE="$BUILD_DIR/MonoListMenuBarLifecycleSmoke"

mkdir -p "$BUILD_DIR"

if ! grep -q 'button?.image = MenuBarIconRenderer.makeImage()' \
  "$ROOT_DIR/MenuBarHelper/main.swift"; then
  echo "菜单栏必须显示 MonoList Logo 图标。" >&2
  exit 1
fi

swiftc \
  -parse-as-library \
  "$ROOT_DIR/MonoList/App/MenuBarBridgeProtocol.swift" \
  "$ROOT_DIR/Tests/MenuBarBridgeSmoke.swift" \
  -o "$TEST_EXECUTABLE"

"$TEST_EXECUTABLE"

swiftc \
  "$ROOT_DIR/MonoList/App/MenuBarBridgeProtocol.swift" \
  "$ROOT_DIR/MenuBarHelper/main.swift" \
  -o "$HELPER_EXECUTABLE"

"$HELPER_EXECUTABLE" 999999 0 &
helper_pid=$!
sleep 1
if kill -0 "$helper_pid" 2>/dev/null; then
  kill "$helper_pid" 2>/dev/null || true
  wait "$helper_pid" 2>/dev/null || true
  echo "菜单栏辅助进程必须在父进程退出后自动结束。" >&2
  exit 1
fi
wait "$helper_pid" 2>/dev/null || true
