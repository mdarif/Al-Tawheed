import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/theme/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];
  static const _shareMessage =
      'The *Sharah Kitab Al-Tawheed* app — 50 audio lectures of '
      'Fazilat Sheikh Abdullah Nasir Rahmani Hafizahullah.\n\n'
      'Download from Google Play Store:\n'
      'https://play.google.com/store/apps/details?id=com.almarfa.tawheed';

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerNotifier>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── Playback ────────────────────────────────────────────────────
          _SectionHeader('Playback'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Playback speed',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: AppColors.onDarkSecondary)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: _speeds.map((s) {
                    final selected = (player.speed - s).abs() < 0.01;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => player.setSpeed(s),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.gold
                                : AppColors.surfaceContainerDark,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${s}x',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.black
                                  : AppColors.onDarkSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const Divider(height: 32),

          // ── App ─────────────────────────────────────────────────────────
          _SectionHeader('App'),
          ListTile(
            leading: const Icon(Icons.share_rounded),
            title: const Text('Share app'),
            onTap: () => SharePlus.instance.share(
              ShareParams(text: _shareMessage),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.star_outline_rounded),
            title: const Text('Rate on Play Store'),
            onTap: () => launchUrl(
              Uri.parse(
                'https://play.google.com/store/apps/details?id=com.almarfa.tawheed',
              ),
              mode: LaunchMode.externalApplication,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.language_rounded),
            title: const Text('almarfa.co'),
            onTap: () => launchUrl(
              Uri.parse('https://almarfa.co'),
              mode: LaunchMode.externalApplication,
            ),
          ),
          const Divider(height: 32),

          // ── About ────────────────────────────────────────────────────────
          _SectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('50 lectures · Sharah Kitab al-Tawheed'),
            subtitle: const Text(
                'By Fazilat Sheikh Abdullah Nasir Rahmani Hafizahullah'),
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
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: AppColors.gold,
        ),
      ),
    );
  }
}
