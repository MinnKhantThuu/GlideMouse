# Contributing

Use Xcode 27 / Swift 6.4 with a macOS 14+ deployment target. Run `swift test` and build the native target before proposing changes. Keep input classification free of UI, disk and network operations. Preserve native primary/secondary clicks. Tag all synthetic events, balance held input, and add replay traces for recognition changes.

Never infer event device identity by timestamp proximity. Mark private-API and untested hardware behavior experimental. Do not include real typed text, device serials, screenshots of other applications, secrets or signing material in test fixtures or diagnostics.

`Scripts/generate-xcode-project.py` regenerates the native app target. Include source and meaningful test changes together. Hardware proof and compiler-only proof must stay separate. Read Docs/ARCHITECTURE.md and Docs/COMPATIBILITY.md before input changes.

For bugs or crashes, use the local issue templates under `.github/ISSUE_TEMPLATE`. Include the exact build, OS/architecture, device model/connection, permission state, competing utilities, reproducible steps and expected/actual behavior. Pause GlideMouse and compare native behavior before attaching sanitized diagnostics. For a crash, retain only relevant app/thread stack frames and remove user paths, identifiers and unrelated application data. Record unavailable or untested cases explicitly.

The current distribution is a development prerelease. A public HTTPS feed and verification key exist, but eligible notarized updates and end-to-end update installation remain release gates. Each release must update the supported/experimental/unavailable matrix in `Docs/COMPATIBILITY.md`; private touch adapter changes require named-device regression traces before advancing a device to verified support.
