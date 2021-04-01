import 'package:flutter/material.dart';
import 'package:myapp/models/channel_model.dart';
import 'package:myapp/models/video_model.dart';
import 'package:myapp/screens/video_screen.dart';
import 'package:myapp/services/api_service.dart';
import 'main_drawer.dart';
import 'package:firebase_database/firebase_database.dart';
import 'welcome.dart';

class HomeVideoScreen extends StatefulWidget {
  @override
  _HomeVideoScreenState createState() => _HomeVideoScreenState();
}

class _HomeVideoScreenState extends State<HomeVideoScreen> {
  Channel _channel;
  bool _isLoading = false;
  int totalVideosCount = 50;
  final APIServiceInstance = APIService.instance;

  @override
  void initState() {
    super.initState();
    _initChannel();
  }

  _initChannel() async {
    Channel channel = await APIServiceInstance.fetchChannel(
        channelId: 'UC6tt6jN-ufLKbrR51jFTTQw');
    setState(() {
      _channel = channel;
    });
  }

  _buildProfileInfo() {
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
            backgroundImage: NetworkImage(_channel.profilePictureUrl),
          ),
          SizedBox(width: 12.0),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  // "_channel.title"
                  "Sheikh Abdullah Nasir Rahmani Hafizahullah",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.clip,
                ),
                Text(
                  '${_channel.title}',
                  style: TextStyle(
                    color: Colors.brown,
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${_channel.subscriberCount} subscribers',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 0),
                Text(
                  "50 Videos",
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
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoScreen(
              id: video.id, allVideos: _channel.videos, index: index),
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
              image: NetworkImage(video.thumbnailUrl),
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
                    video.title,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14.0,
                      //backgroundColor: Colors.purple,
                    ),
                  ),
                ),
                SizedBox(height: 5),
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
                ),
              ],
            ))
          ],
        ),
      ),
    );
  }

  _loadMoreVideos() async {
    _isLoading = true;
    List<Video> moreVideos = await APIServiceInstance.fetchVideosFromPlaylist(
        playlistId: _channel.uploadPlaylistId);
    List<Video> allVideos = _channel.videos..addAll(moreVideos);
    setState(() {
      _channel.videos = allVideos;
    });
    _isLoading = false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () {
        APIServiceInstance.clearNextPageToken();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => WelcomeScreen()),
          (Route<dynamic> route) => false,
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Sharah Kitab Al-Tawheed'),
          //backgroundColor: Colors.blueAccent.shade400,
          elevation: 4,
          /*leading: IconButton(
          icon: Icon(Icons.menu),
          tooltip: 'Menu Icon',
          onPressed: () {},
        ), //IconButton*/
          brightness: Brightness.dark,
          /*actions: [
          IconButton(icon: Icon(Icons.account_box), onPressed: () => {})
        ],*/
        ),
        drawer: MainDrawer(),
        body: _channel != null
            ? NotificationListener<ScrollNotification>(
                onNotification: (ScrollNotification scrollDetails) {
                  if (!_isLoading &&
                      _channel.videos.length <= totalVideosCount &&
                      scrollDetails.metrics.pixels ==
                          scrollDetails.metrics.maxScrollExtent) {
                    DatabaseReference _testRef = FirebaseDatabase.instance
                        .reference()
                        .child("_loadMoreVideos");
                    _testRef.set("Loading more videos!");
                    _loadMoreVideos();
                    _showSnackBar('Loading videos...');
                  }
                  return false;
                },
                child: ListView.builder(
                  itemCount: 1 + _channel.videos.length,
                  itemBuilder: (BuildContext context, int index) {
                    if (index == 0) {
                      return _buildProfileInfo();
                    }
                    // Show only first 50 videos from the playlist https://www.youtube.com/watch?v=MVjeIojedRM&list=PLNA2F9JZ_49FjeYC-Xsl5suQEy4knwyOA&index=7
                    if (index <= 50) {
                      Video video = _channel.videos[index - 1];
                      return _buildVideo(video, index);
                    }
                  },
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

  void _showSnackBar(String message) {
    final snackBar = SnackBar(
      content: Text(
        message,
        //textAlign: TextAlign.center,
      ),
      duration: Duration(seconds: 1),
      //backgroundColor: Colors.indigoAccent.shade700,
      //behavior: SnackBarBehavior.floating,
      /* action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          // Some code to undo the change.
        },
      ), */
    );

    // Find the ScaffoldMessenger in the widget tree
    // and use it to show a SnackBar.
    ScaffoldMessenger.of(context).showSnackBar(snackBar);

/*     ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w300,
            fontSize: 16.0,
          ),
        ),
        backgroundColor: Colors.blueAccent,
        behavior: SnackBarBehavior.floating,
        elevation: 1.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50.0),
        ),
      ),
    ); */
  }
}
