import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:myapp/providers/app_config_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/widgets/settings/playback_speed_selector.dart';
import 'package:myapp/widgets/settings/theme_mode_switch.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfigProvider>().config;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── Appearance ───────────────────────────────────────────────────
          _SectionHeader('Appearance'),
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

          // ── Playback ─────────────────────────────────────────────────────
          _SectionHeader('Playback'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Playback speed', style: context.textTheme.bodySmall),
                const SizedBox(height: 12),
                const PlaybackSpeedSelector(),
              ],
            ),
          ),
          const Divider(height: 32),

          // ── App ──────────────────────────────────────────────────────────
          _SectionHeader('App'),
          ListTile(
            leading: const Icon(Icons.mail_outline_rounded),
            title: const Text('Contact Us'),
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
            title: const Text('Share app'),
            onTap: () => SharePlus.instance.share(
              ShareParams(text: config.share.message),
            ),
          ),
          if (config.links.playStore != null)
            ListTile(
              leading: const Icon(Icons.star_outline_rounded),
              title: const Text('Rate on Play Store'),
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

          // ── Downloads (only when flag is on) ─────────────────────────────
          if (context.watch<FeatureFlagsProvider>().features.downloads)
            _DownloadsSection(),

          // ── About ─────────────────────────────────────────────────────────
          _SectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: Text(
                '${config.about.lectureCount} lectures · ${config.about.appName}'),
            subtitle: Text('By ${config.about.lecturer}'),
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
  static String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final downloads = context.watch<DownloadsProvider>();
    final count = downloads.downloadedCount;
    final size = downloads.totalDownloadedBytes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader('Downloads'),
        ListTile(
          leading: const Icon(Icons.storage_rounded),
          title: Text(count == 0
              ? 'No lectures downloaded'
              : '$count ${count == 1 ? 'lecture' : 'lectures'} downloaded'),
          subtitle:
              count > 0 ? Text('${_formatBytes(size)} used') : null,
        ),
        if (count > 0)
          ListTile(
            leading: Icon(
              Icons.delete_outline_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Clear all downloads',
              style:
                  TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Clear all downloads?'),
                content: Text(
                  '$count ${count == 1 ? 'lecture' : 'lectures'} '
                  '(${_formatBytes(size)}) will be deleted from this device.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(
                      'Delete all',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ],
              ),
            ).then((confirmed) {
              if (confirmed == true && context.mounted) {
                context.read<DownloadsProvider>().deleteAll();
              }
            }),
          ),
        const Divider(height: 32),
      ],
    );
  }
}
