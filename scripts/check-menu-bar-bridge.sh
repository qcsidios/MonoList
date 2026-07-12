#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/tests"
TEST_EXECUTABLE="$BUILD_DIR/MenuBarBridgeSmoke"

mkdir -p "$BUILD_DIR"

if ! grep -q 'NSStatusBar.system.statusItem' \
  "$ROOT_DIR/MonoList/App/AppDelegate.swift"; then
  echo "MonoList 主进程必须直接创建菜单栏状态项。" >&2
  exit 1
fi

if ! grep -q '^@main$' "$ROOT_DIR/MonoList/App/AppDelegate.swift"; then
  echo "MonoList 菜单栏入口必须由 AppKit 应用生命周期托管。" >&2
  exit 1
fi

if rg -q 'NSApplicationDelegateAdaptor' "$ROOT_DIR/MonoList/App"; then
  echo "MonoList 不能再由 SwiftUI App 生命周期托管菜单栏入口。" >&2
  exit 1
fi

if grep -q 'launchMenuBarHelper' "$ROOT_DIR/MonoList/App/AppDelegate.swift"; then
  echo "MonoList 不能再依赖菜单栏辅助进程。" >&2
  exit 1
fi

if ! grep -q 'button?.image = MenuBarIconRenderer.makeImage()' \
  "$ROOT_DIR/MonoList/App/AppDelegate.swift"; then
  echo "菜单栏必须显示 MonoList Logo 图标。" >&2
  exit 1
fi

if grep -q 'autosaveName' "$ROOT_DIR/MonoList/App/AppDelegate.swift"; then
  echo "MonoList 状态项不能继承系统保存的隐藏位置。" >&2
  exit 1
fi

if ! grep -q 'statusItem(withLength: NSStatusItem.variableLength)' \
  "$ROOT_DIR/MonoList/App/AppDelegate.swift"; then
  echo "MonoList 状态项必须同时容纳 Logo 和待办数量。" >&2
  exit 1
fi

if ! awk '
  /NSStatusBar\.system\.statusItem/ { status = NR }
  /let applicationSupportURL/ { support = NR }
  END { exit !(status > 0 && support > 0 && status < support) }
' "$ROOT_DIR/MonoList/App/AppDelegate.swift"; then
  echo "MonoList 必须在加载数据和窗口前注册状态项。" >&2
  exit 1
fi

if ! grep -q 'application.setActivationPolicy(.accessory)' \
  "$ROOT_DIR/MonoList/App/AppDelegate.swift" ||
  grep -q 'NSApp.setActivationPolicy(.regular)' \
  "$ROOT_DIR/MonoList/App/AppDelegate.swift"; then
  echo "MonoList 必须保持 accessory 激活策略。" >&2
  exit 1
fi

if ! awk '
  /application\.setActivationPolicy\(\.accessory\)/ { policy = NR }
  /application\.run\(\)/ { run = NR }
  END { exit !(policy > 0 && run > 0 && policy < run) }
' "$ROOT_DIR/MonoList/App/AppDelegate.swift"; then
  echo "MonoList 必须在启动事件循环前设置 accessory 激活策略。" >&2
  exit 1
fi

swiftc \
  -parse-as-library \
  "$ROOT_DIR/MonoList/App/MenuBarBridgeProtocol.swift" \
  "$ROOT_DIR/Tests/MenuBarBridgeSmoke.swift" \
  -o "$TEST_EXECUTABLE"

"$TEST_EXECUTABLE"
