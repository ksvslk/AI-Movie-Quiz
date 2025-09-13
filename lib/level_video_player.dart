import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:operation_sunrise/data/settings_controller.dart';
import 'package:provider/provider.dart';
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
  ChewieController? _chewieController;

  // This will hold the SettingsController instance from your Provider.
  late SettingsController _settings;

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
    // Note: We can't use context.read here yet.
    // Listeners will be attached in didChangeDependencies.
    _initializePlayer();
    _startAnimationTimer();
  }

  /// Use didChangeDependencies to safely access the Provider
  /// and attach listeners for setting changes.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get the settings controller instance using context.read.
    // We only need to get it once to set up listeners.
    _settings = context.read<SettingsController>();
    
    // Add listeners for BOTH ValueNotifiers. They trigger the same callback.
    _settings.autoplayOn.addListener(_onSettingChanged);
    _settings.loopingOn.addListener(_onSettingChanged);
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

  /// Helper method to create the ChewieController based on current settings.
  /// This avoids code duplication.
  ChewieController _createChewieController() {
    return ChewieController(
      videoPlayerController: _videoPlayerController,
      // Read the current .value from the ValueNotifiers
      autoPlay: _settings.autoplayOn.value,
      looping: _settings.loopingOn.value,
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
  }

  /// This is the callback that reacts to any relevant setting change.
  void _onSettingChanged() {
    // Ensure the player is ready before trying to update it.
    if (_chewieController == null || !_videoPlayerController.value.isInitialized) {
      return;
    }

    final newAutoplayValue = _settings.autoplayOn.value;
    final newLoopingValue = _settings.loopingOn.value;

    // Check if a change is actually needed to avoid unnecessary work.
    if (_chewieController!.autoPlay == newAutoplayValue && _chewieController!.looping == newLoopingValue) {
      return;
    }
    
    // Store the old controller to dispose it after the new one is active.
    final oldChewieController = _chewieController;

    // Create a new ChewieController with the updated settings and update the state.
    // The VideoPlayerController is reused, preserving the video's position.
    setState(() {
      _chewieController = _createChewieController();
    });

    // It's good practice to dispose the old controller after the state has been updated.
    oldChewieController?.dispose();
    
    // For better UX, explicitly play or pause if the autoplay setting changed.
    if (oldChewieController?.autoPlay != newAutoplayValue) {
      if (newAutoplayValue) {
          _videoPlayerController.play();
      } else {
          _videoPlayerController.pause();
      }
    }
  }

  Future<void> _initializePlayer() async {
    final int currentGeneration = _initGeneration;

    try {
      final ref = FirebaseStorage.instance.ref(widget.videoPath);
      final url = await ref.getDownloadURL();

      if (currentGeneration != _initGeneration || !mounted) return;

      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(url));
      await _videoPlayerController.initialize();

      if (currentGeneration != _initGeneration || !mounted) {
        _videoPlayerController.dispose();
        return;
      }
      
      // Use our new helper method to create the initial controller instance.
      // _settings will be available by the time this is needed.
      _chewieController = _createChewieController();
      
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
    // IMPORTANT! Remove ALL listeners to prevent memory leaks.
    _settings.autoplayOn.removeListener(_onSettingChanged);
    _settings.loopingOn.removeListener(_onSettingChanged);

    _initGeneration++;
    _videoPlayerController.dispose();
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
        if (_chewieController != null && _isVideoInitialized && _isAnimationTimePassed)
          FadeTransition(
            opacity: _videoOpacityAnimation,
            child: Chewie(
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

