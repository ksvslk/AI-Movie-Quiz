// level_video_player.dart
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart'; // 1. Import Chewie

class LevelVideoPlayer extends StatefulWidget {
  final String videoPath;

  const LevelVideoPlayer({super.key, required this.videoPath});

  @override
  State<LevelVideoPlayer> createState() => _LevelVideoPlayerState();
}

class _LevelVideoPlayerState extends State<LevelVideoPlayer> {
  // We still need the base video player controller
  late VideoPlayerController _videoPlayerController;
  
  // 2. Add a controller for Chewie
  late ChewieController _chewieController;

  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      final ref = FirebaseStorage.instance.ref(widget.videoPath);
      final url = await ref.getDownloadURL();
      
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(url));
      await _videoPlayerController.initialize();
      
      // 3. Create the Chewie controller after the video controller is initialized
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: false,
        looping: true,
        allowFullScreen: false,
        allowPlaybackSpeedChanging: false,
        showOptions: false,
        showControls: true,
        showControlsOnInitialize: false,
        // You can add many other customizations here
        // aspectRatio: 16 / 9,
        // placeholder: const Center(child: CircularProgressIndicator()),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              'Error playing video: $errorMessage',
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error initializing video player: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  void dispose() {
    // 4. IMPORTANT: Dispose of BOTH controllers to free up resources.
    _videoPlayerController.dispose();
    _chewieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_hasError) {
      return const Center(child: Icon(Icons.error, color: Colors.red, size: 48));
    }
    
    // 5. Instead of the basic VideoPlayer, return the Chewie widget.
    return Chewie(
      controller: _chewieController,
    );
  }
}