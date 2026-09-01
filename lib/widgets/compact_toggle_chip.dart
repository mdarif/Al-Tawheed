import 'package:flutter/material.dart';
import 'package:myapp/theme/app_theme_extensions.dart';

/// A compact, on-brand toggle chip for a small (2-3 option) in-screen switch —
/// e.g. Library's Saved/Downloads segments or Read's Book/Study segments.
///
/// Unlike [SegmentedButton], the label is bounded to a fixed height and
/// scaled down to fit, so long Arabic/Urdu labels don't overflow the chip at
/// narrow width + 2x text.
class CompactToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const CompactToggleChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:
              selected ? context.brandColor : context.chipUnselectedBackground,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: SizedBox(
          height: 24,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: context.textTheme.labelMedium?.copyWith(
                color: selected
                    ? context.onBrandColor
                    : context.chipUnselectedText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
