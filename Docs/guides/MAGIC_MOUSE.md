# Magic Mouse setup and hardware acceptance

The Magic Mouse page is available even when no Magic Mouse is connected. Prepare mappings offline, then use the checklist below when the mouse arrives. Touch support is experimental in the direct-download edition. Software replay and UI tests do not establish real-device compatibility.

## Prepare your setup

1. Open **Magic Mouse** in the sidebar. Select **All apps**, or add/select the app you want to customize.
2. Choose **Review suggested gestures** to inspect the starter setup. Applying it changes the listed touch gestures only; existing physical mouse button mappings remain intact. It does not turn on the engine or touch capture.
3. Choose a gesture, finger count, tap count/direction and optional modifier keys. Select **Set action / Change action**. Record a shortcut or enter the target when the chosen action needs one, then save.
4. **Saved touch gestures** lists this scope's saved inputs, with Edit and Delete. Undo restores a deleted mapping. Removing an app override restores inheritance from All apps.
5. **See gesture examples** opens the same original illustrations used on the website, offline. Animations do not capture or inject mouse input.
6. Open **Touch feel** only when needed. Each setting has a short explanation. Slider changes save at the end of the adjustment, rather than restarting the input adapter repeatedly during a drag.

## Inputs and suggested actions

| Input | Suggested action / configuration |
|---|---|
| One-finger single / double / triple tap | Native left click counts; separate custom actions can replace them |
| Right-side single / double / triple tap | Right click counts; adjustable side and front boundary |
| Two-finger tap | App Exposé |
| Three-finger tap | Show Desktop |
| Two-/three-finger double / triple tap | Assign any supported action; otherwise use that finger count's single-tap action |
| One-finger swipe left / right | Back / Forward; vertical scrolling remains native |
| Two-finger swipe left / right | Previous / next desktop |
| Two-finger swipe up / down | App Exposé / minimize current window |
| Three-finger swipe left / right | Cycle apps backward / forward; pause to commit the highlighted app |
| Three-finger swipe up / down | Mission Control / Show Desktop |
| Pinch / spread | Zoom Out / Zoom In keyboard shortcuts |
| Tap, then touch and hold or move | Drag without pressing the shell; move the mouse, lift the owning finger to release |
| A new second finger while dragging | Continuous vertical/horizontal scroll, with adjustable speed and reversal |
| A stationary resting finger | Excluded from a new gesture after the resting delay; no need to lift the whole hand |
| Command / Option / Control / Shift + gesture | Explicit mappings override; ordinary click/drag actions otherwise preserve held keys |

Actions also include left/right/middle/double/triple click, close/minimize/hide/cycle windows, app switching, Mission Control, App Exposé, Show Desktop, desktop switching, navigation, zoom shortcuts, media controls, recorded keyboard shortcuts, app/folder/URL opening, Apple Shortcuts, and explicitly enabled timed shell commands. Shell commands use `/bin/zsh -lc` with a minimal environment, the selected working directory, and process-group cancellation. Imported automation stays disabled for review.

Native continuous magnification, continuous desktop transitions and native Smart Zoom are not implemented by these discrete actions. Zoom shortcut support varies by app. If macOS Smart Zoom competes with double taps, turn it off in the Mouse pane of System Settings.

## What has been checked in software

- All one-/two-/three-finger tap counts and all 16 modifier combinations.
- Every supported swipe direction, pinch recognition and one-shot delivery.
- Resting contacts, fast brush rejection, thresholds, native scroll quarantine and invalid/out-of-order frames.
- Drag ownership, owner lift with other contacts remaining, second-finger scroll phases/reversal, device change, stale frames and cancellation.
- Timed app chooser state, repeated-step deadline extension and cancellation.
- Version-2 settings without the new tuning fields; settings round-trip and validation.
- Preset review/save, app override save/delete/Undo with temporary settings; ordinary mouse button mappings preserved.
- EN, MY and Simplified Chinese compiled resources; native light/dark layouts at 820 and 1040 points; website animations and responsive layouts.

## Real mouse checklist — not yet passed

Start with disposable documents and normal clicks. Pause other mouse utilities, allow Accessibility/Input Monitoring, connect the Magic Mouse, then enable GlideMouse and **Use Magic Mouse touch gestures**. Test at the pointer's actual target, outside any physical-button capture box.

