#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
xcodebuild -project GlideMouse.xcodeproj -scheme GlideMouse -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath build/Xcode CODE_SIGNING_ALLOWED=NO build
mkdir -p build/Release
APP=build/Release/GlideMouse.app
ditto build/Xcode/Build/Products/Release/GlideMouse.app "$APP"
python3 Scripts/configure-update-build.py "$APP/Contents/Info.plist"
FW="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
SIGN_ID=${GLIDEMOUSE_SIGN_IDENTITY:--}
for item in "$FW/XPCServices/Downloader.xpc" "$FW/XPCServices/Installer.xpc" "$FW/Updater.app" "$FW/Autoupdate"; do
    codesign --force --options runtime --preserve-metadata=entitlements --sign "$SIGN_ID" "$item"
done
codesign --force --options runtime --sign "$SIGN_ID" "$APP/Contents/Frameworks/Sparkle.framework"
codesign --force --options runtime --entitlements Config/GlideMouse.entitlements --sign "$SIGN_ID" "$APP"
codesign --verify --deep --strict "$APP"
lipo -info "$APP/Contents/MacOS/GlideMouse"
STAGE=$(mktemp -d "$PWD/build/dmg-stage.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/GlideMouse.app"
ln -s /Applications "$STAGE/Applications"
cp LICENSE THIRD_PARTY_NOTICES.md "$STAGE/"
RELEASE_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
DMG="build/Release/GlideMouse-$RELEASE_VERSION-developer.dmg"
ZIP="build/Release/GlideMouse-$RELEASE_VERSION-developer.zip"
hdiutil create -volname GlideMouse -srcfolder "$STAGE" -ov -format UDZO "$DMG"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
shasum -a 256 "$DMG" "$ZIP" > build/Release/SHA256SUMS.txt
if [[ -n "${GLIDEMOUSE_NOTARY_PROFILE:-}" && "$SIGN_ID" != "-" ]]; then
    xcrun notarytool submit "$DMG" --keychain-profile "$GLIDEMOUSE_NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP"
    xcrun stapler staple "$DMG"
    xcrun stapler validate "$DMG"
    ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
    shasum -a 256 "$DMG" "$ZIP" > build/Release/SHA256SUMS.txt
fi
printf '%s\n' "Local developer artifacts saved in build/Release. Public publication and hardware beta remain separate."
