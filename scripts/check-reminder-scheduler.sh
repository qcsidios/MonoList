#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/tests"
TEST_EXECUTABLE="$BUILD_DIR/ReminderSchedulerSmoke"
APP_DELEGATE="$ROOT_DIR/MonoList/App/AppDelegate.swift"

mkdir -p "$BUILD_DIR"

if grep -A8 'scheduler.startPolling' "$APP_DELEGATE" |
   grep -q 'isSettingsVisible'; then
  echo "提醒到期不应因为设置窗口打开而延后。" >&2
  exit 1
fi

swiftc \
  -parse-as-library \
  "$ROOT_DIR/MonoList/Tasks/TaskItem.swift" \
  "$ROOT_DIR/MonoList/Settings/AppSettings.swift" \
  "$ROOT_DIR/MonoList/Shared/AtomicFileWriter.swift" \
  "$ROOT_DIR/MonoList/Reminder/ReminderView.swift" \
  "$ROOT_DIR/MonoList/Reminder/ReminderPanelController.swift" \
  "$ROOT_DIR/MonoList/Reminder/ReminderScheduler.swift" \
  "$ROOT_DIR/Tests/ReminderSchedulerSmoke.swift" \
  -o "$TEST_EXECUTABLE"

"$TEST_EXECUTABLE"
