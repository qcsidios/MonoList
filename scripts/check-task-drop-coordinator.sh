#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/tests"
TEST_EXECUTABLE="$BUILD_DIR/TaskDropCoordinatorSmoke"
mkdir -p "$BUILD_DIR"

swiftc -parse-as-library \
  "$ROOT_DIR/MonoList/Tasks/TaskItem.swift" \
  "$ROOT_DIR/MonoList/Tasks/TaskStore.swift" \
  "$ROOT_DIR/MonoList/Tasks/TaskDropCoordinator.swift" \
  "$ROOT_DIR/MonoList/Shared/AtomicFileWriter.swift" \
  "$ROOT_DIR/MonoList/Shared/AppError.swift" \
  "$ROOT_DIR/Tests/TaskDropCoordinatorSmoke.swift" \
  -o "$TEST_EXECUTABLE"

"$TEST_EXECUTABLE"
