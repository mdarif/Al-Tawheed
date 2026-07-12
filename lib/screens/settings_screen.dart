import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/app_config_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';
import 'package:myapp/utils/safe_url_launcher.dart';
import 'package:myapp/widgets/confirm_dialog.dart';
import 'package:myapp/widgets/settings/playback_speed_selector.dart';
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

/// Rounded, bordered container used to group a settings section's rows — the
/// shared "card" chrome so every section reads consistently.
class _SettingsCard extends StatelessWidget {
  final Widget child;
  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: context.groupedSurface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.groupedBorder, width: 1),
          ),
          child: child,
        ),
      ),
    );
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
        children: [
          _SectionHeader(l10n.settingsAppearance),
          const _SettingsCard(child: ThemeModeSwitch()),
          const Divider(height: 32),

          // The series switcher is gated behind its own feature flag (default
          // off) so it can be hidden remotely, on top of requiring multi-series
          // to be active and more than one series to actually be available.
          if (flags.features.seriesSwitcher &&
              flags.multiSeriesEnabled &&
              context.watch<SeriesProvider>().availableSeries.length > 1) ...[
            _SectionHeader(l10n.settingsLanguage),
            const _SettingsCard(child: _SeriesLanguageSelector()),
            const Divider(height: 32),
          ],

          if (flags.features.language) ...[
            _SectionHeader(l10n.settingsLanguage),
            const _SettingsCard(child: _LanguageSelector()),
            const Divider(height: 32),
          ],

          _SectionHeader(l10n.settingsPlayback),
          _SettingsCard(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.settingsPlaybackSpeed,
                    style: context.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  const PlaybackSpeedSelector(),
                ],
              ),
            ),
          ),
          const Divider(height: 32),

          // The App section bundles promotional/outbound links (contact, share,
          // rate, YouTube). Gated behind its own feature flag (default off) so it
          // can be hidden now and re-enabled remotely. The official website is
          // surfaced separately in the About card, so it is not duplicated here.
          if (flags.features.appLinks) ...[
            _SectionHeader(l10n.settingsApp),
            _SettingsCard(
              child: Column(
                children: [
                  ListTile(
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
                  ListTile(
                    leading: const Icon(Icons.share_rounded),
                    title: Text(l10n.settingsShareApp),
                    onTap: () => SharePlus.instance.share(
                      ShareParams(text: config.share.message),
                    ),
                  ),
                  if (config.links.playStore != null)
                    ListTile(
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
                      leading: const Icon(Icons.play_circle_outline_rounded),
                      title: Text(config.branding.appBrand),
                      subtitle: Text(l10n.settingsYouTubeChannel),
                      onTap: () => _launchOrNotify(
                        context,
                        config.links.youtube!,
                        fallbackMessage: config.links.youtube!,
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 32),
          ],

          if (flags.features.downloads) const _DownloadsSection(),

          // Secondary destinations gathered here (reached via the Home gear)
          // rather than each taking a bottom-nav slot or app-bar icon.
          _SettingsCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.bookmark_outline_rounded),
                  title: Text(l10n.saved),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/bookmarks'),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: Text(l10n.settingsAbout),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/about'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: context.textTheme.labelSmall,
      ),
    );
  }
}

class _DownloadsSection extends StatelessWidget {
  const _DownloadsSection();

  static String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final downloads = context.watch<DownloadsProvider>();
    final count = downloads.downloadedCount;
    final size = downloads.totalDownloadedBytes;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(l10n.settingsDownloads),
        _SettingsCard(
          child: Column(
            children: [
              // Wi-Fi only toggle
              SwitchListTile(
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

              // Storage summary + library link
              ListTile(
                leading: const Icon(Icons.storage_rounded),
                title: Text(
                  count == 0
                      ? l10n.settingsNoDownloads
                      : l10n.settingsDownloadsCount(count),
                ),
                subtitle: count > 0
                    ? Text(l10n.settingsStorageUsed(_formatBytes(size)))
                    : null,
                trailing:
                    count > 0 ? const Icon(Icons.chevron_right_rounded) : null,
                onTap: count > 0 ? () => context.push('/offline-library') : null,
              ),

              if (count > 0)
                ListTile(
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: context.colorScheme.error,
                  ),
                  title: Text(
                    l10n.settingsClearDownloads,
                    style: TextStyle(color: context.colorScheme.error),
                  ),
                  onTap: () async {
                    final confirmed = await showConfirmDialog(
                      context,
                      title: l10n.clearAllDownloads,
                      message: l10n.clearAllDownloadsMessage(
                        count,
                        _formatBytes(size),
                      ),
                      confirmLabel: l10n.deleteAll,
                      destructive: true,
                    );
                    if (confirmed && context.mounted) {
                      await context.read<DownloadsProvider>().deleteAll();
                    }
                  },
                ),
            ],
          ),
        ),
        const Divider(height: 32),
      ],
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
class _SeriesLanguageSelector extends StatelessWidget {
  const _SeriesLanguageSelector();

  @override
  Widget build(BuildContext context) {
    final series = context.watch<SeriesProvider>();
    final lang = context.read<LanguageProvider>();
    final current = series.currentSeries;
    final available = series.availableSeries;

    return Column(
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
            onTap: () => _switchTo(context, available[i]),
          ),
        ],
      ],
    );
  }

  Future<void> _switchTo(BuildContext context, SeriesConfig target) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.changeSeriesConfirmTitle,
      message:
          l10n.changeSeriesConfirmMessage(_seriesLanguageLabel(context, target)),
      confirmLabel: l10n.changeSeriesConfirm,
      filledConfirm: true,
    );
    if (!confirmed || !context.mounted) return;

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
  final VoidCallback onTap;

  const _SeriesLanguageRow({
    required this.series,
    required this.teacher,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        _seriesLanguageLabel(context, series),
        style: context.textTheme.bodyMedium?.copyWith(
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      subtitle: teacher.isNotEmpty
          ? Text(teacher, style: context.textTheme.bodySmall)
          : null,
      trailing: selected
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
