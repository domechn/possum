# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
swift build                   # debug build
swift build -c release        # release build
./scripts/make-app.sh         # build + package as build/Possum.app (ad-hoc signed)
open build/Possum.app         # launch the app
swift scripts/generate-icon.swift  # regenerate scripts/AppIcon.icns (only when icon design changes)
```

Verify sleep prevention is working: `pmset -g assertions` should show two "Possum working mode" assertions while work mode is active.

## Architecture

Single-target SwiftUI macOS app (requires macOS 13+) built with Swift Package Manager. No external dependencies. The product name is Possum (假寐, from "playing possum"); the repo directory is still `wakeup`.

**SessionController** is the central state machine driving the app through three states: `idle → countingDown → active`. It owns and coordinates all other components:

- **SleepPreventer** — creates IOKit power assertions (system sleep + display sleep) to keep the machine awake.
- **ScreensaverOverlay** — spawns borderless `NSWindow`s at `.screenSaver` level on every display, hosting the SwiftUI clock view. Adapts to display changes (plug/unplug) via `didChangeScreenParametersNotification`. Owns **HintState** (hint overlay visibility + Esc progress) and cursor show/hide.
- **ExitMonitor** — listens for keyboard/mouse events (global + local monitors) to end the session. Two modes: `.instant` (any input exits; mouse movement filtered through **MouseMoveAccumulator**, cumulative ≥ 10 pt) and `.guarded` (anti-mistouch: only holding Esc for 2s — tracked by **EscHoldTracker** — exits; other input just shows the hint overlay).
- **ScreensaverView** — animated clock face that drifts position each minute (burn-in prevention). Shows **HintOverlayView** (exit instructions, Esc progress bar, exit button) when guarded mode intercepts input. The exit button posts `.exitScreensaverRequested`, observed by SessionController.
- **ContentView** — the main window UI (start/cancel, delay stepper, guarded-mode toggle, session summary).

The app uses `@EnvironmentObject` to pass `SessionController` from the `App` struct down to views. The guarded-exit preference persists via UserDefaults key `guardedExitEnabled`.

## Conventions

- UI strings are in Chinese (zh-CN).
- No localization framework; strings are inline.
- The project deliberately avoids Xcode projects — build exclusively via SPM and the shell script.
- The app icon is generated programmatically (CoreGraphics); edit `scripts/generate-icon.swift` and re-run it rather than editing the icns.
