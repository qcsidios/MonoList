#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/tests"
TEST_EXECUTABLE="$BUILD_DIR/MenuBarBridgeSmoke"

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
