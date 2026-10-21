# Navigation policy — intentionally deferred

**Status:** Deferred; the current roadmap keeps this as a local capability
policy follow-up in P5.

The app's footer tabs are intentionally derived from the active content
edition's capabilities in `SeriesConfig`: `hasBook` and `hasStudyMode` control
whether the Read tab appears (it appears when either is true) and whether Read
shows the Book/Study toggle (only when both are true). Lectures, Library, and
Settings are always present; Library holds Bookmarks and, when the `downloads`
flag is on, Downloads. About is reached from the overflow menu. Route guards
apply the same capability checks. The legacy Urdu edition also has a
client-side `hasBook` default because this app bundles its Urdu book asset; an
explicit manifest `hasBook: false` still wins. This is the current source of truth
and is covered by shell and route-guard tests.

The remote `feature-flags.json` controls rollout flags such as `downloads`,
`studyMode`, and `multiSeries`; it does not define an arbitrary ordered tab
list. Keeping content availability in `series.json` avoids showing a tab for
which the selected edition has no content. This local capability policy is the
navigation follow-up identified in P5 of the maintenance roadmap.

If this policy changes, update the model, shell, route guards, and onboarding
documentation together, with tests for configured and fallback navigation.
Until then, do not add a `series.tabs` schema or describe tabs as
feature-flag-controlled.
