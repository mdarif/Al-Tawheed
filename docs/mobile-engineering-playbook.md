# Mobile Engineering Playbook — lessons for future apps

Portable, app-agnostic lessons learned building and shipping this app. Written to
be lifted into the *next* mobile project. This is the "what I'd tell myself at the
start" doc — the specific landmines for *this* codebase live in
[gotchas.md](gotchas.md); this is the transferable wisdom.

---

## 1. Networking & CDN — the failure mode that bites in production

**A fresh install has no cache, so its very first network fetch MUST succeed —
or degrade gracefully. Design for that one request failing.**

- **Never ship production content on a vendor's default subdomain**
  (`*.pages.dev`, `*.web.app`, `*.s3.amazonaws.com`, `*.blob.core.windows.net`).
  Those resolve to IP ranges some ISPs filter, throttle, or TCP-reset — especially
  on mobile carriers in South Asia / MENA / other emerging markets, which is often
  exactly your audience. **Use a custom domain you control** (its CDN anycast IPs
  are far more universally reachable).
- **"Works in my browser" ≠ "works in the app."** Browsers use *Happy Eyeballs*
  (race IPv4 and IPv6, take whichever connects first) plus caching and auto-retry,
  so they mask a broken path. Your app's HTTP client often lands on the one bad
  route. When a URL loads in a browser but not the app, **test both address
  families explicitly:** `curl -4 URL` vs `curl -6 URL`. Divergence = your bug.
- **Always retry network fetches** (2–3 attempts). Transient TCP resets are normal
  on mobile networks. A one-shot fetch turns a blip into a stranded user. Make the
  HTTP client **injectable** so retries/failures are unit-testable (don't call a
  global `http.get` you can't mock).
- **Auto-recover when connectivity returns.** Listen to a connectivity provider and
  re-run the failed load; don't make the user find and tap "Retry."
- **Range requests (audio/video seeking) need a CDN that supports them.** Some
  static hosts return `200` for a Range request instead of `206` — seeking breaks.
  Verify with `curl -r 0-1024 URL` and expect `206`. (We keep audio on object
  storage that supports Range, JSON on the static CDN.)
- **Know your edge cache.** Content pushes are live at the origin instantly but the
  edge serves stale for the cache TTL. Verify a deploy with a **cache-buster query**
  (`?cb=<timestamp>`) which bypasses the edge; purge for urgent changes. Set short
  TTLs on config/catalog JSON, long/immutable on media.

## 2. Remote-config / content-driven architecture

**Make the app a stable shell; drive content, copy, and feature flags from remote
JSON.** You avoid an app-store release for every content or wording change.

- **But your base URLs are compiled in.** A bad CDN URL needs an app update to fix —
  so the CDN must be rock-solid, and it's worth having a **fallback host** or a
  remotely-overridable base URL for emergencies.
- **Prefer indirection you can change server-side.** We had each series' catalog URL
  *inside* a remote manifest — so repointing the CDN fixed already-installed apps at
  runtime, no release. Design so the fixable knobs live in remote content, not the
  binary.
- **Feature-flag new surfaces** so you can dark-launch and kill remotely.
- **Version your schemas** (`maxSupportedVersion` in the app; "please update" if the
  remote schema is newer). Parse **per-entry with try/catch** so one malformed row
  doesn't blank the whole list.

## 3. Offline-first & caching

- **Stale-while-revalidate is the right default:** serve cache instantly, refresh in
  the background, only block on the network when there's no cache at all. This is
  what shields *existing* users from a CDN outage — only fresh installs feel it.
- **Persisted prefs/cache survive app updates** (not uninstalls). Lean on that: an
  update is not a cache reset.
- **Separate "content language" from "UI language"** if you ship multiple content
  editions — they're independent axes.

## 4. Testing strategy

- **Test the I/O path, not just the pure logic.** Our fetch bug hid for a release
  because only the pure cache-*decision* was tested; the actual fetch/retry/failure
  had zero coverage. Inject a mock HTTP client and test: success, transient-fail→
  success, exhausted→throws.
- **Environmental failures (a flaky ISP route) can't be reproduced in CI — but the
  *resilience* that handles them can.** Test the retry, the fallback, the
  connectivity-recovery — not the outage itself.
- **On-device integration tests catch what unit tests can't:** real network, real
  navigation, process singletons, first-frame timing. Keep a small end-to-end
  journey that cold-boots the app — it's your best "did I strand fresh installs?"
  canary.
- **Widget tests are strict about pending timers/async.** Fire-and-forget work with
  delays (`Future.delayed`) trips "A Timer is still pending after dispose." Prefer
  immediate retries, or make delays injectable/zero in tests.
- **Simulate onboarding from a clean state** (clear prefs at test start) so you
  actually exercise the first-run screens, not a returning-user shortcut.

## 5. Release & CD

- **Automate the whole release to one command**, but keep **production promotion a
  manual human gate** (auto-ship to an internal/testing track; a person promotes to
  prod).
- **Always dry-run first** — it catches build/signing/changelog issues before
  anything ships.
- **Store-console API access is fiddly:** service accounts need app-level (not just
  account-level) permissions, and grants take time to propagate. Budget for it.
- **Never inline free text into a shell `run:` step** in CI (`"${{ ... }}"`) — commit
  messages/changelogs contain quotes that break the script. Pass via `env:`.
- **A consumed store versionCode can't be reused** — if an upload succeeds but a
  later step fails, bump the build number before retrying.

## 6. Diagnosis discipline

- **Reproduce before theorizing.** The root cause here (flaky IPv4) only surfaced
  after actually running the app and reading the socket error, then `curl -4/-6`.
- **Don't assume — test every branch of the hypothesis.** "The CDN is down" was
  wrong (it returned 200 in a browser); the real answer needed per-address-family,
  per-IP, repeated tests.
- **"Works after a few tries" = intermittent = retryable.** That single observation
  reframes the whole fix from "it's broken" to "add resilience + fix the flaky
  dependency."
- **Follow the request to its actual bytes** (status code, resolved IP, headers), not
  the abstraction ("the fetch failed").

## 7. Platform gotchas (Flutter / Android / iOS)

- **Android: `INTERNET` permission must be in the *main* manifest for release
  builds.** Debug builds auto-add it, so a missing permission passes locally and
  dies in production. (Ours was present — but this is the classic trap.)
- **A machine-global `~/.gradle/gradle.properties` overrides every project.** Another
  app pinning a different JDK there silently breaks your build. Pin Java in CI.
- **iOS device family (iPhone-only vs Universal)** decides whether iPad renders
  natively or in a scaled iPhone window — matters for tablet screenshots.
- **Audio/background singletons (e.g. `AudioService`) init once per process** — one
  integration test per file that boots the app.
- **Emulators are unreliable for anything network- or render-sensitive.** A real
  device beats three flaky emulators; budget one for tablet/native checks.
