# Mapping list redesign

Buttons and Magic Mouse settings now show each input alongside its action. Selecting a simple action saves immediately. The trash control removes a saved action; Undo restores it. Shortcuts and actions needing an app, folder, URL or command open a smaller details sheet first. Cancel never commits a partial action.

Add button action lets you press the physical button inside a capture box or choose an already identified button, then choose click, double click or hold. Primary buttons offer double click and hold only; ordinary click and drag behavior remains protected by the existing engine. Add gesture lists named Magic Mouse inputs with diagrams, instead of requiring several dropdown selections to construct a gesture. Modifier combinations and other advanced inputs remain available through Advanced mapping.

The app selector stays above both lists. App profiles show inherited actions without copying global mappings. Custom app changes have separate identities. Removing an override returns to the All apps action. Inherited rows show a link rather than an active delete control. No presets are applied automatically. The existing settings schema, recognizers and injection paths are unchanged.

The large mouse diagram is under Find a button on your mouse. Its labels still open the corresponding button setup. Row diagrams highlight only calibrated positions; an unknown auxiliary-button position shows its number without claiming a physical location.

## Validation

- Universal native Release build: arm64 and x86_64.
- 94 existing core tests passed.
- 38 model checks passed, including inline save/removal/Undo, independent app identities, default inheritance, shortcut options and preserving unrelated gestures.
- 665 localization entries verified in the compiled English, Burmese and Simplified Chinese resources.
- Native screenshots checked at widths 820, 1040 and 1440; Burmese app inheritance also checked in light and dark appearances.
- Interactive isolated preview: changed action without Save, deleted and undid a row, captured a primary button inside the box, added its double-click shortcut, recorded Command-K, edited and removed a Safari override, and added a two-finger double-tap action for Safari.
- The installed local app shows 0.4.0 with the original configuration file preserved byte for byte and the existing engine enabled.

These checks cover UI and configuration behavior. They do not establish physical Magic Mouse acceptance. The local 0.4.0 Developer ID build is not yet an externally notarized release; the public update feed and submitted Store build remain on 0.3.19.
