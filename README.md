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
  artwork, playtime, last-played sorting, search, installed-only /
  playable-on-Mac / Steam Collection filters, and a "What Should I Play?"
  backlog roulette (itself filterable by installed/Collection) for
  owned-but-never-played games. Game pages show storefront details, review
  scores, DLC ownership, achievements (with global unlock rarity), marketing
  and your own captured screenshots, and launch/install actions. A Storage
  view ranks installed games by disk usage. Non-Steam apps and games can be
  added from a file picker and live alongside the rest of your library,
  launched directly rather than through Steam.
- **Store** — featured rails (specials, top sellers, new releases, coming
  soon), live search against the storefront API, in-app detail pages, and
  your Steam wishlist with sale/discount highlighting.
- **Community** — a merged news feed for the games you play (with per-game
  filter chips), live friend activity grouped by game, and Steam's global
  most-played chart with week-over-week movement.
- **Friends** — presence-grouped friends list (In-Game / Online / Offline)
  with one-click Steam chat and in-app profile pages (no browser redirect)
  showing stats, recently/most-played games, a library comparison against
  your own (games in common, what they have that you don't, and
  recommendations), and an achievement comparison for your most-played games
  in common.
- **Profile** — Steam level, aggregate playtime stats, recently played rail,
  a most-played leaderboard, a badges list, a ban/VAC status indicator, and
  a Lifetime Stats view with a monthly playtime goal you can set and track.
- **Menu bar extra** — signed-in identity, Now Playing with a session timer,
  searchable quick-launch of installed games, online friends, and app
  shortcuts.
- **Keyboard-first** — Go menu (⌘1–⌘5) switches sections; Library menu has
  Refresh (⌘R), Launch Last Played Game (⌘L), and Open Steam (⇧⌘S); an
  optional global shortcut (set in Settings) summons Mist from anywhere.
  "Launch \<game\>" also works as a Siri Shortcut / Spotlight action, no
  extra setup required.
- **Theming** — light/dark/system appearance, 20+ accent presets or a custom
  color, quick themes, ambient tinted background, and a master switch for
  the motion layer.
- **Notifications** — opt-in local notifications (all off by default) for a
  game session ending, a friend coming online, an installed game updating, a
  wishlist item going on sale, and hitting your monthly playtime goal.
- **In-app updates** — Mist checks GitHub for new releases (daily, or on
  demand from Settings) and can download, verify, and install one with a
  single click, relaunching automatically when it's done.
- **Account** — sign in with Steam or switch between multiple locally
  detected accounts, optionally launch Mist at login, and export/import your
  Settings to move between Macs or back up before experimenting.

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
bash Scripts/make-dmg.sh             # release build + installable .dmg
```

The script runs `swift build`, wraps the binary into `Mist.app` by hand
(there's no `.xcodeproj`), stamps the version, ad-hoc codesigns it, and
installs the result to `/Applications/Mist.app`. Set `MIST_SKIP_INSTALL=1`
to build without touching /Applications. The build artifact also remains at
`.build/Mist.app`.

`Scripts/make-dmg.sh` does a clean release build and stages a copy with
extended attributes, ACLs, and `.DS_Store` stripped before imaging it, so a
handed-off `.dmg` (`.build/dist/Mist-<version>.dmg`) carries no trace of this
machine or user.

VS Code launch configurations for plain debug/release binary runs are in
`.vscode/launch.json`.

## Versioning & releases

- `VERSION` holds the marketing version (semver) — edit it to cut a release.
- The build number is the git commit count at build time.
- Both are stamped into the app's `Info.plist` by `Scripts/build-app.sh` and
  shown in Settings' footer ("Mist 0.5.1 (11)").
- Release history lives in [CHANGELOG.md](CHANGELOG.md).
- `Scripts/release.sh` publishes a release: builds a `.dmg` and a `.zip`,
  extracts that version's `CHANGELOG.md` section as release notes, tags the
  commit, and runs `gh release create` (requires the
  [GitHub CLI](https://cli.github.com), authenticated via `gh auth login`).
  Bump `VERSION` and add a `CHANGELOG.md` entry first — the script checks
  for both.
- Mist itself polls [GitHub Releases](https://github.com/sasha-mattison/Mist/releases)
  for newer versions (Settings ▸ General ▸ Updates) and can install one
  in place — see "In-app updates" above.

## Project layout

```
Sources/Mist/
  App/        AppDelegate, main-menu commands, navigation model, migrations
  Models/     Decodable API models & view models (library, store, community)
  Services/   Steam Web API, storefront, community/news, local VDF parsing,
              keychain, game launching, artwork & compatibility caches,
              local notifications, wishlist sale monitor, GitHub update
              checker & installer
  Stores/     @Observable state: library, friends, profile, community, settings
  Views/      SwiftUI pages (Library, Store, Community, Friends, Profile),
              menu bar extra, settings, shared components & effects
Scripts/      build-app.sh (bundle assembly + install), make-dmg.sh (dmg
              packaging), release.sh (GitHub release publishing),
              generate-icon.swift
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
