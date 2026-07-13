#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [[ -d "$ROOT_DIR/build" ]]; then
  find "$ROOT_DIR/build" -type d -name '*.app' -prune -exec rm -rf {} +
fi

rm -rf \
  "$ROOT_DIR/build/tests" \
  "$ROOT_DIR/build/release/dmg-staging" \
  "$ROOT_DIR/build/local"

find "$ROOT_DIR" -name .DS_Store -type f -delete

echo "已清理测试 App 与临时构建，仅保留 build/release 安装包。"
