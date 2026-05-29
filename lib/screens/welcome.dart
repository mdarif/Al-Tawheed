import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/tawheed.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(
            color: Color.fromRGBO(255, 255, 255, 0.79),
          ),
          Positioned(
            top: 70,
            left: 0,
            right: 0,
            child: Text(
              'Sharah\n Kitab al-Tawheed \n شرح کتاب التوحید',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 45.0,
                fontWeight: FontWeight.bold,
                color: Colors.black.withValues(alpha: 0.7),
              ),
            ),
          ),
          Center(
            child: Text(
              'By Fazilat Shaikh Abdullah Nasir Rahmani Hafizahullah',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
                color: Colors.black.withValues(alpha: 0.8),
              ),
            ),
          ),
          Container(
            margin: EdgeInsets.only(bottom: 20.0),
            alignment: Alignment.bottomCenter,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 70, vertical: 15),
                elevation: 5,
                textStyle: TextStyle(fontSize: 25),
              ),
              label: Text('WATCH NOW'),
              onPressed: () => Navigator.pushNamed(context, '/videoscreen'),
              icon: Icon(Icons.video_collection),
            ),
          ),
        ],
      ),
    );
  }
}
