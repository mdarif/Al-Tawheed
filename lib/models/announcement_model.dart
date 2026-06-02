import 'dart:io' show Platform;

import 'package:myapp/data/content_i18n_overlay.dart';
import 'package:myapp/models/i18n_field.dart';

class Announcement {
  final String id;
  final String type;
  final Map<String, dynamic> title;
  final Map<String, dynamic> body;
  final Map<String, dynamic>? ctaLabel;
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

  factory Announcement.fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String;
    final overlay = announcementOverlays[id];

    return Announcement(
      id: id,
      type: j['type'] as String? ?? 'info',
      title: mergeI18nOverlay(
        toI18nMap(j['title']),
        overlay?['title'],
      ),
      body: mergeI18nOverlay(
        toI18nMap(j['body']),
        overlay?['body'],
      ),
      ctaLabel: j['ctaLabel'] != null
          ? mergeI18nOverlay(
              toI18nMap(j['ctaLabel']),
              overlay?['ctaLabel'],
            )
          : null,
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
  }

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
