#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if git -C "$ROOT_DIR" ls-files | grep -qE '(^|/)\.DS_Store$'; then
  echo "仓库中不能跟踪 .DS_Store。" >&2
  exit 1
fi

for path in MonoList Tests scripts docs release-notes; do
  [[ -d "$ROOT_DIR/$path" ]] || {
    echo "缺少项目目录：$path" >&2
    exit 1
  }
done

for script in \
  build-local.sh \
  package-dmg.sh \
  release.sh \
  cleanup-build.sh; do
  [[ -f "$ROOT_DIR/scripts/$script" ]] || {
    echo "缺少构建脚本：$script" >&2
    exit 1
  }
done

echo "Project integrity check passed."
