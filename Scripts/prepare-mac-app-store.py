#!/usr/bin/env python3
"""Create an isolated, sandboxed Store candidate. Never install or submit it.

The generated tree is reproducible and disposable; the direct-download source,
installed app, permissions and settings remain untouched. Runtime validation and
Apple distribution signing are separate release gates.
"""
from pathlib import Path
import argparse, json, plistlib, shutil, subprocess, sys

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, default=root / 'build/MacAppStore/source')
args = parser.parse_args()
dest = args.output.resolve()
if dest == root or root not in dest.parents or 'build' not in dest.relative_to(root).parts:
    sys.exit('Output must be an isolated directory under this project build folder.')
if dest.exists():
    sys.exit('Output already exists. Choose a fresh --output; existing files are preserved.')
for folder in ['Sources', 'Assets', 'Config', 'Scripts']:
    shutil.copytree(root / folder, dest / folder, ignore=shutil.ignore_patterns('__pycache__'))

def patch(relative, old, new, count=1):
    path = dest / relative
    content = path.read_text()
    actual = content.count(old)
    if actual != count:
        sys.exit(f'Source drift: {relative}: expected {count} occurrences, found {actual}. Candidate not ready.')
    path.write_text(content.replace(old, new))

# App Sandbox permits the PostEvent and ListenEvent TCC services. AXUIElement
# access is a different privilege. Use Core Graphics permission APIs throughout.
for file in (dest / 'Sources/GlideMouse').rglob('*.swift'):
    text = file.read_text().replace('AXIsProcessTrusted()', 'CGPreflightPostEventAccess()')
    file.write_text(text)
patch('Sources/GlideMouse/Core/AppModel.swift',
      'AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)',
      'CGRequestPostEventAccess()')

# No private framework code is copied into the compiler's source set. Keep only
# inert ABI stubs for the regular button runtime's cleanup/status calls.
(dest / 'Sources/NativeBridge/NativeBridge.c').write_text('''#include "NativeBridge.h"
bool gm_touch_probe(void) { return false; }
const char *gm_touch_status(void) { return "Touch gestures are not included in the App Store edition"; }
int32_t gm_touch_devices(GMDevice *devices, int32_t capacity) { return 0; }
bool gm_touch_start(int32_t index) { return false; }
void gm_touch_stop(void) {}
bool gm_touch_next(GMFrame *frame) { return false; }
uint64_t gm_touch_dropped(void) { return 0; }
''')
# Commands are also absent from this edition, including imported configurations.
(dest / 'Sources/NativeBridge/Commands.c').write_text('''#include "NativeBridge.h"
int32_t gm_command_spawn(const char *e,const char *a,const char *d,const char *h) { return -1; }
int32_t gm_command_poll(int32_t pid,int32_t *status) { return -1; }
void gm_command_cancel(int32_t pid,bool force) {}
''')
blocked = '[.shell, .appleShortcut, .openApp, .openFolder, .volumeUp, .volumeDown, .mute, .playPause, .nextTrack, .previousTrack, .brightnessUp, .brightnessDown]'
patch('Sources/MouseCore/ConfigurationStore.swift',
      '            for m in p.mappings {',
      f'''            for m in p.mappings {{
                guard !{blocked}.contains(m.action) else {{ throw ConfigurationError.invalid("This action is unavailable in the App Store edition") }}
                guard [.button, .buttonHold, .buttonDrag, .buttonWheel, .buttonChord].contains(m.trigger.kind) else {{ throw ConfigurationError.invalid("Touch gestures are unavailable in the App Store edition") }}''')
patch('Sources/MouseCore/ConfigurationStore.swift',
      '        guard c.schemaVersion == Configuration.currentVersion',
      '        guard !c.touchEnabled else { throw ConfigurationError.invalid("Touch gestures are unavailable in the App Store edition") }\n        guard c.schemaVersion == Configuration.currentVersion')
patch('Sources/GlideMouse/Features/MappingEditor.swift',
      'values: TriggerKind.allCases)',
      'values: [.button, .buttonHold, .buttonDrag, .buttonWheel, .buttonChord])')
patch('Sources/GlideMouse/Features/MappingEditor.swift',
      'a != .smartZoom && (a != .canvasPan || triggerKind == .buttonDrag) &&',
      f'!{blocked}.contains(a) && a != .smartZoom && (a != .canvasPan || triggerKind == .buttonDrag) &&')
