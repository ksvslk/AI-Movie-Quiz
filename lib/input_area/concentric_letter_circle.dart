// concentric_letter_circle.dart

import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:operation_sunrise/audio/audio_controller.dart';
import 'package:operation_sunrise/audio/sounds.dart';
import 'package:operation_sunrise/change_notifier/game_controller.dart';
import 'package:operation_sunrise/change_notifier/money_controller.dart';
import 'package:operation_sunrise/input_area/quote_popup.dart';
import 'package:provider/provider.dart';

// ~~~ HELPER CLASS FOR STATIC LAYOUT CALCULATION ~~~
class _LayoutParticle {
  final String letter;
  double radius;
  Offset position;

  _LayoutParticle({
    required this.letter,
    required this.radius,
    this.position = Offset.zero,
  });
}

// ~~~ WIDGET 1: The Main ConcentricLetterCircle (FINAL STABLE LAYOUT) ~~~
class ConcentricLetterCircle extends StatefulWidget {
  final Function(String) onLetterTapped;
  final VoidCallback onBackspaceTapped;
  final VoidCallback onClearAllTapped;
  final VoidCallback onShiftTapped;
  final VoidCallback onSymbolsTapped;
  final VoidCallback onSpaceTapped;
  final VoidCallback onHintTapped;
  final String solutionString;
  final String currentUserInput;

  const ConcentricLetterCircle({
    super.key,
    required this.onLetterTapped,
    required this.onBackspaceTapped,
    required this.onClearAllTapped,
    required this.onShiftTapped,
    required this.onSymbolsTapped,
    required this.onSpaceTapped,
    required this.onHintTapped,
    required this.solutionString,
    required this.currentUserInput,
  });

  @override
  State<ConcentricLetterCircle> createState() => _ConcentricLetterCircleState();
}

class _ConcentricLetterCircleState extends State<ConcentricLetterCircle> {
  static const String _backspaceChar = '\u232B';

  // State variables for the stable layout
  List<_LayoutParticle> _particles = [];
  bool _isLayoutCalculated = false;

  late List<String> _characterSet;
  late Map<String, int> _frequencyMap;
  late int _maxFrequency;

  @override
  void initState() {
    super.initState();
    _generateCharacterData();
  }

