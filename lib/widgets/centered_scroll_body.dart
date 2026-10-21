import 'package:flutter/material.dart';

/// Centres [child] in the space it is given, and lets it scroll when it is
/// taller than that space.
///
/// For full-screen status pages (couldn't load, offline, edition missing,
/// welcome): a bare `Center(Column(...))` looks right at normal text size but
/// overflows its bottom edge on a short screen, at large text, or with a
/// longer translation, and nothing on the page can scroll to reveal what is
/// cut off. Where the height is unbounded the child simply takes its own
/// height.
class CenteredScrollBody extends StatelessWidget {
  const CenteredScrollBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
