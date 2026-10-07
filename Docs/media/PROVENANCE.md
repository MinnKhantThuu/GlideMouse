# Tutorial media

These screenshots and videos were rendered from GlideMouse 0.3.16's native SwiftUI views. The tutorial renderer uses isolated temporary settings, a sample five-button mouse and an example Safari profile. Actions are changed through the app model; no real mouse input or desktop switching is recorded. No personal desktop, live settings export or private development traces are published here.

Ten lessons cover five topics in English and Myanmar. English narration uses macOS's local Samantha text-to-speech voice. Myanmar explanations are displayed as native shaped text; the Myanmar videos have no narration. Captions are burned into the video, with downloadable UTF-8 SRT sidecars. Each MP4 uses H.264 at 1440 × 1080, 24 fps and a fast-start layout for browser playback. English audio is AAC mono.

The `videos/manifest.json` lists the duration, size and capture type. The app and media use original project artwork. To regenerate, package the app, run its `--render-tutorials` command, then run `Scripts/generate-tutorial-videos.py`. FFmpeg and a locally available English macOS voice are required. No paid generation service is used for these lessons.
