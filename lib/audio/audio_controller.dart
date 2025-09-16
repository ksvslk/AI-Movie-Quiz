// Copyright 2022, the Flutter project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:logging/logging.dart';
import 'package:operation_sunrise/data/settings_controller.dart';
import 'package:real_volume/real_volume.dart';

import 'sounds.dart';

/// Allows playing music and sound. A facade to `package:audioplayers`.
class AudioController {
  static final _log = Logger('AudioController');

  SettingsController? _settings;
  ValueNotifier<AppLifecycleState>? _lifecycleNotifier;

  late AudioSource letter;
  late AudioSource select;
  late AudioSource erase;
  late AudioSource eraseAll;
  late AudioSource reveal;
  late AudioSource snapclick;
  late AudioSource impact;

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
      select = await SoLoud.instance.loadAsset('assets/sfx/select.wav');
      erase = await SoLoud.instance.loadAsset('assets/sfx/erase.wav');
      eraseAll = await SoLoud.instance.loadAsset('assets/sfx/erase_all.wav');
      reveal = await SoLoud.instance.loadAsset('assets/sfx/reveal.wav');
      snapclick = await SoLoud.instance.loadAsset('assets/sfx/snapclick.wav');
      impact = await SoLoud.instance.loadAsset('assets/sfx/impact.wav');
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
      case SfxType.select:
        SoLoud.instance.play(select);
        break;
      case SfxType.erase:
        SoLoud.instance.play(erase);
        break;
      case SfxType.eraseAll:
        SoLoud.instance.play(eraseAll);
        break;
      case SfxType.reveal:
        SoLoud.instance.play(reveal);
        break;
      case SfxType.action:
        final action = await SoLoud.instance.loadAsset('assets/sfx/won/action.wav');
        SoLoud.instance.play(action);
        break;
      case SfxType.adventure:
        final adventure = await SoLoud.instance.loadAsset('assets/sfx/won/adventure.wav');
        SoLoud.instance.play(adventure);
        break;
      case SfxType.comedy:
        final comedy = await SoLoud.instance.loadAsset('assets/sfx/won/comedy.wav');
        SoLoud.instance.play(comedy);
        break;
      case SfxType.drama:
        final drama = await SoLoud.instance.loadAsset('assets/sfx/won/drama.wav');
        SoLoud.instance.play(drama);
        break;
      case SfxType.fantasy:
        final fantasy = await SoLoud.instance.loadAsset('assets/sfx/won/fantasy.wav');
        SoLoud.instance.play(fantasy);
        break;
      case SfxType.horror:
        final horror = await SoLoud.instance.loadAsset('assets/sfx/won/horror.wav');
        SoLoud.instance.play(horror);
        break;
      case SfxType.mystery:
        final mystery = await SoLoud.instance.loadAsset('assets/sfx/won/mystery.wav');
        SoLoud.instance.play(mystery);
        break;
      case SfxType.romance:
        final romance = await SoLoud.instance.loadAsset('assets/sfx/won/romance.wav');
        SoLoud.instance.play(romance);
        break;
      case SfxType.scifi:
        final scifi = await SoLoud.instance.loadAsset('assets/sfx/won/scifi.wav');
        SoLoud.instance.play(scifi);
        break;
      case SfxType.thriller:
        final thriller = await SoLoud.instance.loadAsset('assets/sfx/won/thriller.wav');
        SoLoud.instance.play(thriller);
        break;
      case SfxType.war:
        final war = await SoLoud.instance.loadAsset('assets/sfx/won/war.wav');
        SoLoud.instance.play(war);
        break;
      case SfxType.snapclick:
        SoLoud.instance.play(snapclick);
        break;
      case SfxType.impact:
        SoLoud.instance.play(impact);
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
