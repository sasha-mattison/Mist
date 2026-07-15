---
name: verify
description: Build, launch, and drive Mist.app on the live Mac to verify changes end-to-end.
---

# Verifying Mist changes

## Build & launch

```bash
bash Scripts/build-app.sh            # swift build + assemble .build/Mist.app + ad-hoc sign
                                     # …and installs to /Applications/Mist.app (MIST_SKIP_INSTALL=1 to skip)
pkill -x Mist; sleep 1
open -g /Applications/Mist.app       # -g: don't steal focus (user may be using the Mac)
```

## Confirm the window exists (don't trust System Events)

`tell process "Mist" to count windows` returns 0 even when the window
is open. Use CGWindowList instead — a tiny Swift script filtering
`kCGWindowOwnerName == "Mist"` at layer 0; the main window is
1100×720. If the process is alive but CGWindowList shows nothing, the app
launched windowless — see the pitfall below.

## Driving the UI

- Screenshot a specific window: `screencapture -o -x -l <windowID> out.png`.
- Menu bar menus: `tell process "Mist" to click menu item X of menu
  "Go" of menu bar 1` — works, as do `keystroke "4" using command down`
  section shortcuts (⌘1…⌘5) after `tell application "Mist" to activate`.
- The Community page's segmented control is `radio group 1 of group 1 of
  toolbar 1 of window 1` (radio buttons 1–3).
- The toolbar search field resists AX focus (`click text field …` doesn't
  focus it); prefer probing in-page controls (e.g. news filter chips) via a
  CGEvent click at screen coordinates.
- The MenuBarExtra status item ("Game Controller", menu bar 2) does NOT open
  its popover via AX `click`. Post a real CGEvent left click at the status
  item's frame (its window is the Mist-owned window at layer 25);
  the popover then appears as a 300pt-wide Mist window.

## Cautions (live Mac!)

- Never click game cards or quick-launch rows — they launch real games.
- Take a fresh screenshot before every coordinate-based click.
- Real Steam ("Steam", "Steam Helper") may be running — leave it alone.

## Pitfall: windowless launch

On this macOS 26/27-beta SwiftUI, chaining ~6+ modifiers directly on the
WindowGroup root content silently prevents ALL windows (and the status item)
from being created — no crash, no log, run loop idle. Keep scene root
closures to a single unmodified view; environment injection lives inside
MainWindowRoot/MenuBarRoot wrappers in MistApp.swift. If a launch
ever comes up windowless again, suspect a new modifier on the scene root.
