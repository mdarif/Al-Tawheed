// @dart=2.12.0

import 'package:flutter/material.dart';
import 'package:myapp/screens/home_video_screen.dart';
import 'package:myapp/screens/video_screen.dart';
import 'package:myapp/screens/welcome.dart';
import 'package:myapp/screens/readkat_screen.dart';
import 'package:firebase_core/firebase_core.dart';

//void main() => runApp(MyApp());
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final Future<FirebaseApp> _fbApp = Firebase.initializeApp();
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sharah Kitab al-Tawheed',
      // on the FirstScreen widget.
      initialRoute: '/',
      routes: {
        // When navigating to the "/" route, build the FirstScreen widget.
        '/': (context) => WelcomeScreen(),
        // When navigating to the "/second" route, build the SecondScreen widget.
        '/videoscreen': (context) => HomeVideoScreen(),
        '/video': (context) => VideoScreen(),
        '/readkat': (context) => ReadKat()
      },
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Define the default brightness and colors.
        brightness: Brightness.light,
        primaryColor: Colors.limeAccent.shade700,
        //accentColor: Colors.cyan[600],

        // Define the default font family.
        fontFamily: 'Nexa',

        // Define the default TextTheme. Use this to specify the default
        // text styling for headlines, titles, bodies of text, and more.
        textTheme: TextTheme(
          displayLarge: TextStyle(fontSize: 72.0, fontWeight: FontWeight.bold),
          titleLarge: TextStyle(fontSize: 36.0, fontStyle: FontStyle.italic),
          bodyMedium: TextStyle(fontSize: 14.0, fontFamily: 'Hind'),
        ),
      ),
      /* home: FutureBuilder(
          future: _fbApp,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              print('You have an error! ${snapshot.error.toString()} ');
              return Text('Something went wrong');
            } else if (snapshot.hasData) {
              return WelcomeScreen();
            } else {
              return Center(
                child: CircularProgressIndicator(),
              );
            }
          },
        ) */
      //HomeScreen(),
    );
  }
}
