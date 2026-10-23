# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
swift build                   # debug build
swift build -c release        # release build
swift test                    # unit tests (Tests/PossumTests)
./scripts/make-app.sh         # build + package as build/Possum.app (ad-hoc signed)
open build/Possum.app         # launch the app
swift scripts/generate-icon.swift  # regenerate scripts/AppIcon.icns (only when icon design changes)
```

Verify sleep prevention is working: `pmset -g assertions` should show two "Possum working mode" assertions while work mode is active.

## Architecture

Single-target SwiftUI macOS app (requires macOS 13+) built with Swift Package Manager. No external dependencies. The product name is Possum (假寐, from "playing possum").

**SessionController** is the central state machine driving the app through three states: `idle → countingDown → active`. It owns and coordinates all other components:

- **SleepPreventer** — creates IOKit power assertions (system sleep + display sleep) to keep the machine awake. `start()` returns false (and holds nothing) if either assertion fails; SessionController then stays idle and shows `errorMessage`.
- **ScreensaverOverlay** — spawns borderless `OverlayWindow`s at `.screenSaver` level on every display, hosting the SwiftUI clock view. Adapts to display changes (plug/unplug) via `didChangeScreenParametersNotification`. While showing it sets `NSApp.presentationOptions` (hide Dock/menu bar, disable process switching/hide) and re-activates itself on `didResignActiveNotification`. Owns **HintState** (hint overlay visibility + Esc progress); the cursor is shown only while the hint is visible.
- **ExitMonitor** (`@MainActor`) — listens for input to end the session: mouse via global + local monitors, keys via the local monitor only (global key monitoring needs Input Monitoring permission). Two modes: `.instant` (any input exits; mouse movement filtered through **MouseMoveAccumulator**, cumulative ≥ 10 pt, reset after a 0.5s pause) and `.guarded` (anti-mistouch: only holding Esc without modifiers for 2s — tracked by **EscHoldTracker** — exits; other input just shows the hint overlay, throttled).
- **ScreensaverView** — animated clock face that drifts position each minute (burn-in prevention; no animation under Reduce Motion). Shows **HintView** (exit instructions, Esc progress bar, exit button) when guarded mode intercepts input. The exit button calls `ScreensaverOverlay.onExitRequested`, which SessionController sets.
- **ContentView** — the main window UI (start/cancel, delay stepper, guarded-mode toggle, session summary).

The app uses `@EnvironmentObject` to pass `SessionController` from the `App` struct down to views. The guarded-exit preference persists via UserDefaults key `guardedExitEnabled`.

## Conventions

- UI strings are in Chinese (zh-CN).
- No localization framework; strings are inline.
- The project deliberately avoids Xcode projects — build exclusively via SPM and the shell script.
- The app icon is generated programmatically (CoreGraphics); edit `scripts/generate-icon.swift` and re-run it rather than editing the icns.
