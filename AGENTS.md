# AGENTS.md — working on Kitab at-Tawheed

The front door for any AI agent (Claude Code, Codex, Cursor, Copilot, Zed …)
working in this repo. **Read this first, then the doc it points you to for the
task at hand.** It is intentionally short — the detail lives in `docs/` and the
code. When you learn something non-obvious, record it (see *Memory* below).

---

## What this is

**Sharah Kitab at-Tawheed** — an offline-first Flutter audio app (Android + iOS)
by Al Marfa Technologies, live on the [Play Store](https://play.google.com/store/apps/details?id=com.almarfa.tawheed)
(`com.almarfa.tawheed`). Users stream or download lecture series explaining the
book *Kitab at-Tawheed*, with full lock-screen/notification playback.

- **Multi-series:** more than one content series ships in one app — an **Urdu**
  series (Shaikh Abdullah Nasir Rahmani) and an **Arabic** series (Shaikh Salih
  al-Fawzan). Series differ in language, RTL, and available tabs (the Arabic
  series has a Book tab, no Study tab). Series config is remote-driven.
- **4 UI locales (ARB):** `app_en`, `app_ar`, `app_ur`, `app_ur_roman`.
  **Content language and UI language are independent** — see gotchas.
- **Remote-config driven:** brand strings, feature flags, and content URLs come
  from a CDN JSON, so most changes ship without an app release.

Package name is `com.almarfa.tawheed`; the Dart package is `myapp` (imports are
`package:myapp/...`).

---

## Architecture in one breath

UI → `provider`/`ChangeNotifier` providers → services. **Screens never call
services directly.** `lib/app.dart` wires the provider tree in a deliberate
order; `PreferencesService`, `CatalogService`, `DownloadNotificationService` are
`.instance` singletons initialised *before* the `MultiProvider` tree (deliberate,
not an oversight). Full picture: [README.md](README.md#architecture) and
[docs/i18n-architecture.md](docs/i18n-architecture.md).

```
lib/screens (13)  providers (13)  services (8)  models (8)
    widgets (13)  audio/  theme/  l10n/  utils/  data/
```

---

## Essential commands (Makefile)

| Command | What |
|---|---|
| `make test` | Unit + widget tests (mirrors CI) |
| `make analyze` | `flutter analyze --fatal-warnings` |
| `make ci` | Full local CI: analyze + test + debug build |
| `make integration-test DEVICE=<id>` | On-device end-to-end |
| `make orientation-test DEVICE=<id>` | On-device portrait/landscape flip suite |
| `make setup-release-secrets` | One-time: push signing + Play creds to GitHub secrets |
| `make release-auto BUMP=minor` | One-click release from `develop` → Play internal track |

`flutter devices` to find `<id>`. Java **21** required (see gotchas).

---

## Conventions — follow these exactly

1. **i18n: every user-facing string goes in ALL 4 ARB locales** (`en`, `ar`,
   `ur`, `ur_roman`) — never English-only. The ARB is the canonical wording.
2. **One chrome locale:** use `context.l10n` — never fork chrome on the series
   (no `isArabic ? _arXxx : l10n.xxx`, no reviving `l10nForSeries`). The edition
   steers chrome upstream, by supplying the default app language; forking at the
   call site would override the user's explicit pick. **Numbers in chrome follow
   the chrome locale** (`context.localizedDigits` and friends in
   [lib/utils/l10n_extensions.dart](lib/utils/l10n_extensions.dart)) — so the
   Urdu edition, which ships English chrome, keeps Western digits. The **Book**
   is the one exception: it numbers in the *edition's* script. See
   [ADR-0002](docs/decisions/0002-chrome-language-follows-the-content-edition.md).
3. **State flows through providers.** New shared state → a `ChangeNotifier`
   provider wired in `lib/app.dart`, not ad-hoc in a widget.
4. **Commits:** Conventional Commits (`type(scope): subject`). **Never** add a
   `Co-Authored-By` trailer. Releases derive the changelog from these.
5. **Branches:** feature → `develop` → (release) → `master`. Releases are cut
   with `make release-auto` from `develop`; never hand-tag.
6. **Before pushing:** `make analyze && make test` must be green (the pre-push
   hook enforces this).
7. **Changes ship with tests — in the same change.** New or changed behaviour
   gets coverage: pure logic → a unit test; UI → a widget test that fakes the
   platform channel (`SharePlatform`, `url_launcher`, etc., as existing tests
   do). Cover the **happy path *and*** the flag-gated / empty / edge branches
   (e.g. a feature-flagged control: present when on, absent when off). When a
   screen embeds shared chrome (`AppOverflowMenu`, mini-player), its test must
   provide the same providers the app wires globally, or it throws
   `ProviderNotFoundException`. A green `make test` is the floor, not the goal —
   don't wait to be asked for tests.

---

## Memory — how this "second brain" stays alive

This repo's durable memory is **in-repo and portable** so any LLM can use it:

- **[docs/gotchas.md](docs/gotchas.md)** — hard-won landmines (things that cost
  real time to rediscover). **Read it before non-trivial work.**
- **`docs/decisions/`** — ADRs: the *why* behind significant choices (add one
  when you make a decision future-you would question).

**The loop:** when you discover something non-obvious — a landmine, a fixed bug
whose cause wasn't obvious, a convention — **append it to `docs/gotchas.md`** (or
add an ADR) in the same change. Keep entries one fact each, newest patterns
first. That is what makes this a second brain rather than a static readme.

---

## Doc index (`docs/`)

**Start here for a task:**
- [setup.md](docs/setup.md) — environment, signing, platform notes
- [testing.md](docs/testing.md) — test layers and how to run them
- [test-plan.md](docs/test-plan.md) — ranked backlog of the gaps that matter
- [troubleshooting.md](docs/troubleshooting.md) — common failures + fixes
- [ci-cd.md](docs/ci-cd.md) — pipeline, one-time secret setup, branch model
- [release-runbook.md](docs/release-runbook.md) — step-by-step to cut a release
- [deployment.md](docs/deployment.md) — build/deploy commands, signing keys

**Deeper reference:**
- ⭐ [mobile-engineering-playbook.md](docs/mobile-engineering-playbook.md) — **portable lessons for any mobile app** (networking/CDN, offline, testing, release) — read for the *why*, reuse on the next project
- [i18n-architecture.md](docs/i18n-architecture.md) — localisation + series model
- [remote-content-strategy.md](docs/remote-content-strategy.md) — CDN config/catalog
- [offline-mode-plan.md](docs/offline-mode-plan.md) — download/offline design
- [onboarding-flows.md](docs/onboarding-flows.md) — welcome/series selection
- [git-workflow.md](docs/git-workflow.md) — branch + PR flow
- [android-xcode-setup.md](docs/android-xcode-setup.md) · [website-architecture.md](docs/website-architecture.md)
- [play-store-listing.md](docs/play-store-listing.md) · [checklist.md](docs/checklist.md)
