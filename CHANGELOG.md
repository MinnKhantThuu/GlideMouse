# Changelog

## 0.3.18

- Add an always-available Magic Mouse setup page: edit gestures before connecting hardware, review touch-only suggestions, choose finger/tap counts and directions, set modifier overrides, edit/delete and Undo.
- Add timed forward/backward app cycling, modifier-preserving touch clicks and drags, tap-and-move drag recognition, second-finger drag scrolling, resting-contact recovery, swipe/brush tuning and an independent touch-hold delay.
- Preserve old version-2 settings, existing ordinary mouse mappings and immediate desktop button switching. UI-only previews create no event taps or private touch probes.
- Expand the shared EN/MY/ZH offline/website guide to fourteen touch examples in four groups, with original drawings, accessible controls and reduced-motion support.
- Validate 94 core tests, 639 compiled translation entries and temporary-setting save/delete/Undo checks. Real Magic Mouse hardware acceptance remains pending; the adapter is experimental and requires the named-device checklist.

## 0.3.17

- Add original animated input-to-result examples on the website and in the Buttons page.
- Bundle the guide offline with English, Myanmar and Simplified Chinese text.
- Include pause/replay, reduced-motion support and automatic pause outside the viewport.
- Keep animation previews separate from the input runtime and device discovery.
- Mark Magic Mouse touch examples experimental; real hardware validation is still pending.

## 0.3.16

- Add Simplified Chinese across settings, button labels, actions, setup, app profiles, dialogs, menu controls and troubleshooting.
- Localize shortcut recording/accessibility text, named keys, command status and app-owned validation errors.
- Preserve language selection through save/load/import; ship `zh-Hans` resources while storing the preference as `zh`.
- Validate all three languages and format arguments in CI, and include a Chinese user guide.

## 0.3.10

- Keep the app-specific action list in a deterministic button/gesture order during runtime refreshes.
- Identify rows by their canonical trigger so updates retain the correct row identity.

## 0.3.9

- Replace the About pitch with developer attribution, version, support and contact actions.
- Keep settings import/export/reset in a separate settings section.

## 0.3.8

- Align ordinary buttons to shared 40-point controls; give dropdowns, action rows and mouse labels visible borders and hover/press states.
- Align Save/Remove actions to the inspector width and keep mouse labels a consistent size.

- Keep the app being edited visible above button, scrolling and app-management pages.
- Explain inherited versus app-specific actions; scope Save messages and provide Reset to All apps.
- Reuse an existing app setup when selected again and keep scope display accurate after deletion/Undo.
- Make per-app scrolling customization explicit and preview the selected app instead of the currently active app.

## 0.3.7

- Describe button presses, holds, mouse movement and wheel gestures in full sentences in English/Burmese.
- Rename the advanced list to Other saved gestures and explain its empty state.
- Show trigger details even when a saved gesture has a custom name.

## 0.3.6

- Clarify button input versus performed click actions in English and Burmese.
- Make numbered left/right labels selectable and add optional double-click/hold mappings for buttons 1/2.
- Preserve ordinary primary clicks, native double-click counts for hold-only bindings, and native dragging; replay original events at the session layer.
- Add core and macOS event-tap regression checks for primary gestures, capture, modifiers and configuration changes.


## 0.3.5 — version display correction

- About, the window footer and exported diagnostics read the app bundle version instead of showing an old fixed version. Default build metadata matches the release.

## 0.3.4 — mouse picture and action editing

- Always-visible numbered mouse diagram with elbow callouts and explicit position selection for unknown buttons.
- Click once, Double click and Hold are main options, each with its own Save/Remove action controls and Undo.
- Simplified page copy/layout, shorter Burmese labels and collapsed app/preset/advanced controls. Existing mapping triggers and input indices are preserved.

## 0.3.3 — local controls usability update

- Dropdowns and action choices use full rectangular targets with at least 40-point height; input, direction, position and diagnostic selectors share one component.
- Disclosure headings can be clicked across the row. Buttons, tabs and selectors request a pointing-hand cursor, including settings sheets.
- Native render/build checks pass. The user confirmed dropdown text/padding clicks and pointing-hand hover on the connected Mac.

## 0.3.2 — local usability and latency update

- Desktop left/right shortcuts dispatch on the input thread, independently of settings layout and sheets. Keyboard event batches remain serialized and do not execute twice.
- The Buttons page offers an always-ready capture area, compact button choices and a visible action/Save row. Mouse artwork and extra controls remain available in disclosure sections.
- Capture respects the active window, visible scroll bounds and current Space. An inactive capture view cannot clear a sheet's capture area.
- Local latency diagnostics and regression checks distinguish application dispatch from macOS animation and physical mouse acceptance.

## 0.2.0 — local developer alpha

- Native bilingual settings and menu bar controls.
- Auxiliary button mapping, gesture classifier, app/global profiles and smooth wheel scrolling.
- Validated configuration, reviewable import/export, local diagnostics and emergency pause.
- Generated app icon and universal Developer ID packaging.
- Experimental touch bridge and optional Sparkle infrastructure; hardware and public release gates documented.
