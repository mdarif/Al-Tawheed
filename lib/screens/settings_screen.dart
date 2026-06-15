import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:myapp/models/app_config_model.dart';
import 'package:myapp/models/series.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:myapp/providers/app_config_provider.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';
import 'package:myapp/widgets/confirm_dialog.dart';
import 'package:myapp/widgets/settings/about_card.dart';
import 'package:myapp/widgets/settings/playback_speed_selector.dart';
import 'package:myapp/widgets/settings/theme_mode_switch.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfigProvider>().config;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabSettings)),
      body: ListView(
        children: [
          _SectionHeader(l10n.settingsAppearance),
          Padding(
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
                child: const ThemeModeSwitch(),
              ),
            ),
          ),
          const Divider(height: 32),

          if (context.watch<FeatureFlagsProvider>().multiSeriesEnabled &&
              context.watch<SeriesProvider>().availableSeries.length > 1) ...[
            _SectionHeader(l10n.settingsSeries),
            const _SeriesSection(),
            const Divider(height: 32),
          ],

          if (context.watch<FeatureFlagsProvider>().features.language) ...[
            _SectionHeader(l10n.settingsLanguage),
            const _LanguageSelector(),
            const Divider(height: 32),
          ],

          _SectionHeader(l10n.settingsPlayback),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.settingsPlaybackSpeed, style: context.textTheme.bodySmall),
                const SizedBox(height: 12),
                const PlaybackSpeedSelector(),
              ],
            ),
          ),
          const Divider(height: 32),

          _SectionHeader(l10n.settingsApp),
          ListTile(
            leading: const Icon(Icons.mail_outline_rounded),
            title: Text(l10n.settingsContactUs),
            onTap: () => launchUrl(
              Uri(
                scheme: 'mailto',
                path: config.contact.email,
                queryParameters: {'subject': config.contact.subject},
              ),
              mode: LaunchMode.externalApplication,
            ),
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
              onTap: () => launchUrl(
                Uri.parse(config.links.playStore!),
                mode: LaunchMode.externalApplication,
              ),
            ),
          if (config.links.website != null)
            ListTile(
              leading: const Icon(Icons.language_rounded),
              title: Text(config.links.website!
                  .replaceFirst('https://', '')
                  .replaceFirst('http://', '')),
              onTap: () => launchUrl(
                Uri.parse(config.links.website!),
                mode: LaunchMode.externalApplication,
              ),
            ),
          if (config.links.youtube != null)
            ListTile(
              leading: const Icon(Icons.play_circle_outline_rounded),
              title: Text(config.branding.appBrand),
              subtitle: Text(l10n.settingsYouTubeChannel),
              onTap: () => launchUrl(
                Uri.parse(config.links.youtube!),
                mode: LaunchMode.externalApplication,
              ),
            ),
          const Divider(height: 32),

          if (context.watch<FeatureFlagsProvider>().features.downloads)
            const _DownloadsSection(),

          _SectionHeader(l10n.settingsAbout),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: AboutCard(
              about: config.about,
              catalog: context.watch<CatalogProvider>().catalog,
            ),
          ),
          _BrandingFooter(branding: config.branding),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _BrandingFooter extends StatefulWidget {
  final AppConfigBranding branding;
  const _BrandingFooter({required this.branding});

  @override
  State<_BrandingFooter> createState() => _BrandingFooterState();
}

class _BrandingFooterState extends State<_BrandingFooter> {
  String? _version;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((PackageInfo info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          _BrandLink(
            label: widget.branding.appBrand,
            url: widget.branding.appBrandUrl,
          ),
          const SizedBox(height: 2),
          _BrandLink(
            label: widget.branding.poweredByLabel,
            url: widget.branding.publisherUrl,
            muted: true,
          ),
          if (_version != null) ...[
            const SizedBox(height: 4),
            Text(
              context.l10n.settingsAboutVersion(_version!),
              style: context.textTheme.labelSmall?.copyWith(
                color: context.mutedIconColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BrandLink extends StatelessWidget {
  final String label;
  final String url;
  final bool muted;

  const _BrandLink({
    required this.label,
    required this.url,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = muted ? context.mutedIconColor : context.brandColor;
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () => launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: context.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: muted ? FontWeight.w400 : FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.open_in_new_rounded, size: 10, color: color),
          ],
        ),
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
          onChanged: (v) => context.read<DownloadsProvider>().setDownloadOnWifiOnly(v),
        ),

        // Storage summary + library link
        ListTile(
          leading: const Icon(Icons.storage_rounded),
          title: Text(count == 0
              ? l10n.settingsNoDownloads
              : l10n.settingsDownloadsCount(count)),
          subtitle:
              count > 0 ? Text(l10n.settingsStorageUsed(_formatBytes(size))) : null,
          trailing: count > 0
              ? const Icon(Icons.chevron_right_rounded)
              : null,
          onTap: count > 0
              ? () => context.push('/offline-library')
              : null,
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
                context.read<DownloadsProvider>().deleteAll();
              }
            },
          ),
        const Divider(height: 32),
      ],
    );
  }
}

/// The series' canonical English name (e.g. "Kitab at-Tawheed (Arabic)") —
/// shown in the series section/picker regardless of UI language, since these
/// are product/edition names rather than translatable content.
String _seriesName(SeriesConfig series) =>
    series.displayName['en'] as String? ?? series.id;

class _SeriesSection extends StatelessWidget {
  const _SeriesSection();

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final current = context.watch<SeriesProvider>().currentSeries;

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
          child: ListTile(
            leading: const Icon(Icons.library_books_rounded),
            title: Text(_seriesName(current)),
            subtitle: Text(lang.resolve(current.speakerName)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _openPicker(context),
          ),
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final chosen = await showModalBottomSheet<SeriesConfig>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _SeriesPickerSheet(),
    );
    if (chosen == null || !context.mounted) return;

    final current = context.read<SeriesProvider>().currentSeries;
    if (chosen.id == current.id) return;

    final l10n = context.l10n;
    final seriesName = _seriesName(chosen);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.changeSeriesConfirmTitle,
      message: l10n.changeSeriesConfirmMessage(seriesName),
      confirmLabel: l10n.changeSeriesConfirm,
      filledConfirm: true,
    );
    if (!confirmed || !context.mounted) return;

    await switchSeries(context, chosen);
    if (!context.mounted) return;
    context.go('/lectures');
  }
}

class _SeriesPickerSheet extends StatelessWidget {
  const _SeriesPickerSheet();

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final series = context.watch<SeriesProvider>();
    final current = series.currentSeries;
    final l10n = context.l10n;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.settingsSeries,
                style: context.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          ...series.availableSeries.map((s) {
            final selected = s.id == current.id;
            return ListTile(
              leading: Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? context.brandColor : context.mutedIconColor,
              ),
              title: Text(_seriesName(s)),
              subtitle: Text(lang.resolve(s.speakerName)),
              onTap: () => Navigator.pop(context, s),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
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
