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

  /// Whether the Settings "Series" switcher is offered. Gates only the UI
  /// affordance for changing series — multi-series resolution itself is still
  /// governed by the experimental `multiSeries` flag. Defaults to `false` so
  /// the switcher stays hidden until explicitly enabled in the remote config.
  final bool seriesSwitcher;

  /// Whether the Settings "App" section (contact, share, rate, YouTube links)
  /// is shown. Defaults to `false` so the promotional links stay hidden until
  /// explicitly enabled in the remote config; the official website is surfaced
  /// separately in the About card regardless of this flag.
  final bool appLinks;

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
    required this.seriesSwitcher,
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
      playbackSpeed: _bool(j, 'playbackSpeed') ?? d.playbackSpeed,
      continueListening: _bool(j, 'continueListening') ?? d.continueListening,
      language: _bool(j, 'language') ?? d.language,
      seriesSwitcher: _bool(j, 'seriesSwitcher') ?? d.seriesSwitcher,
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
    playbackSpeed: true,
    continueListening: true,
    language: false,
    seriesSwitcher: false,
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
