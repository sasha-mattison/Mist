# Changelog

Versions follow [semver](https://semver.org); the marketing version lives in
the `VERSION` file and the build number is the git commit count, both stamped
into the app bundle by `Scripts/build-app.sh`.

## 0.3.0 — 2026-07-15

- **Friend profiles now open in-app** instead of redirecting to a browser —
  full profile page (stats, recently played, most-played) plus a new
  **Library Comparison** section (games in common / they have / you have,
  with "you might like" recommendations), reachable from Friends and
  Community ▸ Friend Activity.
- Game detail pages gained four new sections: **Steam review score**,
  **DLC ownership** (lazily loaded, owned/unowned per item), **your own
  captured screenshots** (read straight off disk, separate from the
  storefront's marketing screenshots), and **achievements** with unlock
  state and global rarity percentage.
- New Library tools: **"What Should I Play?"** (a backlog of owned-but-never-
  played games with a random-pick roulette) and a **Storage** view ranking
  installed games by disk usage with Finder/Steam shortcuts.
- New **Wishlist** view on the Store tab — your Steam wishlist with
  sale/discount highlighting per item.
- **Steam Collections** (the modern Library UI's custom collections) can now
  filter the library, read directly from Steam's local config — best-effort,
  since the underlying format is undocumented.
- **Lifetime Stats** view on Profile: total games/hours, % never played,
  longest since played, and a most-played leaderboard.
- **Account switcher** in Settings ▸ Account for machines with more than one
  locally-detected Steam account.
- **Launch at login** and a customizable **global keyboard shortcut** to
  summon Mist from anywhere, both in Settings.

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
