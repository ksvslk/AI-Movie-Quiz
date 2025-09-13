// game_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:operation_sunrise/change_notifier/ads_controller.dart';
import 'package:operation_sunrise/change_notifier/game_controller.dart';
import 'package:operation_sunrise/change_notifier/level_controller.dart';
import 'package:operation_sunrise/concentric_letter_circle.dart';
import 'package:operation_sunrise/data/level_info.dart';
import 'package:operation_sunrise/menu/menu_drawer.dart';
import 'dart:math';
import 'package:provider/provider.dart';
import 'level_video_player.dart';

class GameScreen extends StatefulWidget {
  final LevelInfo levelInfo;

  const GameScreen({super.key, required this.levelInfo});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameController _gameController;
  static const int HINT_MAX_LENGTH_ON_ARC = 12;

  int _animatedCorrectChars = 0;
  Timer? _greenAnimationTimer;
  bool _isAnimatingSuccess = false;

  void _goToNextLevel() {
    final levelController = context.read<LevelController>();
    final nextLevel = levelController.advanceFrom(widget.levelInfo.levelNumber);

    if (nextLevel == null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Congratulations!'),
          content: const Text('You have completed all levels.'),
          actions: [
            TextButton(
              child: const Text('MAIN MENU'),
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ],
        ),
      );
    }
  }

  void _onGameControllerUpdate() {
    if (_gameController.isSolved && !_isAnimatingSuccess && mounted) {
      setState(() {
        _isAnimatingSuccess = true;
      });
      _startGreenAnimation();
    }
  }

  void _startGreenAnimation() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      const animationSpeed = Duration(milliseconds: 60);
      _greenAnimationTimer = Timer.periodic(animationSpeed, (timer) {
        if (_animatedCorrectChars >= _gameController.userInput.length) {
          timer.cancel();
        } else {
          if (mounted) {
            setState(() {
              _animatedCorrectChars++;
            });
          }
        }
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _gameController = GameController(levelInfo: widget.levelInfo);
    _gameController.addListener(_onGameControllerUpdate);
  }

  @override
  void didUpdateWidget(covariant GameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.levelInfo.id != oldWidget.levelInfo.id) {
      _greenAnimationTimer?.cancel();
      _gameController.removeListener(_onGameControllerUpdate);
      _gameController.dispose();

      _gameController = GameController(levelInfo: widget.levelInfo);
      _gameController.addListener(_onGameControllerUpdate);

      setState(() {
        _animatedCorrectChars = 0;
        _isAnimatingSuccess = false;
      });
    }
  }

  @override
  void dispose() {
    _greenAnimationTimer?.cancel();
    _gameController.removeListener(_onGameControllerUpdate);
    _gameController.dispose();
    super.dispose();
  }

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

  void _onHintTapped(int index) {
    final ads = context.read<AdsController>();
    final game = _gameController;

    if (index >= game.availableHints.length) return;

    final hint = game.availableHints[index];

    if (hint.isRevealed) {
      if (hint.value.length > HINT_MAX_LENGTH_ON_ARC) {
        _showHintPopup(context, hint.label, hint.value);
      }
    } else if (ads.isAdAvailable()) {
      ads.showRewardedAd(() {
        game.revealHintByIndex(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Hint not available right now. Please try again later.',
          ),
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
                      padding: const EdgeInsets.all(24.0),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final size = min(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );

                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 500),
                            switchInCurve: Curves.easeInOut,
                            switchOutCurve: Curves.easeInOut,
                            transitionBuilder: (Widget child, Animation<double> animation) {
                              // Simple fade transition
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                            child: controller.isSolved
                                ? Center(
                                    key: const ValueKey('solved'),
                                    child: GestureDetector(
                                      onTap: _goToNextLevel,
                                      child: SizedBox(
                                        width: size,
                                        height: size,
                                        child: Lottie.asset(
                                          'assets/animation/success.json',
                                          repeat: false,
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    key: const ValueKey('unsolved'),
                                    child: ConcentricLetterCircle(
                                      onLetterTapped: controller.onLetterTapped,
                                      onBackspaceTapped:
                                          controller.onBackspaceTapped,
                                      onClearAllTapped:
                                          controller.onClearAllTapped,
                                      onSymbolsTapped: () => _onHintTapped(0),
                                      onShiftTapped: () => _onHintTapped(1),
                                      onSpaceTapped: () => _onHintTapped(2),
                                      onHintTapped: () {},
                                    ),
                                  ),
                          );
                        },
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
        floatingActionButtonLocation:
            FloatingActionButtonLocation.miniEndDocked,
      ),
    );
  }

  Widget _buildSolutionField(BuildContext context, GameController controller) {
    final screenWidth = MediaQuery.of(context).size.width;
    const double horizontalPadding = 16.0;
    final double availableWidth = screenWidth - (horizontalPadding * 2);
    const double spacing = 5.0;
    const double runSpacing = 8.0;
    final List<String> words = controller.displaySolution.split(' ');
    final List<String> userInput = controller.userInput;
    final double boxSize = _calculateOptimalBoxSizeForWords(
      availableWidth: availableWidth,
      words: words,
      spacing: spacing,
    );
    final List<Widget> lineWidgets = [];
    int processedCharCount = 0;
    List<String> currentLineWords = [];
    double currentLineWidth = 0;
    final double spaceWidth = boxSize * 0.4;
    for (final String word in words) {
      final double wordWidth =
          (word.length * boxSize) + (max(0, word.length - 1) * spacing);
      final double prospectiveWidth = (currentLineWords.isEmpty)
          ? wordWidth
          : currentLineWidth + spaceWidth + wordWidth;
      if (currentLineWords.isNotEmpty && prospectiveWidth > availableWidth) {
        lineWidgets.add(
          _buildLineWidget(
            words: currentLineWords,
            boxSize: boxSize,
            spacing: spacing,
            userInput: userInput,
            startIndex: processedCharCount,
            isSolved: controller.isSolved,
            animatedCorrectChars: _animatedCorrectChars,
          ),
        );
        processedCharCount += currentLineWords.join().length;
        currentLineWords = [word];
        currentLineWidth = wordWidth;
      } else {
        currentLineWords.add(word);
        currentLineWidth = prospectiveWidth;
      }
    }
    if (currentLineWords.isNotEmpty) {
      lineWidgets.add(
        _buildLineWidget(
          words: currentLineWords,
          boxSize: boxSize,
          spacing: spacing,
          userInput: userInput,
          startIndex: processedCharCount,
          isSolved: controller.isSolved,
          animatedCorrectChars: _animatedCorrectChars,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8.0,
        horizontal: horizontalPadding,
      ),
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

  double _calculateOptimalBoxSizeForWords({
    required double availableWidth,
    required List<String> words,
    required double spacing,
    int maxLines = 3,
  }) {
    const double maxBoxSize = 35.0;
    const double minBoxSize = 10.0;
    const double step = 0.5;
    for (
      double currentSize = maxBoxSize;
      currentSize >= minBoxSize;
      currentSize -= step
    ) {
      int lines = 1;
      double currentLineWidth = 0.0;
      final double spaceWidth = currentSize * 0.4;
      for (final word in words) {
        final double wordWidth =
            (word.length * currentSize) + (max(0, word.length - 1) * spacing);
        if (wordWidth > availableWidth) {
          lines = maxLines + 1;
          break;
        }
        final double prospectiveWidth = (currentLineWidth == 0.0)
            ? wordWidth
            : currentLineWidth + spaceWidth + wordWidth;
        if (prospectiveWidth > availableWidth) {
          lines++;
          currentLineWidth = wordWidth;
        } else {
          currentLineWidth = prospectiveWidth;
        }
      }
      if (lines <= maxLines) {
        return currentSize;
      }
    }
    return minBoxSize;
  }

  // FIXED: Box decoration stays consistent during letter animations
  Widget _buildLineWidget({
    required List<String> words,
    required double boxSize,
    required double spacing,
    required List<String> userInput,
    required int startIndex,
    required bool isSolved,
    required int animatedCorrectChars,
  }) {
    List<Widget> wordWidgets = [];
    int currentInputIndex = startIndex;
    
    for (int i = 0; i < words.length; i++) {
      final String word = words[i];
      for (int j = 0; j < word.length; j++) {
        bool isFilled = currentInputIndex < userInput.length;
        bool isCorrectAndAnimated = isSolved && currentInputIndex < animatedCorrectChars;
        
        // Calculate what the "stable" decoration should be based on whether there's ever been content
        bool hasContent = isFilled;

        wordWidgets.add(
          Container(
            width: boxSize,
            height: boxSize,
            decoration: isCorrectAndAnimated
                ? BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade700, Colors.green.shade500],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(boxSize * 0.2),
                  )
                : hasContent
                    ? BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blueGrey.shade700,
                            Colors.blueGrey.shade600,
                          ],
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
            child: ClipRect(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200), // Faster animation
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  // Simpler transition - just opacity, no sliding
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                child: isFilled
                    ? Text(
                        key: ValueKey('letter_${userInput[currentInputIndex]}_$currentInputIndex'),
                        userInput[currentInputIndex],
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: boxSize * 0.6,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : SizedBox(key: ValueKey('empty_$currentInputIndex')),
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
}