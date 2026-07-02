# 0001 — Serve remote content from a custom domain, with client-side retry

- **Status:** accepted
- **Date:** 2026-07-02

## Context

2.3.0 shipped with the content CDN on `al-tawheed-content.pages.dev`. Fresh
installs began stranding on the "Connect to load lectures" screen despite working
internet. Root cause (diagnosed empirically — see [../gotchas.md](../gotchas.md)
→ Networking / CDN): Cloudflare's `*.pages.dev` subdomain resolves to the
`172.66.44.x` IPv4 range, which is **intermittently TCP-reset** on some ISPs (~7 of
8 tries in testing). IPv6 and other Cloudflare ranges work, so browsers/curl (Happy
Eyeballs → IPv6) succeed while the app's Dart HTTP client hits the dead IPv4 path.
A no-cache first launch needs exactly one successful fetch, so it usually failed;
existing users were shielded by stale-while-revalidate cache.

The app also had no fetch retry and no auto-recovery when the network returned.

## Decision

1. **Serve content from a custom domain** (`content.kitabattawheed.com`) on our own
   Cloudflare zone — it uses the universally-reachable `104.21.x`/`172.67.x` anycast
   IPs (verified 0/8 IPv4 failures vs pages.dev's 7/8). Change both:
   - the app's `AppConfig.contentBaseUrl`, and
   - the remote `series.json` `catalogUrl`s (in the `Al-Tawheed-Content` repo) — the
     latter repairs already-installed apps at runtime, no release needed.
2. **Retry fetches** in `RemoteContentService` (injectable client, default 3
   immediate attempts) and **auto-reload the catalog on connectivity restore** in
   `CatalogProvider`.

Alternatives rejected: forcing IPv6 in the Dart client (not cleanly supported, and
IPv6 isn't guaranteed on all user networks); shipping a hard-coded fallback host
(retry + custom domain covers it more simply).

## Consequences

- New/updated installs fetch everything from the reliable domain; existing installs
  are fixed the moment the CDN `series.json` change propagates (~1 h edge TTL, or
  purge). Retries + connectivity recovery ride over any residual flakiness.
- Two sources of truth to keep in sync for URLs: this repo's `AppConfig` and the
  content repo. The base URL is compiled in — a future CDN change still needs an app
  release, so the custom domain must stay stable.
- General rule for future apps: **never ship production content on a vendor default
  subdomain** — see [../mobile-engineering-playbook.md](../mobile-engineering-playbook.md).
