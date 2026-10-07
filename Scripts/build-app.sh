#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
MODE=${1:-release}
if [[ "$MODE" == "universal" ]]; then
    swift build -c release --arch arm64 --arch x86_64
    BIN_DIR=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)
else
    swift build -c "$MODE"
    BIN_DIR=$(swift build -c "$MODE" --show-bin-path)
fi
APP=build/GlideMouse.app
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN_DIR/GlideMouse" "$APP/Contents/MacOS/GlideMouse"
ditto "$BIN_DIR/GlideMouse_GlideMouse.bundle" "$APP/Contents/Resources/GlideMouse_GlideMouse.bundle"
ditto "$BIN_DIR/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Config/Info.plist "$APP/Contents/Info.plist"
if ! otool -l "$APP/Contents/MacOS/GlideMouse" | rg -q '@executable_path/../Frameworks'; then
    install_name_tool -add_rpath '@executable_path/../Frameworks' "$APP/Contents/MacOS/GlideMouse"
fi
# Ad-hoc signature is a local development identity, never a notarized release claim.
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
printf '%s\n' "Built $APP (ad-hoc local developer build)"
