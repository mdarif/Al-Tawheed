import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/theme/app_theme_extensions.dart';

const _arStartListening = 'ابدأ الاستماع';

// Arabic tagline shown when the series includes a companion book.
const _arTagline = 'شرح صوتي مع متن الكتاب';

// Urdu tagline — "Audio explanation in Urdu"
const _urTagline = 'شیخ الاسلام محمد بن عبدالوہاب رحمہ اللہ';

// Shown on the Urdu welcome screen before the user has selected a language —
// neutral English title that applies regardless of which series they choose.
const _enWelcomeTitle = 'Sharah Kitab at-Tawheed';

// Both series are "Sharah Kitab al-Tawheed" — only the script characters differ.
String _nativeTitleFor(SeriesConfig s) => switch (s.language) {
      'ar' => 'شرح كتاب التوحيد', // Arabic ك (U+0643) ي (U+064A)
      'ur' => 'شرح کتاب التوحید', // Urdu ک (U+06A9) ی (U+06CC)
      _ => (s.displayName['en'] as String?) ?? '',
    };

// Prefers the Arabic name from the config (speakerName['ar']), falls back to
// the transliterated English name. The Arabic name can be added to the remote
// series.json manifest at any time without a code change.
String _speakerNameFor(SeriesConfig s) {
  if (s.language == 'ar') {
    return (s.speakerName['ar'] as String?) ?? 'الشيخ صالح الفوزان حفظه الله';
  }
  return (s.speakerName['en'] as String?) ?? '';
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  Future<void> _startListening(BuildContext context) async {
    final series = context.read<SeriesProvider>();
    if (!context.mounted) return;
    if (series.hasSelectedSeries) {
      series.markWelcomeSeenForCurrentSeries();
      context.go('/lectures');
      return;
    }
    if (series.availableSeries.length > 1) {
      // Do NOT mark welcome as seen here — ChooseSeriesScreen handles it.
      // If the user picks the same series (Urdu), ChooseSeriesScreen marks it
      // seen and goes to /lectures. If they pick a different series (Arabic),
      // ChooseSeriesScreen navigates to / and the router shows that series'
      // welcome. Leaving Urdu unseen means backing out of the picker restores
      // this welcome screen correctly on the next launch.
      unawaited(context.push('/choose-series'));
      return;
    }
    await switchSeries(context, series.availableSeries.first);
    if (!context.mounted) return;
    series.markWelcomeSeenForCurrentSeries();
    context.go('/lectures');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Kick off decoding while the series is still being resolved (isReady=false).
    // By the time the content AnimatedOpacity starts its fade-in, the image is
    // already in the cache — frameBuilder sees wasSynchronouslyLoaded=true and
    // the photo appears in one pass with the rest of the content, no pop-in.
    precacheImage(const AssetImage('assets/images/sheikh_fawzan.png'), context);
    precacheImage(
      const AssetImage('assets/images/kitab_at_tawheed.png'),
      context,
    );
  }

  @override
  Widget build(BuildContext context) {
    final seriesProvider = context.watch<SeriesProvider>();
    final isReady = seriesProvider.isSeriesReady;
    final series = seriesProvider.currentSeries;
    final isRtl = series.isRtl;
    final native = _nativeTitleFor(series);
    final speaker = _speakerNameFor(series);
    final tagline = switch (series.language) {
      'ar' when series.hasBook => _arTagline,
      'ur' => _urTagline,
      _ => null,
    };

    return Theme(
      data: AppTheme.dark,
      // Builder ensures context.semantic / context.brandColor are read from
      // the dark theme scope, not from the parent (potentially light) theme.
      child: Builder(
        builder: (context) {
          final semantic = context.semantic;
          return Scaffold(
            body: Stack(
              children: [
                // Solid black base guarantees contrast for white text on any theme.
                Container(color: Colors.black),
                // Background image at 20% opacity — subtle texture, not a distraction.
                Opacity(
                  opacity: 0.20,
                  child: Container(
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/tawheed.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  ignoring: !isReady,
                  child: AnimatedOpacity(
                    opacity: isReady ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: SafeArea(
                      child: Column(
                        children: [
                          // All content centred as one group — photo, name, title,
                          // tagline all move together when the screen height changes.
                          Expanded(
                            child: Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isRtl) ...[
                                      // Circular sheikh photo with graceful fade-in.
                                      Container(
                                        width: 108,
                                        height: 108,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white24,
                                            width: 2,
                                          ),
                                        ),
                                        child: ClipOval(
                                          child: Image.asset(
                                            'assets/images/sheikh_fawzan.png',
                                            width: 104,
                                            height: 104,
                                            fit: BoxFit.cover,
                                            frameBuilder:
                                                (ctx, child, frame, sync) {
                                              if (sync) return child;
                                              return AnimatedOpacity(
                                                opacity:
                                                    frame == null ? 0.0 : 1.0,
                                                duration: const Duration(
                                                  milliseconds: 400,
                                                ),
                                                curve: Curves.easeIn,
                                                child: child,
                                              );
                                            },
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                              Icons.person_rounded,
                                              color: Colors.white38,
                                              size: 52,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      Container(
                                        width: 108,
                                        height: 108,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white24,
                                            width: 2,
                                          ),
                                        ),
                                        child: ClipOval(
                                          child: Image.asset(
                                            'assets/images/kitab_at_tawheed.png',
                                            width: 104,
                                            height: 104,
                                            fit: BoxFit.cover,
                                            frameBuilder:
                                                (ctx, child, frame, sync) {
                                              if (sync) return child;
                                              return AnimatedOpacity(
                                                opacity:
                                                    frame == null ? 0.0 : 1.0,
                                                duration: const Duration(
                                                  milliseconds: 400,
                                                ),
                                                curve: Curves.easeIn,
                                                child: child,
                                              );
                                            },
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                              Icons.auto_stories_rounded,
                                              color: Colors.white38,
                                              size: 52,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    // Speaker name only for the Arabic series — the Urdu
                                    // screen is shown before a language is selected.
                                    if (isRtl && speaker.isNotEmpty) ...[
                                      Text(
                                        speaker,
                                        textAlign: TextAlign.center,
                                        textDirection: TextDirection.rtl,
                                        style: context.textTheme.bodyLarge
                                            ?.copyWith(
                                          color: Colors.white70,
                                          letterSpacing: 0,
                                          fontFamily: 'NotoNaskhArabic',
                                        ),
                                      ),
                                      const SizedBox(height: 28),
                                    ],
                                    // Hero title.
                                    Text(
                                      isRtl ? native : _enWelcomeTitle,
                                      textAlign: TextAlign.center,
                                      textDirection: isRtl
                                          ? TextDirection.rtl
                                          : TextDirection.ltr,
                                      style: context.textTheme.displayLarge
                                          ?.copyWith(
                                        color: semantic.onScrim,
                                        fontSize: 38,
                                        letterSpacing: isRtl ? 0 : null,
                                        fontFamily:
                                            isRtl ? 'NotoNaskhArabic' : null,
                                      ),
                                    ),
                                    if (!isRtl && native.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        native,
                                        textAlign: TextAlign.center,
                                        textDirection: TextDirection.rtl,
                                        style: context.textTheme.titleLarge
                                            ?.copyWith(
                                          color: Colors.white70,
                                          letterSpacing: 0,
                                          fontFamily: 'NotoNaskhArabic',
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    if (tagline != null)
                                      Text(
                                        tagline,
                                        textAlign: TextAlign.center,
                                        textDirection: TextDirection.rtl,
                                        style: context.textTheme.titleMedium
                                            ?.copyWith(
                                          fontSize: 17,
                                          color: context.brandColor,
                                          letterSpacing: 0,
                                          fontFamily: 'NotoNaskhArabic',
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 18),
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
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