patch('Sources/GlideMouse/Core/ActionExecutor.swift',
      'guard CGPreflightPostEventAccess() else { report("Accessibility permission required"); return }',
      f'guard !{blocked}.contains(m.action) else {{ report("This action is unavailable in the App Store edition"); return }}\n        guard CGPreflightPostEventAccess() else {{ report("Accessibility permission required"); return }}')
# Avoid undocumented system-defined media event encoding in the Store binary.
path = dest / 'Sources/GlideMouse/Core/ActionExecutor.swift'
text = path.read_text()
start, end = text.index('    private func media('), text.index('    private func run(')
text = text[:start] + '    private func media(_ type: Int) {}\n' + text[end:]
path.write_text(text)
patch('Sources/GlideMouse/Features/PreferencesPages.swift',
      'MouseAction.allCases.filter { !$0.requiresTarget',
      f'MouseAction.allCases.filter {{ !{blocked}.contains($0) && !$0.requiresTarget')
patch('Sources/GlideMouse/Features/SimpleMousePage.swift',
      'if model.devices.contains(where: { $0.magicMouse }) {', 'if false {')
patch('Sources/GlideMouse/Features/PreferencesPages.swift',
      '        UpdatePreferences(model: model, updater: model.updater)', '')
# Remove updater implementation and all package/framework references.
(dest / 'Sources/GlideMouse/Core/UpdateController.swift').write_text('''import Foundation
import Combine
@MainActor final class UpdateController: ObservableObject {
    init(enabled: Bool = true) {}
    let canCheck = false
    let automaticallyDownloads = false
    let configured = false
    func start(automaticChecks: Bool) {}
    func setAutomaticChecks(_ enabled: Bool) {}
    func setAutomaticDownloads(_ enabled: Bool) {}
    func check() {}
}
''')
package = (root / 'Package.swift').read_text()
package = package.replace('dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")],', 'dependencies: [],')
package = package.replace(', .product(name: "Sparkle", package: "Sparkle")', '')
package = package.replace(',\n        .testTarget(name: "MouseCoreTests", dependencies: ["MouseCore", "NativeBridge"], resources: [.copy("Fixtures")])', '')
(dest / 'Package.swift').write_text(package)
info_path = dest / 'Config/Info.plist'
info = plistlib.loads(info_path.read_bytes())
info['CFBundleIdentifier'] = 'app.glidemouse.store'
info['LSApplicationCategoryType'] = 'public.app-category.utilities'
for key in list(info):
    if key.startswith('SU') or key == 'GMSupportURL':
        del info[key]
info_path.write_bytes(plistlib.dumps(info))
strings_path = dest / 'Sources/GlideMouse/Resources/Localizable.xcstrings'
strings = json.loads(strings_path.read_text())
for key, my, zh in [
    ('This action is unavailable in the App Store edition', 'App Store ဗားရှင်းမှာ ဒီလုပ်ဆောင်ချက်ကို မသုံးနိုင်ပါ။', 'App Store 版本不支持此操作。'),
    ('Touch gestures are unavailable in the App Store edition', 'App Store ဗားရှင်းမှာ Mouse မျက်နှာပြင်ကို ထိပြီးလုပ်တဲ့ gesture တွေ မပါဝင်ပါ။', 'App Store 版本不支持触控手势。'),
]:
    strings['strings'][key] = {'localizations': {lang: {'stringUnit': {'state': 'translated', 'value': value}} for lang, value in [('en', key), ('my', my), ('zh-Hans', zh)]}}
strings_path.write_text(json.dumps(strings, ensure_ascii=False, indent=2) + '\n')
(dest / 'Config/GlideMouse.entitlements').write_bytes(plistlib.dumps({
    'com.apple.security.app-sandbox': True,
    'com.apple.security.device.usb': True,
    'com.apple.security.device.bluetooth': True,
    'com.apple.security.files.user-selected.read-write': True,
}))
# The direct edition now has an offline Magic Mouse setup screen. Exclude that
# screen and its preview entry points, rather than showing unsupported controls.
patch('Sources/GlideMouse/Features/SettingsRoot.swift',
      '[SettingsPage.mappings, .magic, .scrolling, .general]',
      '[SettingsPage.mappings, .scrolling, .general]')
