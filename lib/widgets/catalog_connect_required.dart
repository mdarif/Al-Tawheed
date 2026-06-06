import 'package:flutter/material.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';

/// Shown when the catalog has never been cached and the device is offline.
class CatalogConnectRequiredBody extends StatelessWidget {
  final CatalogProvider provider;

  const CatalogConnectRequiredBody({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 52, color: context.mutedIconColor),
          const SizedBox(height: 20),
          Text(
            l10n.catalogConnectToLoadTitle,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.catalogConnectToLoadMessage,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: provider.load,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}
