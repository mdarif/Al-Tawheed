// @dart=2.9

import 'package:flutter/material.dart';
import 'main_drawer.dart';
import 'package:flutter/services.dart';

class ReadKat extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarBrightness: Brightness.light,
        ),
        iconTheme: IconThemeData(
          color: Colors.black, //change your color here
        ),
        title: Text('Sharah Kitaab al-Tawheed',
            style: TextStyle(
                fontSize: 20,
                fontStyle: FontStyle.normal,
                color: Colors.black87)),
        centerTitle: true,
        backgroundColor: Colors.limeAccent.shade700,
        elevation: 2,
        /*leading: IconButton(
          icon: Icon(Icons.menu),
          tooltip: 'Menu Icon',
          onPressed: () {},
        ), //IconButton*/
        // brightness: Brightness.light,
        /*actions: [
          IconButton(icon: Icon(Icons.account_box), onPressed: () => {})
        ],*/
      ),
      drawer: MainDrawer(),
      body: const Center(
        child: Text('PDF will come here'),
      ),
    );
  }
}

/* class ReadKat extends StatefulWidget {
  @override
  _ReadKatState createState() => _ReadKatState();
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("About Us"),
      ),
      body: Center(
        child: Card(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const ListTile(
                leading: Icon(Icons.contact_mail),
                title: Text('MUBA Dawah Club'),
                subtitle: Text('We do give dawah to our brothers around!'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadKatState extends State<ReadKat> {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
} */
