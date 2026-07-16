import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/feature_flags_model.dart';

void main() {
  test('language flag defaults to true when omitted', () {
    final flags = FeatureFlags.fromJson({'bookmarks': true});
    expect(flags.language, isTrue);
  });

  test('language flag parses from JSON (can be turned off remotely)', () {
    final flags = FeatureFlags.fromJson({'language': false});
    expect(flags.language, isFalse);
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
