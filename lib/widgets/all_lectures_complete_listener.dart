import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';
import 'package:myapp/utils/l10n_extensions.dart';

/// Watches [PlayerNotifier.pendingAllLecturesComplete] and shows a
/// celebratory bottom sheet once when the flag fires. Safe to place in
/// multiple widget trees — only the first one to see the flag consumes it.
class AllLecturesCompleteListener extends StatefulWidget {
  final Widget child;
  const AllLecturesCompleteListener({super.key, required this.child});

  @override
  State<AllLecturesCompleteListener> createState() =>
      _AllLecturesCompleteListenerState();
}

class _AllLecturesCompleteListenerState
    extends State<AllLecturesCompleteListener> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    final pending = context.select<PlayerNotifier, bool>(
      (p) => p.pendingAllLecturesComplete,
    );

    if (pending && !_handled) {
      _handled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<PlayerNotifier>().clearPendingAllLecturesComplete();
        _showCompletionSheet(context);
      });
    } else if (!pending) {
      _handled = false;
    }

    return widget.child;
  }

  void _showCompletionSheet(BuildContext context) {
    final l10n = context.l10n;
    final isRtl = context.read<SeriesProvider>().currentSeries.isRtl;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.brandColor.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    color: context.brandColor,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    l10n.allLecturesComplete,
                    textAlign: TextAlign.center,
                    style: context.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: context.brandColor,
                      fontFamily: isRtl ? 'NotoNaskhArabic' : null,
                      letterSpacing: isRtl ? 0 : null,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    l10n.allLecturesCompleteMessage,
                    textAlign: TextAlign.center,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.secondaryTextColor,
                      height: 1.5,
                      fontFamily: isRtl ? 'NotoNaskhArabic' : null,
                      letterSpacing: isRtl ? 0 : null,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
