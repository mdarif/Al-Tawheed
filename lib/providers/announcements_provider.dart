import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:myapp/app_config.dart';
import 'package:myapp/models/announcement_model.dart';
import 'package:myapp/services/remote_content_service.dart';

class AnnouncementsProvider extends ChangeNotifier {
  AnnouncementsModel _model = AnnouncementsModel.empty;

  /// Active announcements for the current platform and current date.
  List<Announcement> get active => _model.active;

  Future<void> load() async {
    try {
      final body = await RemoteContentService.fetch(
        url: AppConfig.announcementsUrl,
        cacheKey: 'announcements',
        ttlMs: AppConfig.announcementsCacheTtlMs,
      );
      final raw = jsonDecode(body) as Map<String, dynamic>;
      final model = AnnouncementsModel.fromJson(raw);

      if (model.version > AppConfig.maxSupportedAnnouncementsVersion) {
        return;
      }

      _model = model;
      notifyListeners();
    } catch (_) {
      // Fetch failed — empty list remains; no announcements shown
    }
  }
}
