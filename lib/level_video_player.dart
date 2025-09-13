// level_video_player.dart
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:lottie/lottie.dart';

class LevelVideoPlayer extends StatefulWidget {
  final String videoPath;

  const LevelVideoPlayer({super.key, required this.videoPath});

  @override
  State<LevelVideoPlayer> createState() => _LevelVideoPlayerState();
}

class _LevelVideoPlayerState extends State<LevelVideoPlayer> with TickerProviderStateMixin {
  late VideoPlayerController _videoPlayerController;
  // MODIFICATION 1: Make the ChewieController nullable.
  ChewieController? _chewieController;

  int _initGeneration = 0;

  bool _isVideoInitialized = false;
  bool _isAnimationTimePassed = false;
  bool _hasError = false;

  static const _minAnimationDuration = Duration(seconds: 2);
  static const _transitionDuration = Duration(milliseconds: 500);

  late AnimationController _loadingOpacityController;
  late Animation<double> _loadingOpacityAnimation;
  late AnimationController _videoOpacityController;
  late Animation<double> _videoOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimationControllers();
    _initializePlayer();
    _startAnimationTimer();
  }

  void _initializeAnimationControllers() {
    _loadingOpacityController = AnimationController(vsync: this, duration: _transitionDuration);
    _loadingOpacityAnimation = CurvedAnimation(parent: _loadingOpacityController, curve: Curves.easeIn);
    _videoOpacityController = AnimationController(vsync: this, duration: _transitionDuration);
    _videoOpacityAnimation = CurvedAnimation(parent: _videoOpacityController, curve: Curves.easeIn);
    _loadingOpacityController.forward();
  }

  @override
  void didUpdateWidget(covariant LevelVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.videoPath != oldWidget.videoPath) {
      _initGeneration++;
      
      // MODIFICATION 2: Dispose and immediately nullify the controller.
      // The ?. operator handles the case where it might already be null.
      _videoPlayerController.dispose();
      _chewieController?.dispose();
      _chewieController = null;

      setState(() {
        _isVideoInitialized = false;
        _isAnimationTimePassed = false;
        _hasError = false;
      });

      _loadingOpacityController.forward(from: 0.0);
      _videoOpacityController.reverse(from: 1.0);

      _initializePlayer();
      _startAnimationTimer();
    }
  }

  Future<void> _initializePlayer() async {
    final int currentGeneration = _initGeneration;

    try {
      final ref = FirebaseStorage.instance.ref(widget.videoPath);
      final url = await ref.getDownloadURL();

      if (currentGeneration != _initGeneration || !mounted) {
        return;
      }

      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(url));
      await _videoPlayerController.initialize();

      if (currentGeneration != _initGeneration || !mounted) {
        _videoPlayerController.dispose();
        return;
      }

      // Assign the new controller instance here.
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
            child: Text('Error playing video: $errorMessage', style: const TextStyle(color: Colors.white)),
          );
        },
      );
      
      if (currentGeneration == _initGeneration && mounted) {
        setState(() {
          _isVideoInitialized = true;
          if (_isAnimationTimePassed) {
            _loadingOpacityController.reverse();
            _videoOpacityController.forward();
          }
        });
      }
    } catch (e) {
      print('Error initializing video player: $e');
      if (currentGeneration == _initGeneration && mounted) {
        setState(() {
          _hasError = true;
          _loadingOpacityController.reverse();
        });
      }
    }
  }

  void _startAnimationTimer() {
    Future.delayed(_minAnimationDuration, () {
      if (mounted) {
        setState(() {
          _isAnimationTimePassed = true;
          if (_isVideoInitialized) {
            _loadingOpacityController.reverse();
            _videoOpacityController.forward();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _initGeneration++;
    _videoPlayerController.dispose();
    // MODIFICATION 3: Also dispose and nullify here for completeness.
    _chewieController?.dispose();
    _chewieController = null;
    _loadingOpacityController.dispose();
    _videoOpacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const Center(child: Icon(Icons.error, color: Colors.red, size: 48));
    }
    
    return Stack(
      alignment: Alignment.center,
      children: [
        // MODIFICATION 4: Add a null-check for the controller.
        // This is the ultimate safeguard that prevents the error.
        if (_chewieController != null && _isVideoInitialized && _isAnimationTimePassed)
          FadeTransition(
            opacity: _videoOpacityAnimation,
            child: Chewie(
              // Use the null-assertion operator (!) because we've already checked for null.
              controller: _chewieController!,
            ),
          ),
        
        if (!(_isVideoInitialized && _isAnimationTimePassed) || _loadingOpacityController.value > 0)
          Positioned.fill(
            child: FadeTransition(
              opacity: _loadingOpacityAnimation,
              child: Container(
                color: Colors.black,
                child: Center(
                  child: Lottie.asset(
                    'assets/animation/panda_red.json',
                    width: 300,
                    height: 300,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}