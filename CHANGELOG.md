# Changelog

Versions follow [semver](https://semver.org); the marketing version lives in
the `VERSION` file and the build number is the git commit count, both stamped
into the app bundle by `Scripts/build-app.sh`.

## 0.2.0 — 2026-07-15

- Renamed the project from SteamClient to **Mist**, with a new fog app icon.
  One-time migration keeps sign-in, settings, caches, and the keychain-stored
  Web API key across the rename.
- New **Community** tab with three sections:
  - **News** — merged announcement feed for your library's games (falls back
    to trending games when the library is empty), with per-game filter chips
    and search.
  - **Friend Activity** — in-game friends grouped by the game they're
    playing, plus everyone else online.
  - **Trending** — Steam's global most-played chart with peak player counts
    and week-over-week rank movement.
- Menu bar popover upgrade: signed-in identity header, Now Playing with a
  live session timer, quick-launch search, online friends with one-click
  chat, and Show Library / Open Steam / Refresh / Quit actions.
- Main menu additions: **Go** menu (⌘1–⌘5 section switching) and **Library**
  menu (Refresh ⌘R, Launch Last Played Game ⌘L, Open Steam ⇧⌘S).
- Builds now install to `/Applications/Mist.app` automatically
  (`MIST_SKIP_INSTALL=1` opts out).

## 0.1.0 — 2026-07-14

- Initial app: Library (local VDF + Steam Web API), Store browsing/search,
  Friends list, Profile stats, game launching via `steam://`, menu bar
  quick-launch, Steam OpenID sign-in, theming with accent colors and motion
  effects.
