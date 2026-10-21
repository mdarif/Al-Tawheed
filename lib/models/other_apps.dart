import 'package:myapp/l10n/app_localizations.dart';

/// One of Al Marfa Technologies' other Android apps, as listed on Google Play.
///
/// Hard-coded (like Al Quran Reader's `kOtherApps`): the list is tiny and only
/// ever changes with an app release. [name] is a brand name and is never
/// translated; the [tagline] is, via the ARB files.
class OtherApp {
  const OtherApp({
    required this.name,
    required this.packageId,
    required this.iconAsset,
    required this.tagline,
  });

  /// Brand name, shown verbatim in every UI language.
  final String name;

  /// The Google Play package id (`applicationId`) of the published app.
  final String packageId;

  /// A 128 px copy of the app's launcher icon, bundled (no network images).
  final String iconAsset;

  /// The Play listing's short description, localised.
  final String Function(AppLocalizations l10n) tagline;

  /// The app's Google Play listing. Always `https`, so it passes the
  /// `launchExternalUrl` allowlist.
  String get listingUrl =>
      'https://play.google.com/store/apps/details?id=$packageId';
}

/// This app's own Play package id — never listed under "Our other apps".
const kOwnPackageId = 'com.almarfa.tawheed';

/// Both ids verified live on Google Play. Do not use `com.almarfa.assunnah.ask`
/// (a different app) for As-Sunnah Search.
final List<OtherApp> kOtherApps = <OtherApp>[
  OtherApp(
    name: 'Al Quran Reader',
    packageId: 'com.almarfa.alquran',
    iconAsset: 'assets/brand/other_apps/alquran.png',
    tagline: (l10n) => l10n.otherAppQuranTagline,
  ),
  OtherApp(
    name: 'As-Sunnah Search',
    packageId: 'com.almarfa.assunnah',
    iconAsset: 'assets/brand/other_apps/assunnah.png',
    tagline: (l10n) => l10n.otherAppAssunnahTagline,
  ),
];

/// [kOtherApps] without [ownPackageId], so an app can never advertise itself.
List<OtherApp> otherAppsExcluding(String ownPackageId) => [
      for (final app in kOtherApps)
        if (app.packageId != ownPackageId) app,
    ];
