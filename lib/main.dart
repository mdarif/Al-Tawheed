import 'package:flutter/material.dart';
import 'package:myapp/screens/home_video_screen.dart';
import 'package:myapp/screens/welcome.dart';
import 'package:myapp/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sharah Kitab al-Tawheed',
      initialRoute: '/',
      routes: {
        '/': (context) => WelcomeScreen(),
        '/videoscreen': (context) => const HomeVideoScreen(),
      },
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
    );
  }
}
