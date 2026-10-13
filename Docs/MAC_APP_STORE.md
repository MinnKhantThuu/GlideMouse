# Mac App Store candidate

The direct-download edition remains the shipping app. A separate Store candidate
uses `app.glidemouse.store` and the App Sandbox, with its own settings container.
Version 0.4.2 (26), submitted on 7 October 2026, was rejected on 13 October under Guidelines 2.1 and 2.4.5. Apple specifically rejected mouse-control use of the requested permissions. The onboarding correction is prepared as build 28; technical Sandbox compatibility does not resolve that policy objection. See [the review investigation](REVIEW_2026_10_13.md). The app is not publicly released on the Mac App Store.

## Generate and archive

From the repository root, with Xcode selected:

```sh
python3 Scripts/prepare-mac-app-store.py --output build/MacAppStore/candidate --build-number 28
xcodebuild -project build/MacAppStore/candidate/GlideMouse.xcodeproj \
  -scheme GlideMouse -configuration Release \
  -derivedDataPath build/MacAppStore/DerivedData \
  -archivePath build/MacAppStore/GlideMouse.xcarchive \
  -destination 'generic/platform=macOS' \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
  DEVELOPMENT_TEAM=YOUR_TEAM_ID -allowProvisioningUpdates archive
```

The generator refuses an existing output directory, checks source transformations,
and fails if private touch APIs, AX trust calls, or Sparkle implementations remain.
It changes the generated source only. It does not install an app, alter permissions,
publish anything, or read signing credentials. The signed archive uses the developer
account configured in Xcode. An unsigned archive with `CODE_SIGNING_ALLOWED=NO`
is useful for compilation checks only: exporting it can lose Sandbox entitlements.
Do not use an unsigned compilation artifact as the release archive.

After exporting with Xcode's `app-store-connect` method, validate the actual package:

```sh
python3 Scripts/validate-store-package.py build/MacAppStore/export/GlideMouse.pkg \
  --team-id YOUR_TEAM_ID --build-number 28
```

This extracts the payload without installing it, verifies the installer/app signing,
checks App Sandbox in the signed payload, and rejects preview flags, AX trust/UI
calls, private touch symbols and Sparkle. Run it before upload. Packaging checks
do not establish App Review approval or a real-device permission result.

## Edition differences

The candidate retains the button/hold/double-press recognition and Core Graphics
shortcuts used for desktop switching, Mission Control, scroll processing, URL
opening, and app-specific mappings. The signed sandboxed build passed the runtime
integration checks for button remapping, scroll phases/momentum, capture isolation,
native continuous-scroll passthrough, pause and emergency stop. These checks used
generated events; physical-device and clean-Mac checks remain separate.

The candidate excludes private Magic Mouse touch gestures and the Sparkle updater.
Updates for a published Store release would be handled by the App Store. Shell
commands, Shortcuts command execution, file/app targets that lack persistent
security-scoped bookmarks, and media-key injection using undocumented event
encoding are also excluded. Unsupported mapping imports are rejected, and the
mapping chooser does not offer excluded actions or touch inputs. The direct
edition retains its current features.

The Store candidate does not expose the external donation button. Developer
credit, email and website remain available.

## Permissions and review

Use `CGPreflightPostEventAccess` / `CGRequestPostEventAccess` for synthetic UI
inputs and `CGPreflightListenEventAccess` / `CGRequestListenEventAccess` for
monitoring. These are different from AXUIElement access. Apple DTS explains that
PostEvent and ListenEvent APIs are compatible with App Sandbox, while the separate
Accessibility service is not. The PostEvent permission still appears in the
Accessibility pane in System Settings. This technical compatibility is not a
promise of App Review approval.

See [Apple DTS's explanation](https://developer.apple.com/forums/thread/820594)
and [Review Guidelines 2.4.5 and 2.5.1](https://developer.apple.com/app-store/review/guidelines/).

For release regression testing, verify regular clicks and dragging, side-button mappings,
desktop switching, hold/double press, scrolling, app profiles, learning/recording,
permission denial/revocation and restart persistence on a clean macOS setup.
Use the isolated Store identity and pause the direct edition during input tests.
Never replace the user's working direct edition to test this candidate.

The signed universal package, English and Simplified Chinese screenshots and
metadata, published Data Not Collected privacy declaration, export compliance,
and free pricing are in place. Keep future descriptions and screenshots aligned
with the features actually verified in the Store edition.
Do not mark an unsigned archive or a local ad-hoc build as upload ready.
