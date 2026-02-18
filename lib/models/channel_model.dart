import 'package:myapp/models/video_model.dart';

class Channel {

  final String? id;
  final String? title;
  final String? profilePictureUrl;
  final int? subscriberCount;
  final int? videoCount;

  final String? uploadPlaylistId;
  List<Video>? videos;

  Channel({
    this.id,
    this.title,
    this.profilePictureUrl,
    this.subscriberCount,
    this.videoCount,
    this.uploadPlaylistId,
    this.videos,
  });

  factory Channel.fromMap(Map<String, dynamic> map) {
    return Channel(
      id: map['id'],
      title: map['snippet']['title'],
      profilePictureUrl: map['snippet']['thumbnails']['default']['url'],
      subscriberCount: int.parse(map['statistics']['subscriberCount']),
      videoCount: int.parse(map['statistics']['videoCount']),
      uploadPlaylistId: map['contentDetails']['relatedPlaylists']['uploads'],
    );
  }

}