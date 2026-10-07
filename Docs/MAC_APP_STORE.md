# Mac App Store candidate

The direct-download edition remains the shipping app. A separate Store candidate
uses `app.glidemouse.store` and the App Sandbox, with its own settings container.
Version 0.3.19 (23) has been signed by the Minn Khant Thu developer team and uploaded to App Store Connect. Review submission and approval are still pending.

## Generate and archive

From the repository root, with Xcode selected:

```sh
python3 Scripts/prepare-mac-app-store.py --output build/MacAppStore/candidate
xcodebuild -project build/MacAppStore/candidate/GlideMouse.xcodeproj \
  -scheme GlideMouse -configuration Release \
  -derivedDataPath build/MacAppStore/DerivedData \
  -archivePath build/MacAppStore/GlideMouse.xcarchive \
  -destination 'generic/platform=macOS' \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO archive
```

The generator refuses an existing output directory, checks source transformations,
and fails if private touch APIs, AX trust calls, or Sparkle implementations remain.
It changes the generated source only. It does not install an app, alter permissions,
publish anything, or read signing credentials. The archive command above verifies
compilation; it deliberately does not produce a Store-signed upload.

## Edition differences

The candidate retains the button/hold/double-press recognition and Core Graphics
shortcuts used for desktop switching, Mission Control, scroll processing, URL
opening, and app-specific mappings. These still require runtime testing under the
sandbox with explicit user permission; a successful build does not prove them.

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

Before submitting for review, verify regular clicks and dragging, side-button mappings,
desktop switching, hold/double press, scrolling, app profiles, learning/recording,
permission denial/revocation and restart persistence on a clean macOS setup.
Use the isolated Store identity and pause the direct edition during input tests.
Never replace the user's working direct edition to test this candidate.

The enrolled developer team, explicit Bundle ID, App Store Connect record and signed package are in place. Final privacy/review metadata, screenshots and sandbox runtime checks must be completed before review submission. Keep descriptions
and screenshots aligned with the features actually verified in the Store edition.
Do not mark an unsigned archive or a local ad-hoc build as upload ready.
