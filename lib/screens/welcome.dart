import 'package:flutter/material.dart';
import 'home_video_screen.dart';

class WelcomeScreen extends StatelessWidget {
  //const WelcomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      /*appBar: AppBar(
        title: Text('Welcome to Sharah Kitaab Al Tawheed'),
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
    return DecoratedBox(
      decoration: BoxDecoration(),
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
              margin: EdgeInsets.only(top: 0),
              alignment: Alignment.bottomCenter,
              child: Center(
                child: Text(
                  'Sharah Kitaab Al Tawheed \n شرح کتاب التوحید',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 50.0,
                      fontFamily: 'bold',
                      fontWeight: FontWeight.bold,
                      color: Colors.black.withOpacity(0.8)),
                ),
              ),
            ),
            Container(
              //alignment: Alignment.topCenter,
              margin: EdgeInsets.only(top: 275),
              //alignment: Alignment.topRight,
              //top: 100,
              //right: 0,
              child: Center(
                child: Text(
                  'By Fadilat Sheikh Abdullah Nasir Rahmani Hafizahullah',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 18.0,
                      fontFamily: 'bold',
                      fontWeight: FontWeight.bold,
                      color: Colors.black.withOpacity(0.6)),
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.only(bottom: 40.0),
              alignment: Alignment.bottomCenter,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      // background color
                      primary: Colors.indigoAccent.shade700, // background
                      padding:
                          EdgeInsets.symmetric(horizontal: 80, vertical: 10),

                      textStyle: TextStyle(
                        fontSize: 25,
                        //primaryColor: Colors.indigoAccent.shade700,
                      ),
                    ),
                    child: Text('START NOW'),
                    onPressed: () {
                      Navigator.pushNamed(context, '/videoscreen');
                      /*  Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => HomeVideoScreen()),
                      ); */
                    },
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
    /*return Center(
      child: Card(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            ClipOval(
              child: Image.asset(
                'assets/tawheed.png',
                fit: BoxFit.cover,
                width: 150,
                height: 150,
              ),
            ),
            const ListTile(
              leading: Icon(Icons.book_rounded),
              title: Text('What is Kitab At Tawheed?'),
              subtitle: Text(
                  'Kitab At-Tawheed which is one of the best books on the subject of Tawheed and ranks high in authenticity. In this book, all the relevant Verses have been discussed reasonably, rationally and sincerely; and the essence of the Qur’an and Sunnah is placed in a very simple and appealing manner. This is the reason that the upright persons, beyond group ism and prejudices, have been adopting the correct Islamic path – the path of the Qur’an and Sunnah – under the influence of the basic facts and proofs produced herein.'),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                /*TextButton(
                  child: const Text('START NOW'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => HomeVideoScreen()),
                    );
                  },
                ),*/
                const SizedBox(width: 50),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    // background color
                    primary: Colors.purple,
                    padding: EdgeInsets.symmetric(horizontal: 80, vertical: 10),
                    textStyle: TextStyle(fontSize: 15),
                  ),
                  child: Text('START NOW'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => HomeVideoScreen()),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );*/
  }
}
