#!/usr/bin/env bash
# 构建 WhaleBar.app：SPM 编译 + 手工组装 bundle + ad-hoc 签名
# 用法: ./Scripts/build_app.sh [--debug] [--open] [--clean]
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="release"
OPEN=false
for arg in "$@"; do
  case "$arg" in
    --debug) CONFIG="debug" ;;
    --open)  OPEN=true ;;
    --clean) rm -rf build .build; echo "已清理 build/ 与 .build/"; exit 0 ;;
  esac
done

echo "▸ swift build -c $CONFIG"
swift build -c "$CONFIG"
BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)"

APP_DIR="build/WhaleBar.app"
echo "▸ 组装 $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_PATH/WhaleBar" "$APP_DIR/Contents/MacOS/WhaleBar"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"

echo "▸ ad-hoc 签名"
codesign --force --sign - "$APP_DIR"

echo "✅ 构建完成: $PWD/$APP_DIR"
if [[ "$OPEN" == true ]]; then
  open "$APP_DIR"
fi
