// lib/audio/audio_controller.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:logging/logging.dart';
import 'package:operation_sunrise/audio/sounds.dart';
import 'package:operation_sunrise/data/settings_controller.dart';
import 'package:real_volume/real_volume.dart';

/// A controller that allows playing sound effects and broadcasts system mute state.
class AudioController {
  static final _log = Logger('AudioController');

  SettingsController? _settings;
  ValueNotifier<AppLifecycleState>? _lifecycleNotifier;

  /// A Notifier that broadcasts the system mute state to the rest of the app.
  /// `true` if the system is muted (silent/vibrate), `false` otherwise.
  final ValueNotifier<bool> isMutedNotifier = ValueNotifier(false);

  /// A subscription to the native ringer mode stream to detect real-time changes.
  StreamSubscription? _ringerModeSubscription;

  /// A mapping of sound effects to their preloaded audio sources.
  final Map<SfxType, AudioSource> _sfxs = {};
  final List<SoundHandle> _activeSounds = [];

  AudioController();

  void attachLifecycleNotifier(
    ValueNotifier<AppLifecycleState> lifecycleNotifier,
  ) {
    _lifecycleNotifier?.removeListener(_handleAppLifecycle);
    lifecycleNotifier.addListener(_handleAppLifecycle);
    _lifecycleNotifier = lifecycleNotifier;
  }

  void attachSettings(SettingsController settingsController) {
    if (_settings == settingsController) {
      return;
    }

    final oldSettings = _settings;
    if (oldSettings != null) {
      oldSettings.soundsOn.removeListener(_soundsOnHandler);
    }

    _settings = settingsController;
    settingsController.soundsOn.addListener(_soundsOnHandler);
  }

  void dispose() {
    _lifecycleNotifier?.removeListener(_handleAppLifecycle);
    // Cancel the stream subscription to prevent memory leaks.
    _ringerModeSubscription?.cancel();
    _stopAllSound();
    SoLoud.instance.deinit();
  }

  /// Initializes the audio engine, loads all sound effects, and starts listening
  /// for system mute changes.
  Future<void> initialize() async {
    await SoLoud.instance.init();

    // Start the listener for real-time system volume changes.
    await _initRingerModeListener();

    await _loadAllSfx();
  }

  Future<void> _loadAllSfx() async {
    // Clear any old, invalid sound sources before loading.
    _sfxs.clear();
    try {
      // Paste all your _loadSfx calls here
      await _loadSfx(SfxType.letter, 'assets/sfx/letter.wav');
      await _loadSfx(SfxType.select, 'assets/sfx/select.wav');
      await _loadSfx(SfxType.erase, 'assets/sfx/erase.wav');
      await _loadSfx(SfxType.eraseAll, 'assets/sfx/erase_all.wav');
      await _loadSfx(SfxType.reveal, 'assets/sfx/reveal.wav');
      await _loadSfx(SfxType.snapclick, 'assets/sfx/snapclick.wav');
      await _loadSfx(SfxType.impact, 'assets/sfx/impact.wav');
      await _loadSfx(SfxType.action, 'assets/sfx/won/action.wav');
      await _loadSfx(SfxType.adventure, 'assets/sfx/won/adventure.wav');
      await _loadSfx(SfxType.comedy, 'assets/sfx/won/comedy.wav');
      await _loadSfx(SfxType.drama, 'assets/sfx/won/drama.wav');
      await _loadSfx(SfxType.fantasy, 'assets/sfx/won/fantasy.wav');
      await _loadSfx(SfxType.horror, 'assets/sfx/won/horror.wav');
      await _loadSfx(SfxType.mystery, 'assets/sfx/won/mystery.wav');
      await _loadSfx(SfxType.romance, 'assets/sfx/won/romance.wav');
      await _loadSfx(SfxType.scifi, 'assets/sfx/won/scifi.wav');
      await _loadSfx(SfxType.thriller, 'assets/sfx/won/thriller.wav');
      await _loadSfx(SfxType.war, 'assets/sfx/won/war.wav');
    } on Exception catch (e) {
      _log.severe("Error loading sound files", e);
    }
  }

  /// Sets up the real-time listener for ringer mode changes.
  Future<void> _initRingerModeListener() async {
    // Get the initial state first.
    final initialMode = await RealVolume.getRingerMode();
    isMutedNotifier.value =
        (initialMode == RingerMode.SILENT || initialMode == RingerMode.VIBRATE);

    // Now, listen for any future changes.
    _ringerModeSubscription = RealVolume.onRingerModeChanged.listen((mode) {
      final bool isMuted =
          (mode == RingerMode.SILENT || mode == RingerMode.VIBRATE);

      // If the mute state has changed, update the notifier.
      if (isMutedNotifier.value != isMuted) {
        isMutedNotifier.value = isMuted;
      }

      // If the system is now muted, stop all currently playing sound effects.
      if (isMuted) {
        _stopAllSound();
      }
    });
  }

  /// Helper to load a single sound effect and add it to the map.
  Future<void> _loadSfx(SfxType type, String assetPath) async {
    final source = await SoLoud.instance.loadAsset(assetPath);
    _sfxs[type] = source;
  }

  /// Plays a sound effect of the given [type].
  void playSfx(SfxType type) async {

    final soundsOn = _settings?.soundsOn.value ?? false;
    // ------------------------------------

    if (isMutedNotifier.value || !soundsOn || !SoLoud.instance.isInitialized) {
      return;
    }
    final sound = _sfxs[type];
    if (sound != null) {
      try {
        final handle = await SoLoud.instance.play(sound);
        _activeSounds.add(handle);
      } catch (e) {
        _log.severe('Error playing sound $type: $e');
      }
    } else {
      _log.warning('Tried to play sound $type, but it was not preloaded.');
    }
  }

  void _handleAppLifecycle() async {

    switch (_lifecycleNotifier!.value) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        if (SoLoud.instance.isInitialized) {
          SoLoud.instance.deinit();
        }
        break;
      case AppLifecycleState.resumed:
        if (!SoLoud.instance.isInitialized) {
          await SoLoud.instance.init();
          await _loadAllSfx();
        }
        break;
    }
  }

  void _soundsOnHandler() {
    final soundsOn = _settings?.soundsOn.value ?? false;
    if (!soundsOn) {
      _stopAllSound();
    }
  }

  void _stopAllSound() {
// First, check if the engine is actually running.
    if (SoLoud.instance.isInitialized) {
      // If it is, stop all active sounds.
      for (final handle in _activeSounds) {
        SoLoud.instance.stop(handle);
      }
    }
    // ALWAYS clear the list of handles. If the engine was off,
    // these handles are invalid anyway.
    _activeSounds.clear();
  }
}
