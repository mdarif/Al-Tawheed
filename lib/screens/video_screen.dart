import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:flutter/services.dart';
import 'package:share/share.dart';

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
          if (_index <= 49) {
            var playNextVideo = widget.allVideos[_index];
            _controller.load(playNextVideo.id);
            this.setState(() {
              _index++;
            });
          } else {
            _showEndDialog();
          }
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

  void _showEndDialog() {
    showDialog(
        context: context,
        builder: (ctxt) => new AlertDialog(
              title: Text(
                  'Congratulations, Alhamdulillah you have completed the Sharah Kitaab At-Tawheed',
                  style: TextStyle(fontSize: 20)),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Text(
                        'Please do not forget us in your prayers and duas \n Jazāk Allāhu Khayran‎'),
                    //Text('+91-8595836869'),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('SHARE'),
                  /* style:
                            TextButton.styleFrom(primary: Colors.purple), */
                  onPressed: () {
                    _share();
                    //launchEmailSubmission();
                  },
                ),
                TextButton(
                  child: Text('EXIT'),
                  /* style:
                            TextButton.styleFrom(primary: Colors.purple), */
                  onPressed: () {
                    SystemChannels.platform.invokeMethod('SystemNavigator.pop');
                    //launchEmailSubmission();
                  },
                ),
              ],
            ));
  }

  void _share() {
    Share.share(
        'Check out Sharah Kitaab at-Tawheed on Google Play store at https://almarfa.in',
        subject: 'Like & share Sharah Kitaab At-Tawheed!');
  }
}
