#!/bin/bash
# Pin.app 번들을 만든다.
#
# 사용법:
#   ./bin/build-app.sh                # ./Pin.app 으로 빌드
#   ./bin/build-app.sh --install      # ~/Applications/Pin.app 로 설치
#
# Pin.app 자체는 .gitignore에 들어있다 — 사용자 머신에서 한 번 빌드.

set -e

cd "$(dirname "$0")/.."
PROJECT_ROOT="$PWD"
APP_NAME="Pin"
TARGET_NAME="Pin"
INSTALL=0

if [[ "${1:-}" == "--install" ]]; then
  INSTALL=1
fi

echo "==> Building release binary"
swift build -c release

BIN_PATH="$PROJECT_ROOT/.build/release/$TARGET_NAME"
if [[ ! -f "$BIN_PATH" ]]; then
  echo "❌ Release binary not found at $BIN_PATH"
  exit 1
fi

APP_BUNDLE="$PROJECT_ROOT/$APP_NAME.app"
echo "==> Constructing app bundle at $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# SPM이 생성한 리소스 번들들을 .app 안에 동봉.
# `Bundle.module`이 `Bundle.main.bundleURL/<name>.bundle` 을 찾기 때문에 .app 루트에 둔다.
RELEASE_DIR="$(dirname "$BIN_PATH")"
for bundle in "$RELEASE_DIR"/*.bundle; do
  [[ -e "$bundle" ]] || continue
  cp -R "$bundle" "$APP_BUNDLE/"
done

if [[ -f "$PROJECT_ROOT/AppIcon.icns" ]]; then
  cp "$PROJECT_ROOT/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.pin.sidecar</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# self-signed (codesign)으로 Gatekeeper의 "처음 실행" 흐름이 부드러워짐.
# 서명 실패는 무시 (개발 환경에서 ad-hoc).
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || true

echo "✅ Built: $APP_BUNDLE"

if [[ $INSTALL -eq 1 ]]; then
  DEST_DIR="$HOME/Applications"
  mkdir -p "$DEST_DIR"
  DEST="$DEST_DIR/$APP_NAME.app"
  rm -rf "$DEST"
  mv "$APP_BUNDLE" "$DEST"
  echo "✅ Installed: $DEST"
  echo "   → Spotlight (⌘Space) 'Pin' 또는 Dock에 끌어다 놓기"
else
  echo "   → 'open $APP_BUNDLE' 또는 ~/Applications 으로 끌어다 놓기"
fi
