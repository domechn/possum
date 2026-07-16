# WakeUp — App Icon & Anti-Mistouch Mode Design

## 1. App Icon

### Visual

- **Shape**: macOS standard squircle (rounded-rect superellipse).
- **Background**: Diagonal gradient from deep blue (#1a1a4e) at top-left to deep purple (#3a1a5e) at bottom-right.
- **Moon**: A crescent (geometric arc, slightly right-tilted) in warm gold/yellow (#FFD54F). Positioned center, sized ~55% of icon safe area.
- **Prohibition line**: A single diagonal stroke from top-left to bottom-right across the moon, rounded ends, red-orange (#E53935), stroke width ~8% of icon size.
- **Style**: Flat, no shadows, no gradients on elements themselves. Minimal — reads clearly from 16×16 to 1024×1024.

### Implementation

- `scripts/generate-icon.swift` — standalone Swift script using CoreGraphics to draw the icon programmatically at all required sizes (16, 32, 64, 128, 256, 512, 1024, plus @2x variants) into a `.iconset` folder.
- Run `iconutil --convert icns` to produce `scripts/AppIcon.icns`.
- Committed to repo so daily builds don't need regeneration.
- `scripts/make-app.sh` copies icns to `build/WakeUp.app/Contents/Resources/`.
- `scripts/Info.plist` adds `<key>CFBundleIconFile</key><string>AppIcon</string>`.

---

## 2. Anti-Mistouch Mode

### User-facing behavior

| Setting | Exit behavior |
|---------|--------------|
| Off (default) | Current behavior: mouse move ≥10pt or any key exits immediately |
| On | Only long-press Esc (2s) or click the on-screen exit button exits |

### UI changes — ContentView

- New toggle below the delay stepper: "防误触模式" with subtitle "开启后需按住 Esc 或点击按钮退出屏保".
- Persisted via `@AppStorage("guardedExitEnabled")`, default `false`.
- Toggle disabled while session is active (window is hidden anyway).

### Screensaver hint layer

When guarded mode is active and any input is detected:

1. **Hint overlay appears** on all screens simultaneously:
   - Semi-transparent dark backdrop (black 0.5 opacity) over the clock.
   - Text: "防误触模式 · 按住 Esc 或点击按钮退出"
   - Below text: a "退出屏保" button (rounded rect, white text on red-orange background).
   - Esc hold progress shown as a thin horizontal bar under the text, filling left-to-right over 2 seconds.
2. **Mouse cursor un-hides** so the user can aim at the button.
3. **Auto-dismiss**: if no further input for 5 seconds, hint fades out, cursor re-hides.
4. **Mouse movement during hint** resets the 5-second timer (keeps hint visible) but does NOT exit.

### Exit paths (guarded mode)

| Action | Result |
|--------|--------|
| Press & hold Esc ≥ 2s | Exit screensaver |
| Click "退出屏保" button | Exit screensaver |
| Any other input | Show/refresh hint overlay; do NOT exit |
| Release Esc before 2s | Cancel progress, hint stays visible |

### New types

#### `EscHoldTracker` (pure struct, testable)

```swift
struct EscHoldTracker {
    let requiredDuration: TimeInterval // default 2.0
    private(set) var startTime: Date?

    mutating func keyDown(at time: Date) { ... }
    mutating func keyUp() -> Bool { ... } // returns false (cancelled)
    func progress(at time: Date) -> Double { ... } // 0.0–1.0
    func isComplete(at time: Date) -> Bool { ... }
}
```

#### `HintState: ObservableObject`

```swift
@MainActor
final class HintState: ObservableObject {
    @Published var visible = false
    @Published var escProgress: Double = 0  // 0.0–1.0
    func showHint() { ... }
    func hideHint() { ... }
}
```

Owned by `ScreensaverOverlay`, injected as `@EnvironmentObject` into each screen's `ScreensaverView`.

### ExitMonitor changes

- `arm(mode:onExit:onHint:)` — new `mode` parameter: `.instant` (current) or `.guarded`.
- `.guarded` mode:
  - Non-Esc input → calls `onHint()` callback (shows overlay), does NOT fire exit.
  - Esc keyDown → starts `EscHoldTracker`; a Timer checks progress every 100ms, calling `onHint()` with updated progress.
  - Esc keyUp before 2s → cancels tracker.
  - Esc held ≥ 2s → fires exit.
- Button click exit is handled purely in SwiftUI (Button action calls `SessionController.deactivate()` directly), not through ExitMonitor.

### SessionController changes

- Reads `guardedExitEnabled` from UserDefaults at activation time.
- Passes mode to `ExitMonitor.arm(mode:...)`.
- Passes `HintState` to overlay for hint callbacks.

### Constraints

- No accessibility permissions required (app is frontmost during screensaver).
- Countdown phase unaffected (guarded mode only applies in `.active` state).
- Lid-close still sleeps (unchanged limitation).

---

## 3. Testing

Add a test target `WakeUpTests` to `Package.swift`:

- `MouseMoveAccumulatorTests` — verify threshold behavior.
- `EscHoldTrackerTests` — verify timing logic: incomplete hold cancels, complete hold signals exit, progress calculation.
