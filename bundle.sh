#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

APP_VERSION="${APP_VERSION:-1.2.0M}"
echo "==> Building FinderPlus v${APP_VERSION} (Release)..."
swift build -c release

APP_NAME="FinderPlus.app"
APP_DIR="./build/${APP_NAME}"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
PREVIEWS_DIR="${CONTENTS_DIR}/PREVIEWS"

echo "==> Packaging into ${APP_NAME}..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}" "${PREVIEWS_DIR}"

cp .build/release/FinderPlus "${MACOS_DIR}/FinderPlus"
chmod +x "${MACOS_DIR}/FinderPlus"

cat << EOF > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>FinderPlus</string>
    <key>CFBundleIdentifier</key>
    <string>com.shawnlee.FinderPlus</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>FinderPlus</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1200</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "APPL????" > "${CONTENTS_DIR}/PkgInfo"

echo "==> Successfully created ${APP_DIR}"
echo "Preview cache directory: ${PREVIEWS_DIR}"
echo "You can launch it with: open ${APP_DIR}"
