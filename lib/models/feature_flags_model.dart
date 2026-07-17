class FeatureFlags {
  final bool bookmarks;
  final bool downloads;
  final bool studyMode;
  final bool dailyBenefits;
  final bool announcements;

  /// Governs the player's "Share lecture" app-bar button and the app-bar ⋯
  /// "Share app" action. Defaults `true`. Note: the *lecture-row* share button
  /// is governed separately by [shareLectureRow] so it can be turned off on its
  /// own (see there).
  final bool shareButton;

  /// Whether each lecture row (on the lectures list page) shows a share button.
  /// Split out from [shareButton] so it can be flipped off remotely if the row
  /// looks too crowded, without affecting the player or app-share. Defaults
  /// `true`.
  final bool shareLectureRow;
  final bool playbackSpeed;
  final bool continueListening;
  final bool language;

  /// Whether the Settings "App" section (contact, rate, YouTube links) is shown.
  /// Defaults to `false` so the promotional links stay hidden until explicitly
  /// enabled in the remote config; the official website is surfaced separately
  /// in the About card regardless of this flag. ("Share app" itself moved to the
  /// app-bar ⋯ menu — see [shareButton].)
  final bool appLinks;

  const FeatureFlags({
    required this.bookmarks,
    required this.downloads,
    required this.studyMode,
    required this.dailyBenefits,
    required this.announcements,
    required this.shareButton,
    required this.shareLectureRow,
    required this.playbackSpeed,
    required this.continueListening,
    required this.language,
    required this.appLinks,
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
      shareLectureRow: _bool(j, 'shareLectureRow') ?? d.shareLectureRow,
      playbackSpeed: _bool(j, 'playbackSpeed') ?? d.playbackSpeed,
      continueListening: _bool(j, 'continueListening') ?? d.continueListening,
      language: _bool(j, 'language') ?? d.language,
      appLinks: _bool(j, 'appLinks') ?? d.appLinks,
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
    shareLectureRow: true,
    playbackSpeed: true,
    continueListening: true,
    language: true,
    appLinks: false,
  );
}

class FeatureFlagsModel {
  final int version;
  final FeatureFlags features;

  const FeatureFlagsModel({required this.version, required this.features});

  factory FeatureFlagsModel.fromJson(Map<String, dynamic> j) =>
      FeatureFlagsModel(
        version: j['version'] as int? ?? 1,
        features:
            FeatureFlags.fromJson(j['features'] as Map<String, dynamic>? ?? {}),
      );

  static FeatureFlagsModel get defaults =>
      const FeatureFlagsModel(version: 1, features: FeatureFlags.defaults);
}
