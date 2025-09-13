import 'package:flutter/material.dart';
import 'package:operation_sunrise/data/hint.dart';
import 'package:operation_sunrise/data/level_info.dart';

class GameController extends ChangeNotifier {
  final LevelInfo levelInfo;

  final String displaySolution;
  final List<String> _userInput = [];
  late final int puzzleLength;

  List<Hint> availableHints = [];

  GameController({required this.levelInfo}) : displaySolution = levelInfo.name {
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

  void onLetterTapped(String letter) {
    if (_userInput.length < puzzleLength) {
      _userInput.add(letter);
      notifyListeners();
      _checkWinCondition();
    }
  }

  void onBackspaceTapped() {
    if (_userInput.isNotEmpty) {
      _userInput.removeLast();
      notifyListeners();
    }
  }

  void onClearAllTapped() {
    _userInput.clear();
    notifyListeners();
  }

 // NEW: A single, generic method to reveal a hint by its index.
  void revealHintByIndex(int index) {
    // Check if the hint exists and if it hasn't already been used.
    if (index < availableHints.length && !availableHints[index].isRevealed) {
      availableHints[index].isRevealed = true;
      notifyListeners(); // Tell the UI to update
    }
  }

  // --- Private Logic ---
  void _checkWinCondition() {
    if (_userInput.length == puzzleLength) {
      String userInputString = _userInput.join('');
      String solutionString = displaySolution.replaceAll(' ', '');

      if (userInputString == solutionString) {
        print("Congratulations! You won!");
      }
    }
  }
}
