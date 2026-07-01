# Onboarding Flows — WelcomeScreen & ChooseSeriesScreen

This document maps every code path a user can take through the onboarding
screens, from cold start to landing on `/lectures`. Each scenario lists the
preconditions, the screens seen, and the final state.

---

## Key State Variables

| Variable | Source | Meaning |
|---|---|---|
| `hasCompletedOnboarding` | `SharedPreferences` (`has_completed_onboarding`) | `true` once the user has finished onboarding in a prior session. |
| `hasSelectedSeries` | `SeriesProvider._currentId != null` | `true` when a series id is set — either from saved prefs, legacy data detection, or the multi-series flag being off. |
| `multiSeriesEnabled` | `FeatureFlagsProvider` (remote config) | `true` when the multi-series experiment is active. Defaults to `false`. |
| `_hasLegacyData()` | `PreferencesService` | `true` if any progress, bookmarks, downloads, or studied chapters exist — indicates a pre-v3 install that used the Urdu-only app. |
| `isSeriesReady` | `SeriesProvider._isLoading == false` | `true` once the series is definitively resolved. WelcomeScreen hides content until this is true. |
| `isArabicDevice` | `platformDispatcher.locale.languageCode == 'ar'` | `true` when the device system language is Arabic. |

---

## Route Redirect (app.dart)

The `/` route has a redirect guard:
- If `hasCompletedOnboarding == true` → redirect to `/lectures` (user never sees WelcomeScreen)
- Otherwise → show `WelcomeScreen`

---

## Scenario 1: Returning User (any prior version that completed onboarding)

**Preconditions:** `has_completed_onboarding = true` in SharedPreferences

**Flow:**
1. App starts → `/` route redirect fires
2. `hasCompletedOnboarding` is `true` → redirect to `/lectures`
3. User never sees WelcomeScreen or ChooseSeriesScreen

**Final state:** Lands on `/lectures` immediately

---

## Scenario 2: Existing User Upgrading (has legacy data, no onboarding flag)

This is the most common upgrade path — a user who has been using the v2
Urdu-only app and updates to v3.

