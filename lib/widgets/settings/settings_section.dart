import 'package:flutter/material.dart';
import 'package:myapp/theme/app_theme_extensions.dart';

/// Rounded, bordered container used to group a settings section's rows — the
/// shared "card" chrome so every section reads consistently.
class SettingsCard extends StatelessWidget {
  final Widget child;
  const SettingsCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: context.groupedSurface,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.groupedBorder, width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A settings section's small heading.
class SettingsSectionHeader extends StatelessWidget {
  final String title;
  const SettingsSectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
      child: Text(
        title,
        style: context.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A quiet one-line note under a section's card.
class SettingsSectionFootnote extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  const SettingsSectionFootnote(this.text, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      style: context.textTheme.bodySmall?.copyWith(
        color: context.secondaryTextColor,
      ),
    );
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(28, 6, 28, 0),
      child: onTap == null
          ? label
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(6),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: label,
                ),
              ),
            ),
    );
  }
}
