// lib/widgets/level_video_player.dart (or your file path)

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:lottie/lottie.dart';
import 'package:operation_sunrise/audio/audio_controller.dart';
import 'package:operation_sunrise/data/settings_controller.dart';
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
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;

  late SettingsController _settings;
  late AudioController _audio;

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
    _audio = context.read<AudioController>();

    // Remove old listeners before adding new ones to be safe.
    _settings.autoplayOn.removeListener(_onSettingChanged);
    _settings.loopingOn.removeListener(_onSettingChanged);
    _settings.soundsOn.removeListener(_setPlayerVolume);
    _audio.isMutedNotifier.removeListener(_setPlayerVolume);

    // Add listeners for settings and the crucial real-time mute notifier.
    _settings.autoplayOn.addListener(_onSettingChanged);
    _settings.loopingOn.addListener(_onSettingChanged);
    _settings.soundsOn.addListener(_setPlayerVolume);
    _audio.isMutedNotifier.addListener(_setPlayerVolume);
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
            _videoPlayerController?.value.isInitialized == true) {
          _videoPlayerController!.play();
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant LevelVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSolved) {
      _videoPlayerController?.setVolume(0.0);
    }
    if (widget.videoPath != oldWidget.videoPath) {
      _initGeneration++;
      _videoPlayerController?.dispose();
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
      await _videoPlayerController?.dispose();
      if (currentGeneration != _initGeneration || !mounted) return;

      _videoPlayerController = VideoPlayerController.file(file);
      final controller = _videoPlayerController;
      if (controller == null) return;

      await controller.initialize();
      if (currentGeneration != _initGeneration || !mounted) {
        controller.dispose();
        return;
      }

      _setPlayerVolume(); // Set initial volume based on current settings
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
      log('Error initializing video player: $e');
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
      videoPlayerController: _videoPlayerController!,
      autoPlay: false, // Manually controlled via animation listener
      looping: _settings.loopingOn.value,
      allowFullScreen: false,
      allowPlaybackSpeedChanging: false,
      showOptions: false,
      showControls: true,
      allowMuting: false, // Manually controlling this
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

  /// Sets player volume based on BOTH in-app settings and system mute status.
  void _setPlayerVolume() {
    if (_videoPlayerController?.value.isInitialized != true) {
      return;
    }

    // Mute if the in-app sound setting is off OR if the system is muted.
    final bool shouldMute =
        !_settings.soundsOn.value || _audio.isMutedNotifier.value;
    final double newVolume = shouldMute ? 0.0 : 1.0;

    _videoPlayerController!.setVolume(newVolume);
  }

  /// Handles changes to autoplay or looping settings.
  void _onSettingChanged() {
    if (_chewieController == null ||
        _videoPlayerController?.value.isInitialized != true) {
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
        _videoPlayerController!.play();
      } else {
        _videoPlayerController!.pause();
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
    // Clean up all listeners to prevent memory leaks
    _settings.autoplayOn.removeListener(_onSettingChanged);
    _settings.loopingOn.removeListener(_onSettingChanged);
    _settings.soundsOn.removeListener(_setPlayerVolume);
    _audio.isMutedNotifier.removeListener(_setPlayerVolume);

    _initGeneration++;
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
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
                // The Center widget was removed and Stack now fills the AspectRatio.
                child: Stack(
                  alignment: Alignment.center,
                  // This property makes the Stack's children fill its bounds.
                  fit: StackFit.expand, 
                  children: <Widget>[
                    Image.asset(
                      'assets/images/cinema_screen.jpg',
                      // BoxFit.cover will now correctly fill the 16:9 area.
                      fit: BoxFit.cover,
                    ),
                    Lottie.asset(
                      'assets/animation/panda_red.json',
                      width: 300,
                      height: 300,
                    ),
                  ],
                ),
              ),
            ),
            ),
      ],
    );
  }
}