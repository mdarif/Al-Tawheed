import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/screens/lecture_list_screen.dart';
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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CatalogProvider()),
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
