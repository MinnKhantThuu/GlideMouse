# Compatibility and verification

GlideMouse targets **macOS 14 or later** on **Apple Silicon and Intel**. The packaged app is universal. Compiler support does not prove behavior on every Mac, OS version or device.

| Area | Evidence and current limit |
|---|---|
| Core configuration, button recognition, scrolling and app inheritance | Automated unit and replay tests; 94 tests pass for 0.3.18 |
| Standard wheel and side buttons | Native event-tap integration checks; a user confirmed desktop left/right switching without the earlier application delay on a Bluetooth mouse |
| Primary-button double click and hold | Unit and synthetic native integration checks preserve ordinary clicking/dragging; wider physical hardware acceptance remains necessary |
| Button identification and picture labels | Capture identifies a number; the user confirms its physical position. HID metadata cannot infer upper/lower position reliably |
| English, Myanmar and Simplified Chinese | 639 catalog entries validated in all three languages, compiled resources checked, native UI snapshots reviewed |
| Apple Silicon | Local build/runtime checks available |
| Intel and older supported macOS versions | Universal compiler build; physical runtime matrix still pending |
| Magic Mouse touch gestures | Offline-editable full touch catalog, drag/drag-scroll, modifier clicks, app cycling and synthetic replay checks; experimental private-framework adapter; [hardware checklist](guides/MAGIC_MOUSE.md) remains pending |
| Built-in trackpad | Excluded from the raw-touch adapter; native scroll passes through unless a configured touch gesture currently owns the continuous stream. Mixed-device attribution still needs physical testing |
| Per-device persisted overrides | Resolver exists; live button/wheel adapter lacks reliable device attribution, so these overrides are unavailable |
| Continuous desktop swipes, magnify and Smart Zoom | Unavailable; discrete shortcut actions are not equivalent to native continuous gestures |
| Proprietary extra buttons | Standard reported events only; no vendor-specific driver adapter |
| Updates | Sparkle is included. Distributed developer builds can use the public HTTPS feed and verification key; source builds must supply a feed URL. No eligible notarized update or completed old-to-new installation test is claimed |
| Distribution | Developer ID signed development prerelease; not a notarized production release |

The documentation videos use native SwiftUI screens with temporary sample settings. They show how to configure actions; they do not prove physical input delivery, desktop transitions or permission behavior on another Mac.

GlideMouse advises about competing mouse utilities but does not disable them. Pause the other utility when comparing behavior. Broader acceptance should cover three-/five-button mice, a trackball, Intel hardware, supported OS versions, and named Magic Mouse generations before promoting experimental capabilities.
