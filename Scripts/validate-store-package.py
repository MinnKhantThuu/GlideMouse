#!/usr/bin/env python3
"""Validate the exported Store payload, not just the Xcode source settings.

This checks signing and packaging only. It does not certify App Review policy
compliance, runtime permissions, or physical mouse behavior.
"""
import argparse
import json
import plistlib
import subprocess
import tempfile
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('package', type=Path)
parser.add_argument('--team-id', required=True)
parser.add_argument('--build-number', required=True)
args = parser.parse_args()

def run(*command):
    return subprocess.check_output(command, stderr=subprocess.STDOUT)

with tempfile.TemporaryDirectory(prefix='glidemouse-store-validation-') as temp:
    target = Path(temp) / 'expanded'
    package_signature = run('pkgutil', '--check-signature', str(args.package.resolve())).decode()
    assert f'3rd Party Mac Developer Installer:' in package_signature
    assert f'({args.team_id})' in package_signature
    run('pkgutil', '--expand-full', str(args.package.resolve()), str(target))
    apps = [p for p in target.rglob('*.app') if (p / 'Contents/MacOS/GlideMouse').is_file()]
    assert len(apps) == 1, 'Expected one self-contained GlideMouse app'
    app = apps[0]
    run('codesign', '--verify', '--deep', '--strict', str(app))
    signature = run('codesign', '-dvv', str(app)).decode()
    assert 'Authority=Apple Distribution:' in signature
    assert f'TeamIdentifier={args.team_id}' in signature
    raw = subprocess.check_output(['codesign', '-d', '--entitlements', ':-', str(app)], stderr=subprocess.DEVNULL)
    entitlements = plistlib.loads(raw)
    assert entitlements.get('com.apple.security.app-sandbox') is True, 'Exported payload is missing App Sandbox'
    assert not entitlements.get('com.apple.security.get-task-allow'), 'Distribution build permits debugging'
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    assert info['CFBundleIdentifier'] == 'app.glidemouse.store'
    assert info['CFBundleVersion'] == args.build_number
    assert info.get('GMStoreEdition') is True
    for key in ['GMOnboardingPreview', 'GMListPreview', 'GMMagicPreview', 'GMGuidePreview', 'GMRunDeniedPrivacyCheck']:
        assert not info.get(key), f'Preview enabled in distribution: {key}'
    assert not any(key.startswith('SU') for key in info), 'Sparkle configuration remains'
    assert not list(app.rglob('Sparkle.framework')), 'Sparkle framework remains'
    symbols = run('nm', '-u', str(app / 'Contents/MacOS/GlideMouse')).decode()
    for forbidden in ['_AXIsProcessTrusted', '_AXUIElement', '_MTDeviceCreateList', '_MTRegisterContact', '_setuid', '_seteuid', '_CGRequestListenEventAccess', '_CGPreflightListenEventAccess', '_IOHIDManagerOpen', '_IOHIDDeviceOpen', '_IOHIDDeviceCreate', '_IOHIDDeviceCopyMatchingElements']:
        assert forbidden not in symbols, f'Forbidden Store symbol: {forbidden}'
    print(json.dumps({
        'passed': True, 'bundleID': info['CFBundleIdentifier'],
        'version': info['CFBundleShortVersionString'], 'build': info['CFBundleVersion'],
        'teamID': args.team_id, 'sandbox': True, 'distributionSigned': True,
        'previewDisabled': True, 'explicitListenEventAPIsAbsent': True, 'hidUserClientAPIsAbsent': True, 'privateTouchAndAXAPIsAbsent': True,
        'entitlements': entitlements,
        'scope': 'artifact checks only; not App Review approval or runtime/device proof',
    }, indent=2))
