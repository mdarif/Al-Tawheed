import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/providers/app_config_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/services/download_notification_service.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/testing/widget_keys.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';
import 'package:myapp/utils/safe_url_launcher.dart';
import 'package:myapp/widgets/capability_chip.dart';
import 'package:myapp/widgets/confirm_dialog.dart';
import 'package:myapp/widgets/settings/other_apps_section.dart';
import 'package:myapp/widgets/settings/playback_speed_selector.dart';
import 'package:myapp/widgets/settings/settings_section.dart';
import 'package:myapp/widgets/settings/text_size_setting.dart';
import 'package:myapp/widgets/settings/theme_mode_switch.dart';

/// Opens [url] in an external app, showing [fallbackMessage] in a snackbar if
/// the launch fails (no handler, malformed URL, or a disallowed scheme —
/// these links come from the remote app-config, so [launchExternalUrl]
/// enforces an https/mailto allowlist). Mirrors the Contact Us fallback so
/// every outbound link degrades gracefully instead of silently.
Future<void> _launchOrNotify(
  BuildContext context,
  String url, {
  required String fallbackMessage,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final launched = await launchExternalUrl(url);
  if (!launched) {
    messenger.showSnackBar(SnackBar(content: Text(fallbackMessage)));
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfigProvider>().config;
    final flags = context.watch<FeatureFlagsProvider>();
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabSettings)),
      body: ListView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom + 92,
        ),
        children: [
          SettingsSectionHeader(l10n.settingsAppearance),
          const SettingsCard(child: ThemeModeSwitch()),
          const SizedBox(height: 6),

          // Text size only affects the Book, so it is offered only when the
          // active edition has one. The same value is written by the reader's
          // pinch gesture and its "Aa" sheet (see ReadingProvider).
          if (context.watch<SeriesProvider>().currentSeries.hasBook) ...[
            SettingsSectionHeader(l10n.settingsReading),
            const SettingsCard(child: TextSizeSetting()),
            const SizedBox(height: 6),
          ],

          // The edition switcher is always reachable whenever multi-series is
          // active with more than one series available — there is no separate
          // opt-in flag, so users can never get locked into whichever edition
          // launched.
          if (flags.multiSeriesEnabled &&
              context.watch<SeriesProvider>().availableSeries.length > 1) ...[
            SettingsSectionHeader(l10n.settingsSeries),
            const SettingsCard(child: _SeriesLanguageSelector()),
            const SizedBox(height: 6),
          ],

          // The UI-language picker is headed "App language" (distinct from the
          // content-edition switcher above, which is headed "Language"): the two
          // are independent axes — content edition vs app/chrome language.
          if (flags.features.language) ...[
            SettingsSectionHeader(l10n.settingsAppLanguage),
            const SettingsCard(child: _LanguageSelector()),
            const SizedBox(height: 6),
          ],

          SettingsSectionHeader(l10n.settingsPlayback),
          const SettingsCard(child: _PlaybackSpeedRow()),
          const SizedBox(height: 6),

          if (flags.features.downloads) const _DownloadsSection(),

          // About is always visible: it replaces the old appLinks-gated "App"
          // section and is where the (now removed) shell menu's About and
          // Share app live on. Only the outbound promo rows stay behind
          // `appLinks` (off in production); Share app has its own flag.
          SettingsSectionHeader(l10n.settingsAbout),
          SettingsCard(
            child: Column(
              children: [
                ListTile(
                  key: WidgetKeys.settingsAbout,
                  leading: const Icon(Icons.info_outline_rounded),
                  title: Text(l10n.settingsAboutApp),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/about'),
                ),
                if (flags.features.shareButton)
                  ListTile(
                    key: WidgetKeys.settingsShareApp,
                    leading: const Icon(Icons.share_rounded),
                    title: Text(l10n.settingsShareApp),
                    onTap: () => SharePlus.instance.share(
                      ShareParams(text: config.share.message),
                    ),
                  ),
                if (flags.features.appLinks) ...[
                  ListTile(
                    key: WidgetKeys.settingsContactUs,
                    leading: const Icon(Icons.mail_outline_rounded),
                    title: Text(l10n.settingsContactUs),
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final launched = await launchUrl(
                        Uri(
                          scheme: 'mailto',
                          path: config.contact.email,
                          queryParameters: {'subject': config.contact.subject},
                        ),
                        mode: LaunchMode.externalApplication,
                      );
                      if (!launched) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(config.contact.email)),
                        );
                      }
                    },
                  ),
                  if (config.links.playStore != null)
                    ListTile(
                      key: WidgetKeys.settingsRateApp,
                      leading: const Icon(Icons.star_outline_rounded),
                      title: Text(l10n.settingsRateApp),
                      onTap: () => _launchOrNotify(
                        context,
                        config.links.playStore!,
                        fallbackMessage: config.links.playStore!,
                      ),
                    ),
                  if (config.links.youtube != null)
                    ListTile(
                      key: WidgetKeys.settingsYouTube,
                      leading: const Icon(Icons.play_circle_outline_rounded),
                      title: Text(l10n.settingsYouTubeChannel),
                      subtitle: Text(
                        context.watch<LanguageProvider>().resolve(
                              config.branding.appBrand,
                            ),
                      ),
                      onTap: () => _launchOrNotify(
                        context,
                        config.links.youtube!,
                        fallbackMessage: config.links.youtube!,
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Android-only, and deliberately not behind `appLinks` (see the
          // widget's doc).
          const OtherAppsSection(),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _PlaybackSpeedRow extends StatelessWidget {
  const _PlaybackSpeedRow();

  static String _speedLabel(BuildContext context, double speed) {
    return '${context.localizedDecimal(speed.toStringAsFixed(1))}x';
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerNotifier>();
    final speed = player.speed;
    final l10n = context.l10n;

    return ListTile(
      leading: const Icon(Icons.speed_rounded),
      title: Text(l10n.settingsPlaybackSpeed),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _speedLabel(context, speed),
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => ChangeNotifierProvider<PlayerNotifier>.value(
          value: player,
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.paddingOf(context).bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.settingsPlaybackSpeed,
                    style: context.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  const PlaybackSpeedSelector(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DownloadsSection extends StatelessWidget {
  const _DownloadsSection();

  @override
  Widget build(BuildContext context) {
    final downloads = context.watch<DownloadsProvider>();
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionHeader(l10n.settingsDownloads),
        SettingsCard(
          child: Column(
            children: [
              // Wi-Fi only toggle. The downloaded-lectures list and "remove
              // all" live in Library > Downloads — each collection has exactly
              // one home — so this section is preferences only.
              SwitchListTile(
                key: WidgetKeys.settingsDownloadOnWifiOnly,
                secondary: const Icon(Icons.wifi_rounded),
                title: Text(l10n.downloadOnWifiOnly),
                subtitle: Text(
                  l10n.downloadOnWifiOnlyHint,
                  style: context.textTheme.bodySmall,
                ),
                value: downloads.downloadOnWifiOnly,
                activeThumbColor: context.brandColor,
                onChanged: (v) =>
                    context.read<DownloadsProvider>().setDownloadOnWifiOnly(v),
              ),

              const _NotificationStatusRow(),
            ],
          ),
        ),
        // Settings is a shell branch, so `go` to Library's branch is correct
        // here (the root-navigator pitfall only bites pushed pages).
        SettingsSectionFootnote(
          l10n.settingsDownloadsHint,
          key: WidgetKeys.settingsDownloadsHint,
          onTap: () => context.go('/library?tab=downloads'),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

/// Recovery for a denied/off notification permission (BLK-07) — only shown
/// once we've actually asked (see maybeRequestDownloadNotificationPermission)
/// and the OS currently reports notifications as disabled. Rechecks on app
/// resume so it disappears reactively if the user re-enables it in system
/// Settings and comes back. No in-app deep link to Settings — instructional
/// text only, since that needs a permission-status package this app doesn't
/// otherwise depend on.
class _NotificationStatusRow extends StatefulWidget {
  const _NotificationStatusRow();

  @override
  State<_NotificationStatusRow> createState() => _NotificationStatusRowState();
}

class _NotificationStatusRowState extends State<_NotificationStatusRow>
    with WidgetsBindingObserver {
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (!PreferencesService.instance.hasAskedDownloadNotificationPermission) {
      return;
    }
    final enabled =
        await DownloadNotificationService.instance.areNotificationsEnabled();
    if (mounted) setState(() => _enabled = enabled);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_enabled != false) return const SizedBox.shrink();
    final l10n = context.l10n;
    return ListTile(
      leading: Icon(
        Icons.notifications_off_outlined,
        color: context.colorScheme.error,
      ),
      title: Text(l10n.notificationsSettingsRow),
      subtitle: Text(
        l10n.notificationsDisabledHint,
        style: context.textTheme.bodySmall,
      ),
    );
  }
}

/// The listener-facing label for a series: its language endonym (e.g. "اردو",
/// "العربية"). Internally these are content *series* (each edition has its own
/// teacher and catalog), but to listeners the choice reads as a language, so
/// that is what we show — with the teacher carried as the row subtitle.
String _seriesLanguageLabel(BuildContext context, SeriesConfig series) {
  final l10n = context.l10n;
  return switch (series.language) {
    'ar' => l10n.languageArabic,
    'ur' => l10n.languageUrdu,
    'roman' => l10n.languageRomanUrdu,
    'en' => l10n.languageEnglish,
    _ => series.displayName['en'] as String? ?? series.id,
  };
}

/// Content-language selector, presented as "Language" though it swaps the whole
/// content series. Lists every available edition inline as a checkmark row
/// (language endonym + teacher); tapping a different one confirms first because
/// the switch stops playback and reloads the catalog.
class _SeriesLanguageSelector extends StatefulWidget {
  const _SeriesLanguageSelector();

  @override
  State<_SeriesLanguageSelector> createState() =>
      _SeriesLanguageSelectorState();
}

class _SeriesLanguageSelectorState extends State<_SeriesLanguageSelector> {
  // The id of the edition currently being switched to, or null when idle —
  // guards against a second switch racing the first while it's in flight,
  // and shows an in-row spinner so the switch reads as in-progress rather
  // than unresponsive.
  String? _switchingId;

  @override
  Widget build(BuildContext context) {
    final series = context.watch<SeriesProvider>();
    final lang = context.read<LanguageProvider>();
    final current = series.currentSeries;
    final available = series.availableSeries;

    return AbsorbPointer(
      absorbing: _switchingId != null,
      child: Column(
        children: [
          for (var i = 0; i < available.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: context.groupedBorder,
              ),
            _SeriesLanguageRow(
              series: available[i],
              teacher: lang.resolveForSeries(
                available[i].speakerName,
                available[i],
              ),
              selected: available[i].id == current.id,
              loading: _switchingId == available[i].id,
              onTap: () => _switchTo(context, available[i]),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _switchTo(BuildContext context, SeriesConfig target) async {
    if (_switchingId != null) return;
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.changeSeriesConfirmTitle,
      message: l10n.changeSeriesConfirmMessage(
        _seriesLanguageLabel(context, target),
      ),
      confirmLabel: l10n.changeSeriesConfirm,
      filledConfirm: true,
    );
    if (!confirmed || !context.mounted) return;
    if (_switchingId != null) return;

    setState(() => _switchingId = target.id);
    await switchSeries(context, target);
    if (!context.mounted) return;
    // Navigate to / and let the router decide: welcome screen if this is the
    // first encounter with the new series, /lectures redirect otherwise.
    context.go('/');
  }
}

class _SeriesLanguageRow extends StatelessWidget {
  final SeriesConfig series;
  final String teacher;
  final bool selected;
  final bool loading;
  final VoidCallback onTap;

  const _SeriesLanguageRow({
    required this.series,
    required this.teacher,
    required this.selected,
    this.loading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      key: WidgetKeys.settingsSeriesOption(series.id),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        _seriesLanguageLabel(context, series),
        style: context.textTheme.bodyMedium?.copyWith(
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (teacher.isNotEmpty)
            Text(teacher, style: context.textTheme.bodySmall),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              CapabilityChip(
                icon: Icons.headphones_rounded,
                label: l10n.audioLabel,
              ),
              if (series.hasStudyMode)
                CapabilityChip(
                  icon: Icons.school_rounded,
                  label: l10n.studyMode,
                ),
              if (series.hasBook)
                CapabilityChip(
                  icon: Icons.menu_book_rounded,
                  label: l10n.tabBook,
                ),
            ],
          ),
        ],
      ),
      trailing: loading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: context.brandColor,
              ),
            )
          : selected
              ? Icon(Icons.check_rounded, color: context.brandColor)
              : null,
      // Selected row is inert; only the other editions are actionable.
      onTap: selected ? null : onTap,
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector();

  @override
  Widget build(BuildContext context) {
    final current = context.watch<LanguageProvider>().language;
    final l10n = context.l10n;

    String labelFor(AppLanguage lang) => switch (lang) {
          AppLanguage.english => l10n.languageEnglish,
          AppLanguage.urdu => l10n.languageUrdu,
          AppLanguage.romanUrdu => l10n.languageRomanUrdu,
          AppLanguage.arabic => l10n.languageArabic,
        };

    return RadioGroup<AppLanguage>(
      groupValue: current,
      onChanged: (v) {
        if (v != null) context.read<LanguageProvider>().setLanguage(v);
      },
      child: Column(
        children: AppLanguage.values.map((lang) {
          final selected = lang == current;
          final label = labelFor(lang);
          return RadioListTile<AppLanguage>(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: Text(
              label,
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            subtitle: label != lang.englishName
                ? Text(lang.englishName, style: context.textTheme.bodySmall)
                : null,
            value: lang,
            activeColor: context.brandColor,
          );
        }).toList(),
      ),
    );
  }
}
