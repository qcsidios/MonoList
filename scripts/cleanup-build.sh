#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

rm -rf \
  "$ROOT_DIR/build/tests" \
  "$ROOT_DIR/build/release/dmg-staging"

find "$ROOT_DIR" -name .DS_Store -type f -delete

echo "已清理临时构建，仅保留 build/local 与 build/release 安装包。"
