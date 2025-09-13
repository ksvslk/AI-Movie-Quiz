// level_video_player.dart
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class LevelVideoPlayer extends StatefulWidget {
  final String videoPath;

  const LevelVideoPlayer({super.key, required this.videoPath});

  @override
  State<LevelVideoPlayer> createState() => _LevelVideoPlayerState();
}

class _LevelVideoPlayerState extends State<LevelVideoPlayer> {
  late VideoPlayerController _videoPlayerController;
  late ChewieController _chewieController;

  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  // --- THE FIRST FIX IS HERE ---
  // This method is called when the widget is rebuilt with a new videoPath.
  @override
  void didUpdateWidget(covariant LevelVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the videoPath has changed, we need to dispose of the old controllers
    // and initialize new ones.
    if (widget.videoPath != oldWidget.videoPath) {
      _videoPlayerController.dispose();
      _chewieController.dispose();
      _initializePlayer();
    }
  }

  Future<void> _initializePlayer() async {
    // --- THE SECOND FIX IS HERE ---
    // We must reset the loading state at the beginning of initialization.
    // This ensures the loading spinner shows when switching between levels.
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final ref = FirebaseStorage.instance.ref(widget.videoPath);
      final url = await ref.getDownloadURL();
      
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(url));
      await _videoPlayerController.initialize();
      
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: false,
        looping: true,
        allowFullScreen: false,
        allowPlaybackSpeedChanging: false,
        showOptions: false,
        showControls: true,
        showControlsOnInitialize: false,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              'Error playing video: $errorMessage',
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error initializing video player: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    // This correctly disposes of the final set of controllers when the
    // widget is removed from the screen permanently.
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
    
    return Chewie(
      controller: _chewieController,
    );
  }
}