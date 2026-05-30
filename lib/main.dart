import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:myapp/app.dart';
import 'package:myapp/audio/audio_handler.dart';
import 'package:myapp/services/preferences_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Must be initialised before ProgressProvider.load() is called synchronously
  await PreferencesService.instance.init();

  // Explicit type parameter required — without it, type inference fails on iOS.
  final audioHandler = await AudioService.init<TawheedAudioHandler>(
    builder: () => TawheedAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.almarfa.tawheed.audio',
      androidNotificationChannelName: 'Sharah Kitab al-Tawheed',
      androidNotificationOngoing: true,
      androidShowNotificationBadge: true,
      notificationColor: Color(0xFFC9A84C),
    ),
  );

  runApp(MyApp(audioHandler: audioHandler));
}
