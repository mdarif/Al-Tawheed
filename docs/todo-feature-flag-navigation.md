# Navigation policy — intentionally deferred

**Status:** Deferred; no implementation work is scheduled in the current
maintenance roadmap.

The app's footer tabs are intentionally derived from the active content
edition's capabilities in `SeriesConfig`: `hasBook` adds Book and
`hasStudyMode` adds Study. Lectures and Settings are always present; Bookmarks,
About, and Offline Library are reached from overflow/settings surfaces. Route
guards apply the same capability checks. This is the current source of truth
and is covered by shell and route-guard tests.

The remote `feature-flags.json` controls rollout flags such as `downloads`,
`studyMode`, and `multiSeries`; it does not define an arbitrary ordered tab
list. Keeping content availability in `series.json` avoids showing a tab for
which the selected edition has no content.

If this policy changes, update the model, shell, route guards, and onboarding
documentation together, with tests for configured and fallback navigation.
Until then, do not add a `series.tabs` schema or describe tabs as
feature-flag-controlled.
