import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/services/book_service.dart';

const _arabicSeries = SeriesConfig(
  id: 'tawheed-ar',
  catalogUrl: 'https://example.com/tawheed-ar/catalog.json',
  storagePrefix: 'ar_',
  hasStudyMode: false,
  hasBook: true,
  language: 'ar',
  displayName: {'en': 'Kitab at-Tawheed (Arabic)'},
  speakerName: {'en': 'Shaikh Salih al-Fawzan Hafizhahullah'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // What each asset must *contain* is pinned in book_content_integrity_test —
  // these cover only the service's own job: resolving `series.id` to the right
  // asset and parsing it.
  test('loadBook resolves and parses the Arabic series asset', () async {
    final book = await BookService.instance.loadBook(_arabicSeries);

    expect(book.title, 'كتاب التوحيد');
    expect(book.chapters, isNotEmpty);
  });

  test('loadBook resolves a different asset for the Urdu series', () async {
    final arabic = await BookService.instance.loadBook(_arabicSeries);
    final urdu =
        await BookService.instance.loadBook(SeriesConfig.legacyUrduFallback);

    expect(urdu.chapters, isNotEmpty);
    // The Urdu asset was once a placeholder copy of the Arabic matn. It has
    // been the real Urdu translation since bb33dc3 — assert they are actually
    // different books, so a botched build that ships the wrong asset (or
    // re-introduces the placeholder) fails here rather than in front of a
    // reader.
    expect(urdu.chapters.first.text, isNot(arabic.chapters.first.text));
  });
}
