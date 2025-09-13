// game_screen.dart

import 'package:flutter/material.dart';
// NEW: Import the AdsController to interact with it.
import 'package:operation_sunrise/change_notifier/ads_controller.dart';
import 'package:operation_sunrise/change_notifier/game_controller.dart';
import 'package:operation_sunrise/concentric_letter_circle.dart';
import 'package:operation_sunrise/data/level_info.dart';
import 'package:operation_sunrise/menu/menu_drawer.dart';
import 'dart:math';
import 'package:provider/provider.dart';
import 'level_video_player.dart';

class GameScreen extends StatefulWidget {
  final LevelInfo levelInfo;

  const GameScreen({
    super.key,
    required this.levelInfo,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameController _gameController;
  // NEW: A character limit to decide if a hint is "long" and needs a popup.
  static const int HINT_MAX_LENGTH_ON_ARC = 12;

  @override
  void initState() {
    super.initState();
    _gameController = GameController(levelInfo: widget.levelInfo);
  }

  @override
  void didUpdateWidget(covariant GameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.levelInfo.id != oldWidget.levelInfo.id) {
      _gameController.dispose();
      setState(() {
        _gameController = GameController(levelInfo: widget.levelInfo);
      });
    }
  }

  @override
  void dispose() {
    _gameController.dispose();
    super.dispose();
  }

  // NEW: Helper function to show a popup for long hints.
  void _showHintPopup(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title.toUpperCase()),
        content: Text(content),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // NEW: The coordinated tap handler for all hint buttons.
  void _onHintTapped(int index) {
    // Use context.read inside a callback to get the controllers.
    //final game = context.read<GameController>();
    final ads = context.read<AdsController>();
  // NEW AND CORRECT WAY:
    final game = _gameController;
    
    // Ensure the hint exists before proceeding.
    if (index >= game.availableHints.length) return;

    final hint = game.availableHints[index];

    if (hint.isRevealed) {
      // If the hint is already revealed and is long, show it in a popup.
      if (hint.value.length > HINT_MAX_LENGTH_ON_ARC) {
        _showHintPopup(context, hint.label, hint.value);
      }
      // If it's revealed and short, tapping does nothing.
    } else if (ads.isAdAvailable()) {
      // If the hint is not revealed and an ad is ready, show the ad.
      // The reward callback will then be triggered to reveal the hint.
      ads.showRewardedAd(() {
        game.revealHintByIndex(index);
      });
    } else {
      // If no ad is available, inform the user and try to load another ad.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hint not available right now. Please try again later.'),
          duration: Duration(seconds: 2),
        ),
      );
      ads.reloadRewardedAd();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _gameController,
      child: Scaffold(
        drawer: const MenuDrawer(),
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Consumer<GameController>(
            builder: (context, controller, child) {
              return Column(
                children: [
                  Expanded(
                    flex: 4,
                    child: LevelVideoPlayer(videoPath: widget.levelInfo.path),
                  ),
                  _buildSolutionField(context, controller),
                  Expanded(
                    flex: 5,
                    child: Container(
                      color: Colors.black,
                      padding: const EdgeInsets.all(2.0),
                      child: Center(
                        child: ConcentricLetterCircle(
                          onLetterTapped: controller.onLetterTapped,
                          onBackspaceTapped: controller.onBackspaceTapped,
                          onClearAllTapped: controller.onClearAllTapped,
                          // MODIFIED: All hint taps now go through the new handler.
                          onSymbolsTapped: () => _onHintTapped(0),
                          onShiftTapped: () => _onHintTapped(1),
                          onSpaceTapped: () => _onHintTapped(2),
                          onHintTapped: () {},
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        floatingActionButton: Builder(
          builder: (BuildContext scaffoldContext) {
            return FloatingActionButton(
              elevation: 4.0,
              mini: true,
              onPressed: () {
                Scaffold.of(scaffoldContext).openDrawer();
              },
              child: const Icon(Icons.settings),
            );
          },
        ),
        drawerEnableOpenDragGesture: false,
        endDrawerEnableOpenDragGesture: false,
        floatingActionButtonLocation: FloatingActionButtonLocation.miniEndDocked,
      ),
    );
  }

  // Helper methods below are unchanged and required for the build method
  Widget _buildSolutionField(BuildContext context, GameController controller) {
    final screenWidth = MediaQuery.of(context).size.width;
    const double horizontalPadding = 16.0;
    final double availableWidth = screenWidth - (horizontalPadding * 2);
    const double spacing = 5.0;
    const double runSpacing = 8.0;
    final List<String> words = controller.displaySolution.split(' ');
    final List<String> userInput = controller.userInput;
    final double boxSize = _calculateOptimalBoxSizeForWords(availableWidth: availableWidth, words: words, spacing: spacing,);
    final List<Widget> lineWidgets = [];
    int processedCharCount = 0;
    List<String> currentLineWords = [];
    double currentLineWidth = 0;
    final double spaceWidth = boxSize * 0.4;
    for (final String word in words) {
      final double wordWidth = (word.length * boxSize) + (max(0, word.length - 1) * spacing);
      final double prospectiveWidth = (currentLineWords.isEmpty) ? wordWidth : currentLineWidth + spaceWidth + wordWidth;
      if (currentLineWords.isNotEmpty && prospectiveWidth > availableWidth) {
        lineWidgets.add(_buildLineWidget(words: currentLineWords, boxSize: boxSize, spacing: spacing, userInput: userInput, startIndex: processedCharCount,),);
        processedCharCount += currentLineWords.join().length;
        currentLineWords = [word];
        currentLineWidth = wordWidth;
      } else {
        currentLineWords.add(word);
        currentLineWidth = prospectiveWidth;
      }
    }
    if (currentLineWords.isNotEmpty) {
      lineWidgets.add(_buildLineWidget(words: currentLineWords, boxSize: boxSize, spacing: spacing, userInput: userInput, startIndex: processedCharCount,),);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: horizontalPadding,),
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
  
  double _calculateOptimalBoxSizeForWords({required double availableWidth, required List<String> words, required double spacing, int maxLines = 3,}) {
    const double maxBoxSize = 35.0;
    const double minBoxSize = 10.0;
    const double step = 0.5;
    for (double currentSize = maxBoxSize; currentSize >= minBoxSize; currentSize -= step) {
      int lines = 1;
      double currentLineWidth = 0.0;
      final double spaceWidth = currentSize * 0.4;
      for (final word in words) {
        final double wordWidth = (word.length * currentSize) + (max(0, word.length - 1) * spacing);
        if (wordWidth > availableWidth) { lines = maxLines + 1; break; }
        final double prospectiveWidth = (currentLineWidth == 0.0) ? wordWidth : currentLineWidth + spaceWidth + wordWidth;
        if (prospectiveWidth > availableWidth) { lines++; currentLineWidth = wordWidth; } else { currentLineWidth = prospectiveWidth; }
      }
      if (lines <= maxLines) { return currentSize; }
    }
    return minBoxSize;
  }

  Widget _buildLineWidget({required List<String> words, required double boxSize, required double spacing, required List<String> userInput, required int startIndex,}) {
    List<Widget> wordWidgets = [];
    int currentInputIndex = startIndex;
    for (int i = 0; i < words.length; i++) {
      final String word = words[i];
      for (int j = 0; j < word.length; j++) {
        bool isFilled = currentInputIndex < userInput.length;
        wordWidgets.add(Container(width: boxSize, height: boxSize,
            decoration: isFilled ? BoxDecoration(gradient: LinearGradient(colors: [Colors.blueGrey.shade700, Colors.blueGrey.shade600,], begin: Alignment.topCenter, end: Alignment.bottomCenter,), borderRadius: BorderRadius.circular(boxSize * 0.2),) : BoxDecoration(color: Colors.grey.shade800, border: Border.all(color: Colors.grey.shade600), borderRadius: BorderRadius.circular(boxSize * 0.2),),
            alignment: Alignment.center,
            child: Text(isFilled ? userInput[currentInputIndex] : '', style: TextStyle(color: Colors.white, fontSize: boxSize * 0.6, fontWeight: FontWeight.bold,),),),);
        currentInputIndex++;
        if (j < word.length - 1) { wordWidgets.add(SizedBox(width: spacing)); }
      }
      if (i < words.length - 1) { wordWidgets.add(SizedBox(width: boxSize * 0.4)); }
    }
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: wordWidgets,);
  }
}