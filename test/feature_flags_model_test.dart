import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/feature_flags_model.dart';

void main() {
  test('language flag defaults to false when omitted', () {
    final flags = FeatureFlags.fromJson({'bookmarks': true});
    expect(flags.language, isFalse);
  });

  test('language flag parses from JSON', () {
    final flags = FeatureFlags.fromJson({'language': true});
    expect(flags.language, isTrue);
  });

  test('seriesSwitcher flag defaults to false when omitted', () {
    final flags = FeatureFlags.fromJson({'bookmarks': true});
    expect(flags.seriesSwitcher, isFalse);
  });

  test('seriesSwitcher flag parses from JSON', () {
    final flags = FeatureFlags.fromJson({'seriesSwitcher': true});
    expect(flags.seriesSwitcher, isTrue);
  });

  test('appLinks flag defaults to false when omitted', () {
    final flags = FeatureFlags.fromJson({'bookmarks': true});
    expect(flags.appLinks, isFalse);
  });

  test('appLinks flag parses from JSON', () {
    final flags = FeatureFlags.fromJson({'appLinks': true});
    expect(flags.appLinks, isTrue);
  });
}
