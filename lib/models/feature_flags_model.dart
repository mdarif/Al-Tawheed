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

  factory FeatureFlags.fromJson(Map<String, dynamic> j) {
    const d = FeatureFlags.defaults;
    return FeatureFlags(
      bookmarks: _bool(j, 'bookmarks') ?? d.bookmarks,
      downloads: _bool(j, 'downloads') ?? d.downloads,
      studyMode: _bool(j, 'studyMode') ?? d.studyMode,
      dailyBenefits: _bool(j, 'dailyBenefits') ?? d.dailyBenefits,
      announcements: _bool(j, 'announcements') ?? d.announcements,
      shareButton: _bool(j, 'shareButton') ?? d.shareButton,
      playbackSpeed: _bool(j, 'playbackSpeed') ?? d.playbackSpeed,
      continueListening: _bool(j, 'continueListening') ?? d.continueListening,
      language: _bool(j, 'language') ?? d.language,
    );
  }

  static bool? _bool(Map<String, dynamic> j, String key) {
    final v = j[key];
    return v is bool ? v : null;
  }

  static const FeatureFlags defaults = FeatureFlags(
    bookmarks: true,
    downloads: true,
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
