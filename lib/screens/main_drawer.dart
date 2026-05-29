import 'package:flutter/material.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io' show Platform;

class MainDrawer extends StatelessWidget {
  static const String _shareMessage =
      'The *Sharah Kitab Al-Tawheed* Mobile Application consolidates YouTube lectures of'
      ' *Fazilat Sheikh Abdullah Nasir Rahmani Hafizahullah*.'
      '\n\nDownload from Google Play Store: https://play.google.com/store/apps/details?id=com.almarfa.tawheed'
      '\n\n *YouTube Channel*: https://www.youtube.com/channel/UCCCp4iPyMgqduVahr2gmLVw';

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            decoration: BoxDecoration(color: AppColors.primary),
            padding: EdgeInsets.fromLTRB(20, 60, 30, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage:
                      const AssetImage('assets/images/am_duroos_logo.png'),
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
                  'MANHAJ E SALAF: LEARN ISLAM AS UNDERSTOOD BY THE SALAF',
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
                    'https://play.google.com/store/apps/details?id=com.almarfa.tawheed');
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
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: GestureDetector(
              onTap: () => _launchURL('https://www.almarfa.co'),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.language, size: 14, color: Colors.grey[500]),
                    SizedBox(width: 6),
                    Text(
                      'Powered by ',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                    Text(
                      'Al Marfa Technologies',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.open_in_new, size: 11, color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 8),
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
              _launchEmail();
            },
          ),
          TextButton(
            child: Text('CANCEL'),
            onPressed: () => Navigator.pop(ctxt),
          ),
        ],
      ),
    );
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

  Widget _buildShareButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(icon, size: 30, color: Colors.black),
          ),
          SizedBox(height: 8),
          Text(label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    await launchUrl(Uri.parse(url));
  }

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'arif.mohammed@gmail.com',
      queryParameters: {'subject': 'Contact Al Marfa Software Inc.'},
    );
    await launchUrl(emailUri, mode: LaunchMode.externalApplication);
  }

  Future<void> _shareViaWhatsApp() async {
    final String encodedMessage = Uri.encodeComponent(_shareMessage);
    final launched =
        await launchUrl(Uri.parse('https://wa.me/?text=$encodedMessage'));
    if (!launched) {
      await SharePlus.instance.share(ShareParams(
          text: _shareMessage,
          subject: 'Like & Share Sharah Kitab At-Tawheed!'));
    }
  }

  void _share() {
    SharePlus.instance.share(ShareParams(
      text: _shareMessage,
      subject: 'Like & Share Sharah Kitab At-Tawheed!',
    ));
  }
}
