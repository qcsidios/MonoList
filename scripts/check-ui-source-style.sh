#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TASK_LIST="$ROOT_DIR/MonoList/Tasks/TaskListView.swift"
SETTINGS="$ROOT_DIR/MonoList/Settings/SettingsView.swift"

if grep -q 'Image(systemName: "ellipsis")[[:space:]]*$' "$TASK_LIST" &&
   grep -q '\.offset(y:' "$TASK_LIST"; then
  echo "更多按钮图标不能用 offset 修正垂直位置。" >&2
  exit 1
fi

if ! grep -A18 'HeaderIconLabel(systemName: "ellipsis")' "$TASK_LIST" |
   grep -q '\.buttonStyle(HeaderIconButtonStyle())'; then
  echo "更多按钮必须保留和加号、设置一致的灰色圆角正方形背景。" >&2
  exit 1
fi

if grep -q 'NSComboBox' "$SETTINGS"; then
  echo "设置页下拉控件必须统一使用同一套弹出按钮样式。" >&2
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

echo "UI source style check passed."
