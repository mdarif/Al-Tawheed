import 'package:flutter/material.dart';
import 'package:myapp/models/channel_model.dart';
import 'package:myapp/models/video_model.dart';
import 'package:myapp/screens/video_screen.dart';
import 'package:myapp/services/api_service.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main_drawer.dart';
import 'welcome.dart';
import 'package:intl/intl.dart';

class HomeVideoScreen extends StatefulWidget {
  @override
  _HomeVideoScreenState createState() => _HomeVideoScreenState();
}

class _HomeVideoScreenState extends State<HomeVideoScreen> {
  Channel? _channel;
  Channel? _alMarfaChannel;
  String? _error;
  final apiServiceInstance = APIService.instance;
  static const String tawheedPlaylistId = 'PLNA2F9JZ_49FGNiUHSVa9_8IzyeQnYX2Q';

  @override
  void initState() {
    super.initState();
    _initChannel();
    _fetchAlMarfaDuroosChannel();
  }

  String _formatCount(int? value) {
    if (value == null) return '';
    return NumberFormat.compact().format(value);
  }

  Future<void> _initChannel() async {
    try {
      Channel channel = await apiServiceInstance.fetchChannel(
          channelId: 'UC6tt6jN-ufLKbrR51jFTTQw');
      List<Video> videos = await apiServiceInstance.fetchVideosFromPlaylist(
          playlistId: tawheedPlaylistId);
      setState(() {
        channel.videos = videos;
        _channel = channel;
      });
    } catch (e) {
      setState(() => _error = 'Failed to load videos. Please check your connection.');
    }
  }

  Future<void> _fetchAlMarfaDuroosChannel() async {
    try {
      Channel channel = await apiServiceInstance.fetchChannel(
          channelId: 'UCCCp4iPyMgqduVahr2gmLVw');
      setState(() => _alMarfaChannel = channel);
    } catch (_) {
      // Non-critical — channel banner simply stays blank
    }
  }

  // Build the profile info section at the top of the screen
  Widget _buildProfileInfo() {
    return Container(
      margin: EdgeInsets.all(20.0),
      padding: EdgeInsets.all(20.0),
      height: 130.0,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            offset: Offset(0, 1),
            blurRadius: 6.0,
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            backgroundColor: Colors.white,
            radius: 45.0,
            backgroundImage:
                const AssetImage('assets/images/am_duroos_logo.png'),
          ),
          SizedBox(width: 12.0),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _alMarfaChannel?.title ?? 'Loading...',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${_formatCount(_alMarfaChannel?.subscriberCount)} subscribers',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 0),
                Text(
                  "${_formatCount(_alMarfaChannel?.videoCount)} Videos",
                  style: TextStyle(
                    color: AppColors.textGreen,
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  // Build each video item in the list
  Widget _buildVideo(Video video, int index) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoScreen(
              id: video.id, allVideos: _channel!.videos, index: index),
        ),
      ),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 20.0, vertical: 5.0),
        padding: EdgeInsets.all(5.0),
        height: 100.0,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              offset: Offset(0, 1),
              blurRadius: 2.0,
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Image(
              width: 130.0,
              image: NetworkImage(video.thumbnailUrl!),
            ),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.only(left: 12, top: 5),
                  child: Text(
                    video.title!,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14.0,
                    ),
                  ),
                ),
              ],
            ))
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        apiServiceInstance.clearNextPageToken(tawheedPlaylistId);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => WelcomeScreen()),
          (Route<dynamic> route) => false,
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sharah Kitab al-Tawheed'),
        ),
        drawer: MainDrawer(),
        body: _error != null
            ? Center(child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(_error!, textAlign: TextAlign.center),
              ))
            : _channel != null
                ? Column(
                    children: [
                      _buildProfileInfo(),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _channel!.videos!.length + 1,
                          itemBuilder: (BuildContext context, int index) {
                            if (index == 0) {
                              return _buildYouTubePromoBanner(context);
                            }
                            final videoIndex = index - 1;
                            return _buildVideo(_channel!.videos![videoIndex], videoIndex);
                          },
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
      ),
    );
  }

  // Build the YouTube promotional banner as the first item in the list
  Widget _buildYouTubePromoBanner(BuildContext context) {
    final subscriberCount = _formatCount(_alMarfaChannel?.subscriberCount);

    return GestureDetector(
      onTap: () async {
        await launchUrl(Uri.parse(
            'https://www.youtube.com/channel/UCCCp4iPyMgqduVahr2gmLVw'));
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        padding: EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.youtubeRed, AppColors.youtubeRedLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.youtubeRed.withValues(alpha: 0.3),
              offset: Offset(0, 4),
              blurRadius: 8.0,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  Icon(Icons.play_circle_filled, color: Colors.red, size: 28),
            ),
            SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AL MARFA DUROOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.0,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Join $subscriberCount subscribers',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11.0,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Manhaj e Salaf: Learn Islam as Understood by the Salaf',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}
