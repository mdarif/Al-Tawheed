import 'package:myapp/models/catalog.dart';
import 'package:myapp/models/series.dart';

/// Website used when the remote app-config carries no `links.website`.
const String _fallbackWebsite = 'https://kitabattawheed.com';

/// Public website URL for [lecture], matching the slug scheme the marketing
/// site generates in **`Al-Tawheed-Web/src/lib/catalog.ts`**:
///
///   Urdu series   → `{base}/lectures/{chapterId}/part-NN/`
///   Arabic series → `{base}/arabic/dars-NN/`
///
/// where `NN` is the zero-padded [Lecture.number]. Both repos read the same
/// `catalog.json`, so `chapterId` + `number` reproduce the exact slug.
///
/// The digits are always ASCII (`padLeft`), never localized numerals — this is
/// a URL, so it must stay valid under every UI language. This mirroring is a
/// hidden cross-repo coupling: if the website changes its slug scheme, shared
/// links 404. See `docs/gotchas.md`.
String lectureWebUrl(
  Lecture lecture,
  SeriesConfig series, {
  String? websiteBase,
}) {
  final raw = (websiteBase == null || websiteBase.isEmpty)
      ? _fallbackWebsite
      : websiteBase;
  final base = raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  final nn = lecture.number.toString().padLeft(2, '0');

  // Arabic series lives under /arabic/dars-NN/; every other (Urdu) series uses
  // the chaptered /lectures/{chapterId}/part-NN/ path.
  if (series.language == 'ar') {
    return '$base/arabic/dars-$nn/';
  }
  return '$base/lectures/${lecture.chapterId}/part-$nn/';
}

/// The text handed to the OS share sheet for a lecture — the resolved [title]
/// followed by the web [url], mirroring the Book reader's share format.
String lectureShareText({required String title, required String url}) =>
    '$title\n\n$url';
