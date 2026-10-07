<p align="center"><img src="Assets/AppIcon-transparent.png" width="88" alt="GlideMouse icon"></p>

# GlideMouse

Set mouse button actions, adjust scrolling and use different settings in individual apps on macOS. A native app by Minn Khant Thu, available in English, Myanmar and Simplified Chinese.

**[Website](https://minnkhantthuu.github.io/GlideMouse/) · [မြန်မာ](README_MM.md) · [简体中文](Docs/USER_GUIDE_ZH.md)**

**[Download for macOS — DMG](https://github.com/MinnKhantThuu/GlideMouse/releases/download/v0.3.19/GlideMouse-0.3.19-developer.dmg)**

The screenshots and instructions below show **0.4.2**. [Releases](https://github.com/MinnKhantThuu/GlideMouse/releases) lists the available installers.

![GlideMouse button actions with input icons, action selectors and delete buttons](Docs/media/screenshots/en-buttons.png)

## Install

Requires **macOS 14 or later**, on Apple Silicon or Intel. Download the DMG, open it and drag GlideMouse to Applications. Quit any older copy before opening the installed app. No Xcode or build commands are needed.

Open **Mouse setup**, allow the permissions, then return and refresh. Reopen the app if macOS has not applied the permission change yet. Install in Applications before granting permissions.

| Permission | Why it is needed |
|---|---|
| Accessibility | Perform the action you chose, such as a shortcut or desktop change |
| Input Monitoring | Recognize mouse buttons and wheel input |

Mouse settings stay on your Mac. GlideMouse does not keep a log of what you type. Update checks contact the update host; selected website or automation actions may contact their own destinations.

## Find a screen

| Screen | What you can do |
|---|---|
| **Buttons** | Add a button input, choose its action directly in the row, or remove it |
| **Magic Mouse** | Prepare touch gestures, see their inputs and choose actions; direct-download edition only, hardware validation pending |
| **Scrolling** | Choose a scrolling feel, speed and direction |
| **Settings** | Language, appearance, login launch, updates, optional button suggestions, backups and developer contact |
| **Mouse setup** | Check permissions and identify buttons |
| **Advanced → App-specific settings** | Review a selected app’s overrides and inherited actions |
| **Advanced → Tuning / Devices** | Fine adjustments and connected mouse information |
| **Help → Troubleshooting** | Permission checks and optional technical details |

Advanced headings open when you click anywhere on their row, including the text. You can keep them closed for everyday use.

## 1. Add a button action

1. Open **Buttons**. Leave the scope at **All apps** to start.
2. Click **Add button action**.
3. Press the mouse button **inside the capture box**, or choose its number from the list.
4. Choose **Click once**, **Double click** or **Hold**.
5. Choose the action. Ordinary actions save immediately; a shortcut or target action opens a detail sheet where you finish with **Save**.
6. Enable GlideMouse, move outside the capture box and try the button.

Button numbers come from the mouse. They do not guarantee a physical position. Open **Find a button on your mouse → Label buttons** to capture each wheel/side button and confirm its position. The diagram is optional. Small mouse icons and numbers beside each row identify the input while you edit.

| Example input | Action |
|---|---|
| Lower side button → Click once | Space left (previous desktop) |
| Upper side button → Click once | Space right (next desktop) |
| Lower side button → Hold | Mission Control |

Use your own captured buttons. Desktop switching needs more than one macOS Space and the Control–Left/Right shortcuts enabled under Keyboard → Keyboard Shortcuts → Mission Control. Test those shortcuts from the keyboard first if switching does not work.

**Input versus action:** a row labelled Double click describes how you press the physical button. **Perform left double click** in the action chooser tells GlideMouse to send a left-button double click. A side-button single press can therefore produce a left-button double click.

**Left/right buttons (1 and 2)** support optional double-click and hold bindings, while ordinary clicks and dragging remain usable. A double-click binding introduces a short wait to distinguish one click from two. Avoid assigning double click to a button that needs an immediate single click.

## 2. Change or remove an action

Click the action selector **anywhere in its rectangle**, then choose another action. The row saves automatically. You can search the action chooser by name.

![Searchable action chooser](Docs/media/screenshots/en-actions.png)

Click the **trash button in that row** to remove just that input. Removing Click once does not remove Hold or Double click. **Undo** restores a recent change. The **… menu** contains action details, advanced mapping and, for app overrides, **Reset to All apps action**.

Actions have explicit names: **Increase volume**, **Decrease volume**, **Mute / unmute**, **Search apps (Spotlight)** and **Open screenshot tools**. Some actions depend on the current app’s keyboard shortcuts.

## 3. Set one app differently

**All apps** provides defaults. You do not need to add every application.

1. Click **Add app** in the scope bar and select an installed app.
2. Check that its name appears in the scope bar.
3. Change an action in a row. It saves for that app only.
4. Bring that app to the front to try it.

**From All apps** means the row inherits the default. Choosing another action creates **Custom for this app**. Inputs you leave alone keep their defaults. For example, a side button can switch desktops normally and go Back while Safari is frontmost.

![App-specific settings and inherited actions](Docs/media/screenshots/en-profiles.png)

Select the app and use **Remove app** to remove its GlideMouse setup. This does not uninstall the application. The default actions apply again; Undo can restore the setup. An inherited row cannot be deleted from one app as though it were its own mapping—edit All apps to remove the default, or choose a custom action for this app.

## 4. Adjust scrolling

![Scrolling controls](Docs/media/screenshots/en-scrolling.png)

Start with **Standard** or **Smooth**, then change speed and direction. Open finer adjustments only if needed.

| Control | Meaning |
|---|---|
| Speed | How far one wheel step moves the page |
| Direction | Normal or reversed wheel direction |
| Smoothness | How gradually a wheel step moves the page |
| Momentum | Continue briefly after you stop turning the wheel |
| Acceleration | More distance when you turn the wheel quickly; zero removes it |
| Shift + wheel | Horizontal scrolling |
| Control + wheel | Fine scrolling |
| Option + wheel | Zoom through shortcuts supported by the current app |

For a selected app, enable **Use different scrolling in this app** before making its own adjustments. Otherwise it inherits All apps. Native continuous trackpad/Magic Mouse scrolling stays native; these controls handle ordinary discrete wheels.

## 5. Shortcuts and advanced inputs

Choose **Keyboard shortcut**, focus **Record shortcut**, then press the combination. Finish with Save in the detail sheet. Existing mappings outside capture/recording areas keep working. Check that the shortcut works from your keyboard in the target app first.

Open app/folder/website actions need a target. Shell commands and Apple Shortcuts are advanced, opt-in actions. Imported command automation remains disabled until reviewed.

**Advanced mapping** supports hold-and-move, hold-and-wheel, modifier combinations and other supported inputs. The ordinary row list handles most setups.

## 6. Settings and help

![Settings](Docs/media/screenshots/en-settings.png)

- Choose **English, မြန်မာ or 简体中文** and system/light/dark appearance without changing your actions.
- Enable launch at login or optional action-name feedback.
- **Suggested button actions** is an optional collapsed section in Settings. Review suggestions before applying; nothing is added just by opening it. You can create your own rows instead.
- Check for updates manually or allow automatic checks/downloads. A newer signed release must be offered by the feed; a source commit alone does not update an installed app. Store edition updates use the App Store.
- Export settings for a backup. Import previews Merge or Replace; Replace pauses the engine, and Merge rejects conflicts.
- About includes developer details, email, the app website and support link.

**Emergency pause: ⌃⌥⌘ Esc** (Control + Option + Command + Escape). Pause is also available from the menu bar. Re-enable when ready.

The **? button on Buttons** opens an offline animated guide. The [website](https://minnkhantthuu.github.io/GlideMouse/#mouse-guide) has the same examples. Viewing them does not perform actions or change settings. The overview film uses sample app screens, English text and original music. Older tutorial recordings are archived and show an earlier interface.

## Troubleshooting

| Symptom | Check |
|---|---|
| Nothing happens | Engine enabled, both permissions granted, mouse connected; reopen after granting permissions |
| Wrong button | Capture it and confirm its position; do not assume 4 or 5 |
| Desktop does not switch | Multiple Spaces, Control–Left/Right enabled and working from keyboard |
| Works only in one app | Scope, overrides and which app is frontmost |
| Click feels delayed | Double-click/hold bindings and timing, separately from macOS transition animation |
| Two utilities conflict | Pause the other utility while comparing |
| No update offered | Feed needs an eligible newer release |

Use Help → Troubleshooting for checks. Technical details stays collapsed. Review exported diagnostics before sharing; do not post private files or credentials. Report reproducible issues on [GitHub](https://github.com/MinnKhantThuu/GlideMouse/issues), including version, macOS, mouse model, scope and steps.

## Compatibility and editions

The direct-download edition includes experimental Magic Mouse setup for taps, swipes, pinch/spread, tap-and-drag, scroll while dragging, resting fingers and modifiers. **Real Magic Mouse hardware validation is pending.** Native continuous desktop swipes, magnify and Smart Zoom are unavailable. Proprietary vendor buttons may not emit standard input. Device-specific button/wheel overrides are unavailable. See [Compatibility](Docs/COMPATIBILITY.md) and [Magic Mouse setup](Docs/guides/MAGIC_MOUSE.md).

The sandboxed Store edition includes regular buttons, click/double/hold, keyboard shortcuts, desktop/Mission Control actions, wheel adjustments, URL actions and app-specific settings. It excludes private touch gestures, media/brightness injection, command execution, app/folder targets, Sparkle and the donation button. See [Store edition](Docs/MAC_APP_STORE.md).

## Developer

**Minn Khant Thu** · [Website](https://minnkhantthu.up.railway.app/) · [Email](mailto:minnkhantthu.ucsy@gmail.com) · [Buy Me a Coffee](https://buymeacoffee.com/minnkhantthu)

[MIT license](LICENSE) · [Third-party notices](THIRD_PARTY_NOTICES.md) · [Build and contribute](CONTRIBUTING.md)
