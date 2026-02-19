// @dart=2.12.0

import 'package:flutter/material.dart';
import 'dart:developer' as developer;

class WelcomeScreen extends StatelessWidget {
  //const WelcomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      /*appBar: AppBar(
        title: Text('Welcome to Sharah Kitaab al-Tawheed'),
      ),*/
      body: MyStatelessWidget(),
    );
  }
}

// This is the stateless widget that the main application instantiates.
class MyStatelessWidget extends StatelessWidget {
  //const MyStatelessWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      //decoration: BoxDecoration(),
      child: Scaffold(
        body: Stack(
          //fit: StackFit.expand,
          //alignment: AlignmentDirectional.topCenter,
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                    image: AssetImage('assets/tawheed.png'), fit: BoxFit.cover),
              ),
            ),
            Container(
              color: Color.fromRGBO(255, 255, 255, 0.79),
            ),
            Container(
              //alignment: Alignment.topCenter,
              //color: Colors.white,
              //margin: EdgeInsets.only(top: 0),
              //alignment: Alignment.bottomCenter,
              child: Positioned(
                top: 70,
                left: 0,
                right: 0,
                child: Text(
                  'Sharah\n Kitab al-Tawheed \n شرح کتاب التوحید',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 45.0,
                      fontFamily: 'bold',
                      fontWeight: FontWeight.bold,
                      color: Colors.black.withOpacity(0.7)),
                ),
              ),
            ),
            Container(
              // alignment: Alignment.topCenter,
              //color: Colors.green,
              //alignment: Alignment.topRight,
              //top: 100,
              //right: 0,
              child: Center(
                child: Text(
                  'By Fadilat Shaikh Abdullah Nasir Rahmani Hafizahullah',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 18.0,
                      fontFamily: 'bold',
                      fontWeight: FontWeight.bold,
                      color: Colors.black.withOpacity(0.8)),
                ),
              ),
            ),
/*             Container(
              margin: EdgeInsets.only(bottom: 20.0),
              alignment: Alignment.bottomCenter,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      // background color
                      primary: Colors.limeAccent.shade700, // background
                      padding:
                          EdgeInsets.symmetric(horizontal: 70, vertical: 15),
                      elevation: 3,

                      textStyle: TextStyle(
                        //color: Colors.black87,
                        fontSize: 25,
                        //primaryColor: Colors.indigoAccent.shade700,
                      ),
                    ),
                    label: Text('READ NOW'),
                    onPressed: () {
                      Navigator.pushNamed(context, '/readkat');
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => HomeVideoScreen()),
                      );
                    },
                    icon: Icon(Icons.book),
                  ),
                ],
              ),
            ), */
            Container(
              margin: EdgeInsets.only(bottom: 20.0),
              alignment: Alignment.bottomCenter,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      // background color
                      foregroundColor: Colors.black,
                      backgroundColor: Colors.limeAccent.shade700, // text color
                      padding:
                          EdgeInsets.symmetric(horizontal: 70, vertical: 15),
                      elevation: 5,

                      textStyle: TextStyle(
                        //color: Colors.black.withOpacity(0.6),
                        fontSize: 25,
                        //primaryColor: Colors.indigoAccent.shade700,
                      ),
                    ),
                    label: Text('WATCH NOW'),
                    onPressed: () {
                      developer.log('WATCH NOW, go to video screen');
                      Navigator.pushNamed(context, '/videoscreen');
                    },
                    icon: Icon(Icons.video_collection),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
