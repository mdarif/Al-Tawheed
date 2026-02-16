import 'package:flutter/material.dart';
import 'package:myapp/models/channel_model.dart';
import 'package:myapp/models/video_model.dart';
import 'package:myapp/screens/video_screen.dart';
import 'package:myapp/services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
// ignore: import_of_legacy_library_into_null_safe
import 'main_drawer.dart';
// import 'package:firebase_database/firebase_database.dart';
// ignore: import_of_legacy_library_into_null_safe
import 'welcome.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as developer;

class HomeVideoScreen extends StatefulWidget {
  @override
  _HomeVideoScreenState createState() => _HomeVideoScreenState();
}

class _HomeVideoScreenState extends State<HomeVideoScreen> {
  Channel? _channel;
  Channel? _alMarfaChannel;
  // bool _isLoading = false;
  int totalVideosCount = 50;
  final apiServiceInstance = APIService.instance;

  @override
  void initState() {
    super.initState();
    _initChannel();
    _fetchAlMarfaDuroosChannel();
  }

  _initChannel() async {
    Channel channel = await apiServiceInstance.fetchChannel(
        channelId: 'UC6tt6jN-ufLKbrR51jFTTQw');
    setState(() {
      _channel = channel;
    });
  }

  _fetchAlMarfaDuroosChannel() async {
    Channel channel = await apiServiceInstance.fetchChannel(
        channelId: 'UCCCp4iPyMgqduVahr2gmLVw');
    setState(() {
      _alMarfaChannel = channel;
    });
  }

  _buildProfileInfo() {
    developer.log(
        '_buildProfileInfo: Build fetched YT Channel profile info pn top pf the screen');
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
            backgroundImage: NetworkImage(
                'https://scontent.fdel52-1.fna.fbcdn.net/v/t39.30808-6/460928293_927260439420580_1308407852678437045_n.jpg?_nc_cat=105&ccb=1-7&_nc_sid=6ee11a&_nc_ohc=vkhCj3vNhn8Q7kNvwHZycKZ&_nc_oc=Adnn6xMaVOa1Cas1kIvNVrelLrjaD4ukVGZYY5foK-kdm7Ls_a32gAF6tZUhdhpkVVg&_nc_zt=23&_nc_ht=scontent.fdel52-1.fna&_nc_gid=uqZswuj5cT3fxQz1YTjm8Q&oh=00_Aft6vzGBXC01Gv5ikU9crD7a5CKt3eDEyaufz9GfwcY2vg&oe=69990327'),
          ),
          SizedBox(width: 12.0),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _alMarfaChannel?.title ?? 'AL MARFA DUROOS',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${_alMarfaChannel?.subscriberCount ?? '8.7K'} subscribers',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 0),
                Text(
                  "${_alMarfaChannel?.videoCount ?? '241'} Videos",
                  style: TextStyle(
                    color: Colors.green[600],
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

  _buildVideo(Video video, int index) {
    developer.log(
        '_buildVideo: Build fetched VIDEOS rows on the main screen $index');
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
                //SizedBox(width: 10.0),
                Container(
                  padding: const EdgeInsets.only(left: 12, top: 5),
                  //flex: 1,
                  child: Text(
                    video.title!,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14.0,
                      //backgroundColor: Colors.purple,
                    ),
                  ),
                ),
/*                 SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.only(left: 12),
                  //flex: 1,
                  child: Text(
                    video.channelTitle,
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12.0,
                      //backgroundColor: Colors.red,
                    ),
                  ),
                ), */
              ],
            ))
          ],
        ),
      ),
    );
  }

/*   _loadMoreVideos() async {
    //_isLoading = true;

    List<Video> moreVideos = await apiServiceInstance.fetchVideosFromPlaylist(
        playlistId: _channel!.uploadPlaylistId);
    List<Video> allVideos = _channel!.videos!..addAll(moreVideos);
    setState(() {
      _channel!.videos = allVideos;
    });
    //_isLoading = false;
  } */

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        apiServiceInstance.clearNextPageToken();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => WelcomeScreen()),
          (Route<dynamic> route) => false,
        );
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarBrightness: Brightness.light,
          ),
          iconTheme: IconThemeData(
            color: Colors.black, //change your color here
          ),
          title: Text('Sharah Kitab al-Tawheed',
              style: TextStyle(
                  fontSize: 20,
                  fontStyle: FontStyle.normal,
                  color: Colors.black87)),
          centerTitle: true,
          backgroundColor: Colors.limeAccent.shade700,
          elevation: 2,
        ),
        drawer: MainDrawer(),
        body: _channel != null
            ? Container(
                child: Column(
                  children: [
                    _buildProfileInfo(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _channel!.videos!.length + 1,
                        itemBuilder: (BuildContext context, int index) {
                          // Show YouTube promotional banner as first item
                          if (index == 0) {
                            return _buildYouTubePromoBanner(context);
                          }
                          
                          final videoIndex = index - 1;
                          developer.log(
                              '_buildVideo: ListView.builder itemBuilder $videoIndex itemCount: ${_channel!.videos!.length}');
                          Video video = _channel!.videos![videoIndex];
                          return _buildVideo(video, videoIndex);
                        },
                      ),
                    )
                  ],
                ),
              )
            : Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor, // Red
                  ),
                ),
              ),
      ),
    );
  }

/*   void _showSnackBar(String message) {
    developer.log('_showSnackBar');
    final snackBar = SnackBar(
      content: Text(
        message,
        //textAlign: TextAlign.center,
      ),
      duration: Duration(seconds: 1),
    );

    // Find the ScaffoldMessenger in the widget tree
    // and use it to show a SnackBar.
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  } */

  _buildYouTubePromoBanner(BuildContext context) {
    final subscriberCount = _alMarfaChannel?.subscriberCount ?? '8.7K';
    
    return GestureDetector(
      onTap: () async {
        const String youtubeUrl =
            'https://www.youtube.com/channel/UCCCp4iPyMgqduVahr2gmLVw';
        if (await canLaunch(youtubeUrl)) {
          await launch(youtubeUrl);
        }
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        padding: EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade600, Colors.red.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.3),
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
              child: Icon(Icons.play_circle_filled, color: Colors.red, size: 28),
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
                    'Manhaj e Salaf: A Return to the Sunnah',
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
