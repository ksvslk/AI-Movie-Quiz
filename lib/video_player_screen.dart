// video_player_screen.dart
import 'package:flutter/material.dart';
import 'level_video_player.dart'; // We use our reusable video player widget

class VideoPlayerScreen extends StatelessWidget {
  final String videoPath;

  const VideoPlayerScreen({super.key, required this.videoPath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Level Preview'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: LevelVideoPlayer(videoPath: videoPath),
      ),
      backgroundColor: Colors.black,
    );
  }
}