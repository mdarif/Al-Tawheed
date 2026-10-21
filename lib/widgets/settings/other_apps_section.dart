import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myapp/models/other_apps.dart';
import 'package:myapp/testing/widget_keys.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';
import 'package:myapp/utils/safe_url_launcher.dart';
import 'package:myapp/widgets/settings/settings_section.dart';

/// Settings › "Our other apps": links to Al Marfa's other Google Play apps.
///
/// Android only — hidden on every other platform until real App Store ids
/// exist (the links are Play listings). Deliberately NOT gated by the
/// `appLinks` feature flag, which is off in production and would hide it.
/// Reads [defaultTargetPlatform] (not `dart:io`) so tests can override it.
class OtherAppsSection extends StatelessWidget {
  const OtherAppsSection({super.key});

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    final apps = otherAppsExcluding(kOwnPackageId);
    if (apps.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;

    return Column(
      key: WidgetKeys.settingsOtherAppsSection,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionHeader(l10n.settingsOtherApps),
        SettingsCard(
          child: Column(
            children: [
              for (var i = 0; i < apps.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: context.groupedBorder,
                  ),
                _OtherAppRow(app: apps[i]),
              ],
            ],
          ),
        ),
        SettingsSectionFootnote(l10n.settingsOtherAppsFooter),
        const SizedBox(height: 6),
      ],
    );
  }
}

class _OtherAppRow extends StatelessWidget {
  final OtherApp app;
  const _OtherAppRow({required this.app});

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final launched = await launchExternalUrl(app.listingUrl);
    if (launched) return;
    // No handler (no Play Store / no browser): keep the link recoverable.
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.settingsOtherAppsOpenFailed),
        action: SnackBarAction(
          label: l10n.settingsOtherAppsCopyLink,
          onPressed: () =>
              Clipboard.setData(ClipboardData(text: app.listingUrl)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tagline = app.tagline(l10n);
    final locale = Localizations.localeOf(context);
    // Nastaliq (Urdu script chrome) needs generous leading; Roman Urdu is Latin.
    final isNastaliq =
        locale.languageCode == 'ur' && locale.scriptCode != 'roman';
    final height = isNastaliq ? 2.0 : null;

    return Semantics(
      key: WidgetKeys.settingsOtherApp(app.packageId),
      button: true,
      label: l10n.settingsOtherAppOpensInPlay(app.name),
      hint: tagline,
      excludeSemantics: true,
      onTap: () => _open(context),
      child: InkWell(
        onTap: () => _open(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    app.iconAsset,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    // A missing/corrupt icon must not break the row.
                    errorBuilder: (_, __, ___) => SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.apps_rounded,
                        color: context.secondaryTextColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.name,
                        style: context.textTheme.bodyLarge?.copyWith(
                          height: height,
                        ),
                      ),
                      Text(
                        tagline,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.secondaryTextColor,
                          height: height,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.open_in_new_rounded,
                  size: 20,
                  color: context.secondaryTextColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
