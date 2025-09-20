// Copyright 2022, the Flutter project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:operation_sunrise/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_persistence.dart';

/// An implementation of [SettingsPersistence] that uses
/// `package:shared_preferences`.
class LocalStorageSettingsPersistence extends SettingsPersistence {
  final Future<SharedPreferences> instanceFuture =
      SharedPreferences.getInstance();

  final Logger _log = Logger('LocalStorageSettingsPersistence');
  static const _completedLevelsKey = 'completedLevels';
  
  @override
  Future<Set<int>> getCompletedLevels() async {
    final prefs = await instanceFuture;
    final levelStrings = prefs.getStringList(_completedLevelsKey);
    if (levelStrings == null) {
      return {};
    }
    return levelStrings.map(int.parse).toSet();
  }

  @override
  Future<void> saveCompletedLevels(Set<int> completedLevels) async {
    final prefs = await instanceFuture;
    // Convert set of integers to a list of strings to store in SharedPreferences
    final levelStrings = completedLevels.map((e) => e.toString()).toList();
    await prefs.setStringList(_completedLevelsKey, levelStrings);
  }

  @override
  Future<bool> getSoundsOn() async {
    final prefs = await instanceFuture;
    return prefs.getBool('soundsOn') ?? true;
  }

  @override
  Future<void> saveSoundsOn(bool value) async {
    final prefs = await instanceFuture;
    await prefs.setBool('soundsOn', value);
  }

  @override
  Future<bool> getEulaAccepted() async {
    final prefs = await instanceFuture;
    return prefs.getBool('eulaAccepted') ?? false;
  }

  @override
  Future<void> setEulaAccepted() async {
    final prefs = await instanceFuture;
    await prefs.setBool('eulaAccepted', true);
  }

  static const _appInstallTimeKey = 'app_install_time';
  static const _lastReviewAskTimeKey = 'last_review_ask_time';

  @override
  Future<DateTime?> getAppInstallTime() async {
    final prefs = await instanceFuture;
    final timeString = prefs.getString(_appInstallTimeKey);
    return timeString != null ? DateTime.parse(timeString) : null;
  }

  @override
  Future<DateTime?> getLastReviewAskTime() async {
    final prefs = await instanceFuture;
    final timeString = prefs.getString(_lastReviewAskTimeKey);
    return timeString != null ? DateTime.parse(timeString) : null;
  }

  @override
  Future<void> saveAppInstallTime() async {
    final prefs = await instanceFuture;
    if (prefs.getString(_appInstallTimeKey) == null) {
      await prefs.setString(
        _appInstallTimeKey,
        DateTime.now().toUtc().toIso8601String(),
      );
    }
  }

  @override
  Future<void> saveLastReviewAskTime() async {
    final prefs = await instanceFuture;
    await prefs.setString(
      _lastReviewAskTimeKey,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  @override
  Future<void> saveLastPlayedLevel(int levelNr) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(C.lastPlayedLevelKey, levelNr);
  }

  @override
  Future<int> getLastPlayedLevel() async {
    final prefs = await SharedPreferences.getInstance();
    // Return the saved level, or 1 if nothing is saved yet.
    return prefs.getInt(C.lastPlayedLevelKey) ?? 1;
  }

  @override
  Future<bool> getAutoplayOn() async {
    final prefs = await instanceFuture;
    return prefs.getBool('autoplayOn') ?? true;
  }

  @override
  Future<void> saveAutoplayOn(bool value) async {
    final prefs = await instanceFuture;
    await prefs.setBool('autoplayOn', value);
  }

  @override
  Future<bool> getLoopingOn() async {
    final prefs = await instanceFuture;
    return prefs.getBool('loopingOn') ?? true;
  }

  @override
  Future<void> saveLoopingOn(bool value) async {
    final prefs = await instanceFuture;
    await prefs.setBool('loopingOn', value);
  }
}
