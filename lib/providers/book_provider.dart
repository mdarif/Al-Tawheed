import 'package:flutter/foundation.dart';
import 'package:myapp/models/book_content.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/services/book_service.dart';

enum BookStatus { idle, loading, loaded, error }

/// Holds the bundled "Book" content (the full Arabic text of Kitab
/// at-Tawheed) for the current series.
///
/// [load] is a no-op for series without a book ([SeriesConfig.hasBook]),
/// so series without a `assets/content/book_<id>.json` asset (e.g. the Urdu
/// series) never touch [BookService].
class BookProvider extends ChangeNotifier {
  BookStatus _status = BookStatus.idle;
  BookContent? _book;
  String? _error;

  BookStatus get status => _status;
  BookContent? get book => _book;
  String? get error => _error;

  Future<void> load(SeriesConfig series) async {
    if (!series.hasBook) return;
    if (_status == BookStatus.loading || _status == BookStatus.loaded) return;
    _status = BookStatus.loading;
    _error = null;
    notifyListeners();

    try {
      _book = await BookService.instance.loadBook(series);
      _status = BookStatus.loaded;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _status = BookStatus.error;
    }
    notifyListeners();
  }

  /// Injects book content without loading the asset — for tests only.
  @visibleForTesting
  void setBookForTest(BookContent book) {
    _book = book;
    _status = BookStatus.loaded;
    _error = null;
    notifyListeners();
  }

  /// Simulates a failed load — for tests only.
  @visibleForTesting
  void setErrorForTest(Object error) {
    _error = error.toString();
    _status = BookStatus.error;
    notifyListeners();
  }
}
