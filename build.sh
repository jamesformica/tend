#!/bin/bash
# Builds Tend.app for local installation.
#
# Usage:
#   ./build.sh           # build only, outputs build/Tend.app
#   ./build.sh run       # build + launch (without installing to /Applications)
#   ./build.sh install   # build + copy to /Applications
#   ./build.sh reset     # quit app + wipe persisted plant/lineage state

set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Tend"
BUNDLE_ID="com.tend.Tend"
VERSION="0.1.0"
BUILD_NUMBER="$(date +%s)"
MIN_MACOS="13.0"
CONFIG="${CONFIG:-release}"
STATE_DIR="${HOME}/Library/Application Support/${APP_NAME}"

if [[ "${1:-}" == "reset" ]]; then
    if pgrep -x "${APP_NAME}" > /dev/null; then
        echo "→ Quitting running ${APP_NAME}…"
        osascript -e "tell application \"${APP_NAME}\" to quit" 2>/dev/null || true
        sleep 0.5
        pkill -x "${APP_NAME}" 2>/dev/null || true
    fi
    if [[ -d "${STATE_DIR}" ]]; then
        rm -rf "${STATE_DIR}"
        echo "✓ Wiped ${STATE_DIR}"
    else
        echo "✓ No state to wipe (${STATE_DIR} not present)"
    fi
    exit 0
fi

echo "→ Building ${APP_NAME} ${VERSION} (build ${BUILD_NUMBER})…"
swift build -c "${CONFIG}"

BINARY=".build/${CONFIG}/${APP_NAME}"
if [[ ! -f "${BINARY}" ]]; then
    echo "✗ Build artifact not found at ${BINARY}" >&2
    exit 1
fi

APP_BUNDLE="build/${APP_NAME}.app"
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BINARY}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

cat > "${APP_BUNDLE}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key>
    <string>${MIN_MACOS}</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Ad-hoc sign so macOS treats the bundle as valid.
SIGN_IDENTITY="${TEND_SIGN_IDENTITY:--}"
codesign --force --sign "${SIGN_IDENTITY}" "${APP_BUNDLE}" 2>&1 | grep -v "replacing existing signature" || true

echo "✓ Built ${APP_BUNDLE}"

SUBCOMMAND="${1:-}"
case "${SUBCOMMAND}" in
    run)
        if pgrep -x "${APP_NAME}" > /dev/null; then
            echo "→ Quitting running ${APP_NAME}…"
            osascript -e "tell application \"${APP_NAME}\" to quit" 2>/dev/null || true
            sleep 0.5
            pkill -x "${APP_NAME}" 2>/dev/null || true
        fi
        open "${APP_BUNDLE}"
        echo "✓ Launched"
        ;;
    install)
        if pgrep -x "${APP_NAME}" > /dev/null; then
            echo "→ Quitting running ${APP_NAME}…"
            osascript -e "tell application \"${APP_NAME}\" to quit" 2>/dev/null || true
            sleep 0.5
            pkill -x "${APP_NAME}" 2>/dev/null || true
        fi
        rm -rf "/Applications/${APP_NAME}.app"
        cp -R "${APP_BUNDLE}" "/Applications/${APP_NAME}.app"
        touch "/Applications/${APP_NAME}.app"
        echo "✓ Installed /Applications/${APP_NAME}.app"
        ;;
    "")
        echo ""
        echo "  Run:      ./build.sh run"
        echo "  Install:  ./build.sh install"
        echo "  Reset:    ./build.sh reset"
        ;;
    *)
        echo "✗ Unknown subcommand: ${SUBCOMMAND}" >&2
        exit 1
        ;;
esac
