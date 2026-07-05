#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$ROOT_DIR/build/release/dmg-staging/MonoList.app}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "缺少 App：$APP_PATH" >&2
  exit 1
fi

bundle_id="$(plutil -extract CFBundleIdentifier raw "$APP_PATH/Contents/Info.plist")"
[[ "$bundle_id" == "com.qingcheng.monolist.mac" ]] || {
  echo "Bundle ID 不正确：$bundle_id" >&2
  exit 1
}

signature_info="$(codesign -dv --verbose=4 "$APP_PATH" 2>&1 || true)"
if rg -q 'Signature=adhoc' <<<"$signature_info"; then
  echo "正式版本禁止使用 ad-hoc 签名。" >&2
  exit 1
fi

requirement="$(codesign -dr - "$APP_PATH" 2>&1 || true)"
if rg -q '^designated => cdhash ' <<<"$requirement"; then
  echo "正式版本 designated requirement 不能仅包含 cdhash。" >&2
  exit 1
fi
if ! rg -q 'identifier "com\.qingcheng\.monolist\.mac"' <<<"$requirement"; then
  echo "签名要求未包含固定 Bundle ID。" >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP_PATH" >/dev/null
echo "Release signature check passed."
