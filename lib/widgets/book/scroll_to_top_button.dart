import 'package:flutter/material.dart';
import 'package:myapp/theme/app_theme_extensions.dart';

/// A small round "back to top" button that slides in when the reader has been
/// scrolled down, mirroring the Quran app's pattern. Always in the tree so it
/// can animate both ways; taps are ignored while hidden so it is not a dead
/// zone over the text.
class ScrollToTopButton extends StatelessWidget {
  const ScrollToTopButton({
    required this.visible,
    required this.onPressed,
    super.key,
  });

  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, 0.4),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 220),
        child: IgnorePointer(
          ignoring: !visible,
          child: Material(
            color: context.elevatedSurface,
            shape: const CircleBorder(),
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.25),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: context.brandColor,
                  semanticLabel: 'Scroll to top',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
