# Overclock

**Games built in-house. Running hotter than rated.**

▶︎ **Play now: https://overclock-arcade.vercel.app**

A small arcade, shipped two ways from one codebase.

| | |
|---|---|
| **`web/`** | The arcade. Plain HTML/JS, no build step, no framework. Deploys anywhere static. |
| **`ios/`** | A native iOS wrapper. The game ships *inside* the app and runs with no internet. |

## Apex Run
Pseudo-3D arcade racer — three circuits, seven rivals, three laps, and a championship across
all of them. Keyboard, gamepad over Bluetooth or USB, or on-screen touch controls.

## Kaboom
Catch the Mad Bomber's bombs in your buckets. Miss one and every bomb on screen detonates and
costs you a bucket. Speed and points per bomb rise every level, with streaks, a bonus for a
perfect level, extra buckets, and a saved best score. Fills the whole screen on a phone. Keyboard, mouse, gamepad, or drag a finger to slide the buckets.

---

## The iOS app

Open `ios/Overclock.xcodeproj` and press ⌘R.

It is a `WKWebView` host, but not a naive one. What the wrapper adds:

**Haptics.** The game calls `Overclock.haptic('heavy')` on a crash, `'success'` on a high score.
This is the single biggest thing separating a website in a box from something that feels native —
a crash you *feel* lands differently from one you only see.

**A pause control.** The game binds `togglePause()` to **P** and **Escape**. A phone has no
keyboard, so the wrapper injects a real `.tbtn` into the game's own touch row — centred between
the turn and brake controls, inheriting the existing styling. It fires a synthetic keypress, so
it runs the game's own handler. **The game's code was never modified to support this.**

**Directory-link resolution.** A web server turns `apex_run/` into `apex_run/index.html`
automatically. `file://` does not — the link silently lands on nothing. The wrapper resolves it,
so the same HTML works served or bundled.

**Plus:** screen never sleeps mid-race · branded splash so there's no white flash · safe-area
insets so nothing hides under the Dynamic Island · no double-tap zoom, pinch, scroll, bounce, or
long-press magnifier · audio plays without a tap-to-unlock gate.

### The bridge
```js
Overclock.haptic('light'|'medium'|'heavy'|'success'|'warning'|'error')
Overclock.share('Scored 4,200 on Apex Run!')   // native iOS share sheet
Overclock.isApp                                 // true only inside the app
```
Safe to call on the web — there they no-op, so the game never has to know where it's running.

## Updating the game
Replace `ios/Overclock/web/` with the new build and press ⌘R. That's the whole process.

## License
MIT
