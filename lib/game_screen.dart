// game_screen.dart

import 'package:flutter/material.dart';
import 'package:operation_sunrise/audio/audio_controller.dart';
import 'package:operation_sunrise/audio/sounds.dart';
import 'package:operation_sunrise/concentric_letter_circle.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'level_video_player.dart';

class GameScreen extends StatefulWidget {
  final String videoPath;
  final String levelName;

  const GameScreen({
    super.key,
    required this.videoPath,
    required this.levelName,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final String _displaySolution = 'The Godfather Part II';
  final List<String> _userInput = [];

  void _onLetterTapped(String letter) {
    final int puzzleLength = _displaySolution.replaceAll(' ', '').length;
    setState(() {
      if (_userInput.length < puzzleLength) {
        _userInput.add(letter);
      }
    });
  }

  void _onBackspaceTapped() {
    setState(() {
      if (_userInput.isNotEmpty) {
        _userInput.removeLast();
      }
    });
  }

  void _onClearAllTapped() {
    setState(() {
      _userInput.clear();
    });
  }

  /// Calculates the single optimal box size that allows all words to fit
  /// within a maximum number of lines.
  double _calculateOptimalBoxSizeForWords({
    required double availableWidth,
    required List<String> words,
    required double spacing,
    int maxLines = 3,
  }) {
    const double maxBoxSize = 30.0;
    const double minBoxSize = 10.0;
    const double step = 0.5;

    for (double currentSize = maxBoxSize; currentSize >= minBoxSize; currentSize -= step) {
      int lines = 1;
      double currentLineWidth = 0.0;
      final double spaceWidth = currentSize * 0.4;

      for (final word in words) {
        final double wordWidth = (word.length * currentSize) + (max(0, word.length - 1) * spacing);

        // This check handles cases where a single word is too long for the screen
        if (wordWidth > availableWidth) {
          lines = maxLines + 1; // Mark as invalid
          break;
        }

        final double prospectiveWidth = (currentLineWidth == 0.0) ? wordWidth : currentLineWidth + spaceWidth + wordWidth;

        if (prospectiveWidth > availableWidth) {
          lines++;
          currentLineWidth = wordWidth; // Start a new line
        } else {
          currentLineWidth = prospectiveWidth;
        }
      }

      if (lines <= maxLines) {
        return currentSize; // This is the largest size that fits, so it's optimal.
      }
    }
    return minBoxSize; // Fallback if no size fits
  }

  /// Builds a single line (a Row widget) of letter boxes.
  Widget _buildLineWidget({
    required List<String> words,
    required double boxSize,
    required double spacing,
    required List<String> userInput,
    required int startIndex,
  }) {
    List<Widget> wordWidgets = [];
    int currentInputIndex = startIndex;

    for (int i = 0; i < words.length; i++) {
      final String word = words[i];
      for (int j = 0; j < word.length; j++) {
        bool isFilled = currentInputIndex < userInput.length;
        wordWidgets.add(
          Container(
            width: boxSize,
            height: boxSize,
            decoration: isFilled
              ? BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blueGrey.shade700, Colors.blueGrey.shade600],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(boxSize * 0.2),
                )
              : BoxDecoration(
                  color: Colors.grey.shade800,
                  border: Border.all(color: Colors.grey.shade600),
                  borderRadius: BorderRadius.circular(boxSize * 0.2),
                ),
            alignment: Alignment.center,
            child: Text(
              isFilled ? userInput[currentInputIndex] : '',
              style: TextStyle(
                color: Colors.white,
                fontSize: boxSize * 0.6,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
        currentInputIndex++;

        if (j < word.length - 1) {
          wordWidgets.add(SizedBox(width: spacing));
        }
      }

      if (i < words.length - 1) {
        wordWidgets.add(SizedBox(width: boxSize * 0.4));
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: wordWidgets,
    );
  }

  /// Lays out the solution field using a single, uniform box size for all lines.
  Widget _buildSolutionField(BuildContext context) {

    final screenWidth = MediaQuery.of(context).size.width;
    const double horizontalPadding = 16.0;
    final double availableWidth = screenWidth - (horizontalPadding * 2);
    const double spacing = 5.0;
    const double runSpacing = 8.0;

    final List<String> words = _displaySolution.split(' ');

    // 1. Calculate the single optimal size for the entire layout first.
    final double boxSize = _calculateOptimalBoxSizeForWords(
      availableWidth: availableWidth,
      words: words,
      spacing: spacing,
      maxLines: 3,
    );

    // 2. Use this single 'boxSize' to lay out the lines.
    final List<Widget> lineWidgets = [];
    int processedCharCount = 0;
    List<String> currentLineWords = [];
    double currentLineWidth = 0;
    final double spaceWidth = boxSize * 0.4;

    for (final String word in words) {
      final double wordWidth = (word.length * boxSize) + (max(0, word.length - 1) * spacing);
      final double prospectiveWidth = (currentLineWords.isEmpty) ? wordWidth : currentLineWidth + spaceWidth + wordWidth;

      if (currentLineWords.isNotEmpty && prospectiveWidth > availableWidth) {
        // Line is full. Build the widget using the uniform boxSize.
        lineWidgets.add(
          _buildLineWidget(
            words: currentLineWords,
            boxSize: boxSize,
            spacing: spacing,
            userInput: _userInput,
            startIndex: processedCharCount,
          ),
        );
        processedCharCount += currentLineWords.join().length;

        // Start a new line.
        currentLineWords = [word];
        currentLineWidth = wordWidth;
      } else {
        // Word fits. Add it to the current line.
        currentLineWords.add(word);
        currentLineWidth = prospectiveWidth;
      }
    }

    // Add the final line after the loop finishes.
    if (currentLineWords.isNotEmpty) {
      lineWidgets.add(
        _buildLineWidget(
          words: currentLineWords,
          boxSize: boxSize,
          spacing: spacing,
          userInput: _userInput,
          startIndex: processedCharCount,
        ),
      );
    }

    // The final widget is a Column of Rows.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: horizontalPadding),
      child: Column(
        children: [
          for (int i = 0; i < lineWidgets.length; i++) ...[
            lineWidgets[i],
            if (i < lineWidgets.length - 1) SizedBox(height: runSpacing),
          ],
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final audioController = context.read<AudioController>();

    void letterWasTapped(String letter) {
      audioController.playSfx(SfxType.letter);
      print("TERE");
      _onLetterTapped(letter);
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.levelName, style: const TextStyle(color: Colors.white70)),
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 4,
              child: LevelVideoPlayer(videoPath: widget.videoPath),
            ),
            
            _buildSolutionField(context),
            
            Expanded(
              flex: 5,
              child: Container(
                color: Colors.black,
                padding: const EdgeInsets.all(2.0),
                child: Center(
                  child: ConcentricLetterCircle(
                    onLetterTapped: letterWasTapped,
                    onBackspaceTapped: _onBackspaceTapped,
                    onClearAllTapped: _onClearAllTapped, 
                    onShiftTapped: () { /* Placeholder */ }, 
                    onSymbolsTapped: () { /* Placeholder */ }, 
                    onSpaceTapped: () { /* Placeholder */ },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}