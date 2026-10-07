# Mouse input illustrations — 0.4.1

Generated with the built-in image_gen tool. Original RGBA PNGs are retained without resampling or flattening alpha. Runtime code places button numbers, calibrated button highlights, tap counts and hold indicators over the images.

## Standard mouse

Asset: `Sources/GlideMouse/Resources/ButtonMouseGlyph-v1.png`

Prompt:

Use case: product-mockup.
Asset type: transparent raster mouse illustration for a macOS utility's small 56 by 72 point input icons.
Primary request: A single clearly recognizable ordinary five-button computer mouse, strictly orthographic TOP VIEW, front at top, centered vertical. Broad rounded silver-white body with charcoal grey crisp outer contour, two clearly divided primary buttons at top and a large black vertical scroll wheel between them. Two short distinct side buttons visible protruding slightly on the LEFT edge in the upper middle and lower middle. Smooth restrained satin shading, bold clean features that remain readable at thumbnail size, premium macOS product illustration. Body ratio width to height about 0.62. Fully visible with only 5 percent padding. Symmetrical main shell, no perspective.
Scene/backdrop: genuine transparent alpha, no background, no floor, no cast shadow.
Constraints: one mouse only; no text, numbers, labels, arrows, cursor, blue highlights, cable, logo, brand, watermark, decorative detail, blurry edges. Button divisions and wheel must be immediately obvious. Silver surface needs good contrast on both light and dark UI.

## Touch mouse

Asset: `Sources/GlideMouse/Resources/TouchMouseGlyph-v1.png`

Prompt:

Use case: product-mockup.
Asset type: transparent raster Magic Mouse illustration for a macOS utility's small 56 by 72 point input icons.
Primary request: One smooth touch-surface mouse, strictly orthographic TOP VIEW with front at top, centered vertical. A clearly recognizable slim Magic Mouse shaped body: elongated capsule with softly rounded front and back, smooth uninterrupted satin white touch surface and clean charcoal silver edge contour. Body width to height about 0.58, filling canvas with about 5 percent padding. Restrained soft grey edge shading, crisp silhouette, premium macOS product illustration readable at very small size. No perspective.
Scene/backdrop: genuine transparent alpha, no background, floor or cast shadow.
Constraints: one mouse only; no scroll wheel, seams, side buttons, separate physical buttons, text, numbers, labels, arrows, dots, blue highlights, cable, logo, brand or watermark. Surface remains empty so app can overlay gesture indicators. Crisp edges and enough edge contrast on light and dark backgrounds.


## Validation

- Universal Release Xcode build succeeded.
- Both PNGs have alpha and are included in the native app and Swift Package resource lists.
- Rendered standard/Magic Mouse pages in EN/MY/ZH at 820, 1040 and 1440 points, plus dark mode.
- Compiled localization check: 665 entries, all three languages passed.
- Native v0.4.1 (25) shows the new icons in Buttons and Add button action; sheet height adjusted to keep its title and Advanced disclosure visible.
- Developer ID signing and deep strict bundle verification passed.
- Existing user settings remained byte-for-byte unchanged. Input recognition was not modified.
