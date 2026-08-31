# Design system

This is the current UI vocabulary of At-Tawheed. It records components and
tokens already used in the app; it is not a proposal for a new component
library.

## Theme and semantic colors

`AppTheme.light` and `AppTheme.dark` are the two entry points. `AppColors`
contains the palette, while `AppSemanticColors` maps that palette to roles such
as `brand`, `groupedSurface`, `progressTrack`, `onScrim`, and the book's verse,
citation, and hadith colors. Widgets read roles through the `BuildContext`
extensions in `app_theme_extensions.dart` (`brandColor`, `secondaryTextColor`,
`groupedSurface`, and related accessors), rather than importing palette values.

Secondary text is a full-opacity role. Light mode uses warm grey `#6C6256`
and dark mode uses `#A0A0A5`; each meets the WCAG AA 4.5:1 normal-text
threshold on its theme surface. Do not add alpha to this role at call sites.
The exact ratios are guarded in `test/app_theme_test.dart`.

## Typography

`AppTypography.create` starts from Material 3's platform typography, then
defines the app's display, headline, title, body, and label sizes and weights.
Titles use tighter tracking on iOS; body styles use platform-appropriate line
height. `bodySmall` is the secondary-text style. Reader content is separate:
the book chooses Noto Naskh Arabic for Arabic runs and the configured Nastaliq
font for Urdu runs, with script-specific size and leading.

## Spacing and layout

There is no global spacing scale token. Existing components use small fixed
increments (4, 6, 8, 10, 12, 14, 16, 20, 24, and 28 dp) according to the
surface: 16 dp is common horizontal screen padding; cards and sheets commonly
use 20–24 dp; compact controls use 4–12 dp. Preserve directional layout for
content and use `EdgeInsetsDirectional` when the edge is semantic rather than
physical. Long labels use `Expanded`/`Flexible` and ellipsis where the current
component already does so.

## Reusable components

- `AppOverflowMenu` is the shell app-bar hub for secondary destinations and
  actions.
- `LectureTile`, `ChapterHeader`, `SelectionChip`, `DownloadButton`, and
  `MiniPlayer` are the lecture-list and playback building blocks.
- `OfflineStatusBanner` communicates the global offline state; `OfflineSheet`
  manages a lecture's saved-audio actions.
- `StudyStatusChip` displays the existing studied, in-progress, and not-started
  states. `ScrollToTopButton` is the reader's contextual floating action.
- `ConfirmDialog` provides the shared informational and confirmation dialog
  helpers. Screen-specific surfaces may still compose Material widgets around
  these helpers.

Interactive icon controls should retain a Material tooltip (which supplies a
screen-reader label) and at least the existing component's minimum hit area.
Do not fork chrome typography or colors by content edition; the active theme
and `context.l10n` own app chrome.

## Sheets, dialogs, and status

Modal bottom sheets are opened with `showModalBottomSheet`, use a rounded top
corner where the current sheet does, and keep content inside `SafeArea` with
content-driven height. `showAlertDialog` and `showConfirmDialog` pop with the
dialog builder context, which is required under go_router. Destructive
confirmation actions use the theme error role; ordinary primary actions use
the filled/brand button treatment already defined by `AppTheme`.

Status UI uses semantic roles: brand for saved/progress-positive states, the
theme error role for failed/destructive states, and secondary text for quiet
metadata. Feature-specific status components may add a tinted surface or
border, but should not use raw palette colors when a semantic role exists.

## Book reader accessibility

Reader lines preserve the printed color and ornate punctuation visually, while
their semantics announce the words without Qur'an ornaments or hadith
guillemets. The body remains selectable and vertically scrollable at large text
scales; the 2.0 text-scale and semantics behavior is covered by
`test/book_reader_screen_test.dart`.
