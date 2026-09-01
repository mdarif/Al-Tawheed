import 'package:flutter/material.dart';
import 'package:myapp/theme/app_theme_extensions.dart';

/// Small pill used to preview an edition's capabilities — e.g. Audio, Study
/// Mode, Book — on the chooser cards and the Settings edition-switcher rows.
class CapabilityChip extends StatelessWidget {
  final IconData? icon;
  final String label;

  const CapabilityChip({super.key, this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.elevatedSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: context.brandColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: context.secondaryTextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
