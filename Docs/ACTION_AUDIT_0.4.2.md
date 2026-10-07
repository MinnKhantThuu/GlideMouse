# Action labels and expandable controls — 0.4.2

The volume direction codes were correct. The Burmese label for increasing volume could also be read as making the sound quieter. It now explicitly means making the sound louder; decreasing volume keeps its own action. Stored action identifiers and user mappings are unchanged.

Reviewed every stored action route and EN/MY/ZH label. Eight media key codes and eighteen virtual key codes match the installed Apple SDK definitions. No reversed volume, brightness, browser or desktop direction pairs were found in source. Mute toggles both ways, App launcher opens Spotlight, and Screenshot opens the screenshot toolbar; labels now describe those behaviors. Smart Zoom remains excluded from selectable actions; Canvas pan is restricted to held-button drag.

This is a source/routing audit, not a claim that every action was physically exercised. Some shortcuts depend on the foreground app and macOS shortcut settings. Destructive actions such as Close window and Lock screen were not fired during this audit.

Optional side-button suggestions moved to Settings, initially collapsed, with explanation and explicit review before changes. Suggestions are not required, and moving their controls does not apply any settings. Magic Mouse suggestions use the same clear wording.

Expandable sections use an explicit full-width Button for the label, blank area and arrow in pages and sheets. The Add button sheet scrolls its input area so expanded content cannot cut off the title or controls.

## Action review

| Action | English label | Burmese label |
| --- | --- | --- |
| none | Do nothing | ဘာမှမလုပ်ပါ |
| leftClick | Perform a left click | ဘယ်ကလစ် လုပ်ပေးမည် |
| rightClick | Perform a right click | ညာကလစ် လုပ်ပေးမည် |
| middleClick | Perform a wheel click | ဘီးခလုတ် ကလစ်လုပ်ပေးမည် |
| doubleClick | Perform a left double click | ဘယ်ကလစ် နှစ်ချက်လုပ်ပေးမည် |
| tripleClick | Perform a left triple click | ဘယ်ကလစ် သုံးချက်လုပ်ပေးမည် |
| toggleDrag | Toggle drag | ဖိဆွဲခြင်းဖွင့်ပိတ် |
| back | Back | နောက်ပြန် |
| forward | Forward | ရှေ့ဆက် |
| zoomIn | Zoom in | ချဲ့ရန် |
| zoomOut | Zoom out | ချုံ့ရန် |
| quickLook | Quick Look | Quick Look |
| smartZoom | Native Smart Zoom (unavailable) | Native Smart Zoom (မရသေး) |
| closeWindow | Close window | Window ပိတ်ရန် |
| minimizeWindow | Minimize window | Window ချုံ့ထားရန် |
| hideApp | Hide app | App ဖျောက်ထားရန် |
| cycleWindows | Cycle windows | ဒီ App ၏ Window များ ပြောင်းရန် |
| appSwitcher | Next app | နောက် app သို့ |
| previousApp | Previous app | အရင် app သို့ |
| cycleAppsForward | Cycle apps forward | နောက် app ကို ရွေးမည် |
| cycleAppsBackward | Cycle apps backward | အရင် App ကို ရွေးမည် |
| missionControl | Mission Control | Window အားလုံး ကြည့်ရန် |
| appExpose | App Exposé | လက်ရှိ App ၏ Window များ ကြည့်ရန် |
| showDesktop | Show desktop | Desktop ပြရန် |
| spaceLeft | Space left | Desktop ဘယ်ဘက်သို့ |
| spaceRight | Space right | Desktop ညာဘက်သို့ |
| appLauncher | Search apps (Spotlight) | App ရှာဖွင့်ရန် (Spotlight) |
| volumeUp | Increase volume | အသံကျယ်စေရန် |
| volumeDown | Decrease volume | အသံလျှော့ရန် |
| mute | Mute / unmute | အသံပိတ် / ပြန်ဖွင့်ရန် |
| playPause | Play / pause | မီဒီယာ ဖွင့် / ခေတ္တရပ်ရန် |
| nextTrack | Next track | နောက်သီချင်း |
| previousTrack | Previous track | အရင်သီချင်း |
| brightnessUp | Brightness up | မျက်နှာပြင် ပိုလင်းစေရန် |
| brightnessDown | Brightness down | မျက်နှာပြင် အလင်းလျှော့ရန် |
| shortcut | Custom shortcut | စိတ်ကြိုက် shortcut |
| openApp | Open app | App ဖွင့်ရန် |
| openFolder | Open folder | Folder ဖွင့်ရန် |
| openURL | Open web URL | ဝဘ်လင့်ခ်ဖွင့်ရန် |
| lockScreen | Lock screen | Screen လော့ခ်ချရန် |
| screenshot | Open screenshot tools | Screenshot ရိုက်ရန် ကိရိယာများဖွင့်မည် |
| appleShortcut | Run Apple Shortcut | Apple Shortcut လုပ်ဆောင်ရန် |
| shell | Shell command (opt-in) | Shell command (ခွင့်ပြုမှသာ) |
| canvasPan | Canvas pan | Canvas ရွှေ့ရန် (ခလုတ်ဖိထား၍) |
