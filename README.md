# Mist

A native macOS companion app for Steam, built with SwiftUI. Mist reads your
local Steam install and the Steam Web API to give you a fast, Mac-feeling
window into your library, the storefront, your friends, and the community —
plus a menu bar quick-launcher that's always one click away.

> Mist is a personal project and is not affiliated with or endorsed by
> Valve Corporation. Game launching, installs, and purchases are handed off
> to the real Steam client via `steam://` URLs.

## Features

- **Library** — your installed and owned games merged into one grid with
  artwork, playtime, last-played sorting, search, and installed-only /
  playable-on-Mac filters. Game pages show storefront details, screenshots,
  and launch/install actions.
- **Store** — featured rails (specials, top sellers, new releases, coming
  soon) and live search against the storefront API, with in-app detail pages.
- **Community** — a merged news feed for the games you play (with per-game
  filter chips), live friend activity grouped by game, and Steam's global
  most-played chart with week-over-week movement.
- **Friends** — presence-grouped friends list (In-Game / Online / Offline)
  with one-click Steam chat.
- **Profile** — Steam level, aggregate playtime stats, recently played rail,
  and a most-played leaderboard.
- **Menu bar extra** — signed-in identity, Now Playing with a session timer,
  searchable quick-launch of installed games, online friends, and app
  shortcuts.
- **Keyboard-first** — Go menu (⌘1–⌘5) switches sections; Library menu has
  Refresh (⌘R), Launch Last Played Game (⌘L), and Open Steam (⇧⌘S).
- **Theming** — light/dark/system appearance, 20+ accent presets or a custom
  color, quick themes, ambient tinted background, and a master switch for
  the motion layer.

## Requirements

- macOS 26 or later (built against the macOS 26 beta SDK).
- Xcode Command Line Tools (a full Xcode install is not required).
- The Steam client installed locally (Mist reads its VDF files and launches
  games through it).
- Optional but recommended: a personal [Steam Web API key](https://steamcommunity.com/dev/apikey)
  to load your owned games, profile, friends, and community data. The key is
  stored in the macOS Keychain.

## Building

```bash
bash Scripts/build-app.sh            # debug build
bash Scripts/build-app.sh release    # release build
```

The script runs `swift build`, wraps the binary into `Mist.app` by hand
(there's no `.xcodeproj`), stamps the version, ad-hoc codesigns it, and
installs the result to `/Applications/Mist.app`. Set `MIST_SKIP_INSTALL=1`
to build without touching /Applications. The build artifact also remains at
`.build/Mist.app`.

VS Code launch configurations for plain debug/release binary runs are in
`.vscode/launch.json`.

## Versioning

- `VERSION` holds the marketing version (semver) — edit it to cut a release.
- The build number is the git commit count at build time.
- Both are stamped into the app's `Info.plist` by `Scripts/build-app.sh` and
  shown in Settings' footer ("Mist 0.2.0 (14)").
- Release history lives in [CHANGELOG.md](CHANGELOG.md).

## Project layout

```
Sources/Mist/
  App/        AppDelegate, main-menu commands, navigation model, migrations
  Models/     Decodable API models & view models (library, store, community)
  Services/   Steam Web API, storefront, community/news, local VDF parsing,
              keychain, game launching, artwork & compatibility caches
  Stores/     @Observable state: library, friends, profile, community, settings
  Views/      SwiftUI pages (Library, Store, Community, Friends, Profile),
              menu bar extra, settings, shared components & effects
Scripts/      build-app.sh (bundle assembly + install), generate-icon.swift
Resources/    Info.plist, AppIcon
```

## Development notes

- **`@ViewState` instead of `@State`**: the Command Line Tools toolchain
  lacks the SwiftUIMacros compiler plugin, so `@State` doesn't compile here.
  `@ViewState` (Views/Shared/ViewState.swift) is a drop-in replacement —
  use it everywhere you'd reach for `@State`.
- **Keep scene roots to a single unmodified view**: on the current macOS
  beta, chaining ~6+ modifiers directly inside a `WindowGroup`/`MenuBarExtra`
  closure makes the app launch with no windows at all, silently. Environment
  injection lives in the `MainWindowRoot`/`MenuBarRoot` wrappers in
  `MistApp.swift` — add new modifiers there, not on the scene root.
- Keyless endpoints (storefront, ISteamNews, ISteamChartsService) work
  without any setup; everything identity-related needs the Web API key plus
  a signed-in or locally detected SteamID.
