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
  final String appBrand;
  final String appBrandUrl;
  final String publisher;
  final String publisherUrl;
  final String poweredByLabel;

  const AppConfigBranding({
    required this.appBrand,
    required this.appBrandUrl,
    required this.publisher,
    required this.publisherUrl,
    required this.poweredByLabel,
  });

  factory AppConfigBranding.fromJson(Map<String, dynamic> j) =>
      AppConfigBranding(
        appBrand: j['appBrand'] as String? ?? 'Al Marfa Duroos',
        appBrandUrl: j['appBrandUrl'] as String? ??
            'https://www.youtube.com/@almarfaduroos',
        publisher: j['publisher'] as String? ?? 'Al Marfa Technologies',
        publisherUrl: j['publisherUrl'] as String? ?? 'https://almarfa.co',
        poweredByLabel: j['poweredByLabel'] as String? ??
            'Powered by Al Marfa Technologies',
      );

  static const AppConfigBranding defaults = AppConfigBranding(
    appBrand: 'Al Marfa Duroos',
    appBrandUrl: 'https://www.youtube.com/@almarfaduroos',
    publisher: 'Al Marfa Technologies',
    publisherUrl: 'https://almarfa.co',
    poweredByLabel: 'Powered by Al Marfa Technologies',
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
        classCount: j['classCount'] as int? ?? 15,
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
          subject: 'Sharah Kitab at-Tawheed — Feedback',
        ),
        share: const AppConfigShare(
          message: 'The *Sharah Kitab at-Tawheed* app — 50 audio lectures of '
              'Fazilat Shaikh Abdullah Nasir Rahmani Hafizahullah.\n\n'
              'https://kitabattawheed.com/download/',
        ),
        about: const AppConfigAbout(
          appName: 'Sharah Kitab at-Tawheed',
          lecturer: 'Shaikh Abdullah Nasir Rahmani Hafizahullah',
          lectureCount: 50,
          classCount: 15,
          totalDuration: '27h 7m',
        ),
        branding: AppConfigBranding.defaults,
      );
}
