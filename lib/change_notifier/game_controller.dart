// game_controller.dart

import 'package:flutter/material.dart';
import 'package:operation_sunrise/audio/audio_controller.dart';
import 'package:operation_sunrise/audio/sounds.dart';
import 'package:operation_sunrise/data/hint.dart';
import 'package:operation_sunrise/data/level_info.dart';

class GameController extends ChangeNotifier {
  final LevelInfo levelInfo;
  final AudioController audioController;

  final String displaySolution;
  final List<String> _userInput = [];
  late final int puzzleLength;

  // NEW: A boolean to track the solved state.
  bool _isSolved = false;

  List<Hint> availableHints = [];

  GameController({required this.levelInfo, required this.audioController})
    : displaySolution = levelInfo.name {
    puzzleLength = displaySolution.replaceAll(' ', '').length;
    _initializeHints();
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

  List<String> get userInput => _userInput;

  // NEW: Public getter for the UI to read the solved state.
  bool get isSolved => _isSolved;

  void onLetterTapped(String letter) {
    if (_userInput.length < puzzleLength) {
      _userInput.add(letter);
      // MODIFIED: Check win condition before notifying listeners.
      _checkWinCondition();
      notifyListeners();
    }
  }

  void onBackspaceTapped() {
    if (_userInput.isNotEmpty) {
      _userInput.removeLast();
      // MODIFIED: If the user backspaces, the puzzle is no longer solved.
      _isSolved = false;
      notifyListeners();
    }
  }

  void onClearAllTapped() {
    _userInput.clear();
    // MODIFIED: If the user clears, the puzzle is no longer solved.
    _isSolved = false;
    notifyListeners();
  }

  void revealHintByIndex(int index, {bool playSound = true}) {
    if (index < availableHints.length && !availableHints[index].isRevealed) {
      availableHints[index].isRevealed = true;
      Future.delayed(Duration(milliseconds: 500)).then((a) {
        if (playSound) audioController.playSfx(SfxType.reveal);
        notifyListeners();
      });
    }
  }

  // In game_controller.dart

  void _checkWinCondition() {
    if (_userInput.length == puzzleLength && !_isSolved) {
      String userInputString = _userInput.join('');
      String solutionString = displaySolution.replaceAll(' ', '');

      // --- DEBUGGING AND FIX ---
      // 1. Print the values to see what's being compared in your debug console.
      print("Checking win condition...");
      print("User Input: '$userInputString'");
      print("Solution:   '$solutionString'");

      // 2. Make the comparison case-insensitive by converting both to lowercase.
      if (userInputString.toLowerCase() == solutionString.toLowerCase()) {
        print(
          "SUCCESS: Strings match! Setting isSolved to true.",
        ); // <-- This should print when you win
        playWinSound();
        _isSolved = true;
      } else {
        print("FAILURE: Strings do not match.");
      }
      // --- END DEBUGGING AND FIX ---
    }
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
}
