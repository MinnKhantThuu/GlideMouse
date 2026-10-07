# Contributing

Use Xcode 27 / Swift 6.4 with a macOS 14+ deployment target. Run `swift test` and build the native target before proposing changes. Keep input classification free of UI, disk and network operations. Preserve native primary/secondary clicks. Tag all synthetic events, balance held input, and add replay traces for recognition changes.

Never infer event device identity by timestamp proximity. Mark private-API and untested hardware behavior experimental. Do not include real typed text, device serials, screenshots of other applications, secrets or signing material in test fixtures or diagnostics.

`Scripts/generate-xcode-project.py` regenerates the native app target. Include source and meaningful test changes together. Hardware proof and compiler-only proof must stay separate. Read Docs/ARCHITECTURE.md and Docs/COMPATIBILITY.md before input changes.

For bugs or crashes, use the local issue templates under `.github/ISSUE_TEMPLATE`. Include the exact build, OS/architecture, device model/connection, permission state, competing utilities, reproducible steps and expected/actual behavior. Pause GlideMouse and compare native behavior before attaching sanitized diagnostics. For a crash, retain only relevant app/thread stack frames and remove user paths, identifiers and unrelated application data. Record unavailable or untested cases explicitly.

The current distribution is a development prerelease. A public HTTPS feed and verification key exist, but eligible notarized updates and end-to-end update installation remain release gates. Each release must update the supported/experimental/unavailable matrix in `Docs/COMPATIBILITY.md`; private touch adapter changes require named-device regression traces before advancing a device to verified support.

## Development setup

```sh
git clone https://github.com/MinnKhantThuu/GlideMouse.git
cd GlideMouse
python3 Scripts/check-localization.py
swift test
```

Open `GlideMouse.xcodeproj` and run the GlideMouse scheme. A terminal build is also available:

```sh
Scripts/build-app.sh release
Scripts/package-release.sh
```

The first command builds a local ad-hoc app. Packaging builds a universal app and DMG/ZIP under `build/Release`. Set your own `GLIDEMOUSE_SIGN_IDENTITY` for Developer ID signing and an existing `GLIDEMOUSE_NOTARY_PROFILE` to notarize; do not use another developer's credentials. Dependencies are pinned in Package.resolved. Network access is needed to fetch dependencies on the first build.

Read [Architecture](Docs/ARCHITECTURE.md), [Security](SECURITY.md) and [Release checklist](Docs/RELEASE_CHECKLIST.md). Core tests, compiled resource checks, synthetic/native UI checks and physical hardware acceptance are different types of evidence.

## Documentation media

To regenerate the documentation captures and videos:

```sh
build/Release/GlideMouse.app/Contents/MacOS/GlideMouse --render-tutorials build/tutorial-scenes
python3 Scripts/generate-tutorial-videos.py build/tutorial-scenes
```

This uses native sample UI captures, local English speech synthesis and FFmpeg. It needs no paid service. It writes temporary settings and never demonstrates real desktop actions. The private development evidence/settings are excluded from the public source snapshot.

App icon and mouse illustration provenance: [Assets/GENERATION.md](Assets/GENERATION.md).
