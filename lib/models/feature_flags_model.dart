class FeatureFlags {
  final bool bookmarks;
  final bool downloads;
  final bool studyMode;
  final bool dailyBenefits;
  final bool announcements;
  final bool shareButton;
  final bool playbackSpeed;
  final bool continueListening;
  final bool language;

  const FeatureFlags({
    required this.bookmarks,
    required this.downloads,
    required this.studyMode,
    required this.dailyBenefits,
    required this.announcements,
    required this.shareButton,
    required this.playbackSpeed,
    required this.continueListening,
    required this.language,
  });

  factory FeatureFlags.fromJson(Map<String, dynamic> j) => FeatureFlags(
        bookmarks: j['bookmarks'] as bool? ?? true,
        downloads: j['downloads'] as bool? ?? false,
        studyMode: j['studyMode'] as bool? ?? false,
        dailyBenefits: j['dailyBenefits'] as bool? ?? true,
        announcements: j['announcements'] as bool? ?? true,
        shareButton: j['shareButton'] as bool? ?? true,
        playbackSpeed: j['playbackSpeed'] as bool? ?? true,
        continueListening: j['continueListening'] as bool? ?? true,
        language: j['language'] as bool? ?? false,
      );

  static const FeatureFlags defaults = FeatureFlags(
    bookmarks: true,
    downloads: false,
    studyMode: false,
    dailyBenefits: true,
    announcements: true,
    shareButton: true,
    playbackSpeed: true,
    continueListening: true,
    language: false,
  );
}

class FeatureFlagsModel {
  final int version;
  final FeatureFlags features;

  const FeatureFlagsModel({required this.version, required this.features});

  factory FeatureFlagsModel.fromJson(Map<String, dynamic> j) =>
      FeatureFlagsModel(
        version: j['version'] as int? ?? 1,
        features: FeatureFlags.fromJson(
            j['features'] as Map<String, dynamic>? ?? {}),
      );

  static FeatureFlagsModel get defaults =>
      const FeatureFlagsModel(version: 1, features: FeatureFlags.defaults);
}
