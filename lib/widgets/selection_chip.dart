import 'package:flutter/material.dart';
import 'package:myapp/theme/app_theme_extensions.dart';

class SelectionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final EdgeInsetsGeometry padding;
  final bool expand;

  const SelectionChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: expand ? double.infinity : null,
        padding: padding,
        decoration: BoxDecoration(
          color: selected ? context.brandColor : context.chipUnselectedBackground,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: expand ? Alignment.center : null,
        child: Text(
          label,
          textAlign: expand ? TextAlign.center : null,
          style: context.textTheme.labelMedium?.copyWith(
            color: selected ? context.onBrandColor : context.chipUnselectedText,
          ),
        ),
      ),
    );
  }
}
