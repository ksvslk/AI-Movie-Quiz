// game_screen.dart
import 'package:flutter/material.dart';
import 'package:operation_sunrise/concentric_letter_circle.dart';
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
  final String _displaySolution = 'THE LORD OF THE RINGS: THE FELLOWSHIP OF THE RING';
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

  /// Calculates the largest possible box size that allows the solution to fit in maxLines.
  double _calculateOptimalBoxSize({
    required double availableWidth,
    required String solution,
    required double spacing,
    int maxLines = 3,
  }) {
    const double maxBoxSize = 40.0; // The largest size we want
    const double minBoxSize = 10.0; // The smallest size we'll allow
    const double step = 0.5;      // How much to shrink the size in each iteration

    for (double currentSize = maxBoxSize; currentSize >= minBoxSize; currentSize -= step) {
      int lines = 1;
      double currentLineWidth = 0.0;
      final double spaceCharWidth = currentSize * 0.4; // Width of a space between words

      for (int i = 0; i < solution.length; i++) {
        final char = solution[i];
        final isSpace = char == ' ';
        final itemWidth = isSpace ? spaceCharWidth : currentSize;
        
        // If it's not the first item on the line, add spacing
        final double widthWithSpacing = (currentLineWidth == 0.0) ? itemWidth : itemWidth + spacing;

        if (currentLineWidth + widthWithSpacing > availableWidth) {
          lines++;
          currentLineWidth = itemWidth; // Start a new line
        } else {
          currentLineWidth += widthWithSpacing;
        }
      }

      // If it fits within the max lines, we found our optimal size
      if (lines <= maxLines) {
        return currentSize;
      }
    }
    
    // If even the smallest size doesn't fit, return the smallest size as a fallback.
    return minBoxSize;
  }

  Widget _buildSolutionField(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const double horizontalPadding = 16.0;
    const double spacing = 6.0;
    const double runSpacing = 8.0;

    // 1. Calculate the available width for the Wrap widget
    final double availableWidth = screenWidth - (horizontalPadding * 2);

    // 2. Proactively calculate the best box size to fit within 3 lines
    final double boxSize = _calculateOptimalBoxSize(
      availableWidth: availableWidth,
      solution: _displaySolution,
      spacing: spacing,
      maxLines: 3,
    );

    List<Widget> solutionWidgets = [];
    int userInputIndex = 0;

    for (int i = 0; i < _displaySolution.length; i++) {
      String char = _displaySolution[i];

      if (char == ' ') {
        solutionWidgets.add(SizedBox(width: boxSize * 0.4));
      } else {
        bool isFilled = userInputIndex < _userInput.length;
        
        solutionWidgets.add(
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
              isFilled ? _userInput[userInputIndex] : '',
              style: TextStyle(
                color: Colors.white,
                fontSize: boxSize * 0.6,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
        userInputIndex++;
      }
    }
    
    // We no longer need the Container with constraints.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: horizontalPadding),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: runSpacing,
        spacing: spacing,
        children: solutionWidgets,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ... The rest of your build method remains unchanged ...
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(widget.levelName),
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
                    onLetterTapped: _onLetterTapped,
                    onBackspaceTapped: _onBackspaceTapped,
                    onClearAllTapped: _onClearAllTapped, onShiftTapped: () { print("aa"); }, onSymbolsTapped: () { print("bb"); }, onSpaceTapped: () { print("cc"); },
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