// Copyright 2022, the Flutter project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:operation_sunrise/constants.dart';
import 'settings_persistence.dart';

/// An class that holds settings like [playerName] or [musicOn],
/// and saves them to an injected persistence store.
class SettingsController with ChangeNotifier {
  final Logger _log = Logger('SettingsController');

  final SettingsPersistence _persistence;
  ValueNotifier<bool> soundsOn = ValueNotifier(true);
  ValueNotifier<bool> autoplayOn = ValueNotifier(true);
  ValueNotifier<bool> loopingOn = ValueNotifier(true);
  int _lastPlayedLevelNumber = 1;
  int get lastPlayedLevelNumber => _lastPlayedLevelNumber;
  bool isEulaAccepted = false;

  /// Creates a new instance of [SettingsController] backed by [persistence].
  SettingsController({required SettingsPersistence persistence})
    : _persistence = persistence;

  /// Asynchronously loads values from the injected persistence store.
  Future<void> loadStateFromPersistence() async {
    await Future.wait([
      _persistence.getSoundsOn().then((value) => soundsOn.value = value),
      _persistence.getAutoplayOn().then((value) => autoplayOn.value = value),
      _persistence.getLoopingOn().then((value) => loopingOn.value = value),
      _persistence.getEulaAccepted().then((value) => isEulaAccepted = value),
      _persistence.getLastPlayedLevel().then(
        (value) => _lastPlayedLevelNumber = value,
      ),
    ]);
    saveAppInstallTime();
    notifyListeners();
  }

  Future<void> setLastPlayedLevel(int levelNumber) async {
    if (_lastPlayedLevelNumber != levelNumber) {
      _lastPlayedLevelNumber = levelNumber;
      await _persistence.saveLastPlayedLevel(levelNumber);
      notifyListeners();
    }
  }

  void dispose() {
    super.dispose();
    soundsOn.dispose();
  }

  Future<void> setEulaAccepted() async {
    isEulaAccepted = true;
    _persistence.setEulaAccepted();
  }

  void toggleSoundsOn() {
    soundsOn.value = !soundsOn.value;
    _persistence.saveSoundsOn(soundsOn.value);
  }

  void toggleAutoplayOn() {
    autoplayOn.value = !autoplayOn.value;
    _persistence.saveAutoplayOn(autoplayOn.value);
  }

  void toggleLoopingOn() {
    loopingOn.value = !loopingOn.value;
    _persistence.saveAutoplayOn(loopingOn.value);
  }

  Future<void> saveAppInstallTime() async {
    await _persistence.saveAppInstallTime();
  }

  Future<bool> canAskForReview() async {
    final now = DateTime.now().toUtc();

    // Rule 2: Check if app was installed at least 15 minutes ago.
    final installTime = await _persistence.getAppInstallTime();
    if (installTime == null) {
      // If we have no install time, we can't check the duration.
      return false;
    }

    final minutes = FirebaseRemoteConfig.instance.getInt(
      C.minutesBeforeReviewTag,
    );

    if (now.difference(installTime).inMinutes < minutes) {
      return false;
    }

    // Rule 3: Check when the last review was asked.
    final lastAskTime = await _persistence.getLastReviewAskTime();
    if (lastAskTime == null) {
      // Never asked before. All other conditions have passed.
      await _persistence.saveLastReviewAskTime();
      return true;
    }

    final days = FirebaseRemoteConfig.instance.getInt(C.dayBeforeReviewTag);

    // It has been asked before. Check if it was at least 1 day ago.
    if (now.difference(lastAskTime).inDays >= days) {
      await _persistence.saveLastReviewAskTime();
      return true;
    }
    return false;
  }
}
