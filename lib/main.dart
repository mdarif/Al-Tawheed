import 'package:flutter/material.dart';
import 'package:myapp/screens/home_video_screen.dart';
import 'package:myapp/screens/welcome.dart';
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
        title: 'Sharah Kitaab Al Tawheed',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: Colors.purple,
        ),
        home: FutureBuilder(
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
        )
        //HomeScreen(),
        );
  }
}
