import 'dart:io' show Platform;

class Announcement {
  final String id;
  final String type;
  final String title;
  final String body;
  final String? ctaLabel;
  final String? ctaUrl;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final List<String> platforms;

  const Announcement({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.ctaLabel,
    this.ctaUrl,
    this.validFrom,
    this.validUntil,
    required this.platforms,
  });

  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
        id: j['id'] as String,
        type: j['type'] as String? ?? 'info',
        title: j['title'] as String,
        body: j['body'] as String,
        ctaLabel: j['ctaLabel'] as String?,
        ctaUrl: j['ctaUrl'] as String?,
        validFrom: j['validFrom'] != null
            ? DateTime.tryParse(j['validFrom'] as String)
            : null,
        validUntil: j['validUntil'] != null
            ? DateTime.tryParse(j['validUntil'] as String)
            : null,
        platforms: (j['platforms'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            ['android', 'ios'],
      );

  bool get isActive => isActiveAt(DateTime.now());

  /// Visible at [moment] — useful for tests and scheduling.
  bool isActiveAt(DateTime moment) {
    if (validFrom != null && moment.isBefore(validFrom!)) return false;
    if (validUntil != null && moment.isAfter(validUntil!)) return false;
    return true;
  }

  bool get matchesPlatform {
    if (Platform.isAndroid) return platforms.contains('android');
    if (Platform.isIOS) return platforms.contains('ios');
    return true;
  }
}

class AnnouncementsModel {
  final int version;
  final List<Announcement> announcements;

  const AnnouncementsModel({required this.version, required this.announcements});

  factory AnnouncementsModel.fromJson(Map<String, dynamic> j) =>
      AnnouncementsModel(
        version: j['version'] as int? ?? 1,
        announcements: (j['announcements'] as List<dynamic>?)
                ?.map((e) => Announcement.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  /// Active announcements for the current platform and date.
  List<Announcement> get active =>
      announcements.where((a) => a.isActive && a.matchesPlatform).toList();

  static AnnouncementsModel get empty =>
      const AnnouncementsModel(version: 1, announcements: []);
}
