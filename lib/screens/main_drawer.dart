// @dart=2.9

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:developer' as developer;

class MainDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final drawerHeader = UserAccountsDrawerHeader(
      accountName: Text(
        "Powered by Al Marfa Software Inc.",
        style: TextStyle(
          color: Colors.black87,
          fontSize: 14.0,
          fontWeight: FontWeight.w600,
        ),
      ),
      accountEmail: Text("https://almarfa.in",
          style: TextStyle(
            color: Colors.black87,
            fontSize: 13.0,
            fontWeight: FontWeight.w400,
          )),
      currentAccountPicture: const CircleAvatar(
        radius: 55,
        backgroundColor: Color(0xffFDCF09),
        child: CircleAvatar(
          radius: 40,
          //backgroundImage: AssetImage('assets/am-logo-mobile-2.jpg'),
          backgroundImage: NetworkImage(
              'https://almarfa.in/wp-content/uploads/2022/03/am-logo-mobile-kat-2.jpg'),
        ),
      ),
      onDetailsPressed: () {
        print("_launchURL");
        developer.log('_launchURL');
        _launchURL();
      },
    );
    return Drawer(
      // Add a ListView to the drawer. This ensures the user can scroll
      // through the options in the drawer if there isn't enough vertical
      // space to fit everything.
      child: ListView(
        // Important: Remove any padding from the ListView.
        padding: EdgeInsets.zero,
        children: [
          drawerHeader,
          /*ListTile(
            title: Text(
              "About Us",
            ),
            leading: const Icon(Icons.monitor),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AboutUs()),
              );
            },
          ),*/
          ListTile(
              title: Text(
                "Contact Us",
              ),
              leading: const Icon(Icons.alternate_email),
              onTap: () {
                showDialog(
                    context: context,
                    builder: (ctxt) => new AlertDialog(
                          title: Text('Al Marfa Software Inc.',
                              style: TextStyle(fontSize: 20)),
                          content: SingleChildScrollView(
                            child: ListBody(
                              children: <Widget>[
                                Text(
                                    'If you have any feedback or suggestion(s) please write back to us.'),
                                //Text('+91-8595836869'),
                              ],
                            ),
                          ),
                          actions: <Widget>[
                            TextButton(
                              child: Text('EMAIL US'),
                              /* style:
                                  TextButton.styleFrom(primary: Colors.purple), */
                              onPressed: () {
                                launchEmailSubmission();
                              },
                            ),
                          ],
                        ));
              }
              /*onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ContactUs()),
              );
            },*/
              ),
        ],
      ),
    );
  }
}

_launchURL() async {
  developer.log('_launchURL()');
  const url = 'https://almarfa.in';
  if (await canLaunch(url)) {
    await launch(url);
  } else {
    throw 'Could not launch $url';
  }
}

void launchEmailSubmission() async {
  developer.log('launchEmailSubmission()');
  final Uri params =
      Uri(scheme: 'mailto', path: 'arif.mohammed@gmail.com', queryParameters: {
    'subject': 'Contact Al Marfa Software Inc.',
    //'body': 'Default body'
  });

  String url = params.toString();
  if (await canLaunch(url)) {
    await launch(url);
  } else {
    print('Could not launch $url');
  }
}
