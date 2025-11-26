import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:lottie/lottie.dart';
import 'package:operation_sunrise/audio/audio_controller.dart';
import 'package:operation_sunrise/data/settings_controller.dart';
import 'package:operation_sunrise/globals.dart'; // Import the global ad signal
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
  bool _hasError = false;
  bool _isLoading = true;

  bool _wasPlayingBeforeAd = false;
  bool _adIsShowing = false;
  bool _autoplayPrevented = false; // Flag to remember a deferred autoplay

  static const _minAnimationDuration = Duration(milliseconds: 300);
  static const _transitionDuration = Duration(milliseconds: 500);

  late AnimationController _loadingOpacityController;
  late Animation<double> _loadingOpacityAnimation;
  late AnimationController _videoOpacityController;
  late Animation<double> _videoOpacityAnimation;
  late final ValueNotifier<AppLifecycleState> _lifecycleListenable;

  @override
  void initState() {
    super.initState();
    _initializeAnimationControllers();

    _audio = context.read<AudioController>();
    _settings = context.read<SettingsController>();
    _lifecycleListenable = context.read<ValueNotifier<AppLifecycleState>>();

    _adIsShowing = isAdShowingNotifier.value;

    isAdShowingNotifier.addListener(_onAdStateChanged);
    _lifecycleListenable.addListener(_onAppLifecycleStateChanged);
    _audio.isMutedNotifier.addListener(_setPlayerVolume);
    _settings.soundsOn.addListener(_setPlayerVolume);
    _settings.loopingOn.addListener(_updateLoopingSetting);

    _initAndCrossfade();
  }

  void _onAdStateChanged() {
    _adIsShowing = isAdShowingNotifier.value;

    if (!mounted || _chewieController == null) return;

    if (_adIsShowing) {
      if (_chewieController!.isPlaying) {
        _wasPlayingBeforeAd = true;
        _chewieController!.pause();
      }
    } else {
      // Case 1: The video was playing before, so resume it.
      if (_wasPlayingBeforeAd) {
        _chewieController!.play();
        _wasPlayingBeforeAd = false;
      }
      // Case 2: Autoplay was blocked by the ad, so start it now.
      else if (_autoplayPrevented) {
        _chewieController!.play();
        _autoplayPrevented = false;
      }
    }
  }

  void _onAppLifecycleStateChanged() {
    if (!mounted || _chewieController == null) return;

    final appLifecycleState = _lifecycleListenable.value;

    if (appLifecycleState != AppLifecycleState.resumed) {
      if (_chewieController!.isPlaying) {
        _wasPlayingBeforeAd = true;
        _chewieController!.pause();
      }
    } else {
      if (_wasPlayingBeforeAd && !_adIsShowing) {
        _chewieController!.play();
        _wasPlayingBeforeAd = false;
      }
    }
  }


  void _initializeAnimationControllers() {
    _loadingOpacityController = AnimationController(
        vsync: this,
        duration: _transitionDuration
    )..forward();

    _loadingOpacityAnimation = CurvedAnimation(
        parent: _loadingOpacityController,
        curve: Curves.easeIn
    );

    _videoOpacityController = AnimationController(
        vsync: this,
        duration: _transitionDuration
    );

    _videoOpacityAnimation = CurvedAnimation(
        parent: _videoOpacityController,
        curve: Curves.easeIn
    );
  }

  @override
  void didUpdateWidget(covariant LevelVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isSolved != oldWidget.isSolved) {
      _setPlayerVolume();
    }

    if (widget.videoPath != oldWidget.videoPath) {
      _initGeneration++;
      _disposeControllers();
      // Reset flags for the new video
      _autoplayPrevented = false;
      _wasPlayingBeforeAd = false;
      setState(() {
        _hasError = false;
        _isLoading = true;
      });
      _loadingOpacityController.forward(from: 0.0);
      _videoOpacityController.reverse(from: 1.0);
      _initAndCrossfade();
    }
  }

  void _updateLoopingSetting() {
    if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) {
      return;
    }
    final newLoopingValue = _settings.loopingOn.value;
    if (_videoPlayerController!.value.isLooping != newLoopingValue) {
      _videoPlayerController!.setLooping(newLoopingValue);
    }
  }

  Future<void> _initAndCrossfade() async {
    final int currentGeneration = _initGeneration;

    final results = await Future.wait([
      _initializePlayer(),
      Future.delayed(_minAnimationDuration),
    ]);

    final success = results[0] as bool;

    if (currentGeneration == _initGeneration && mounted && success) {
      setState(() {
        _isLoading = false;
      });
      _loadingOpacityController.reverse();
      _videoOpacityController.forward();
    }
  }

  Future<bool> _initializePlayer() async {
    final int currentGeneration = _initGeneration;

    try {
      final url = await FirebaseStorage.instance
          .ref(widget.videoPath)
          .getDownloadURL();

      if (currentGeneration != _initGeneration || !mounted) return false;

      final file = await DefaultCacheManager().getSingleFile(url);
      if (currentGeneration != _initGeneration || !mounted) return false;

      _videoPlayerController = VideoPlayerController.file(file);
      await _videoPlayerController!.initialize();

      if (currentGeneration != _initGeneration || !mounted) {
        _videoPlayerController?.dispose();
        return false;
      }

      _setPlayerVolume();
      _updateLoopingSetting();

      if (mounted) {
        final bool shouldAutoplay = _settings.autoplayOn.value && !_adIsShowing;

        // If autoplay is on in settings but we're stopping it, set the flag.
        if (_settings.autoplayOn.value && !shouldAutoplay) {
          _autoplayPrevented = true;
        }

        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController!,
          autoPlay: shouldAutoplay,
          looping: _settings.loopingOn.value,
          allowFullScreen: false,
          allowPlaybackSpeedChanging: false,
          showOptions: false,
          showControls: true,
          allowMuting: false,
          draggableProgressBar: false,
          showControlsOnInitialize: false,
        );
      }

      return true;
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
      return false;
    }
  }

  void _setPlayerVolume() {
    if (_videoPlayerController == null ||
        !_videoPlayerController!.value.isInitialized) {
      return;
    }

    if (widget.isSolved) {
      _videoPlayerController!.setVolume(0.0);
      return;
    }

    final shouldMute = !_settings.soundsOn.value || _audio.isMutedNotifier.value;
    _videoPlayerController!.setVolume(shouldMute ? 0.0 : 1.0);
  }

  void _disposeControllers() {
    _chewieController?.dispose();
    _chewieController = null;
    _videoPlayerController?.dispose();
    _videoPlayerController = null;
  }

  @override
  void dispose() {
    isAdShowingNotifier.removeListener(_onAdStateChanged);
    _lifecycleListenable.removeListener(_onAppLifecycleStateChanged);
    _audio.isMutedNotifier.removeListener(_setPlayerVolume);
    _settings.soundsOn.removeListener(_setPlayerVolume);
    _settings.loopingOn.removeListener(_updateLoopingSetting);

    _initGeneration++;

    _disposeControllers();
    _loadingOpacityController.dispose();
    _videoOpacityController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isAdShowingNotifier,
      builder: (context, isAdShowing, child) {
        if (isAdShowing) {
          return const SizedBox.shrink();
        }
        return child!;
      },
      child: Builder(
        builder: (context) {
          if (_hasError) {
            return const Center(
                child: Icon(Icons.error_outline, color: Colors.red, size: 48));
          }

          return Stack(
            alignment: Alignment.center,
            children: [
              if (_chewieController != null && !_isLoading)
                FadeTransition(
                  opacity: _videoOpacityAnimation,
                  child: Chewie(controller: _chewieController!),
                ),
              if (_isLoading)
                FadeTransition(
                  opacity: _loadingOpacityAnimation,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      alignment: Alignment.center,
                      children: [
                        Image.asset('assets/images/cinema_screen.jpg',
                            fit: BoxFit.cover),
                        Lottie.asset('assets/animation/panda_red.json'),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}