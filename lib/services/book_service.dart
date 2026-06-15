import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:myapp/models/book_content.dart';
import 'package:myapp/models/series.dart';

/// Loads the bundled "Book" asset (the full Arabic text of Kitab at-Tawheed)
/// for series that have one (see [SeriesConfig.hasBook]).
///
/// Unlike [CatalogService], this is a bundled Flutter asset — no network
/// fetch, no caching: it ships with the app build and is read once.
class BookService {
  BookService._();
  static final BookService instance = BookService._();

  Future<BookContent> loadBook(SeriesConfig series) async {
    final raw =
        await rootBundle.loadString('assets/content/book_${series.id}.json');
    return BookContent.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
