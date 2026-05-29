import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';


class VideoScreen extends StatefulWidget {
  final String? id;
  final List? allVideos;
  final int? index;

  VideoScreen({this.id, this.allVideos, this.index});

  @override
  _VideoScreenState createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  late YoutubePlayerController _controller;
  int? _index;

  @override
  void initState() {
    super.initState();
    _index = widget.index;
    _controller = YoutubePlayerController(
      initialVideoId: widget.id!,
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
        onReady: () {},
        onEnded: (data) {
          final lastIndex = widget.allVideos!.length - 1;
          if (_index! < lastIndex) {
            setState(() => _index = _index! + 1);
            _controller.load(widget.allVideos![_index!].id);
          } else {
            _showEndDialog();
          }
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
        builder: (ctxt) => AlertDialog(
              title: Text(
                  'Congratulations, Alhamd-o-lillah you have completed the Sharah Kitaab At-Tawheed',
                  style: TextStyle(fontSize: 20)),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Text(
                        'Please do not forget us in your prayers and duas \n\nJazāk Allāhu Khayran‎'),
                    //Text('+91-8595836869'),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('SHARE'),
                  onPressed: _share,
                ),
                TextButton(
                  child: Text('EXIT'),
                  onPressed: () {
                    SystemChannels.platform.invokeMethod('SystemNavigator.pop');
                  },
                ),
              ],
            ));
  }

  void _share() {
    SharePlus.instance.share(ShareParams(
      text:
          'The *Sharah Kitab Al-Tawheed* Mobile Application consolidates YouTube lectures of *Fazilat Sheikh Abdullah Nasir Rahmani Hafizahullah*.\n\nDownload it from: https://almarfa.in/kitab-at-tawheed/',
      subject: 'Like & Share Sharah Kitab At-Tawheed!',
    ));
  }
}
