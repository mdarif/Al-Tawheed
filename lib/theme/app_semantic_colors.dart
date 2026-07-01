import 'package:flutter/material.dart';
import 'package:myapp/theme/app_colors.dart';

/// Semantic UI colors consumed by widgets — never reference [AppColors]
/// directly outside the theme layer.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color brand;
  final Color brandSubtle;
  final Color brandEmphasis;
  final Color onBrand;
  final Color groupedSurface;
  final Color groupedBorder;
  final Color elevatedSurface;
  final Color progressTrack;
  final Color surfaceTint;
  final Color accentGradientStart;
  final Color accentGradientEnd;
  final Color accentGradientBorder;
  final Color scrimOverlay;
  final Color onScrim;
  final Color onScrimMuted;
  final Color bookVerse;
  final Color bookCitation;
  final Color bookHadith;

  const AppSemanticColors({
    required this.brand,
    required this.brandSubtle,
    required this.brandEmphasis,
    required this.onBrand,
    required this.groupedSurface,
    required this.groupedBorder,
    required this.elevatedSurface,
    required this.progressTrack,
    required this.surfaceTint,
    required this.accentGradientStart,
    required this.accentGradientEnd,
    required this.accentGradientBorder,
    required this.scrimOverlay,
    required this.onScrim,
    required this.onScrimMuted,
    required this.bookVerse,
    required this.bookCitation,
    required this.bookHadith,
  });

  factory AppSemanticColors.dark(ColorScheme scheme) => AppSemanticColors(
        brand: scheme.primary,
        brandSubtle: scheme.primary.withValues(alpha: 0.12),
        brandEmphasis: AppColors.goldDark,
        onBrand: scheme.onPrimary,
        groupedSurface: scheme.surface,
        groupedBorder: AppColors.surfaceContainerDark,
        elevatedSurface: scheme.surfaceContainerHighest,
        progressTrack: scheme.surfaceContainerHighest,
        surfaceTint: AppColors.surfaceTintDark,
        accentGradientStart: scheme.primary.withValues(alpha: 0.15),
        accentGradientEnd: scheme.primary.withValues(alpha: 0.05),
        accentGradientBorder: scheme.primary.withValues(alpha: 0.25),
        scrimOverlay: AppColors.backgroundDark.withValues(alpha: 0.8),
        onScrim: AppColors.onDark,
        onScrimMuted: AppColors.onDark.withValues(alpha: 0.65),
        bookVerse: AppColors.bookVerseDark,
        bookCitation: AppColors.bookCitationDark,
        bookHadith: AppColors.bookHadithDark,
      );

  factory AppSemanticColors.light(ColorScheme scheme) => AppSemanticColors(
        brand: scheme.primary,
        brandSubtle: AppColors.brandSubtleLight,
        brandEmphasis: AppColors.goldLightThemeDark,
        onBrand: scheme.onPrimary,
        groupedSurface: scheme.surface,
        groupedBorder: AppColors.surfaceContainerLight,
        elevatedSurface: scheme.surfaceContainerHighest,
        progressTrack: scheme.surfaceContainerHighest,
        surfaceTint: AppColors.surfaceTintLight,
        accentGradientStart: AppColors.goldLightTheme.withValues(alpha: 0.18),
        accentGradientEnd: AppColors.goldLightTheme.withValues(alpha: 0.06),
        accentGradientBorder: AppColors.goldLightTheme.withValues(alpha: 0.28),
        scrimOverlay: AppColors.backgroundDark.withValues(alpha: 0.8),
        onScrim: Colors.white,
        onScrimMuted: Colors.white.withValues(alpha: 0.65),
        bookVerse: AppColors.bookVerseLight,
        bookCitation: AppColors.bookCitationLight,
        bookHadith: AppColors.bookHadithLight,
      );

  @override
  AppSemanticColors copyWith({
    Color? brand,
    Color? brandSubtle,
    Color? brandEmphasis,
    Color? onBrand,
    Color? groupedSurface,
    Color? groupedBorder,
    Color? elevatedSurface,
    Color? progressTrack,
    Color? surfaceTint,
    Color? accentGradientStart,
    Color? accentGradientEnd,
    Color? accentGradientBorder,
    Color? scrimOverlay,
    Color? onScrim,
    Color? onScrimMuted,
    Color? bookVerse,
    Color? bookCitation,
    Color? bookHadith,
  }) {
    return AppSemanticColors(
      brand: brand ?? this.brand,
      brandSubtle: brandSubtle ?? this.brandSubtle,
      brandEmphasis: brandEmphasis ?? this.brandEmphasis,
      onBrand: onBrand ?? this.onBrand,
      groupedSurface: groupedSurface ?? this.groupedSurface,
      groupedBorder: groupedBorder ?? this.groupedBorder,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
      progressTrack: progressTrack ?? this.progressTrack,
      surfaceTint: surfaceTint ?? this.surfaceTint,
      accentGradientStart: accentGradientStart ?? this.accentGradientStart,
      accentGradientEnd: accentGradientEnd ?? this.accentGradientEnd,
      accentGradientBorder: accentGradientBorder ?? this.accentGradientBorder,
      scrimOverlay: scrimOverlay ?? this.scrimOverlay,
      onScrim: onScrim ?? this.onScrim,
      onScrimMuted: onScrimMuted ?? this.onScrimMuted,
      bookVerse: bookVerse ?? this.bookVerse,
      bookCitation: bookCitation ?? this.bookCitation,
      bookHadith: bookHadith ?? this.bookHadith,
    );
  }

  @override
  AppSemanticColors lerp(AppSemanticColors? other, double t) {
    if (other == null) return this;
    return AppSemanticColors(
      brand: Color.lerp(brand, other.brand, t)!,
      brandSubtle: Color.lerp(brandSubtle, other.brandSubtle, t)!,
      brandEmphasis: Color.lerp(brandEmphasis, other.brandEmphasis, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      groupedSurface: Color.lerp(groupedSurface, other.groupedSurface, t)!,
      groupedBorder: Color.lerp(groupedBorder, other.groupedBorder, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      progressTrack: Color.lerp(progressTrack, other.progressTrack, t)!,
      surfaceTint: Color.lerp(surfaceTint, other.surfaceTint, t)!,
      accentGradientStart:
          Color.lerp(accentGradientStart, other.accentGradientStart, t)!,
      accentGradientEnd:
          Color.lerp(accentGradientEnd, other.accentGradientEnd, t)!,
      accentGradientBorder:
          Color.lerp(accentGradientBorder, other.accentGradientBorder, t)!,
      scrimOverlay: Color.lerp(scrimOverlay, other.scrimOverlay, t)!,
      onScrim: Color.lerp(onScrim, other.onScrim, t)!,
      onScrimMuted: Color.lerp(onScrimMuted, other.onScrimMuted, t)!,
      bookVerse: Color.lerp(bookVerse, other.bookVerse, t)!,
      bookCitation: Color.lerp(bookCitation, other.bookCitation, t)!,
      bookHadith: Color.lerp(bookHadith, other.bookHadith, t)!,
    );
  }
}
