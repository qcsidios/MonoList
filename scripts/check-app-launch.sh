#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/tests"
TEST_EXECUTABLE="$BUILD_DIR/AppLaunchSmoke"
APP_DIR="$ROOT_DIR/build/local/MonoList.app"
ICON_PNG="$ROOT_DIR/build/local/AppIcon.iconset/icon_512x512@2x.png"

mkdir -p "$BUILD_DIR"

swiftc \
  -parse-as-library \
  "$ROOT_DIR/Tests/AppLaunchSmoke.swift" \
  -o "$TEST_EXECUTABLE"

"$TEST_EXECUTABLE" "$APP_DIR" "$ICON_PNG"
