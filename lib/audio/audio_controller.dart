// Copyright 2022, the Flutter project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:logging/logging.dart';
import 'package:operation_sunrise/database/settings_controller.dart';
import 'package:real_volume/real_volume.dart';

import 'sounds.dart';

/// Allows playing music and sound. A facade to `package:audioplayers`.
class AudioController {
  static final _log = Logger('AudioController');

  SettingsController? _settings;
  ValueNotifier<AppLifecycleState>? _lifecycleNotifier;

  late AudioSource letter;

  AudioController({int polyphony = 2});

  void attachLifecycleNotifier(
    ValueNotifier<AppLifecycleState> lifecycleNotifier,
  ) {
    _lifecycleNotifier?.removeListener(_handleAppLifecycle);
    lifecycleNotifier.addListener(_handleAppLifecycle);
    _lifecycleNotifier = lifecycleNotifier;
  }

  void attachSettings(SettingsController settingsController) {
    if (_settings == settingsController) {
      // Already attached to this instance. Nothing to do.
      return;
    }

    // Remove handlers from the old settings controller if present
    final oldSettings = _settings;
    if (oldSettings != null) {
      oldSettings.soundsOn.removeListener(_soundsOnHandler);
    }

    _settings = settingsController;

    // Add handlers to the new settings controller
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
      letter = await SoLoud.instance.loadAsset('assets/sfx/letter.wav');
    } on Exception catch (e) {
      _log.severe("Error loading sound files", e);
    }
  }

  void playSfx(SfxType type) async {
    RingerMode? ringerMode = await RealVolume.getRingerMode();
    if (ringerMode == RingerMode.SILENT || ringerMode == RingerMode.VIBRATE) return;
    // Check app setting first
    final soundsOn = _settings?.soundsOn.value ?? false;
    if (!soundsOn) {
      return;
    }

    // Check if app is in foreground (don't play sounds when backgrounded)
    if (_lifecycleNotifier?.value != AppLifecycleState.resumed) {
      return;
    }

    switch (type) {
      case SfxType.letter:
        SoLoud.instance.play(letter);
        break;
    }
  }

  void _handleAppLifecycle() {
    switch (_lifecycleNotifier!.value) {
      case AppLifecycleState.paused:
        _stopAllSound();
      case AppLifecycleState.detached:
        _stopAllSound();
      case AppLifecycleState.hidden:
        _stopAllSound();
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
        _stopAllSound();
        break;
    }
  }

  void _soundsOnHandler() {
    // Handle when sound settings change
    final soundsOn = _settings?.soundsOn.value ?? false;
    if (!soundsOn) {
      _stopAllSound();
    }
  }

  void _stopAllSound() async {
  }
}
