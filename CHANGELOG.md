# Changelog

Versions follow [semver](https://semver.org); the marketing version lives in
the `VERSION` file and the build number is the git commit count, both stamped
into the app bundle by `Scripts/build-app.sh`.

## 0.5.0 — 2026-07-16

- **Non-Steam apps and games** — a new "+" button in the Library adds any
  app via a file picker; it shows up in the grid, launches directly (no
  Steam involved), and can be removed from a context menu.
- **Backlog roulette filters** — "What Should I Play?" can now be narrowed
  to Installed Only or a specific Steam Collection before rolling; the pick
  also persists across visits instead of re-randomizing every time, rolling
  over automatically after a week (or on request).
- **Friend achievement comparison** — a friend's profile now shows your
  achievement progress side by side with theirs for your most-played games
  in common.
- **Badges**, a **ban/VAC status indicator**, and a **monthly playtime
  goal** (tracked locally, since Steam's API has no monthly breakdown) with
  progress shown in Profile ▸ Lifetime Stats.
- **Settings export/import** — back up or move your theme, hotkey, and
  notification preferences to another Mac.
- **Siri Shortcuts / Spotlight** — "Launch \<game\>" now works as a system
  Shortcut, no extra setup required.

## 0.4.0 — 2026-07-16

- **In-app updates** — Mist now checks GitHub for new releases (once a day,
  or on demand from Settings), and can download, verify, and install one
  with a single click, relaunching automatically when it's done.
- **Notifications** — opt-in local notifications (all off by default) for a
  game session ending, a friend coming online, an installed game updating,
  and a wishlist item going on sale, each with its own toggle.
- Settings is now split into **Appearance** and **General** tabs — theming
  stays on its own, while launch-at-login, the global hotkey, and
  notifications live together in General.
- New `Scripts/make-dmg.sh` produces a clean, installable `.dmg` for
  sharing builds with other people.

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
