# Guide media

The website and README use GlideMouse 0.4.2 native UI screenshots. The detailed
English and Myanmar guide at `tutorials.html` now uses current screenshots and
written steps. Its existing chapter URLs remain valid. It no longer embeds the
0.3.16 walkthrough recordings or their controls.

Screenshots use isolated sample settings and a five-button mouse fixture. The
Myanmar guide adds captures of the Add button action box, press-type choices,
action chooser, shortcut details, and a Safari-specific Back action. These were
captured in `MappingListPreview`, which constructs `AppModel(testing: true,
rendering: true)` and does not start an input engine or read personal settings.
The sample actions are configuration examples, not physical-input recordings.

The 0.3.16 recordings remain in `videos/` as historical media. Their manifest
and captions describe that earlier interface; they are not linked as the current
user guide. `Scripts/generate-tutorial-videos.py` is their historical encoder.

The landing-page overview film is documented separately in `intro/README.md`.
Project artwork and media are covered by the project license and third-party
notices where applicable.

## Consistent guide captures

All current guide images use the light appearance. The new PNG filenames include
their content hash so older browser caches do not select an earlier dark capture.
The earlier PNG and JPEG paths remain available for cached pages and old links.
The guide uses an accessible in-page viewer with zoom, Close, Escape, and focus
restoration; direct image links remain the fallback when JavaScript is unavailable.

Regenerate the captures with `Scripts/build-app.sh debug`, then
`build/GlideMouse.app/Contents/MacOS/GlideMouse --render-guide-screenshots build/guide-screenshots-light`.
`GuideScreenshotRenderer` fixes the appearance in both AppKit and SwiftUI and
verifies that no input runtime is created. It does not change live mouse settings.
