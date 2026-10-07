#!/usr/bin/env python3
"""Inject a chosen HTTPS feed and release version before signing the app."""
import os, plistlib, re, sys
from pathlib import Path
from urllib.parse import urlparse
path = Path(sys.argv[1])
data = plistlib.loads(path.read_bytes())
feed = os.environ.get('GLIDEMOUSE_UPDATE_FEED_URL', '')
if feed:
    url = urlparse(feed)
    if url.scheme != 'https' or not url.hostname or url.username or url.password or url.fragment:
        raise SystemExit('Update feed must be an HTTPS URL without credentials or fragment.')
    data['SUFeedURL'] = feed
version = os.environ.get('GLIDEMOUSE_RELEASE_VERSION', '')
build = os.environ.get('GLIDEMOUSE_RELEASE_BUILD', '')
if bool(version) != bool(build):
    raise SystemExit('Provide release version and build together.')
if version:
    if not re.fullmatch(r'\d+(?:\.\d+){1,2}', version) or not re.fullmatch(r'[1-9]\d*', build):
        raise SystemExit('Release version must be numeric and build must be a positive integer.')
    data['CFBundleShortVersionString'] = version
    data['CFBundleVersion'] = build
path.write_bytes(plistlib.dumps(data))
