#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
: "${GLIDEMOUSE_UPDATE_DOWNLOAD_URL:?Provide an HTTPS URL prefix for versioned update downloads}"
python3 - <<'PY'
import os
from urllib.parse import urlparse
u=urlparse(os.environ['GLIDEMOUSE_UPDATE_DOWNLOAD_URL'])
if u.scheme != 'https' or not u.hostname or u.username or u.password or u.query or u.fragment:
    raise SystemExit('Download prefix must be an HTTPS URL without credentials, query or fragment.')
PY
APP=build/Release/GlideMouse.app
# Public updates must pass signature and notarization validation.
codesign --verify --deep --strict "$APP"
xcrun stapler validate "$APP"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")
mkdir -p build/Updates
ditto -c -k --sequesterRsrc --keepParent "$APP" "build/Updates/GlideMouse-$VERSION.zip"
.build/artifacts/sparkle/Sparkle/bin/generate_appcast --account app.glidemouse.desktop \
    --download-url-prefix "$GLIDEMOUSE_UPDATE_DOWNLOAD_URL" build/Updates
printf '%s\n' 'Signed update feed generated in build/Updates. Upload is a separate step.'
