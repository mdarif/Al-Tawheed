import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:myapp/providers/app_config_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/widgets/settings/playback_speed_selector.dart';
import 'package:myapp/widgets/settings/theme_mode_selector.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfigProvider>().config;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── Appearance ───────────────────────────────────────────────────
          _SectionHeader('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Theme', style: theme.textTheme.bodySmall),
                const SizedBox(height: 12),
                const ThemeModeSelector(),
              ],
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
                Text('Playback speed', style: theme.textTheme.bodySmall),
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
