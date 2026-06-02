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
}
