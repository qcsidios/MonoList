#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/tests"
TEST_EXECUTABLE="$BUILD_DIR/AppSettingsSmoke"

mkdir -p "$BUILD_DIR"

swiftc \
  -parse-as-library \
  "$ROOT_DIR/MonoList/Settings/AppSettings.swift" \
  "$ROOT_DIR/MonoList/Shared/AtomicFileWriter.swift" \
  "$ROOT_DIR/Tests/AppSettingsSmoke.swift" \
  -o "$TEST_EXECUTABLE"

"$TEST_EXECUTABLE"