Record the mouse generation/model, macOS version and CPU architecture. The private adapter currently accepts non-built-in family 112 only. A recognized HID mouse name alone does not prove that the touch ABI works for that generation. Unsupported private device families remain disabled.

| Check | Pass condition |
|---|---|
| Adapter discovery | Touch contacts appear for this Magic Mouse; built-in/external trackpads are not selected |
| Native click, right click, normal scroll | Ordinary mouse input still works when touch is paused and enabled |
| Single/double/triple tap with 1, 2 and 3 fingers | Correct counts, no phantom actions after lifting |
| Right-side and front zone | Boundary matches the physical surface orientation; no mistaken left/right actions |
| One-/two-/three-finger swipes | Each enabled direction runs once; no competing native page/desktop transition |
| Pinch / spread | Correct shortcut direction in an app that supports it |
| Resting fingers | New taps/swipes work while another finger rests; scrolling does not create a click |
| Drag and release | Selected item follows mouse motion, owning-finger lift releases even when another finger remains |
| Drag + second-finger scroll | Correct vertical/horizontal direction and speed; no double scroll or missing end phase |
| Modifier mappings | Command-click selects multiple items; custom modifier override wins only in its app scope |
| App cycling | Repeated swipes move one app at a time; stopping commits once; no Command key remains held |
| Faults | Pause, quit, sleep, disconnect, permission loss and callback timeout release every synthetic held input |
| Mixed devices | Ordinary mouse and trackpad input remain usable during touch actions; continuous event attribution needs physical confirmation |
| Restart | Saved mappings persist without silently enabling new presets |

Emergency pause: **Control + Option + Command + Escape**. The menu-bar Pause switch is also available. Do not call Magic Mouse hardware support verified until this checklist passes for the named device and OS.

## မြန်မာလို စလုပ်ရန်

Magic Mouse မရှိသေးလည်း sidebar က **Magic Mouse** ကို ဝင်ပြီး ကြိုသတ်မှတ်ထားနိုင်ပါတယ်။ **အကြံပြု gesture များ ကြည့်ရန်** ကို နှိပ်ပြီး ပါလာမယ့် action တွေကို အရင်ကြည့်ပါ။ လက်ရှိ mouse ရဲ့ ဘေးခလုတ်ဆက်တင်တွေကို မပြောင်းပါဘူး။

Gesture၊ လက်ချောင်းအရေအတွက်၊ ထိမယ့်အကြိမ်ရေ သို့မဟုတ် ဦးတည်ချက်ကို ရွေးပြီး **လုပ်ဆောင်ချက် သတ်မှတ်ရန်** ကို နှိပ်ပါ။ Action ရွေးပြီး သိမ်းပါ။ App တစ်ခုကို ရွေးထားရင် အဲဒီ app မှာပဲ ပြောင်းပါမယ်။ မပြင်ထားတဲ့ gesture တွေက App အားလုံးအတွက် ဆက်တင်ကို ဆက်သုံးပါမယ်။

Mouse ရလာရင် အခြား mouse app တွေကို ခေတ္တပိတ်ပြီး GlideMouse နဲ့ Magic Mouse touch gesture ကို ဖွင့်ပါ။ တစ်ချက်ထိ၊ ညာခြမ်းထိ၊ နှစ်ချက်/သုံးချက်ထိတာတွေကို အရင်စမ်းပါ။ ပြီးမှ swipe၊ pinch၊ drag၊ drag လုပ်ရင်း scroll နဲ့ key တွဲနှိပ်တာတွေကို စမ်းပါ။ Mouse အစစ်နဲ့ မစမ်းရသေးလို့ လက်ရှိ touch support က စမ်းသပ်ဆဲပါ။

## 中文快速设置

未连接 Magic Mouse 时也能打开侧栏的 **Magic Mouse** 页面设置手势。先查看建议手势，再选择手势、手指数、次数或方向，以及可选修饰键，设置操作并保存。建议设置不会替换其他鼠标的物理按键，也不会自动启用输入引擎。

选择某个 App 后保存的覆盖设置只在该 App 前台运行时生效，其余手势继续沿用所有 App 的设置。可以编辑、删除或撤销删除。

拿到鼠标后，暂停其他鼠标工具，连接 Magic Mouse，启用 GlideMouse 和触控手势。从轻点和右侧轻点开始，再检查多次轻点、滑动、捏合、拖动、拖动时滚动及修饰键。真实硬件验证尚未完成，触控支持仍为实验功能。
