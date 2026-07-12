import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:myapp/models/app_config_model.dart';
import 'package:myapp/providers/app_config_provider.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';
import 'package:myapp/utils/safe_url_launcher.dart';
import 'package:myapp/widgets/settings/about_card.dart';

/// Standalone About page — the app/series details, version, and brand links.
/// Split out of Settings and pushed full-screen from the Settings "About" row
/// (mirrors the al-Quran app's dedicated About page).
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfigProvider>().config;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsAbout)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: AboutCard(
              about: config.about,
              catalog: context.watch<CatalogProvider>().catalog,
              website: config.links.website,
            ),
          ),
          _BrandingFooter(branding: config.branding),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Opens [url] externally through the https/mailto allowlist, showing
/// [fallbackMessage] in a snackbar if the launch fails.
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
            Semantics(
              button: true,
              label: context.l10n.settingsAboutVersion(_version!),
              child: GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _version!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.settingsVersionCopied),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: Text(
                  context.l10n.settingsAboutVersion(_version!),
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.mutedIconColor,
                  ),
                ),
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
      onTap: () => _launchOrNotify(context, url, fallbackMessage: url),
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