**Preconditions:**
- `has_completed_onboarding = false` (key didn't exist in v2)
- Legacy data exists (progress, bookmarks, downloads, or studied chapters)
- `multiSeriesEnabled` can be either true or false

**Flow:**
1. `SeriesProvider.load()` runs:
   - If `multiSeriesEnabled == false`: `_currentId = legacyId` → `hasSelectedSeries = true`
   - If `multiSeriesEnabled == true`: `_hasLegacyData() == true` → `_currentId = legacyId`, saved to prefs → `hasSelectedSeries = true`
2. Either way, user is pinned to Urdu series silently
3. `/` route redirect: `hasCompletedOnboarding` is `false` → show WelcomeScreen
4. WelcomeScreen shows the Urdu welcome splash (book icon, "Sharah Kitab at-Tawheed", "START LISTENING")
5. User taps "START LISTENING"
6. `_startListening()`: `hasSelectedSeries == true` → `completeOnboarding()` → `context.go('/lectures')`

**Final state:** Sees WelcomeScreen once → taps CTA → lands on `/lectures`. Never sees ChooseSeriesScreen.

---

## Scenario 3: Fresh Install, multiSeries OFF

**Preconditions:**
- Clean install, no SharedPreferences data
- `multiSeriesEnabled = false` (the default)

**Flow:**
1. `SeriesProvider.load(false)`: `_currentId = legacyId` → `hasSelectedSeries = true`
2. `/` route: `hasCompletedOnboarding = false` → show WelcomeScreen
3. WelcomeScreen shows Urdu welcome splash
4. User taps "START LISTENING"
5. `_startListening()`: `hasSelectedSeries == true` → `completeOnboarding()` → `/lectures`

**Final state:** Sees WelcomeScreen → taps CTA → `/lectures`. Never sees ChooseSeriesScreen.

---

## Scenario 4: Fresh Install, multiSeries ON, Non-Arabic Device

**Preconditions:**
- Clean install, no data
- `multiSeriesEnabled = true`
- Device language is not Arabic

**Flow:**
1. `SeriesProvider.load(true)`: no saved id, no legacy data → `_currentId = null`, `_isLoading = true`
2. `loadManifest()` fetches series.json → `_maybeDefaultToArabic()`: device is not Arabic, skips → `_currentId` stays null, `_isLoading = false`
3. `/` route: `hasCompletedOnboarding = false` → show WelcomeScreen
4. WelcomeScreen: `isSeriesReady = true`, `hasSelectedSeries = false` → shows Urdu fallback content (because `currentSeries` falls back to `legacyUrduFallback`)
5. User taps "START LISTENING"
6. `_startListening()`: `hasSelectedSeries == false` → check `availableSeries.length > 1` → `true` → `context.push('/choose-series')`
7. ChooseSeriesScreen shows cards for all available series
8. User taps a card (e.g. Urdu)
9. `_select()`: `switchSeries()` → `completeOnboarding()` → `context.go('/lectures')`

**Final state:** WelcomeScreen → taps CTA → ChooseSeriesScreen → taps card → `/lectures`

---

## Scenario 5: Fresh Install, multiSeries ON, Arabic Device

**Preconditions:**
- Clean install, no data
- `multiSeriesEnabled = true`
- Device language is Arabic

**Flow:**
1. `SeriesProvider.load(true)`: no saved id, no legacy data → `_currentId = null`, `_isLoading = true`
2. `loadManifest()` fetches series.json → `_maybeDefaultToArabic()`: device IS Arabic → auto-selects Arabic series, saves to prefs → `_currentId = arabicSeriesId`, `_isLoading = false`
3. `/` route: `hasCompletedOnboarding = false` → show WelcomeScreen
4. WelcomeScreen: `isSeriesReady = true`, series is Arabic → shows Arabic welcome (sheikh photo, Arabic title, Arabic CTA)
5. User taps "ابدأ الاستماع" (Start Listening in Arabic)
6. `_startListening()`: `hasSelectedSeries == true` → `completeOnboarding()` → `/lectures`

**Final state:** Arabic WelcomeScreen → taps CTA → `/lectures`. Never sees ChooseSeriesScreen.

---

## Scenario 6: Fresh Install, multiSeries ON, Only One Series Available

**Preconditions:**
- Clean install, no data
- `multiSeriesEnabled = true`
- Manifest returns only one series (or manifest fetch fails → fallback to `[legacyUrduFallback]`)

**Flow:**
1. `SeriesProvider.load(true)`: no saved id, no legacy data → `_currentId = null`
2. `loadManifest()`: only one series available, not Arabic device → `_currentId` stays null
3. `/` route: show WelcomeScreen
4. User taps "START LISTENING"
5. `_startListening()`: `hasSelectedSeries == false`, `availableSeries.length == 1` → `switchSeries()` with the single series → `completeOnboarding()` → `/lectures`

**Final state:** WelcomeScreen → taps CTA → `/lectures`. No ChooseSeriesScreen (only one option).

---

## Scenario 7: Fresh Install, multiSeries ON, Manifest Fetch Fails

**Preconditions:**
- Clean install, no data, no cached manifest
- `multiSeriesEnabled = true`
- Network unavailable or series.json fails

**Flow:**
1. `loadManifest()` fails → falls back to `[SeriesConfig.legacyUrduFallback]`
2. Same as Scenario 6 — single series, no ChooseSeriesScreen

**Final state:** WelcomeScreen → taps CTA → `/lectures`

---

## Scenario 8: Existing User, multiSeries ON, Has Saved Series Selection

**Preconditions:**
- `selected_series_id` exists in prefs (user previously picked via ChooseSeriesScreen or Settings)
- `has_completed_onboarding = true`

**Flow:**
1. `SeriesProvider.load(true)`: saved id found → `_currentId = savedId`, `_isLoading = false`
2. `/` route: `hasCompletedOnboarding = true` → redirect to `/lectures`

**Final state:** Straight to `/lectures`

---

## ChooseSeriesScreen — Internal Behavior

| Behavior | Implementation |
|---|---|
| Card rendering | One `_SeriesCard` per entry in `availableSeries` |
| Language thumbnail | Gold square with native script label (اردو / العربية) |
| Metric chips | "Audio" (always), "Study Mode" (if `hasStudyMode`), "Book" (if `hasBook`) |
| Speaker name | Shortened — leading honorific ("Shaikh", "Fazilat Shaikh", "الشيخ") stripped |
| Arabic card title | Always shows `كتاب التوحيد` regardless of UI language |
| Arabic native subtitle | Shows `شرح كتاب التوحيد` (Arabic script) |
| Urdu native subtitle | Shows `شرح کتاب التوحید` (Urdu script) |
| Card elevation | `Material` with `elevation: 2` for tappable affordance |
| Tap a card | `switchSeries()` → `completeOnboarding()` → `context.go('/lectures')` |
| Loading state | Tapped card shows dimmed overlay + small spinner; other cards are `AbsorbPointer`-blocked |
| Double-tap guard | `_selectingId` prevents concurrent taps |

---

## WelcomeScreen — Internal Behavior

| Behavior | Implementation |
|---|---|
| Content hidden while loading | `AnimatedOpacity(opacity: isReady ? 1.0 : 0.0)` + `IgnorePointer(ignoring: !isReady)` |
| Urdu variant | Book icon (brand gold), "Sharah Kitab at-Tawheed" title, "START LISTENING" CTA |
| Arabic variant | Sheikh photo (circular, fade-in), Arabic speaker name, Arabic title, Arabic tagline (if book), "ابدأ الاستماع" CTA |
| CTA action | Calls `_startListening()` — branches on `hasSelectedSeries` and `availableSeries.length` |
| Background | Black base + tawheed.png at 20% opacity |
| Theme | Forces `AppTheme.dark` regardless of system/app theme |

---

## Edge Cases

1. **Existing install with zero usage data + multiSeries ON** — no legacy data detected, treated as fresh install. Will see ChooseSeriesScreen if >1 series available. This is a narrow case (installed but never played/bookmarked/downloaded anything).

2. **Manifest loads slowly** — WelcomeScreen content is invisible (`isSeriesReady = false`) until manifest resolves. The solid black background + background image show immediately; content fades in once ready.

3. **System back from ChooseSeriesScreen** — `context.push('/choose-series')` means back returns to WelcomeScreen. Onboarding is NOT completed until a card is tapped, so killing the app and reopening will show WelcomeScreen again.

4. **Series switching from Settings** — existing users can switch series from Settings without ever touching ChooseSeriesScreen. Uses the same `switchSeries()` function but does not re-run onboarding.

5. **`completeOnboarding()` is idempotent** — calling it when already `true` is a no-op. Safe to call from multiple paths.
