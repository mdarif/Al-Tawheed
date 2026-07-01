import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';

/// Subtle banner shown across shell tabs when the device is offline.
class OfflineStatusBanner extends StatelessWidget {
  const OfflineStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final downloadsEnabled = context.select<FeatureFlagsProvider, bool>(
      (p) => p.features.downloads,
    );
    if (!downloadsEnabled) return const SizedBox.shrink();

    final isOffline = context.select<ConnectivityProvider, bool>(
      (c) => c.isOffline,
    );
    if (!isOffline) return const SizedBox.shrink();

    final l10n = context.l10n;

    return Material(
      color: const Color(0xFFE65100).withValues(
        alpha: context.isDarkTheme ? 0.22 : 0.12,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 14,
                color: const Color(0xFFE65100),
              ),
              const SizedBox(width: 6),
              Text(
                l10n.offlineBadge,
                style: context.textTheme.labelSmall?.copyWith(
                  color: const Color(0xFFE65100),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
