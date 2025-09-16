import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:lottie/lottie.dart';
import 'package:operation_sunrise/data/settings_controller.dart'; // Assuming this path is correct for your project
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class LevelVideoPlayer extends StatefulWidget {
  final String videoPath;
  final bool isSolved;

  const LevelVideoPlayer({
    super.key,
    required this.videoPath,
    required this.isSolved,
  });

  @override
  State<LevelVideoPlayer> createState() => _LevelVideoPlayerState();
}

class _LevelVideoPlayerState extends State<LevelVideoPlayer>
    with TickerProviderStateMixin {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;

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
    _initializePlayer();
    _startAnimationTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _settings = context.read<SettingsController>();

    _settings.autoplayOn.addListener(_onSettingChanged);
    _settings.loopingOn.addListener(_onSettingChanged);
    _settings.soundsOn.addListener(_onSoundsOnSettingChanged);
  }

  void _initializeAnimationControllers() {
    _loadingOpacityController = AnimationController(
      vsync: this,
      duration: _transitionDuration,
    );
    _loadingOpacityAnimation = CurvedAnimation(
      parent: _loadingOpacityController,
      curve: Curves.easeIn,
    );
    _videoOpacityController = AnimationController(
      vsync: this,
      duration: _transitionDuration,
    );
    _videoOpacityAnimation = CurvedAnimation(
      parent: _videoOpacityController,
      curve: Curves.easeIn,
    );
    _loadingOpacityController.forward();

    _loadingOpacityController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        if (_settings.autoplayOn.value &&
            _videoPlayerController.value.isInitialized) {
          _videoPlayerController.play();
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant LevelVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSolved) {
      _chewieController?.setVolume(0.0);
    }
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

  Future<void> _initializePlayer() async {
    final int currentGeneration = _initGeneration;
    try {
      final ref = FirebaseStorage.instance.ref(widget.videoPath);
      final url = await ref.getDownloadURL();
      if (currentGeneration != _initGeneration || !mounted) return;

      final file = await DefaultCacheManager().getSingleFile(url);

      _videoPlayerController = VideoPlayerController.file(file);
      await _videoPlayerController.initialize();

      if (currentGeneration != _initGeneration || !mounted) {
        _videoPlayerController.dispose();
        return;
      }

      _onSoundsOnSettingChanged();
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

  ChewieController _createChewieController() {
    return ChewieController(
      videoPlayerController: _videoPlayerController,
      autoPlay: false, // Manually controlled via animation listener
      looping: _settings.loopingOn.value,
      allowFullScreen: false,
      allowPlaybackSpeedChanging: false,
      showOptions: false,
      showControls: true,
      allowMuting: false,
      draggableProgressBar: false,
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
  }

  void _onSoundsOnSettingChanged() {
    if (!_videoPlayerController.value.isInitialized) {
      return;
    }
    final newVolume = _settings.soundsOn.value ? 1.0 : 0.0;
    _videoPlayerController.setVolume(newVolume);
  }

  void _onSettingChanged() {
    if (_chewieController == null ||
        !_videoPlayerController.value.isInitialized) {
      return;
    }
    final newAutoplayValue = _settings.autoplayOn.value;
    final newLoopingValue = _settings.loopingOn.value;
    if (_chewieController!.autoPlay == newAutoplayValue &&
        _chewieController!.looping == newLoopingValue) {
      return;
    }
    final oldChewieController = _chewieController;
    setState(() {
      _chewieController = _createChewieController();
    });
    oldChewieController?.dispose();
    if (oldChewieController?.autoPlay != newAutoplayValue) {
      if (newAutoplayValue) {
        _videoPlayerController.play();
      } else {
        _videoPlayerController.pause();
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
    _settings.autoplayOn.removeListener(_onSettingChanged);
    _settings.loopingOn.removeListener(_onSettingChanged);
    _settings.soundsOn.removeListener(_onSoundsOnSettingChanged);

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
      return const Center(
        child: Icon(Icons.error, color: Colors.red, size: 48),
      );
    }
    final bool isVideoReady = _isVideoInitialized && _isAnimationTimePassed;

    return Stack(
      alignment: Alignment.center,
      children: [
        if (_chewieController != null && isVideoReady)
          FadeTransition(
            opacity: _videoOpacityAnimation,
            child: Chewie(controller: _chewieController!),
          ),

        if (!isVideoReady || _loadingOpacityController.value > 0)
          IgnorePointer(
            ignoring: isVideoReady,
            child: FadeTransition(
              opacity: _loadingOpacityAnimation,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: Colors.white,
                  child: Center(
                    // --- CHANGED THIS SECTION ---
                    // Use a Stack to layer the image and the panda animation.
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        // Layer 1: Your Image (will be in the back)
                        Image.asset(
                          'assets/images/cinema_screen.jpg', // <-- Your image path
                          width: 640,
                          height: 360,
                          fit: BoxFit.cover, // Adjust the fit to your liking
                        ),

                        // Layer 2: Panda Animation (will be on top of the image)
                        Lottie.asset(
                          'assets/animation/panda_red.json',
                          width: 300,
                          height: 300,
                        ),
                      ],
                    ),
                    // ---------------------------
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
