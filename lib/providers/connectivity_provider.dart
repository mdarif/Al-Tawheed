import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class ConnectivityProvider extends ChangeNotifier with WidgetsBindingObserver {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _debounce;

  bool _isOnline = true;
  List<ConnectivityResult> _results = const [ConnectivityResult.wifi];

  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;
  bool get isWifi => _results.contains(ConnectivityResult.wifi);
  bool get isMobile => _results.contains(ConnectivityResult.mobile);

  ConnectivityProvider() {
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  ConnectivityProvider._test(bool online)
      : _isOnline = online,
        _results = online
            ? const [ConnectivityResult.wifi]
            : const [ConnectivityResult.none];

  ConnectivityProvider._testMobile()
      : _isOnline = true,
        _results = const [ConnectivityResult.mobile];

  @visibleForTesting
  factory ConnectivityProvider.testOnline() => ConnectivityProvider._test(true);

  @visibleForTesting
  factory ConnectivityProvider.testOffline() =>
      ConnectivityProvider._test(false);

  /// Online via mobile data — isOnline true, isWifi false.
  @visibleForTesting
  factory ConnectivityProvider.testOnlineMobile() =>
      ConnectivityProvider._testMobile();

  /// Flips online/offline at runtime and notifies listeners — for tests that
  /// exercise a connectivity transition (e.g. offline → online recovery).
  @visibleForTesting
  void setOnlineForTest(bool online) {
    _isOnline = online;
    _results = online
        ? const [ConnectivityResult.wifi]
        : const [ConnectivityResult.none];
    notifyListeners();
  }

  Future<void> _init() async {
    await _refresh();
    _sub =
        _connectivity.onConnectivityChanged.listen((_) => _scheduleRefresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleRefresh();
    }
  }

  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _refresh);
  }

  // Re-query the platform directly rather than trusting the results handed
  // to onConnectivityChanged: during a wifi-to-mobile handoff, the wifi
  // "lost" callback can arrive after the mobile "available" one, so the
  // stream's last event can be a transient `none` with nothing afterwards
  // to correct it — leaving the app stuck thinking it's offline.
  Future<void> _refresh() async {
    final results = await _connectivity.checkConnectivity();
    final nowOnline = _resultsOnline(results);
    if (nowOnline == _isOnline && listEquals(results, _results)) return;
    _results = results;
    _isOnline = nowOnline;
    notifyListeners();
  }

  static bool _resultsOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  @override
  void dispose() {
    _debounce?.cancel();
    _sub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
