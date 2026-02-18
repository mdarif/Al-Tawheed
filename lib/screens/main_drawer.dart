// @dart=2.12.0

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io' show Platform;

class MainDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Custom Header with Al Marfa branding
          Container(
            decoration: BoxDecoration(
              color: Colors.limeAccent.shade700,
            ),
            padding: EdgeInsets.fromLTRB(20, 40, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 40,
                   backgroundImage: NetworkImage(
                      'https://scontent.fdel52-1.fna.fbcdn.net/v/t39.30808-6/460928293_927260439420580_1308407852678437045_n.jpg?_nc_cat=105&ccb=1-7&_nc_sid=6ee11a&_nc_ohc=vkhCj3vNhn8Q7kNvwHZycKZ&_nc_oc=Adnn6xMaVOa1Cas1kIvNVrelLrjaD4ukVGZYY5foK-kdm7Ls_a32gAF6tZUhdhpkVVg&_nc_zt=23&_nc_ht=scontent.fdel52-1.fna&_nc_gid=uqZswuj5cT3fxQz1YTjm8Q&oh=00_Aft6vzGBXC01Gv5ikU9crD7a5CKt3eDEyaufz9GfwcY2vg&oe=69990327',
                    ),
                ),
                SizedBox(height: 16),
                Text(
                  'AL MARFA DUROOS',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 18.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'MANHAJ E SALAF: A RETURN TO THE SUNNAH',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 12.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          // Menu Items
          _buildDrawerItem(
            icon: Icons.mail_outline,
            title: 'Contact Us',
            onTap: () {
              Navigator.pop(context);
              _showContactDialog(context);
            },
          ),
          if (Platform.isAndroid)
            _buildDrawerItem(
              icon: Icons.star_outline,
              title: 'Rate App',
              onTap: () {
                Navigator.pop(context);
                _launchURL(
                  'https://play.google.com/store/apps/details?id=com.almarfa.tawheed',
                );
              },
            ),
          _buildDrawerItem(
            icon: Icons.share_outlined,
            title: 'Share App',
            onTap: () {
              Navigator.pop(context);
              _showShareOptions(context);
            },
          ),
          Divider(indent: 16, endIndent: 16, thickness: 1),
          // YouTube Channel Card
          _buildYouTubeChannelCard(context),
          SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Powered by Al Marfa Software Inc.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.black54),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  void _showContactDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctxt) => AlertDialog(
        title: Text(
          'Al Marfa Software Inc.',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text(
                'If you have any feedback or suggestions, please write back to us.',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: Text('EMAIL US'),
            onPressed: () {
              Navigator.pop(ctxt);
              launchEmailSubmission();
            },
          ),
          TextButton(
            child: Text('CANCEL'),
            onPressed: () {
              Navigator.pop(ctxt);
            },
          ),
        ],
      ),
    );
  }
}

Widget _buildYouTubeChannelCard(BuildContext context) {
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _launchURL('https://www.youtube.com/channel/UCCCp4iPyMgqduVahr2gmLVw');
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade600, Colors.red.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.3),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.play_circle_filled, color: Colors.white, size: 32),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Al Marfa Duroos',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Subscribe to YouTube Channel',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white),
          ],
        ),
      ),
    ),
  );
}

_launchURL(String url) async {
  if (await canLaunch(url)) {
    await launch(url);
  } else {
    throw 'Could not launch $url';
  }
}

Future<void> launchEmailSubmission() async {
  final Uri emailUri = Uri(
    scheme: 'mailto',
    path: 'arif.mohammed@gmail.com',
    queryParameters: {
      'subject': 'Contact Al Marfa Software Inc.',
    },
  );

  try {
    await launchUrl(
      emailUri,
      mode: LaunchMode.externalApplication,
    );
  } catch (e) {
    print('Could not launch $emailUri');
  }
}

void _showShareOptions(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (context) => Container(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Share via',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildShareButton(
                context,
                icon: Icons.messenger,
                label: 'WhatsApp',
                onTap: () {
                  Navigator.pop(context);
                  _shareViaWhatsApp();
                },
              ),
              _buildShareButton(
                context,
                icon: Icons.more_horiz,
                label: 'More',
                onTap: () {
                  Navigator.pop(context);
                  _share();
                },
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _buildShareButton(BuildContext context,
    {required IconData icon,
    required String label,
    required VoidCallback onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.limeAccent.shade700,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Icon(icon, size: 30, color: Colors.black),
        ),
        SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

void _shareViaWhatsApp() async {
  final String message =
      'The *Sharah Kitab Al-Tawheed* Mobile Application consolidates YouTube lectures of *Fadilat Sheikh Abdullah Nasir Rahmani Hafizahullah*.\n\nDownload from Google Play Store: https://play.google.com/store/apps/details?id=com.almarfa.tawheed\n\n *YouTube Channel*: https://www.youtube.com/channel/UCCCp4iPyMgqduVahr2gmLVw';
  final String encodedMessage = Uri.encodeComponent(message);
  final String whatsappUrl = 'https://wa.me/?text=$encodedMessage';
  if (await canLaunch(whatsappUrl)) {
    await launch(whatsappUrl);
  } else {
    // Fallback to generic share if WhatsApp not installed
    Share.share(message);
  }
}

void _share() {
  Share.share(
      'The *Sharah Kitab Al-Tawheed* Mobile Application consolidates YouTube lectures of *Fadilat Sheikh Abdullah Nasir Rahmani Hafizahullah*.\n\nDownload from Google Play Store: https://play.google.com/store/apps/details?id=com.almarfa.tawheed\n\n *YouTube Channel*: https://www.youtube.com/channel/UCCCp4iPyMgqduVahr2gmLVw',
      subject: 'Like & share Sharah Kitab At-Tawheed!');
}
