# Release checklist

Source: https://github.com/MinnKhantThuu/GlideMouse  
Tutorials: https://minnkhantthuu.github.io/GlideMouse/tutorials.html  
Update infrastructure: https://github.com/MinnKhantThuu/GlideMouse-updates

Public developer downloads are **development prereleases** until notarization and the distribution checks below pass. Publishing source or a GitHub release does not automatically publish an eligible Sparkle update.

1. Start with a clean checkout and pinned dependencies. Run `python3 Scripts/check-localization.py`, `swift test` and the native universal Release build. Review UI changes at multiple widths in each supported language.
2. Set the release version and increasing build together (`GLIDEMOUSE_RELEASE_VERSION`, `GLIDEMOUSE_RELEASE_BUILD`), or update the bundle defaults deliberately. Keep the About/footer/export version consistent.
3. Supply an HTTPS `GLIDEMOUSE_UPDATE_FEED_URL` before signing if this distribution will use Sparkle. Verify `SUFeedURL` and the public Ed25519 key in the packaged app. Private signing/update keys never belong in source, fixtures, logs or chat.
4. Run `Scripts/package-release.sh`. Without a signing identity it produces an ad-hoc development build. Set your own `GLIDEMOUSE_SIGN_IDENTITY` for Developer ID distribution. The script signs nested helpers/frameworks before the app, verifies signatures, produces universal DMG/ZIP artifacts and writes SHA-256 checksums.
5. To notarize, supply an existing `GLIDEMOUSE_NOTARY_PROFILE`. Submit, staple and validate the DMG; check the packaged app and final ZIP. Keep a signed but unnotarized artifact clearly labelled as a development prerelease. Do not disable Gatekeeper.
6. Test an install into Applications on a clean Mac, both permissions, launch at login, pause/re-enable, restart, settings recovery and imported automation review. Verify physical buttons and scrolling separately from synthetic event tests.
7. Test a previously installed build upgrading to the new build. Sign the update archive with the matching Sparkle key and publish a reviewed appcast only when it meets the intended channel's distribution requirements. Check signature rejection, version ordering, feed availability and preservation of existing settings.
8. Review exactly which source, screenshots, videos and artifacts will be public. Exclude personal settings, internal development evidence, device serials, unrelated screenshots, credentials and signing material.
9. Publish the reviewed source and release notes. Verify the remote commit, downloads, hashes, README image links, English/Myanmar tutorial playback and GitHub Pages availability. Keep compatibility claims tied to actual evidence.

Current release gates include notarization, broader physical hardware/OS acceptance, end-to-end automatic update installation, VoiceOver acceptance and sustained energy/performance measurement. The tutorial renderer uses isolated sample settings and must never be presented as a physical hardware test.
