#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/tests"
BRIDGE_TEST="$BUILD_DIR/MenuBarBridgeSmoke"
HELPER_TEST="$BUILD_DIR/MenuBarServiceLifecycleSmoke"

mkdir -p "$BUILD_DIR"

if rg -q 'NSStatusBar\.system\.statusItem' \
  "$ROOT_DIR/MonoList/App/AppDelegate.swift"; then
  echo "主进程不能继续创建已被 macOS 隐藏的状态项。" >&2
  exit 1
fi

if ! rg -q 'launchMenuBarHelper' \
  "$ROOT_DIR/MonoList/App/AppDelegate.swift" ||
  ! rg -q 'openApplication' \
  "$ROOT_DIR/MonoList/App/AppDelegate.swift"; then
  echo "MonoList 必须通过 LaunchServices 启动独立菜单栏服务。" >&2
  exit 1
fi

if ! rg -q 'NSStatusBar\.system\.statusItem' \
  "$ROOT_DIR/MenuBarHelper/main.swift" ||
  ! rg -q 'MenuBarIconRenderer\.makeImage' \
  "$ROOT_DIR/MenuBarHelper/main.swift" ||
  ! rg -q 'MenuBarBridgeProtocol\.title' \
  "$ROOT_DIR/MenuBarHelper/main.swift"; then
  echo "菜单栏服务必须同时创建 Logo 和待办数量。" >&2
  exit 1
fi

if ! rg -q 'statusItemAutosaveName' \
  "$ROOT_DIR/MenuBarHelper/main.swift"; then
  echo "菜单栏服务必须使用新的稳定状态项名称。" >&2
  exit 1
fi

swiftc \
  -parse-as-library \
  "$ROOT_DIR/MonoList/App/MenuBarBridgeProtocol.swift" \
  "$ROOT_DIR/Tests/MenuBarBridgeSmoke.swift" \
  -o "$BRIDGE_TEST"

"$BRIDGE_TEST"

swiftc \
  "$ROOT_DIR/MonoList/App/MenuBarBridgeProtocol.swift" \
  "$ROOT_DIR/MonoList/App/MenuBarIconRenderer.swift" \
  "$ROOT_DIR/MenuBarHelper/main.swift" \
  -o "$HELPER_TEST"

"$HELPER_TEST" 999999 0 &
helper_pid=$!
for _ in {1..30}; do
  if ! kill -0 "$helper_pid" 2>/dev/null; then
    break
  fi
  sleep 0.1
done
if kill -0 "$helper_pid" 2>/dev/null; then
  kill "$helper_pid" 2>/dev/null || true
  wait "$helper_pid" 2>/dev/null || true
  echo "菜单栏服务必须在主进程退出后自动结束。" >&2
  exit 1
fi
wait "$helper_pid" 2>/dev/null || true

echo "Menu bar bridge smoke passed."
