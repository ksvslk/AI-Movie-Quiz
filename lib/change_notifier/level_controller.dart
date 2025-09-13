// controllers/level_controller.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:operation_sunrise/data/settings_controller.dart';
import 'package:operation_sunrise/data/level_info.dart';

class LevelController extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SettingsController _settingsController;
  late StreamSubscription<QuerySnapshot> _levelsSubscription;

  final Completer<void> _initialLoadCompleter = Completer<void>();
  Future<void> get initializationComplete => _initialLoadCompleter.future;

  List<LevelInfo> levels = [];
  String? _error;
  int _currentLevelIndex = 0;
  int? _pendingLevelNumberToOpen;

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
            print("[Debug] Firestore data received. Is from cache: ${snapshot.metadata.isFromCache}");
            
            try {
              levels = snapshot.docs
                  .map((doc) => LevelInfo.fromFirestore(doc))
                  .toList();
              _error = null;

              // --- THE FIX IS HERE ---
              // If this is the first data event of any kind (cache or server),
              // we complete the future. This unlocks the UI and ends the loading screen.
              if (!_initialLoadCompleter.isCompleted) {
                _initialLoadCompleter.complete();
                print("[Debug] Initial load complete. UI is now unlocked.");
              }

              // Now, we determine which level to show.
              // We only process a pending notification link if we have fresh data from the server.
              if (!snapshot.metadata.isFromCache) {
                print("[Debug] Data is from server. Processing any pending notification taps.");
                if (_processPendingLevel()) {
                  // A pending level from a notification was found and handled.
                } else {
                  // No pending level, so fall back to the last played one.
                  _findInitialLevel();
                }
              } else {
                // If data is from cache, we don't process the pending level yet to avoid race conditions.
                // We just load the last played level based on the cached data for now.
                _findInitialLevel();
              }
              
              notifyListeners();

            } catch (e, stackTrace) {
              _error = "Error parsing level data.";
              if (!_initialLoadCompleter.isCompleted) {
                _initialLoadCompleter.completeError(e);
              }
              notifyListeners();
            }
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
    final index = levels.indexWhere((level) => level.levelNumber == lastLevelNum);
    _currentLevelIndex = (index != -1) ? index : 0;
  }
  
  void selectLevelByNumber(int levelNumber) {
    if (levels.isEmpty) return;
    final index = levels.indexWhere((level) => level.levelNumber == levelNumber);
    if (index != -1 && _currentLevelIndex != index) {
      _currentLevelIndex = index;
      notifyListeners();
    }
  }

  LevelInfo? advanceFrom(int completedLevelNumber) {
    final completedIndex = levels.indexWhere((level) => level.levelNumber == completedLevelNumber);

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
      }
    }
  }

  @override
  void dispose() {
    _levelsSubscription.cancel();
    super.dispose();
  }
}