import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:myapp/providers/app_config_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/language_provider.dart';
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
            child: Container(
              decoration: BoxDecoration(
                color: context.groupedSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.groupedBorder, width: 1),
              ),
              child: const ThemeModeSwitch(),
            ),
          ),
          const Divider(height: 32),

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
          const Divider(height: 32),

          if (context.watch<FeatureFlagsProvider>().features.downloads)
            const _DownloadsSection(),

          _SectionHeader(l10n.settingsAbout),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: AboutCard(about: config.about),
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
