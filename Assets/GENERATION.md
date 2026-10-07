# Asset provenance
Built-in imagegen, 2026-10-06. Original generated raster, no third-party logo source. Used in the native window and app bundle. PNG master plus iconset and ICNS exports; editable vector remains pending.

Prompt: Use case: logo-brand. Asset type: original macOS app icon for GlideMouse, a mouse gestures and smooth scrolling utility. Create one polished square 1024x1024 app icon: vivid blue rounded square tile with a simple white top-view computer mouse silhouette and a graceful cyan motion swoosh wrapping around its lower right. Bold readable silhouette at 16px, minimal premium native macOS aesthetic, subtle depth, centered generous safe padding. No text, no letters, no Apple logos, no SF Symbols, no existing brand marks, no mockup, no extra objects. Save the generated image.

Generated master was resized to square exports using sips; no generative editing performed.

`GlideMouse-mark.svg` is an independently authored editable companion mark based on the same mouse/motion direction; it is not a lossless vectorization of the generated raster. The generated PNG remains the shipped icon master. The menu bar uses original template drawing code in MenuIcon.swift.

Final shipped raster: `AppIcon-transparent.png`, built-in imagegen edit (2026-10-06), genuine alpha confirmed with sips. Original opaque PNG is kept as the initial concept. Final iconset/ICNS/catalog and in-app PNG use the transparent version.

Edit prompt 1: Use case: background-extraction. Edit target: supplied GlideMouse app icon. Remove ONLY the black outside corners/background beyond the blue rounded-square icon silhouette, replacing that outside area with genuine alpha transparency. Preserve the entire blue tile, white mouse silhouette, cyan swoosh, colors, lighting, detail and composition exactly. Do not remove any dark blue inside the tile. Deliver a clean square transparent PNG app icon, no text, no mockup.

Edit prompt 2: Use case: precise-object-edit. Edit target: attached GlideMouse transparent app icon. Change only the outside silhouette cleanup: remove all stray cyan/blue pixels outside the rounded blue square tile and make its external edge perfectly smooth, clean and antialiased, with transparent alpha everywhere outside the single rounded square. In particular remove blue flecks near the bottom right and top edge. Preserve the mouse, cyan swoosh, tile colors, lighting, dimensions and all interior content exactly. No other edits.
