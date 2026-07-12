import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myapp/app.dart';
import 'package:myapp/audio/audio_handler.dart';
import 'package:myapp/services/download_notification_service.dart';
import 'package:myapp/services/download_service.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Must be initialised before ProgressProvider.load() is called synchronously
  await PreferencesService.instance.init();
  // Must be initialised before DownloadsProvider.load() so localPath() is synchronous
  await DownloadService.init();
  await DownloadNotificationService.instance.init();

  // Explicit type parameter required — without it, type inference fails on iOS.
  final audioHandler = await AudioService.init<TawheedAudioHandler>(
    builder: () => TawheedAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.almarfa.tawheed.audio',
      androidNotificationChannelName: 'Sharah Kitab at-Tawheed',
      androidNotificationOngoing: true,
      androidShowNotificationBadge: true,
      notificationColor: AppColors.goldLightTheme,
    ),
  );

  runApp(MyApp(audioHandler: audioHandler));
}
