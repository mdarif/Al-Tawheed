import 'package:flutter/material.dart';
import 'about_us.dart';
import 'contact_us.dart';

class MainDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final drawerHeader = UserAccountsDrawerHeader(
      accountName: Text(
        "Mohammad Arif",
      ),
      accountEmail: Text(
        "arif.mohammed@gmail.com",
      ),
      currentAccountPicture: const CircleAvatar(
        child: FlutterLogo(size: 42.0),
      ),
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
              "About Us",
            ),
            leading: const Icon(Icons.monitor),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: Text(
              "Contact Us",
            ),
            leading: const Icon(Icons.favorite),
            onTap: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
