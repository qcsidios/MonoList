#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/tests"
TEST_EXECUTABLE="$BUILD_DIR/StatusItemLabelSmoke"

mkdir -p "$BUILD_DIR"

swiftc \
  -parse-as-library \
  "$ROOT_DIR/MonoList/App/StatusItemLabel.swift" \
  "$ROOT_DIR/Tests/StatusItemLabelSmoke.swift" \
  -o "$TEST_EXECUTABLE"

"$TEST_EXECUTABLE"
