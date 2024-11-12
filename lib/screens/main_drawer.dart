// @dart=2.12.0

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io' show Platform;

class MainDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final drawerHeader = UserAccountsDrawerHeader(
      decoration: BoxDecoration(
        color: Colors.limeAccent.shade700,
      ),
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
        _launchURL('https://almarfa.in');
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
              ),
          if (Platform.isAndroid)
            ListTile(
              title: Text(
                "Rate App",
              ),
              leading: const Icon(Icons.star),
              onTap: () {
                _launchURL(
                    'https://play.google.com/store/apps/details?id=com.almarfa.tawheed');
              },
            ),
          ListTile(
            title: Text(
              "Share App",
            ),
            leading: const Icon(Icons.share),
            onTap: () {
              _share();
            },
          ),
        ],
      ),
    );
  }
}

_launchURL(String url) async {
  if (await canLaunch(url)) {
    await launch(url);
  } else {
    throw 'Could not launch $url';
  }
}

void launchEmailSubmission() async {
  final Uri params =
      Uri(scheme: 'mailto', path: 'arif.mohammed@gmail.com', queryParameters: {
    'subject': 'Contact Al Marfa Software Inc.',
  });

  String url = params.toString();
  if (await canLaunch(url)) {
    await launch(url);
  } else {
    print('Could not launch $url');
  }
}

void _share() {
  Share.share(
      'The *Sharah Kitab Al-Tawheed* Mobile Application consolidates YouTube lectures of *Fadilat Sheikh Abdullah Nasir Rahmani Hafizahullah*.\n\nDownload it from: https://almarfa.in/kitab-at-tawheed/',
      subject: 'Like & share Sharah Kitab At-Tawheed!');
}
