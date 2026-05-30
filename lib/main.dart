import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/audio/audio_handler.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/screens/lecture_list_screen.dart';
import 'package:myapp/screens/welcome.dart';
import 'package:myapp/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Explicit type parameter required — without it, type inference fails on iOS
  // and AudioService.init returns null instead of TawheedAudioHandler.
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

class MyApp extends StatelessWidget {
  final TawheedAudioHandler audioHandler;
  const MyApp({super.key, required this.audioHandler});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CatalogProvider()),
        ChangeNotifierProvider(
          create: (_) => PlayerNotifier(audioHandler),
        ),
      ],
      child: MaterialApp(
        title: 'Sharah Kitab al-Tawheed',
        initialRoute: '/',
        routes: {
          '/': (context) => WelcomeScreen(),
          '/lectures': (context) => const LectureListScreen(),
        },
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
      ),
    );
  }
}
