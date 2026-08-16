# Overclock — iOS app

The `overclock-arcade` game, wrapped as a real iOS app. Built 2026-08-16.
**The game is bundled inside — it runs with no internet.**

## Run it
Open `Overclock.xcodeproj` in Xcode → pick a simulator → **⌘R**.

**To install on a real iPhone** (the only step Claude can't do):
target **Overclock** → **Signing & Capabilities** → set **Team** to your Apple ID → plug the
phone in, choose it as the destination, ⌘R.
A free Apple ID works; the app expires every 7 days and you re-run it. $99/yr Developer Program
makes it permanent and allows TestFlight / App Store.

---

# 🎮 FOR WHOEVER WRITES THE GAME — native powers you can call from JavaScript

The app injects a `window.Overclock` object **before your code runs**. These are safe to call on
the website too — there they simply do nothing, so you never need to check where you are.

```js
Overclock.haptic('light')     // a tap, a tick, a coin
Overclock.haptic('medium')    // landed a jump, hit a checkpoint
Overclock.haptic('heavy')     // crash, big hit
Overclock.haptic('success')   // new high score
Overclock.haptic('warning')   // low health, running out of time
Overclock.haptic('error')     // game over

Overclock.share('Scored 4,200 on Apex Run!')   // opens the real iOS share sheet

Overclock.isApp               // true only inside the iOS app
```

**Why haptics matter more than they sound.** They are the single biggest thing that separates
"a website in a box" from something that feels like a real game on a phone. A crash you *feel*
lands completely differently from one you only see. **One line of code per event.**

Use them sparingly — constant buzzing gets ignored and drains battery. Big moments only.

---

## What the wrapper handles for you
| | |
|---|---|
| **Screen never sleeps** | `isIdleTimerDisabled` — the phone won't dim mid-run |
| **No white flash** | branded splash holds until the first frame paints |
| **No double-tap zoom** | that gesture eats fast taps in a game — blocked |
| **No pinch zoom, no scroll, no bounce** | the canvas stays put |
| **No text selection or long-press menu** | no magnifier popping up mid-game |
| **Audio plays immediately** | no tap-to-unlock gate |
| **Offline** | the whole game ships inside the app |
| **Falls back to the live site** | only if the bundled copy is ever missing |

## Layout
```
Overclock/
├── OverclockApp.swift   app entry + splash screen
├── GameView.swift       WKWebView host + the JS↔Swift bridge
├── Info.plist
├── Assets.xcassets/     app icon + splash logo
└── web/                 THE GAME — index.html, apex_run/, icons/, manifest.json
```

## Updating the game
Replace the files in `Overclock/web/` with the new build and hit ⌘R. That's the whole process.
To pull the current live version down again:

```bash
cd Overclock/web
curl -s https://overclock-arcade.vercel.app/ -o index.html
curl -s https://overclock-arcade.vercel.app/apex_run/ -o apex_run/index.html
```

## Credit where it's due
The game was already built as a **PWA** — `apple-mobile-web-app-capable`, a web manifest,
`apple-touch-icon`, `theme-color`, `display: standalone`. **That is why this took twenty minutes.**
It wasn't a web page that needed converting; it was already an app, and this put a native shell
around it and handed it the hardware.
