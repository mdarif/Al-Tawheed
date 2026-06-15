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

  test('loadBook parses the bundled asset', () async {
    final book = await BookService.instance.loadBook(_arabicSeries);

    expect(book.title, 'كتاب التوحيد');
    expect(book.author, isNotEmpty);
    expect(book.chapters, hasLength(68));
    expect(book.chapters.first.id, 'intro');
    expect(book.chapters.first.number, 0);
    expect(book.chapters.last.id, 'ch-67');
    expect(book.chapters.last.number, 67);
    for (final chapter in book.chapters) {
      expect(chapter.title, isNotEmpty);
      expect(chapter.text, isNotEmpty);
    }
  });
}
