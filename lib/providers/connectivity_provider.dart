import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityProvider extends ChangeNotifier {
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
  factory ConnectivityProvider.testOnline() =>
      ConnectivityProvider._test(true);

  @visibleForTesting
  factory ConnectivityProvider.testOffline() =>
      ConnectivityProvider._test(false);

  /// Online via mobile data — isOnline true, isWifi false.
  @visibleForTesting
  factory ConnectivityProvider.testOnlineMobile() =>
      ConnectivityProvider._testMobile();

  Future<void> _init() async {
    final results = await _connectivity.checkConnectivity();
    _results = results;
    _isOnline = _resultsOnline(results);
    _sub = _connectivity.onConnectivityChanged.listen(_onChanged);
  }

  void _onChanged(List<ConnectivityResult> results) {
    final nowOnline = _resultsOnline(results);
    final changed = nowOnline != _isOnline || !listEquals(results, _results);
    if (!changed) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _results = results;
      _isOnline = nowOnline;
      notifyListeners();
    });
  }

  static bool _resultsOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  @override
  void dispose() {
    _debounce?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