  @override
  void didUpdateWidget(ConcentricLetterCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.solutionString != oldWidget.solutionString) {
      // New puzzle, regenerate characters and mark the layout as needing recalculation.
      _generateCharacterData();
      setState(() {
        _isLayoutCalculated = false;
      });
    }
  }

  /// Prepares the list of characters for the keyboard.
  void _generateCharacterData() {
    // Define the valid characters to extract from the solution string.
    // The hyphen '-' is at the end to be treated as a literal character.
    final validCharsRegex = RegExp(r'[A-Z0-9:,.!?-]');

    // Extract the unique, valid characters from the solution.
    // This set is now the ONLY source for the keyboard buttons.
    final uniqueSolutionChars = widget.solutionString
        .toUpperCase()
        .runes
        .map((r) => String.fromCharCode(r))
        .where((s) => validCharsRegex.hasMatch(s))
        .toSet();

    // Calculate the frequency of characters for button sizing. This is still needed.
    final frequencyMap = <String, int>{};
    for (var char in widget.solutionString.toUpperCase().runes) {
      final charStr = String.fromCharCode(char);
      if (uniqueSolutionChars.contains(charStr)) {
        frequencyMap.update(charStr, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    final maxFrequency = frequencyMap.values.fold(
      0,
      (prev, element) => max(prev, element),
    );

    // Create the character set directly from the unique solution characters.
    List<String> characterSet = uniqueSolutionChars.toList();

    // --- All filler logic has been removed. ---

    // Shuffle the required characters and add the backspace button.
    characterSet.shuffle();
    characterSet.add(_backspaceChar);

    // Update the state.
    _characterSet = characterSet;
    _frequencyMap = frequencyMap;
    _maxFrequency = maxFrequency;
  }

  /// Performs a one-time, intensive calculation to find the final static positions.
  void _calculateAndStoreLayout(
    double containerRadius,
    double averageButtonSize,
  ) {
    final List<_LayoutParticle> particles = _characterSet.map((letter) {
      double sizeMultiplier = 1.0;
      if (letter == _backspaceChar) {
        sizeMultiplier = 1.15;
      } else {
        final int frequency = _frequencyMap[letter] ?? 0;
        final double freqRatio = (_maxFrequency > 0)
            ? frequency / _maxFrequency
            : 0;
        const double baseMultiplier = 0.85;
        const double multiplierRange = 0.30;
        sizeMultiplier = baseMultiplier + (freqRatio * multiplierRange);
      }
      return _LayoutParticle(
        letter: letter,
        radius: (averageButtonSize / 2.0) * sizeMultiplier,
      );
    }).toList();

    _runPackingSimulation(particles, containerRadius);

    // Save the final layout to the state.
    setState(() {
      _particles = particles;
      _isLayoutCalculated = true;
    });
  }

  /// Runs a headless simulation to find stable, padded positions.
  void _runPackingSimulation(
    List<_LayoutParticle> particles,
    double containerRadius,
  ) {
    if (particles.isEmpty || containerRadius <= 0) return;

    const double padding = 6.0; // INCREASED PADDING
    final random = Random();
    for (var p in particles) {
      p.position = Offset.fromDirection(random.nextDouble() * 2 * pi, 1.0);
    }

    // Phase 1: Relax particles.
    int iterations = 100;
    for (int i = 0; i < iterations; i++) {
      for (int j = 0; j < particles.length; j++) {
        final p1 = particles[j];
        for (int k = j + 1; k < particles.length; k++) {
          final p2 = particles[k];
          final delta = p2.position - p1.position;
          double distance = delta.distance;
          final minDistance = p1.radius + p2.radius + padding;
          if (distance < minDistance) {
            final overlap = minDistance - distance;
            if (distance == 0.0) {
              p1.position -= Offset.fromDirection(
                random.nextDouble() * 2 * pi,
                0.1,
              );
            } else {
              final direction = delta / distance;
              p1.position -= direction * overlap * 0.5;
              p2.position += direction * overlap * 0.5;
            }
          }
        }
        p1.position *= 0.98;
      }
    }

    // Phase 2: Scale the cluster to perfectly fit.
    double clusterRadius = 0;
    for (final p in particles) {
      clusterRadius = max(clusterRadius, p.position.distance + p.radius);
    }
    if (clusterRadius > 0) {
      final double scaleFactor = containerRadius / clusterRadius;
      for (final p in particles) {
        p.position *= scaleFactor;
        p.radius *= scaleFactor;
      }
    }

    // Phase 3: Final relaxation pass.
    iterations = 50;
    for (int i = 0; i < iterations; i++) {
      for (int j = 0; j < particles.length; j++) {
        final p1 = particles[j];
        for (int k = j + 1; k < particles.length; k++) {
          final p2 = particles[k];
          final delta = p2.position - p1.position;
          double distance = delta.distance;
          final minDistance = p1.radius + p2.radius + padding;
          if (distance < minDistance) {
            final overlap = minDistance - distance;
            if (distance != 0.0) {
              final direction = delta / distance;
              p1.position -= direction * overlap * 0.5;
              p2.position += direction * overlap * 0.5;
            }
          }
        }
        if (p1.position.distance > containerRadius - p1.radius) {
          p1.position =
              p1.position /
              p1.position.distance *
              (containerRadius - p1.radius);
        }
      }
    }
  }

  Map<String, int> _calculateFrequency(String text) {
    final counts = <String, int>{};
    for (var char in text.toUpperCase().runes) {
      final charStr = String.fromCharCode(char);
      // Use the updated RegExp here as well.
      if (charStr.contains(RegExp(r'[A-Z0-9:,.!?-]'))) {
        counts.update(charStr, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final requiredCounts = _calculateFrequency(widget.solutionString);
    final usedCounts = _calculateFrequency(widget.currentUserInput);

    return LayoutBuilder(
      builder: (context, constraints) {
        const double maxDiameter = 500.0;
        final double effectiveDiameter = min(
          maxDiameter,
          min(constraints.maxWidth, constraints.maxHeight),
        );
        if (effectiveDiameter <= 0 || _characterSet.isEmpty) {
          return const SizedBox.shrink();
        }

        const double arcStrokeWidth = 36.0;
        final double totalAvailableRadius = effectiveDiameter / 2;
        final double arcRingInnerRadius = totalAvailableRadius - arcStrokeWidth;
        final double maxRadiusForLetters = arcRingInnerRadius - 12.0;

        final double averageButtonSize = max(
          30.0,
          min(effectiveDiameter / 10, 45.0),
        );

        final arcController = ArcButtonController(
          radius: totalAvailableRadius,
          strokeWidth: arcStrokeWidth,
          onShiftTapped: widget.onShiftTapped,
          onSymbolsTapped: widget.onSymbolsTapped,
          onSpaceTapped: widget.onSpaceTapped,
          onHintTapped: widget.onHintTapped,
        );

        // If layout is not calculated yet, do it once after the first frame.
        if (!_isLayoutCalculated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _calculateAndStoreLayout(maxRadiusForLetters, averageButtonSize);
            }
          });

          // Render the outer controls while the layout calculates.
          return Center(
            child: SizedBox(
              width: effectiveDiameter,
              height: effectiveDiameter,
              child: Stack(
                alignment: Alignment.center,
                children: [arcController],
              ),
            ),
          );
        }

        // If layout is ready, build the widgets from the stable particle list.
        final List<Widget> allLetterWidgets = [arcController];

        for (int i = 0; i < _particles.length; i++) {
          final particle = _particles[i];
          final isRequired = requiredCounts.containsKey(particle.letter);
          final isVisible =
              !isRequired ||
              (usedCounts[particle.letter] ?? 0) <
                  (requiredCounts[particle.letter] ?? 0);

          allLetterWidgets.add(
            Transform.translate(
              offset: particle.position,
              child: IgnorePointer(
                ignoring: !isVisible,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: isVisible ? 1.0 : 0.0,
                  child: _LetterCircleButton(
                    letter: particle.letter,
                    size: particle.radius * 2,
                    animationIndex: i, // <-- PASS THE INDEX HERE
                    onLetterTapped: widget.onLetterTapped,
                    onBackspaceTapped: widget.onBackspaceTapped,
                    onClearAllTapped: widget.onClearAllTapped,
                  ),
                ),
              ),
            ),
          );
        }

        return Center(
          child: SizedBox(
            width: effectiveDiameter,
            height: effectiveDiameter,
            child: Container(
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: Stack(
                alignment: Alignment.center,
                children: allLetterWidgets,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ~~~ WIDGET 2: A Stateful Button with an Entrance Animation ~~~
class _LetterCircleButton extends StatefulWidget {
  final String letter;
  final double size;
  final Function(String) onLetterTapped;
  final VoidCallback onBackspaceTapped;
  final VoidCallback onClearAllTapped;
  final int animationIndex; // New property for staggered animation

  static const String _backspaceChar = '\u232B';

  const _LetterCircleButton({
    super.key,
    required this.letter,
    required this.size,
    required this.onLetterTapped,
    required this.onBackspaceTapped,
    required this.onClearAllTapped,
    required this.animationIndex,
  });

  @override
  State<_LetterCircleButton> createState() => _LetterCircleButtonState();
}

class _LetterCircleButtonState extends State<_LetterCircleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut, // A fun, bouncy curve
    );

    final audioController = context.read<AudioController>();

    // Stagger the animation start time based on the index
    final delay = Duration(milliseconds: 50 + (widget.animationIndex * 40));
    Future.delayed(delay, () {
      if (mounted) {
        audioController.playSfx(SfxType.snapclick);
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isBackspace =
        widget.letter == _LetterCircleButton._backspaceChar;
    final audioController = context.read<AudioController>();

    // --- The visual code is the same, just using `widget.` to access properties ---
    final Color seatBackColor = isBackspace
        ? Colors.pink.shade800
        : Colors.redAccent.shade400;
    final Color seatBaseColor = isBackspace
        ? Colors.pink.shade900.withOpacity(0.8)
        : Colors.redAccent;
    final Color armrestColor = isBackspace
        ? Colors.pink.shade900
        : Colors.redAccent.shade700;

    final seatBackDecoration = BoxDecoration(
      color: seatBackColor,
      border: Border(
        bottom: BorderSide(color: Colors.black.withOpacity(0.5), width: 0.1),
      ),
    );
    final armrestDecoration = BoxDecoration(color: armrestColor);

    Widget letterContent;

    if (isBackspace) {
      letterContent = Icon(
        Icons.backspace_outlined,
        color: Colors.white70,
        size: widget.size * 0.5,
      );
    } else {
      final double finalFontSize = widget.size * 0.70;

      final textStyle = TextStyle(
        color: Colors.white,
        fontSize: finalFontSize,
        fontWeight: FontWeight.bold,
        shadows: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      );

      final painter = TextPainter(
        text: TextSpan(text: widget.letter, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      final textWidth = painter.width;
      final maxWidth = widget.size * 0.75;
      double scale = 1.0;
      if (textWidth > maxWidth) {
        scale = maxWidth / textWidth;
      }

      letterContent = Transform.scale(
        scale: scale,
        child: Text(widget.letter, style: textStyle),
      );
    }

    final buttonVisuals = Container(
      color: seatBaseColor,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: [
              SizedBox(
                width: widget.size * 0.15,
                child: Column(
                  children: [
                    Expanded(
                      flex: 7,
                      child: Container(decoration: armrestDecoration),
                    ),
                    Expanded(flex: 2, child: Container()),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      flex: 7,
                      child: Container(decoration: seatBackDecoration),
                    ),
                    Expanded(flex: 2, child: Container()),
                  ],
                ),
              ),
              SizedBox(
                width: widget.size * 0.15,
                child: Column(
                  children: [
                    Expanded(
                      flex: 7,
                      child: Container(decoration: armrestDecoration),
                    ),
                    Expanded(flex: 2, child: Container()),
                  ],
                ),
              ),
            ],
          ),
          letterContent,
        ],
      ),
    );

    // --- The root of the widget is now wrapped in a ScaleTransition ---
    return ScaleTransition(
      scale: _scaleAnimation,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Material(
          elevation: 2.0,
          shadowColor: Colors.black.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.size * 0.45),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              buttonVisuals,
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(widget.size * 0.45),
                  highlightColor: Colors.white.withOpacity(0.25),
                  splashColor: Colors.white.withOpacity(0.2),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (isBackspace) {
                      audioController.playSfx(SfxType.erase);
                      widget.onBackspaceTapped();
                    } else {
                      audioController.playSfx(SfxType.select);
                      widget.onLetterTapped(widget.letter);
                    }
                  },
                  onLongPress: () {
                    if (isBackspace) {
                      audioController.playSfx(SfxType.eraseAll);
                      HapticFeedback.lightImpact();
                      widget.onClearAllTapped();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ~~~ WIDGET 3: The Arc Button Controller ~~~

enum _TappedArc { none, symbols, shift, space, hint }

class ArcButtonController extends StatefulWidget {
  final double radius;
  final double strokeWidth;
  final VoidCallback onShiftTapped;
  final VoidCallback onSymbolsTapped;
  final VoidCallback onSpaceTapped;
  final VoidCallback onHintTapped;

  const ArcButtonController({
    super.key,
    required this.radius,
    required this.strokeWidth,
    required this.onShiftTapped,
    required this.onSymbolsTapped,
    required this.onSpaceTapped,
    required this.onHintTapped,
  });

  @override
  State<ArcButtonController> createState() => _ArcButtonControllerState();
}

class _ArcButtonControllerState extends State<ArcButtonController>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _revealAnimationController;
  _TappedArc _tappedArc = _TappedArc.none;
  Offset? _tapPosition;

  _TappedArc _revealingArc = _TappedArc.none;
  late List<bool> _lastRevealedState;
  bool _isFirstBuild = true;
  final List<_TappedArc> _hintArcTypes = const [
    _TappedArc.symbols,
    _TappedArc.shift,
    _TappedArc.space,
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _animationController.addListener(() {
      setState(() {});
    });

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _tappedArc = _TappedArc.none;
          _tapPosition = null;
        });
      }
    });

    _revealAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _revealAnimationController.addListener(() => setState(() {}));
    _revealAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _revealingArc = _TappedArc.none;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _revealAnimationController.dispose();
    super.dispose();
  }

  void _checkForHintReveals(GameController game) {
    if (!mounted) return;

    final currentRevealedState = game.availableHints
        .map((h) => h.isRevealed)
        .toList();

    if (_isFirstBuild) {
      _lastRevealedState = currentRevealedState;
      _isFirstBuild = false;
      return;
    }

    if (_lastRevealedState.length != currentRevealedState.length) {
      _lastRevealedState = currentRevealedState;
      return;
    }

    for (int i = 0; i < currentRevealedState.length; i++) {
      if (currentRevealedState[i] && !_lastRevealedState[i]) {
        if (i < _hintArcTypes.length) {
          setState(() {
            _revealingArc = _hintArcTypes[i];
          });
          _revealAnimationController.forward(from: 0.0);
        }
      }
    }
    _lastRevealedState = currentRevealedState;
  }

  // *** NEW METHOD START ***
  /// Automatically reveals all hints if the user is subscribed.
  /// This is a state-driven action, checked on every build.
  void _revealAllHintsIfSubscribed(GameController game, MoneyController money) {
    if (!mounted) return;

    // If the user is subscribed, iterate through all hints.
    if (money.isSubscribed()) {
      for (int i = 0; i < game.availableHints.length; i++) {
        // If a hint is not yet revealed, reveal it.
        if (!game.availableHints[i].isRevealed) {
          // This call will notify listeners of the GameController, causing a
          // rebuild and ensuring this logic doesn't run again for this hint.
          game.revealHintByIndex(i);
        }
      }
    }
  }
  // *** NEW METHOD END ***

  void _handleTapDown(
    TapDownDetails details,
    MoneyController money,
    GameController game,
  ) {
    final tapPosition = details.localPosition;
    final center = Offset(widget.radius, widget.radius);
    final dx = tapPosition.dx - center.dx;
    final dy = tapPosition.dy - center.dy;

    final distance = sqrt(dx * dx + dy * dy);
    if (distance < widget.radius - widget.strokeWidth ||
        distance > widget.radius) {
      return;
    }

    var angle = atan2(dy, dx);
    if (angle < 0) angle += 2 * pi;
    final angleDeg = angle * 180 / pi;

    final bool isSymbolsTappable = angleDeg >= 5 && angleDeg <= 85;
    final bool isShiftTappable = angleDeg >= 95 && angleDeg <= 175;
    final bool isSpaceTappable = angleDeg >= 185 && angleDeg <= 265;
    final bool isHintTappable = angleDeg >= 275 && angleDeg <= 355;

    _TappedArc tappedArc;
    if (isSymbolsTappable) {
      tappedArc = _TappedArc.symbols;
    } else if (isShiftTappable) {
      tappedArc = _TappedArc.shift;
    } else if (isSpaceTappable) {
      tappedArc = _TappedArc.space;
    } else if (isHintTappable) {
      tappedArc = _TappedArc.hint;
    } else {
      return;
    }

    const int longHintThreshold = 20;
    final hintIndex = _hintArcTypes.indexOf(tappedArc);

    if (hintIndex != -1 && hintIndex < game.availableHints.length) {
      final hint = game.availableHints[hintIndex];
      // Note: With the new automatic reveal logic, if money.isSubscribed() is true,
      // hint.isRevealed will also be true after the next build.
      // So this logic correctly handles showing popups for already revealed hints.
      if (hint.isRevealed || money.isSubscribed()) {
        if (hint.value.length > longHintThreshold) {
          HapticFeedback.mediumImpact();
          showDialog(
            context: context,
            builder: (ctx) => QuotePopup(quote: hint.value, title: hint.label),
          );
          setState(() {
            _tappedArc = tappedArc;
            _tapPosition = details.localPosition;
          });
          _animationController.forward(from: 0.0);
        }
        return;
      }
 
    }

    if (_animationController.isAnimating) return;

    VoidCallback action;
    switch (tappedArc) {
      case _TappedArc.symbols:
        action = widget.onSymbolsTapped;
        break;
      case _TappedArc.shift:
        action = widget.onShiftTapped;
        break;
      case _TappedArc.space:
        action = widget.onSpaceTapped;
        break;
      case _TappedArc.hint:
        // If subscribed, the hints are revealed automatically.
        // The button becomes a status indicator, so tapping does nothing.
        action = money.isSubscribed()
            ? () {}
            : money.purchaseSubscription;
        break;
      default:
        return;
    }

    HapticFeedback.lightImpact();
    action();

    setState(() {
      _tappedArc = tappedArc;
      _tapPosition = details.localPosition;
    });
    _animationController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final money = context.watch<MoneyController>();
    final game = context.watch<GameController>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForHintReveals(game);
      // *** MODIFIED LOGIC START ***
      // On every build, check if the user is subscribed and reveal hints accordingly.
      _revealAllHintsIfSubscribed(game, money);
      // *** MODIFIED LOGIC END ***
    });

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) => _handleTapDown(details, money, game),
      child: CustomPaint(
        size: Size.fromRadius(widget.radius),
        painter: _ArcPainter(
          strokeWidth: widget.strokeWidth,
          tappedArc: _tappedArc,
          animationValue: _animationController.value,
          tapPosition: _tapPosition,
          moneyController: money,
          gameController: game,
          revealingArc: _revealingArc,
          revealAnimationValue: _revealAnimationController.value,
        ),
      ),
    );
  }
}

// ~~~ WIDGET 4: The Custom Painter (with Subtitles) (UNCHANGED) ~~~
class _ArcPainter extends CustomPainter {
  final double strokeWidth;
  final _TappedArc tappedArc;
  final double animationValue;
  final Offset? tapPosition;
  final MoneyController moneyController;
  final GameController gameController;
  final _TappedArc revealingArc;
  final double revealAnimationValue;

  _ArcPainter({
    required this.strokeWidth,
    required this.tappedArc,
    required this.animationValue,
    required this.tapPosition,
    required this.moneyController,
    required this.gameController,
    required this.revealingArc,
    required this.revealAnimationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width / 2 - strokeWidth / 2;

    const double gap = pi / 18.0;
    const double sweepAngle = (pi / 2) - gap;

    const baseRed = Color(0xFF5d1919);
    const highlightRed = Color(0xFFa12a2a);
    const baseGreen = Color(0xFF195d19);
    const highlightGreen = Color(0xFF2aa12a);
    const disabledColor = Color(0xFF444444);
    const tappableQuoteColor = Color.fromARGB(255, 28, 45, 54);
    const tappableQuoteHighlight = Color(0xFF2aa1a1);

    final titleStyle = TextStyle(
      fontSize: 14,
      color: Colors.white.withOpacity(0.9),
      fontWeight: FontWeight.bold,
      fontFamily: "EpundaSlab",
    );
    final subtitleStyle = TextStyle(
      fontSize: 10,
      color: Colors.white.withOpacity(0.7),
      fontFamily: "",
    );

    final List<Map<String, dynamic>> hintArcProperties = [
      {
        'startAngle': (pi / 36.0),
        'flipText': true,
        'arcType': _TappedArc.symbols,
      },
      {
        'startAngle': (19 * pi / 36.0),
        'flipText': true,
        'arcType': _TappedArc.shift,
      },
      {
        'startAngle': (37 * pi / 36.0),
        'flipText': false,
        'arcType': _TappedArc.space,
      },
    ];

    List<Map<String, dynamic>> arcSections = [];
    const int longHintThreshold = 22;

    final availableHints = gameController.availableHints;
    for (int i = 0; i < hintArcProperties.length; i++) {
      if (i < availableHints.length) {
        final hint = availableHints[i];
        final bool isLongHint = hint.value.length > longHintThreshold;

        if (hint.isRevealed) {
          arcSections.add({
            ...hintArcProperties[i],
            'text': isLongHint ? 'SHOW QUOTE' : hint.value,
            'subtitle': null,
            'baseColor': isLongHint ? tappableQuoteColor : disabledColor,
            'highlightColor': isLongHint
                ? tappableQuoteHighlight
                : highlightRed,
          });
        } else {
          arcSections.add({
            ...hintArcProperties[i],
            'text': hint.label.toUpperCase(),
            'subtitle': 'Watch Ad',
            'baseColor': baseRed,
            'highlightColor': highlightRed,
          });
        }
      }
    }

    final isSubscribed = moneyController.isSubscribed();
    final productInfo = moneyController.getProductFriendlyInfo();
    final productDescription = moneyController.getDescriptionOfProduct();
    arcSections.add({
      'text': isSubscribed ? 'You own premium!' : (productInfo ?? 'GET PREMIUM'),
      'subtitle': isSubscribed ? null : productDescription,
      'startAngle': (55 * pi / 36.0),
      'flipText': false,
      'arcType': _TappedArc.hint,
      'baseColor': isSubscribed ? const Color.fromARGB(255, 86, 0, 136) : baseGreen,
      'highlightColor': isSubscribed ? const Color.fromARGB(255, 51, 0, 154) : highlightGreen,
    });

    final double capAdjust = asin((strokeWidth / 2) / baseRadius);

    for (var section in arcSections) {
      final startAngle = section['startAngle'] as double;
      final currentArcType = section['arcType'] as _TappedArc;
      final baseColor = section['baseColor'] as Color;
      final highlightColor = section['highlightColor'] as Color;

      final color = (currentArcType == tappedArc)
          ? Color.lerp(
              highlightColor,
              baseColor,
              Curves.easeOut.transform(animationValue),
            )!
          : baseColor;

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: baseRadius),
        startAngle + capAdjust,
        sweepAngle - (2 * capAdjust),
        false,
        paint,
      );

      if (currentArcType == revealingArc && revealingArc != _TappedArc.none) {
        final double glowProgress = Curves.easeInOutCubic.transform(
          revealAnimationValue,
        );
        final double maxGlowSize = strokeWidth * 0.4;

        final glowPaint = Paint()
          ..color = const Color.fromARGB(
            117,
            255,
            251,
            0,
          ).withOpacity(1.0 - glowProgress)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + (maxGlowSize * glowProgress)
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: baseRadius),
          startAngle + capAdjust,
          sweepAngle - (2 * capAdjust),
          false,
          glowPaint,
        );
      }

      final String? title = section['text'] as String?;
      final String? subtitle = section['subtitle'] as String?;
      final bool hasSubtitle = subtitle != null && subtitle.isNotEmpty;

      final double titleRadius = hasSubtitle ? baseRadius - 7.0 : baseRadius;
      final double subtitleRadius = baseRadius + 7.0;

      if (title != null) {
        _drawCurvedText(
          canvas: canvas,
          center: center,
          text: title,
          style: titleStyle,
          radius: titleRadius,
          startAngle: section['startAngle'] as double,
          sweepAngle: sweepAngle,
          isUpsideDown: section['flipText'] as bool,
        );
      }

      if (hasSubtitle) {
        _drawCurvedText(
          canvas: canvas,
          center: center,
          text: subtitle,
          style: subtitleStyle,
          radius: subtitleRadius,
          startAngle: section['startAngle'] as double,
          sweepAngle: sweepAngle,
          isUpsideDown: section['flipText'] as bool,
        );
      }
    }
  }

  void _drawCurvedText({
    required Canvas canvas,
    required Offset center,
    required String text,
    required TextStyle style,
    required double radius,
    required double startAngle,
    required double sweepAngle,
    required bool isUpsideDown,
  }) {
    if (radius <= 0 || text.isEmpty) return;

    // --- 1. Measurement Pass ---
    // Measure the total angular width of the text at its original font size.
    double initialTotalAngle = 0;
    for (int i = 0; i < text.length; i++) {
      final painter = TextPainter(
        text: TextSpan(text: text[i], style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      final asinValue = painter.width / (2 * radius);
      if (asinValue.abs() > 1) return; // Avoid math errors
      initialTotalAngle += 2 * asin(asinValue);
    }

    // --- 2. Determine Final Font Size ---
    // This is the corrected logic.
    TextStyle effectiveStyle = style;
    // This factor controls the padding. Lower value = more padding.
    const double arcTextPaddingFactor = 0.85; 

    // Calculate the target angle, which is the available space minus padding.
    final double targetAngle = sweepAngle * arcTextPaddingFactor;

    // If the text's angle is larger than our target, we MUST scale it down.
    // Otherwise, we use the original size (scale factor of 1.0).
    // This prevents short text like "OK" from being stretched to fill the arc.
    if (initialTotalAngle > targetAngle && style.fontSize != null) {
      final double scaleFactor = targetAngle / initialTotalAngle;
      effectiveStyle = style.copyWith(fontSize: style.fontSize! * scaleFactor);
    }
    // *** END OF CORRECTED LOGIC ***

    // --- 3. Drawing Pass ---
    // Now, build the final painters and draw the text using the effective style.
    final String effectiveText = isUpsideDown
        ? text.split('').reversed.join('')
        : text;
    double finalTotalAngle = 0;
    final List<TextPainter> charPainters = [];

    // We must re-measure with the new font size to correctly center the text.
    for (int i = 0; i < effectiveText.length; i++) {
      final painter = TextPainter(
        text: TextSpan(text: effectiveText[i], style: effectiveStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      charPainters.add(painter);

      final asinValue = painter.width / (2 * radius);
      if (asinValue.abs() > 1) return; // Avoid math errors
      finalTotalAngle += 2 * asin(asinValue);
    }

    // Center the text within the arc using the final calculated angle.
    final double centeredStartAngle =
        startAngle + (sweepAngle - finalTotalAngle) / 2;
    double currentAngle = 0;

    for (int i = 0; i < charPainters.length; i++) {
      final textPainter = charPainters[i];
      final charWidth = textPainter.width;
      final alpha = 2 * asin(charWidth / (2 * radius));
      final angleForThisChar = centeredStartAngle + currentAngle + alpha / 2;

      canvas.save();
      canvas.translate(
        center.dx + radius * cos(angleForThisChar),
        center.dy + radius * sin(angleForThisChar),
      );
      final rotation = angleForThisChar + (pi / 2) + (isUpsideDown ? pi : 0);
      canvas.rotate(rotation);
      textPainter.paint(
        canvas,
        Offset(-charWidth / 2, -textPainter.height / 2),
      );
      canvas.restore();
      currentAngle += alpha;
    }
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) {
    bool hintsChanged = false;
    if (gameController.availableHints.length !=
        oldDelegate.gameController.availableHints.length) {
      hintsChanged = true;
    } else {
      for (int i = 0; i < gameController.availableHints.length; i++) {
        if (gameController.availableHints[i].isRevealed !=
            oldDelegate.gameController.availableHints[i].isRevealed) {
          hintsChanged = true;
          break;
        }
      }
    }
    return tappedArc != oldDelegate.tappedArc ||
        animationValue != oldDelegate.animationValue ||
        moneyController.isSubscribed() !=
            oldDelegate.moneyController.isSubscribed() ||
        hintsChanged ||
        revealingArc != oldDelegate.revealingArc ||
        revealAnimationValue != oldDelegate.revealAnimationValue;
  }
}