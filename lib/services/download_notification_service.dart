import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class DownloadNotificationService {
  DownloadNotificationService._();
  static final instance = DownloadNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final Map<String, Timer> _dismissTimers = {};

  static const _channelId = 'downloads';
  static const _channelName = 'Downloads';

  /// Overrides [areNotificationsEnabled]'s result in tests, where the real
  /// platform is never Android. `null` (the default) means "use the real
  /// platform check".
  @visibleForTesting
  bool? areNotificationsEnabledForTest;

  /// Sets up the plugin and notification channel only — does **not** ask for
  /// permission. The permission prompt is contextual (first download action,
  /// with a rationale), not a startup interruption — see [requestPermission]
  /// and BLK-07.
  Future<void> init() async {
    if (!Platform.isAndroid) return;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        importance: Importance.low,
        showBadge: false,
      ),
    );
  }

  /// Shows the native permission dialog (Android 13+; a no-op granted-by-
  /// default on older Android). Returns `null` off Android, where there is
  /// nothing to ask.
  Future<bool?> requestPermission() async {
    if (!Platform.isAndroid) return null;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return android?.requestNotificationsPermission();
  }

  /// Current grant state, for the Settings recovery row — checkable anytime,
  /// unlike [requestPermission] which shows a dialog. `null` off Android.
  Future<bool?> areNotificationsEnabled() async {
    if (areNotificationsEnabledForTest != null) {
      return areNotificationsEnabledForTest;
    }
    if (!Platform.isAndroid) return null;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return android?.areNotificationsEnabled();
  }

  int _idFor(String lectureId) => lectureId.hashCode & 0x7FFFFFFF;

  Future<void> showProgress(
    String lectureId,
    String title,
    double progress,
  ) async {
    if (!Platform.isAndroid) return;
    _cancelPendingDismiss(lectureId);
    final percent = (progress * 100).round();
    await _plugin.show(
      _idFor(lectureId),
      title,
      null,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          ongoing: true,
          showProgress: true,
          maxProgress: 100,
          progress: percent,
          indeterminate: percent == 0,
          onlyAlertOnce: true,
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
          enableVibration: false,
        ),
      ),
    );
  }

  Future<void> showComplete(String lectureId, String title) async {
    if (!Platform.isAndroid) return;
    _cancelPendingDismiss(lectureId);
    await _plugin.show(
      _idFor(lectureId),
      title,
      'Download complete',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
          enableVibration: false,
        ),
      ),
    );
    _dismissTimers[lectureId] =
        Timer(const Duration(seconds: 4), () => dismiss(lectureId));
  }

  Future<void> dismiss(String lectureId) async {
    if (!Platform.isAndroid) return;
    _cancelPendingDismiss(lectureId);
    await _plugin.cancel(_idFor(lectureId));
  }

  /// Cancels a pending auto-dismiss timer so a fresh notification for the same
  /// lecture (e.g. a re-download started within the 4s window) isn't cancelled
  /// by a stale timer from the previous completion.
  void _cancelPendingDismiss(String lectureId) {
    _dismissTimers.remove(lectureId)?.cancel();
  }
}
