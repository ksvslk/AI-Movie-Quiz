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

  ValueNotifier<AppLifecycleState>? _lifecycleNotifier;
  DateTime? _timeOfPause;
  static const _sessionTimeout = Duration(seconds: 200);

  // This variable now ONLY exists in memory.
  DateTime? sessionStartTime;

  int _lastPlayedLevelNumber = 1;
  int get lastPlayedLevelNumber => _lastPlayedLevelNumber;
  bool isEulaAccepted = false;

  /// Creates a new instance of [SettingsController] backed by [persistence].
  SettingsController({required SettingsPersistence persistence})
    : _persistence = persistence;

  Future<bool> shouldShowInterstitialAd() async {
    final appInstallTime = await _persistence.getAppInstallTime();
    final now = DateTime.now().toUtc();
    int minutes;

    _log.log(
      Level.INFO,
      "⏰ appInstallTime: Level ${appInstallTime?.toIso8601String()}",
    );
    _log.log(
      Level.INFO,
      "⏱️ sessionStartTime: Level ${sessionStartTime?.toIso8601String()}",
    );

    if (appInstallTime != null) {
      final days = FirebaseRemoteConfig.instance.getInt(C.dayBeforeFasterAds);
      if (now.difference(appInstallTime).inDays < days) {
        minutes = FirebaseRemoteConfig.instance.getInt(C.minutesBeforeFirstAd);
        _log.log(Level.INFO, "now < appInstallTime, so minutes are $minutes");
      } else {
        minutes = FirebaseRemoteConfig.instance.getInt(
          C.minutesBeforeFasterAds,
        );
        _log.log(Level.INFO, "now >= appInstallTime, so minutes are $minutes");
      }
      if (sessionStartTime != null) {
        if (now.difference(sessionStartTime!).inMinutes >= minutes) {
          _log.log(
            Level.INFO,
            "now >= sessionStartTime, so we SHOULD SHOW ADS!",
          );
          return true;
        }
      }
    }
    return false;
  }

void _onAppLifecycleStateChanged() {
  final state = _lifecycleNotifier?.value;
  _log.log(Level.INFO, "AppLifecycleState: $state");

  switch (state) {
    case AppLifecycleState.paused:
    case AppLifecycleState.inactive:
    case AppLifecycleState.hidden:
    case AppLifecycleState.detached:
      _timeOfPause = DateTime.now().toUtc();
      _log.log(Level.INFO, "App paused at: ${_timeOfPause!.toIso8601String()}");
      break;
    case AppLifecycleState.resumed:
      final now = DateTime.now().toUtc();
      final timeOfPause = _timeOfPause;
      _log.log(Level.INFO, "timeOfPause: $timeOfPause");
      
      // Only update session time if we have a valid pause time AND the timeout exceeded
      if (timeOfPause != null && now.difference(timeOfPause) > _sessionTimeout) {
        // Update the in-memory variable directly.
        sessionStartTime = now;
        _log.log(Level.INFO, "Session timeout exceeded. New session started at: ${sessionStartTime!.toIso8601String()}");
      } else if (timeOfPause != null) {
        _log.log(Level.INFO, "Session continues (pause was ${now.difference(timeOfPause).inSeconds}s, timeout is ${_sessionTimeout.inSeconds}s)");
      } else {
        _log.log(Level.INFO, "App resumed without tracked pause. Continuing existing session started at: ${sessionStartTime?.toIso8601String()}");
      }
      break;
    case null:
      break;
  }
}

  void attachLifecycleNotifier(ValueNotifier<AppLifecycleState> notifier) {
    _lifecycleNotifier?.removeListener(_onAppLifecycleStateChanged);
    _lifecycleNotifier = notifier;
    _lifecycleNotifier?.addListener(_onAppLifecycleStateChanged);
  }

  Future<void> loadStateFromPersistence() async {
    if (sessionStartTime == null) {
      sessionStartTime = DateTime.now().toUtc();
      _log.log(
        Level.INFO,
        "Initial sessionStartTime set: ${sessionStartTime!.toIso8601String()}",
      );
    }
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

  @override
  void dispose() {
    super.dispose();
    _lifecycleNotifier?.removeListener(_onAppLifecycleStateChanged);
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

    final installTime = await _persistence.getAppInstallTime();
    if (installTime == null) {
      return false;
    }

    final minutes = FirebaseRemoteConfig.instance.getInt(
      C.minutesBeforeReviewTag,
    );

    if (now.difference(installTime).inMinutes < minutes) {
      return false;
    }

    final lastAskTime = await _persistence.getLastReviewAskTime();
    if (lastAskTime == null) {
      await _persistence.saveLastReviewAskTime();
      return true;
    }

    final days = FirebaseRemoteConfig.instance.getInt(C.dayBeforeReviewTag);

    if (now.difference(lastAskTime).inDays >= days) {
      await _persistence.saveLastReviewAskTime();
      return true;
    }
    return false;
  }
}
