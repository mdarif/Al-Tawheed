import 'package:flutter/foundation.dart';

class ShellChromeProvider extends ChangeNotifier {
  bool _visible = true;

  bool get visible => _visible;

  void show() => setVisible(true);

  void hide() => setVisible(false);

  void setVisible(bool visible) {
    if (_visible == visible) return;
    _visible = visible;
    notifyListeners();
  }
}
