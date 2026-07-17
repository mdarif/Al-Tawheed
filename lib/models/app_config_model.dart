import 'package:myapp/app_config.dart';
import 'package:myapp/models/i18n_field.dart';

class AppConfigLinks {
  final String? playStore;
  final String? appStore;
  final String? website;
  final String? youtube;

  const AppConfigLinks({
    this.playStore,
    this.appStore,
    this.website,
    this.youtube,
  });

  factory AppConfigLinks.fromJson(Map<String, dynamic> j) => AppConfigLinks(
        playStore: j['playStore'] as String?,
        appStore: j['appStore'] as String?,
        website: j['website'] as String?,
        youtube: j['youtube'] as String?,
      );
}

class AppConfigContact {
  final String email;
  final String subject;

  const AppConfigContact({required this.email, required this.subject});

  factory AppConfigContact.fromJson(Map<String, dynamic> j) => AppConfigContact(
        email: j['email'] as String? ?? '',
        subject: j['subject'] as String? ?? '',
      );
}

class AppConfigShare {
  final String message;

  const AppConfigShare({required this.message});

  factory AppConfigShare.fromJson(Map<String, dynamic> j) =>
      AppConfigShare(message: j['message'] as String? ?? '');
}

class AppConfigBranding {
  /// Multilingual (`{en, ar, ur, roman}`) — resolve via
  /// [LanguageProvider.resolve]. Branding is chrome, so it follows the app
  /// language rather than the content edition.
  final Map<String, dynamic> appBrand;
  final String appBrandUrl;
  final String publisher;
  final String publisherUrl;

  /// Multilingual — see [appBrand].
  final Map<String, dynamic> poweredByLabel;

  const AppConfigBranding({
    required this.appBrand,
    required this.appBrandUrl,
    required this.publisher,
    required this.publisherUrl,
    required this.poweredByLabel,
  });

  factory AppConfigBranding.fromJson(Map<String, dynamic> j) =>
      AppConfigBranding(
        appBrand: _localizable(j['appBrand'], defaults.appBrand),
        appBrandUrl: j['appBrandUrl'] as String? ?? defaults.appBrandUrl,
        publisher: j['publisher'] as String? ?? defaults.publisher,
        publisherUrl: j['publisherUrl'] as String? ?? defaults.publisherUrl,
        poweredByLabel:
            _localizable(j['poweredByLabel'], defaults.poweredByLabel),
      );

  /// Reads a branding label that may be a plain String (what every published
  /// app_config.json still sends) or an i18n map.
  ///
  /// Merged **over** the bundled default rather than replacing it, so a remote
  /// config sending only the legacy English string still picks up any bundled
  /// translations — wording can then ship from the content repo alone, with no
  /// app release, which is the whole point of keeping branding in Layer 2
  /// (remote JSON) rather than the ARBs.
  ///
  /// Blank entries are dropped before merging. `toI18nMap` renders anything it
  /// can't read as `{'en': ''}`, which would otherwise merge *over* the default
  /// and blank the label — the one failure this fallback exists to prevent.
  static Map<String, dynamic> _localizable(
    dynamic value,
    Map<String, dynamic> fallback,
  ) {
    if (value == null) return fallback;
    final overlay = toI18nMap(value)
      ..removeWhere((_, v) => v is! String || v.isEmpty);
    return overlay.isEmpty ? fallback : {...fallback, ...overlay};
  }

  // NOTE: these carry `en` only. "Al Marfa Duroos" and "Al Marfa Technologies"
  // are a real company's marks; their Arabic/Urdu wording is the owner's to
  // decide, not something to guess at here. Until they add one, `resolve`
  // falls back to `en` — the same text as today. Adding `ar`/`ur` keys to
  // app_config.json is a content deploy, not a release.
  static const AppConfigBranding defaults = AppConfigBranding(
    appBrand: {'en': 'Al Marfa Duroos'},
    appBrandUrl: 'https://www.youtube.com/@almarfaduroos',
    publisher: 'Al Marfa Technologies',
    publisherUrl: 'https://almarfa.co',
    poweredByLabel: {'en': 'Powered by Al Marfa Technologies'},
  );
}

class AppConfigAbout {
  final String appName;
  final String lecturer;
  final int lectureCount;
  final int classCount;
  final String totalDuration;

  const AppConfigAbout({
    required this.appName,
    required this.lecturer,
    required this.lectureCount,
    required this.classCount,
    required this.totalDuration,
  });

  factory AppConfigAbout.fromJson(Map<String, dynamic> j) => AppConfigAbout(
        appName: j['appName'] as String? ?? '',
        lecturer: j['lecturer'] as String? ?? '',
        lectureCount: j['lectureCount'] as int? ?? 0,
        classCount: j['classCount'] as int? ?? 0,
        totalDuration: j['totalDuration'] as String? ?? '',
      );
}

class AppConfigModel {
  final int version;
  final AppConfigLinks links;
  final AppConfigContact contact;
  final AppConfigShare share;
  final AppConfigAbout about;
  final AppConfigBranding branding;

  const AppConfigModel({
    required this.version,
    required this.links,
    required this.contact,
    required this.share,
    required this.about,
    required this.branding,
  });

  factory AppConfigModel.fromJson(Map<String, dynamic> j) => AppConfigModel(
        version: j['version'] as int? ?? 1,
        links:
            AppConfigLinks.fromJson(j['links'] as Map<String, dynamic>? ?? {}),
        contact: AppConfigContact.fromJson(
          j['contact'] as Map<String, dynamic>? ?? {},
        ),
        share:
            AppConfigShare.fromJson(j['share'] as Map<String, dynamic>? ?? {}),
        about:
            AppConfigAbout.fromJson(j['about'] as Map<String, dynamic>? ?? {}),
        branding: AppConfigBranding.fromJson(
          j['branding'] as Map<String, dynamic>? ?? {},
        ),
      );

  /// Safe fallback used when the remote fetch fails and no cache exists.
  static AppConfigModel get defaults => AppConfigModel(
        version: 1,
        links: const AppConfigLinks(
          playStore:
              'https://play.google.com/store/apps/details?id=com.almarfa.tawheed',
          website: 'https://kitabattawheed.com',
          youtube: 'https://www.youtube.com/@almarfaduroos',
        ),
        contact: const AppConfigContact(
          email: 'arif.mohammed@gmail.com',
          subject: '${AppConfig.appTitle} — Feedback',
        ),
        share: const AppConfigShare(
          // Multilingual (Urdu/Arabic-first audience) + the branded website
          // download page. Kept in sync with the remote app-config.json; the
          // remote copy wins once fetched.
          message: '*${AppConfig.appTitle}* — free audio lectures explaining '
              'Kitab at-Tawheed, now in Urdu & Arabic.\n\n'
              'اردو اور عربی میں کتاب التوحید کی مکمل تشریح — مفت آڈیو دروس سنیں اور ڈاؤن لوڈ کریں۔\n\n'
              'شرح كتاب التوحيد بالأردية والعربية — دروس صوتية مجانية، استمِع وحمِّل التطبيق.\n\n'
              'https://kitabattawheed.com/download/',
        ),
        about: const AppConfigAbout(
          appName: AppConfig.appTitle,
          lecturer: 'Shaikh Abdullah Nasir Rahmani Hafizahullah',
          lectureCount: 50,
          classCount: 15,
          totalDuration: '27h 7m',
        ),
        branding: AppConfigBranding.defaults,
      );
}
