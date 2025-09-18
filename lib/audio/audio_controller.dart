// lib/audio/audio_controller.dart

// Copyright 2022, the Flutter project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:logging/logging.dart';
import 'package:operation_sunrise/audio/sounds.dart';
import 'package:operation_sunrise/data/settings_controller.dart';
import 'package:real_volume/real_volume.dart';

/// A controller that allows playing sound effects.
class AudioController {
  static final _log = Logger('AudioController');

  SettingsController? _settings;
  ValueNotifier<AppLifecycleState>? _lifecycleNotifier;

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
    _stopAllSound();
    SoLoud.instance.deinit();
  }

  /// Preloads all sound effects.
  Future<void> initialize() async {
    await SoLoud.instance.init();

    try {
      // Load all sounds into the map
      await _loadSfx(SfxType.letter, 'assets/sfx/letter.wav');
      await _loadSfx(SfxType.select, 'assets/sfx/select.wav');
      await _loadSfx(SfxType.erase, 'assets/sfx/erase.wav');
      await _loadSfx(SfxType.eraseAll, 'assets/sfx/erase_all.wav');
      await _loadSfx(SfxType.reveal, 'assets/sfx/reveal.wav');
      await _loadSfx(SfxType.snapclick, 'assets/sfx/snapclick.wav');
      await _loadSfx(SfxType.impact, 'assets/sfx/impact.wav');

      // Preload the 'won' sounds
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

  /// Helper to load a single sound effect and add it to the map.
  Future<void> _loadSfx(SfxType type, String assetPath) async {
    final source = await SoLoud.instance.loadAsset(assetPath);
    _sfxs[type] = source;
  }

  /// Plays a sound effect of the given [type].
  void playSfx(SfxType type) async {
    // Check device ringer mode first.
    final ringerMode = await RealVolume.getRingerMode();
    if (ringerMode == RingerMode.SILENT || ringerMode == RingerMode.VIBRATE) {
      return;
    }

    // Check app setting.
    final soundsOn = _settings?.soundsOn.value ?? false;
    if (!soundsOn) {
      return;
    }

    // Check if app is in foreground.
    /*
    if (_lifecycleNotifier?.value == AppLifecycleState.paused) {
      return;
    }
    */

    // Find the preloaded sound and play it.
    final sound = _sfxs[type];
    if (sound != null) {
      // Capture the handle when you play the sound
      final handle = await SoLoud.instance.play(sound);
      _activeSounds.add(handle);
    } else {
      _log.warning('Tried to play sound $type, but it was not preloaded.');
    }
  }

  void _handleAppLifecycle() {
    switch (_lifecycleNotifier!.value) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _stopAllSound();
        break;
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
        // No need to do anything when resuming or going inactive.
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
    // Stop each sound individually
    for (final handle in _activeSounds) {
      SoLoud.instance.stop(handle);
    }
    // Clear the list of active sounds
    _activeSounds.clear();
  }
}
