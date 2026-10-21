import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:myapp/l10n/app_localizations.dart';

class DownloadNotificationService {
  DownloadNotificationService._()
      : _plugin = FlutterLocalNotificationsPlugin(),
        _isAndroid = Platform.isAndroid;

  /// Builds a service around a fake [plugin] so tests can capture what would
  /// be shown, with the platform gate forced on (the host is never Android).
  @visibleForTesting
  DownloadNotificationService.forTest(
    this._plugin, {
    bool isAndroid = true,
  }) : _isAndroid = isAndroid;

  static DownloadNotificationService instance = DownloadNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin;
  final bool _isAndroid;
  final Map<String, Timer> _dismissTimers = {};

  static const _channelId = 'downloads';

  /// `name\u0000description` of the channel as last registered with Android,
  /// so [syncChannel] only touches the platform when the locale actually
  /// changed the visible text.
  String? _registeredChannelText;

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
    if (!_isAndroid) return;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);

    // `init()` runs before the app (and so the chrome language) exists, hence
    // no BuildContext and no locale yet: register the channel in English so it
    // is never missing, then [syncChannel] renames it to the chrome language
    // as soon as the downloads layer knows it.
    await syncChannel(lookupAppLocalizations(const Locale('en')));
  }

  static String _channelText(AppLocalizations l10n) =>
      '${l10n.downloadNotificationChannelName}\u0000'
      '${l10n.downloadNotificationChannelDescription}';

  bool _isChannelCurrent(AppLocalizations l10n) =>
      _channelText(l10n) == _registeredChannelText;

  /// Makes the notification channel's name and description match [l10n].
  ///
  /// Android has no per-locale channel strings: the name is stored once, at
  /// creation, in whatever language the app passed. Calling
  /// `createNotificationChannel` again with the **same id** updates the
  /// name/description of the existing channel in place (importance, sound etc.
  /// are deliberately NOT changed by Android after first creation, and users'
  /// own channel settings survive) — so a chrome-language change is a rename,
  /// not a delete + recreate. A no-op when the text is already registered.
  Future<void> syncChannel(AppLocalizations l10n) async {
    if (!_isAndroid) return;
    if (_isChannelCurrent(l10n)) return;
    final name = l10n.downloadNotificationChannelName;
    final description = l10n.downloadNotificationChannelDescription;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    try {
      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          _channelId,
          name,
          description: description,
          importance: Importance.low,
          showBadge: false,
        ),
      );
      _registeredChannelText = _channelText(l10n);
    } catch (e) {
      // A failed rename must never stop the progress notification itself.
      debugPrint('DownloadNotificationService: channel sync failed: $e');
    }
  }

  /// Shows the native permission dialog (Android 13+; a no-op granted-by-
  /// default on older Android). Returns `null` off Android, where there is
  /// nothing to ask.
  Future<bool?> requestPermission() async {
    if (!_isAndroid) return null;
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
    if (!_isAndroid) return null;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return android?.areNotificationsEnabled();
  }

  int _idFor(String lectureId) => lectureId.hashCode & 0x7FFFFFFF;

  Future<void> showProgress(
    String lectureId,
    String title,
    double progress,
    AppLocalizations l10n,
  ) async {
    if (!_isAndroid) return;
    _cancelPendingDismiss(lectureId);
    if (!_isChannelCurrent(l10n)) await syncChannel(l10n);
    final percent = (progress * 100).round();
    await _plugin.show(
      _idFor(lectureId),
      title,
      null,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          l10n.downloadNotificationChannelName,
          channelDescription: l10n.downloadNotificationChannelDescription,
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

  Future<void> showComplete(
    String lectureId,
    String title,
    AppLocalizations l10n,
  ) async {
    if (!_isAndroid) return;
    _cancelPendingDismiss(lectureId);
    if (!_isChannelCurrent(l10n)) await syncChannel(l10n);
    await _plugin.show(
      _idFor(lectureId),
      title,
      l10n.downloadComplete,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          l10n.downloadNotificationChannelName,
          channelDescription: l10n.downloadNotificationChannelDescription,
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
    if (!_isAndroid) return;
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
