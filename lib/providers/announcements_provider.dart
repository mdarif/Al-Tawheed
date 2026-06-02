import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:myapp/app_config.dart';
import 'package:myapp/models/announcement_model.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/services/remote_content_service.dart';

class AnnouncementsProvider extends ChangeNotifier {
  AnnouncementsModel _model = AnnouncementsModel.empty;
  Set<String> _dismissed = {};

  /// Active, non-dismissed announcements for the current platform and date.
  List<Announcement> get visible =>
      _model.active.where((a) => !_dismissed.contains(a.id)).toList();

  Future<void> load({bool forceRefresh = false}) async {
    _dismissed = PreferencesService.instance.loadDismissedAnnouncements();

    try {
      final body = await RemoteContentService.fetch(
        url: AppConfig.announcementsUrl,
        cacheKey: 'announcements',
        ttlMs: AppConfig.announcementsCacheTtlMs,
        forceRefresh: forceRefresh,
      );
      _applyBody(body);
    } catch (_) {
      // Fetch failed — empty list; no banner shown
    }
  }

  void _applyBody(String body) {
    final raw = jsonDecode(body) as Map<String, dynamic>;
    final model = AnnouncementsModel.fromJson(raw);

    if (model.version > AppConfig.maxSupportedAnnouncementsVersion) {
      return;
    }

    _model = model;
    notifyListeners();
  }

  /// Re-fetch from CDN, bypassing cache TTL (e.g. pull-to-refresh on Home).
  Future<void> refresh() => load(forceRefresh: true);

  /// Dismiss an announcement permanently (survives app restarts).
  Future<void> dismiss(String id) async {
    _dismissed.add(id);
    notifyListeners();
    await PreferencesService.instance.saveDismissedAnnouncements(_dismissed);
  }
}
