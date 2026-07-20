#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/tests"
TEST_EXECUTABLE="$BUILD_DIR/ReminderSchedulerSmoke"
APP_DELEGATE="$ROOT_DIR/MonoList/App/AppDelegate.swift"

mkdir -p "$BUILD_DIR"

POLLING_BLOCK="$(grep -A10 'scheduler.startPolling' "$APP_DELEGATE")"
if ! echo "$POLLING_BLOCK" | grep -q 'isSettingsVisible' ||
   ! echo "$POLLING_BLOCK" | grep -q 'reminderPanelController.*isVisible'; then
  echo "MonoList 主窗口、设置窗口或上一条提醒可见时，下一条提醒必须等待。" >&2
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
