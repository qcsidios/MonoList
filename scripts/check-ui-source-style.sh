#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TASK_LIST="$ROOT_DIR/MonoList/Tasks/TaskListView.swift"
TASK_ROW="$ROOT_DIR/MonoList/Tasks/TaskRowView.swift"
WINDOW_COORDINATOR="$ROOT_DIR/MonoList/App/WindowCoordinator.swift"
SETTINGS="$ROOT_DIR/MonoList/Settings/SettingsView.swift"

if grep -q 'Image(systemName: "ellipsis")[[:space:]]*$' "$TASK_LIST" &&
   grep -q '\.offset(y:' "$TASK_LIST"; then
  echo "更多按钮图标不能用 offset 修正垂直位置。" >&2
  exit 1
fi

HEADER_ICON_BLOCK="$(awk '
  /private struct HeaderIconLabel/ { capture = 1 }
  /private struct TaskDragPreview/ { capture = 0 }
  capture { print }
' "$TASK_LIST")"
if echo "$HEADER_ICON_BLOCK" | grep -qE '\.background|\.overlay|RoundedRectangle'; then
  echo "主窗口顶部三个图标按钮必须统一无背景，不画灰色圆角矩形。" >&2
  exit 1
fi

if grep -q 'NSComboBox' "$SETTINGS"; then
  echo "设置页下拉控件必须统一使用同一套弹出按钮样式。" >&2
  exit 1
fi

if grep -q '\.toggleStyle(.switch)' "$SETTINGS" ||
   ! grep -q 'SettingsSwitchStyle' "$SETTINGS"; then
  echo "设置页开关必须使用项目内固定样式，避免系统 switch 重装后丢失白色滑块。" >&2
  exit 1
fi

if ! grep -q 'SettingValueBackground' "$SETTINGS"; then
  echo "设置内容框必须复用统一的灰色圆角矩形样式。" >&2
  exit 1
fi

if ! grep -q 'private static let controlWidth: CGFloat = 180' "$SETTINGS"; then
  echo "轻提醒卡片右侧控件必须统一为 180pt 宽。" >&2
  exit 1
fi

if ! grep -q 'maxVisibleItems: 8' "$SETTINGS" ||
   ! grep -q 'ScrollView(.vertical' "$SETTINGS"; then
  echo "时间选择下拉框必须限高为最多 8 项，并允许内部滚动。" >&2
  exit 1
fi

if grep -q '\.frame(width: 88' "$TASK_ROW" ||
   grep -q 'Color.clear.frame(width: 56' "$TASK_ROW"; then
  echo "待办行右侧不能为隐藏提醒按钮预留大块空白。" >&2
  exit 1
fi

if grep -q 'Image(systemName: "bell")' "$TASK_ROW" &&
   ! grep -q 'private var reminderStatusLine' "$TASK_ROW"; then
  echo "提醒状态应显示在待办正文下方，不应占用右侧操作区。" >&2
  exit 1
fi

if ! grep -q 'ReminderTimeDropdown' "$TASK_ROW" ||
   ! grep -q 'private static let maxVisibleItems = 8' "$TASK_ROW"; then
  echo "单条提醒时间必须拆成小时/分钟两个限高下拉框。" >&2
  exit 1
fi

if ! grep -q 'ScrollViewReader' "$TASK_LIST" ||
   ! grep -q 'scrollTo("task-draft-row"' "$TASK_LIST"; then
  echo "长列表新增待办必须自动滚动到草稿输入行。" >&2
  exit 1
fi

CONTINUE_DRAFT_BLOCK="$(awk '
  /private func continueDraft\(\)/ { capture = 1 }
  /private func selectTask/ { capture = 0 }
  capture { print }
' "$TASK_LIST")"
if ! echo "$CONTINUE_DRAFT_BLOCK" | grep -q 'draftScrollRequest = UUID()'; then
  echo "连续新增待办时必须再次滚动到草稿输入行。" >&2
  exit 1
fi

if ! grep -q 'func dropExited' "$TASK_LIST" ||
   ! grep -q 'coordinator.clearTarget()' "$TASK_LIST"; then
  echo "取消或移出拖拽目标时必须清除分组落点状态。" >&2
  exit 1
fi

if grep -q 'event.window !== panel && event.window?.level != .statusBar' "$WINDOW_COORDINATOR"; then
  echo "点击提醒浮层、菜单或下拉时不应被误判为主窗口外点击。" >&2
  exit 1
fi

echo "UI source style check passed."
