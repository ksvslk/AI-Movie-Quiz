// Copyright 2022, the Flutter project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// An interface of persistence stores for settings.
///
/// Implementations can range from simple in-memory storage through
/// local preferences to cloud-based solutions.
abstract class SettingsPersistence {
  Future<bool> getEulaAccepted();
  Future<bool> getSoundsOn();
  Future<bool> getAutoplayOn();
  Future<bool> getLoopingOn();

  Future<void> setEulaAccepted();
  Future<void> saveSoundsOn(bool value);
  Future<void> saveAutoplayOn(bool value);
  Future<void> saveLoopingOn(bool value);

  Future<void> saveAppInstallTime();
  Future<void> saveLastReviewAskTime();

  Future<void> saveLastPlayedLevel(int levelNr);
  Future<int> getLastPlayedLevel();

  Future<DateTime?> getAppInstallTime();
  Future<DateTime?> getLastReviewAskTime();

  Future<void> saveCompletedLevels(Set<int> completedLevels);
  Future<Set<int>> getCompletedLevels();
}
