// controllers/level_controller.dart

import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:operation_sunrise/data/settings_controller.dart';
import 'package:operation_sunrise/data/level_info.dart';

class LevelController extends ChangeNotifier {
  final Logger _log = Logger('level_controller.dart');

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SettingsController _settingsController;
  late StreamSubscription<QuerySnapshot> _levelsSubscription;

  final Completer<void> _initialLoadCompleter = Completer<void>();
  Future<void> get initializationComplete => _initialLoadCompleter.future;

  List<LevelInfo> levels = [];
  String? _error;
  int _currentLevelIndex = 0;
  int? _pendingLevelNumberToOpen;
  LevelInfo? lastLevelAdded;

  String? get error => _error;
  LevelInfo? get currentLevel =>
      levels.isNotEmpty ? levels[_currentLevelIndex] : null;

  LevelController({required SettingsController settingsController})
    : _settingsController = settingsController {
    _listenToLevels();
  }

  void _listenToLevels() {
    _levelsSubscription = _db
        .collection('levels')
        .orderBy('levelNumber')
        .snapshots()
        .listen(
          (snapshot) {
            // --- KEY CHANGE IS HERE ---
            // Instead of rebuilding the whole list from scratch, we process
            // the individual changes that Firestore tells us about.
            for (var change in snapshot.docChanges) {
              switch (change.type) {
                case DocumentChangeType.added:
                  final newLevel = LevelInfo.fromFirestore(change.doc);

                  // --- THIS IS THE FIX ---
                  // We only want to treat this as a "special event" if the initial
                  // load of levels is already complete.
                  if (_initialLoadCompleter.isCompleted) {
                    // This is a TRUE new level that was added while the app was running.
                    lastLevelAdded = newLevel; // Or fire your Stream event here
                  } else {
                    // This is just part of the initial data load.
                  }

                  // IMPORTANT: We always add the level to our local list,
                  // regardless of whether it's an initial load or a new addition.
                  levels.add(newLevel);
                  break;

                case DocumentChangeType.modified:
                  // (This logic remains the same)
                  final modifiedLevel = LevelInfo.fromFirestore(change.doc);
                  final index = levels.indexWhere(
                    (l) => l.id == modifiedLevel.id,
                  );
                  if (index != -1) {
                    levels[index] = modifiedLevel;
                  }
                  break;

                case DocumentChangeType.removed:
                  // (This logic remains the same)
                  final removedLevel = LevelInfo.fromFirestore(change.doc);
                  levels.removeWhere((l) => l.id == removedLevel.id);
                  break;
              }
            }

            levels.sort((a, b) => a.levelNumber.compareTo(b.levelNumber));

            _error = null;

            // Your existing logic for completing the completer is perfect.
            // It runs AFTER the loop above has processed the first batch.
            if (!_initialLoadCompleter.isCompleted) {
              _initialLoadCompleter.complete();
            }

            // (The rest of your method remains the same)
            // A pending notification-tap navigation always wins — the cached
            // level list is complete enough to navigate. The old !isFromCache
            // gate waited for a server snapshot that never fires when the
            // data is unchanged, so cold-start taps landed on the last
            // played level instead.
            if (_processPendingLevel()) {
            } else {
              _findInitialLevel();
            }
            notifyListeners();
          },
          onError: (e) {
            _error = "Failed to connect to levels data.";
            if (!_initialLoadCompleter.isCompleted) {
              _initialLoadCompleter.completeError(e);
            }
            notifyListeners();
          },
        );
  }

  // --- No other changes are needed in the rest of the file ---

  bool _processPendingLevel() {
    if (_pendingLevelNumberToOpen != null && levels.isNotEmpty) {
      final index = levels.indexWhere(
        (level) => level.levelNumber == _pendingLevelNumberToOpen,
      );
      if (index != -1) {
        _currentLevelIndex = index;
        _pendingLevelNumberToOpen = null;
        return true;
      }
    }
    return false;
  }

  void _findInitialLevel() {
    if (levels.isEmpty) return;
    final lastLevelNum = _settingsController.lastPlayedLevelNumber;
    final index = levels.indexWhere(
      (level) => level.levelNumber == lastLevelNum,
    );
    _currentLevelIndex = (index != -1) ? index : 0;
  }

  void selectLevelByNumber(int levelNumber) {
    if (levels.isEmpty) return;
    final index = levels.indexWhere(
      (level) => level.levelNumber == levelNumber,
    );
    if (index != -1 && _currentLevelIndex != index) {
      _currentLevelIndex = index;
      notifyListeners();
    }
  }

  LevelInfo? advanceFrom(int completedLevelNumber) {
    final completedIndex = levels.indexWhere(
      (level) => level.levelNumber == completedLevelNumber,
    );

    // Progress write-through: lets the agent see how far each player got
    // (who is stuck, who finished the fresh content). Merge into the same
    // per-uid doc the push token lives in; best-effort.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && !kIsWeb) {
      final col = Platform.isIOS ? 'fcmTokensIos' : 'fcmTokensAndroid';
      FirebaseFirestore.instance.collection(col).doc(uid).set({
        'lastLevel': completedLevelNumber,
        'lastLevelAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).catchError((_) {});
    }

    // Check if the completed level was found and if a next level exists.
    if (completedIndex != -1 && completedIndex + 1 < levels.length) {
      // IMPORTANT: Update the master state to the new index.
      _currentLevelIndex = completedIndex + 1;

      // Notify listeners so other parts of the UI (like the level select screen) are aware.
      notifyListeners();

      // Return the data for the new, current level.
      return levels[_currentLevelIndex];
    }

    // No next level was found.
    return null;
  }

  Future<void> setupFCMListeners() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();

    RemoteMessage? initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // Cold-start fallback: the plugin's initial message is racy (another
    // getInitialMessage call may have consumed it, or the tap event fired
    // while the engine was still booting). MainActivity captured levelNumber
    // straight from the launch intent; fetch it here, where the platform
    // channel is guaranteed to be registered.
    try {
      final n = await const MethodChannel('stagenator/claim')
          .invokeMethod<String>('getPendingLevelNumber');
      final levelNumber = n == null ? null : int.tryParse(n);
      if (levelNumber != null) {
        _pendingLevelNumberToOpen = levelNumber;
        if (_processPendingLevel()) notifyListeners();
      }
    } catch (_) {
      // iOS / channel unavailable — plugin paths handle what they can
    }

    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {});
    await messaging.subscribeToTopic('new_levels');
  }

  void _handleNotificationTap(RemoteMessage message) {
    final levelNumberString = message.data['levelNumber'];
    if (levelNumberString != null) {
      final levelNumber = int.tryParse(levelNumberString);
      if (levelNumber != null) {
        _pendingLevelNumberToOpen = levelNumber;
        // Consume immediately when the level list is already loaded — the
        // snapshot listener only runs on data changes, so a tap while the
        // app is alive would otherwise never navigate.
        if (_processPendingLevel()) notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _levelsSubscription.cancel();
    super.dispose();
  }
}
