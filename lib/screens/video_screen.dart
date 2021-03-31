import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:flutter/services.dart';

class VideoScreen extends StatefulWidget {
  final String id;
  final List allVideos;
  final int index;

  VideoScreen({this.id, this.allVideos, this.index});

  @override
  _VideoScreenState createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  YoutubePlayerController _controller;
  int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.index;
    _controller = YoutubePlayerController(
      initialVideoId: widget.id,
      flags: YoutubePlayerFlags(
        mute: false,
        autoPlay: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      onExitFullScreen: () {
        //SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      },
      player: YoutubePlayer(
        controller: _controller,
        onEnded: (data) {
          var playNextVideo = widget.allVideos[_index];
          _controller.load(playNextVideo.id);
          this.setState(() {
            _index++;
          });
          //_showSnackBar('Next Video Started!');
        },
      ),
      builder: (context, player) {
        return Column(
          children: <Widget>[
            player,
          ],
        );
      },
    );
  }

/*   void _showSnackBar(String message) {
    final snackBar = SnackBar(
      content: Text(message),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          // Some code to undo the change.
        },
      ),
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
  } */
}