patch('Sources/GlideMouse/Features/SettingsRoot.swift',
      'case .magic: MagicMousePage(model: model)', 'case .magic: EmptyView()')
patch('Sources/GlideMouse/Features/SettingsRoot.swift',
      'if model.devices.contains(where: { $0.magicMouse }) { Button(model.text("Magic Mouse preset"))',
      'if false { Button(model.text("Magic Mouse preset"))')
patch('Sources/GlideMouse/Features/PreferencesPages.swift',
      'if model.devices.contains(where: { $0.magicMouse }) {', 'if false {')
(dest / 'Sources/GlideMouse/Features/MagicMousePage.swift').unlink()
launcher = dest / 'Sources/GlideMouse/GlideMouseApp.swift'
text = launcher.read_text()
start = text.index('        if let i = CommandLine.arguments.firstIndex(of: "--render-magic")')
end = text.index('        if CommandLine.arguments.contains("--guide-preview")', start)
text = text[:start] + text[end:]
start = text.index('\nstruct MagicMouseSettingsPreview: App {')
end = text.index('/// Preview fixtures', start)
text = text[:start] + text[end:]
launcher.write_text(text)
harness = dest / 'Sources/GlideMouse/Core/TestHarness.swift'
text = harness.read_text()
start = text.index('    /// UI and persistence verification without event taps')
end = text.index('    static func render(to directory: URL)', start)
text = text[:start] + text[end:]
text = text.replace(' + MagicMouseCatalog.defaults', '')
text = text.replace('[SettingsPage.mappings, .magic, .general]', '[SettingsPage.mappings, .general]')
harness.write_text(text)
guide = dest / 'Sources/GlideMouse/Resources/MouseGuide/guide.html'
text = guide.read_text()
lines = [line for line in text.splitlines() if 'data-gesture-mode="touch"' not in line]
guide.write_text('\n'.join(lines) + '\n')

generator = dest / 'Scripts/generate-xcode-project.py'
gen = generator.read_text()
gen = '\n'.join(line for line in gen.splitlines() if not line.startswith(('sparkle=obj(', 'embed=obj(', 'embedphase=obj('))) + '\n'
gen = gen.replace(",('Sparkle',sparkle)", '').replace('({local},{sparkle},)', '({local},)')
gen = gen.replace("'ENABLE_APP_SANDBOX':'NO'", "'ENABLE_APP_SANDBOX':'YES'")
gen = gen.replace("'PRODUCT_BUNDLE_IDENTIFIER':'app.glidemouse.desktop'", "'PRODUCT_BUNDLE_IDENTIFIER':'app.glidemouse.store'")
generator.write_text(gen)
subprocess.run([sys.executable, str(generator)], check=True)
# Fail closed before reporting a usable candidate if private/updater APIs remain.
for directory in ['Sources', 'Config', 'GlideMouse.xcodeproj']:
    for file in (dest / directory).rglob('*'):
        if file.suffix not in ['.swift', '.c', '.h', '.plist', '.pbxproj']: continue
        text = file.read_text()
        for token in ['MultitouchSupport.framework', 'MTDeviceCreateList', 'MTRegisterContact', 'import Sparkle', 'AXIsProcessTrusted', 'SPUStandardUpdater', 'with: .systemDefined']:
            if token in text:
                sys.exit(f'Forbidden Store implementation remains: {file.relative_to(dest)}: {token}')
report = {
    'bundleID': info['CFBundleIdentifier'], 'version': info['CFBundleShortVersionString'],
    'sandbox': True, 'privateTouchAdapter': False, 'sparkle': False,
    'status': 'candidate only; not signed for distribution, not runtime validated, not uploaded',
    'excludedActions': ['shell','appleShortcut','openApp','openFolder','volumeUp','volumeDown','mute','playPause','nextTrack','previousTrack','brightnessUp','brightnessDown'],
    'retainedActions': 'button clicks, holds/double presses, keyboard shortcuts, desktop switching, Mission Control, scroll smoothing, URL opening and app-specific mappings',
    'permissionAPIs': ['CGPreflightPostEventAccess','CGRequestPostEventAccess','CGPreflightListenEventAccess','CGRequestListenEventAccess'],
}
(dest.parent / (dest.name + '-preparation.json')).write_text(json.dumps(report, indent=2) + '\n')
print(dest)
