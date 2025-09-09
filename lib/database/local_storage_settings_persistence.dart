// Copyright 2022, the Flutter project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_persistence.dart';

/// An implementation of [SettingsPersistence] that uses
/// `package:shared_preferences`.
class LocalStorageSettingsPersistence extends SettingsPersistence {
  final Future<SharedPreferences> instanceFuture =
      SharedPreferences.getInstance();

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
  Future<String> getToken() async {
    final prefs = await instanceFuture;
    return prefs.getString('fcmToken') ?? "";
  }

  @override
  Future<void> setToken(String value) async {
    final prefs = await instanceFuture;
    await prefs.setString('fcmToken', value);
  }

  @override
  Future<Map<String, String>> getBanned() async {
    final prefs = await instanceFuture;
    final bannedMapString = prefs.getString('bannedUsers');
    final bannedMapObject = Map<String, String>.from(
      jsonDecode(bannedMapString ?? "{}"),
    );
    return bannedMapObject;
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
}
