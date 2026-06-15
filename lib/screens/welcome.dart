import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';

// Arabic label for the call-to-action button, shown for the Arabic series —
// mirrors the _arXxx pattern used elsewhere (home_screen.dart,
// player_screen.dart, choose_series_screen.dart).
const _arStartListening = 'ابدأ الاستماع';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _startListening(BuildContext context) async {
    final series = context.read<SeriesProvider>();
    if (series.hasSelectedSeries) {
      context.go('/lectures');
      return;
    }
    if (series.availableSeries.length > 1) {
      context.go('/choose-series');
      return;
    }
    // Manifest unavailable / single-series — select it and continue
    // without showing the picker.
    await switchSeries(context, series.availableSeries.first);
    if (!context.mounted) return;
    context.go('/lectures');
  }

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final isRtl = context.watch<SeriesProvider>().currentSeries.isRtl;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/tawheed.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(color: Colors.black.withValues(alpha: 0.85)),
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Text(
                        'Sharah\n Kitab al-Tawheed',
                        textAlign: TextAlign.center,
                        style: context.textTheme.displayLarge?.copyWith(
                          color: semantic.onScrim,
                          fontSize: 38,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'شرح کتاب التوحید',
                        textAlign: TextAlign.center,
                        style: context.textTheme.titleMedium?.copyWith(
                          fontSize: 30,
                          color: context.brandColor,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        textStyle: context.textTheme.labelLarge
                            ?.copyWith(color: semantic.onBrand),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: Icon(
                        Icons.headphones_rounded,
                        size: 22,
                        color: semantic.onBrand,
                      ),
                      label: Text(
                        isRtl ? _arStartListening : 'START LISTENING',
                        style: TextStyle(
                          color: semantic.onBrand,
                          // Arabic script renders visually smaller at the same
                          // point size, and positive letter-spacing breaks its
                          // cursive letter connections.
                          fontSize: isRtl ? 20 : null,
                          letterSpacing: isRtl ? 0 : null,
                        ),
                      ),
                      onPressed: () => _startListening(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
