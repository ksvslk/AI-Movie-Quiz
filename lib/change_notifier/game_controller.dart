// game_controller.dart

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:operation_sunrise/audio/audio_controller.dart';
import 'package:operation_sunrise/audio/sounds.dart';
import 'package:operation_sunrise/data/hint.dart';
import 'package:operation_sunrise/data/level_info.dart';
import 'package:operation_sunrise/data/settings_controller.dart';

class GameController extends ChangeNotifier {
  final LevelInfo levelInfo;
  final AudioController audioController;
  final SettingsController settingsController; // 2. Change dependency
  
  final String displaySolution;
  final List<String> _userInput = [];
  late final int puzzleLength;

  bool _isSolved = false;
  DateTime? _levelStartTime;

  List<Hint> availableHints = [];

  GameController({required this.levelInfo, required this.audioController, required this.settingsController})
    : displaySolution = levelInfo.name {
    puzzleLength = displaySolution.replaceAll(' ', '').length;
    _initializeHints();
    _trackLevelStart();
  }

  void _initializeHints() {
    levelInfo.hints.forEach((key, value) {
      availableHints.add(
        Hint(
          label: key.toUpperCase(),
          value: value.toString(), // Ensure value is a string
        ),
      );
    });
  }

  Future<void> _trackLevelStart() async {
    _levelStartTime = DateTime.now();
    await trackLevelBegin(levelInfo.levelNumber);
  }

  List<String> get userInput => _userInput;

  bool get isSolved => _isSolved;

  void onLetterTapped(String letter) {
    if (_userInput.length < puzzleLength) {
      _userInput.add(letter);
      _checkWinCondition();
      notifyListeners();
    }
  }

  void onBackspaceTapped() {
    if (_userInput.isNotEmpty) {
      _userInput.removeLast();
      _isSolved = false;
      notifyListeners();
    }
  }

  void onClearAllTapped() {
    _userInput.clear();
    _isSolved = false;
    notifyListeners();
  }

  void revealHintByIndex(int index, {bool playSound = true}) {
    if (index < availableHints.length && !availableHints[index].isRevealed) {
      availableHints[index].isRevealed = true;
      notifyListeners();
    }
  }

  void _checkWinCondition() {
    if (_userInput.length == puzzleLength && !_isSolved) {
      String userInputString = _userInput.join('');
      String solutionString = displaySolution.replaceAll(' ', '');

      if (userInputString.toLowerCase() == solutionString.toLowerCase()) {
        settingsController.markLevelAsCompleted(levelInfo.levelNumber);
        _trackLevelComplete();
        playWinSound();
        _isSolved = true;
      }
    }
  }

  Future<void> _trackLevelComplete() async {
    int timeTakenSeconds = 0;
    if (_levelStartTime != null) {
      timeTakenSeconds = DateTime.now().difference(_levelStartTime!).inSeconds;
    }
    
    await trackLevelFinish(
      levelInfo.levelNumber, 
      timeTakenSeconds
    );
  }

  void playWinSound() {
    audioController.playSfx(SfxType.impact);
    if (levelInfo.sound == 'action') {
      audioController.playSfx(SfxType.action);
    } else if (levelInfo.sound == 'adventure') {
      audioController.playSfx(SfxType.adventure);
    } else if (levelInfo.sound == 'comedy') {
      audioController.playSfx(SfxType.comedy);
    } else if (levelInfo.sound == 'drama') {
      audioController.playSfx(SfxType.drama);
    } else if (levelInfo.sound == 'fantasy') {
      audioController.playSfx(SfxType.fantasy);
    } else if (levelInfo.sound == 'horror') {
      audioController.playSfx(SfxType.horror);
    } else if (levelInfo.sound == 'mystery') {
      audioController.playSfx(SfxType.mystery);
    } else if (levelInfo.sound == 'romance') {
      audioController.playSfx(SfxType.romance);
    } else if (levelInfo.sound == 'scifi') {
      audioController.playSfx(SfxType.scifi);
    } else if (levelInfo.sound == 'thriller') {
      audioController.playSfx(SfxType.thriller);
    } else if (levelInfo.sound == 'war') {
      audioController.playSfx(SfxType.war);
    }
  }

  Future<void> trackLevelBegin(int? levelNumber) async {
    if (levelNumber == null) return;
    await FirebaseAnalytics.instance.logEvent(
      name: 'level_begin',
      parameters: {
        'level_number': levelNumber,
      },
    );
  }

  Future<void> trackLevelFinish(int? levelNumber, int timeTaken) async {
    if (levelNumber == null) return;
    await FirebaseAnalytics.instance.logEvent(
      name: 'level_finish',
      parameters: {
        'level_number': levelNumber,
        'time_taken': timeTaken,
      },
    );
  }
  
}
