import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/book_content.dart';
import 'package:myapp/models/series.dart';
import 'package:myapp/providers/book_provider.dart';

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

  test('load is a no-op for a series without a book', () async {
    final provider = BookProvider();

    await provider.load(SeriesConfig.legacyUrduFallback);

    expect(provider.status, BookStatus.idle);
    expect(provider.book, isNull);
  });

  test('load fetches and parses the bundled asset', () async {
    final provider = BookProvider();

    await provider.load(_arabicSeries);

    expect(provider.status, BookStatus.loaded);
    expect(provider.book!.chapters, hasLength(68));
  });

  test('load is a no-op once already loaded', () async {
    final provider = BookProvider();

    await provider.load(_arabicSeries);
    final book = provider.book;
    await provider.load(_arabicSeries);

    expect(provider.status, BookStatus.loaded);
    expect(provider.book, same(book));
  });

  test('setBookForTest injects content without loading the asset', () {
    final provider = BookProvider();
    const book = BookContent(title: 'title', author: 'author', chapters: []);

    provider.setBookForTest(book);

    expect(provider.status, BookStatus.loaded);
    expect(provider.book, same(book));
  });

  test('setErrorForTest sets the error state', () {
    final provider = BookProvider();

    provider.setErrorForTest(Exception('boom'));

    expect(provider.status, BookStatus.error);
    expect(provider.error, contains('boom'));
  });
}
