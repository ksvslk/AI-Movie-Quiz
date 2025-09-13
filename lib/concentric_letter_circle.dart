// concentric_letter_circle.dart

// Final version incorporating the 4th arc button which is dynamically updated
// based on a MoneyController and includes a title and subtitle on all arcs.
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:operation_sunrise/change_notifier/game_controller.dart';
import 'package:operation_sunrise/change_notifier/money_controller.dart';
import 'package:provider/provider.dart';

// A helper class to hold the results of our layout calculation.
class _LayoutSolution {
  final List<int> seatsPerRing;
  final double buttonSize;
  _LayoutSolution(this.seatsPerRing, this.buttonSize);
}

// ~~~ WIDGET 1: The Main ConcentricLetterCircle ~~~
class ConcentricLetterCircle extends StatelessWidget {
  final Function(String) onLetterTapped;
  final VoidCallback onBackspaceTapped;
  final VoidCallback onClearAllTapped;
  final VoidCallback onShiftTapped;
  final VoidCallback onSymbolsTapped;
  final VoidCallback onSpaceTapped;
  final VoidCallback onHintTapped;

  static const String _backspaceChar = '\u232B';

  final List<String> _characterSet = [
    'X', 'Q', 'Z', 'K', 'V', 'P', 'B', 'G', 'Y', 'F', 'M', 'C',
    ':', "'", '-', '2',
    'J', 'U', 'W', 'L', 'D', 'R', 'H', 'S', 'N', 'I', 'O', 'A', 'T', 'E', _backspaceChar,
  ];

  ConcentricLetterCircle({
    super.key,
    required this.onLetterTapped,
    required this.onBackspaceTapped,
    required this.onClearAllTapped,
    required this.onShiftTapped,
    required this.onSymbolsTapped,
    required this.onSpaceTapped,
    required this.onHintTapped,
  });

  _LayoutSolution _findOptimalLayout(double maxRadius, int characterCount) {
    _LayoutSolution bestSolution = _LayoutSolution([], 0.0);
    const double minPadding = 4.0;

    for (int outerRingSeats = 22; outerRingSeats >= 10; outerRingSeats--) {
      double sinVal = sin(pi / outerRingSeats);
      double candidateButtonSize = (2 * maxRadius * sinVal - minPadding) / (1 + sinVal);
      if (candidateButtonSize < 15) continue;
      List<int> ringCapacities = [];
      int totalCapacity = 0;
      double nextAvailableRadius = maxRadius;
      while (nextAvailableRadius >= candidateButtonSize) {
        double currentRingCenterRadius = nextAvailableRadius - candidateButtonSize / 2;
        if (currentRingCenterRadius <= 0) break;
        double circumference = 2 * pi * currentRingCenterRadius;
        int seatsInThisRing = (circumference / (candidateButtonSize + minPadding)).floor();
        if (seatsInThisRing < 3) break;
        ringCapacities.add(seatsInThisRing);
        totalCapacity += seatsInThisRing;
        nextAvailableRadius -= (candidateButtonSize + minPadding);
      }
      if (totalCapacity >= characterCount && candidateButtonSize > bestSolution.buttonSize) {
        bestSolution = _LayoutSolution(ringCapacities, candidateButtonSize);
      }
    }
    return bestSolution;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double maxDiameter = 500.0;
        final double effectiveDiameter = min(maxDiameter, min(constraints.maxWidth, constraints.maxHeight));
        if (effectiveDiameter <= 0) return const SizedBox.shrink();

        final List<Widget> allLetterWidgets = [];
        int characterIndex = 0;
        
        const double arcStrokeWidth = 35.0;
        const double desiredPadding = 4.0;
        final double totalAvailableRadius = effectiveDiameter / 2;

        final double arcRingInnerRadius = totalAvailableRadius - arcStrokeWidth;
        final double maxRadiusForLetters = arcRingInnerRadius - desiredPadding;
        
        final _LayoutSolution solution = _findOptimalLayout(maxRadiusForLetters, _characterSet.length);
        final List<int> ringCapacities = solution.seatsPerRing;
        final double uniformButtonSize = solution.buttonSize;
        
        if (ringCapacities.isEmpty || uniformButtonSize <= 0) return const SizedBox.shrink();

        allLetterWidgets.add(
          ArcButtonController(
            radius: totalAvailableRadius,
            strokeWidth: arcStrokeWidth,
            onShiftTapped: onShiftTapped,
            onSymbolsTapped: onSymbolsTapped,
            onSpaceTapped: onSpaceTapped,
            onHintTapped: onHintTapped,
          ),
        );
        
        double nextAvailableRadius = maxRadiusForLetters;

        for (int i = 0; i < ringCapacities.length; i++) {
          final int capacityOfThisRing = ringCapacities[i];
          final int remainingChars = _characterSet.length - characterIndex;
          final int numSeatsOnThisLayer = min(capacityOfThisRing, remainingChars);

          if (numSeatsOnThisLayer == 0) break;

          final double currentRadius = nextAvailableRadius - (uniformButtonSize / 2);
          final double anglePerLetter = (2 * pi) / numSeatsOnThisLayer;
          final double angleOffset = (i % 2 != 0) ? 0.0 : anglePerLetter / 2;

          for (int j = 0; j < numSeatsOnThisLayer; j++) {
            final String letter = _characterSet[characterIndex];
            final double angle = angleOffset + (j * anglePerLetter);
            final double x = cos(angle) * currentRadius;
            final double y = sin(angle) * currentRadius;
            
            allLetterWidgets.add(
              Transform.translate(
                offset: Offset(x, y),
                child: _LetterCircleButton(
                  letter: letter,
                  size: uniformButtonSize,
                  onLetterTapped: onLetterTapped,
                  onBackspaceTapped: onBackspaceTapped,
                  onClearAllTapped: onClearAllTapped,
                ),
              ),
            );
            characterIndex++;
          }
          const double minPadding = 4.0;
          nextAvailableRadius -= (uniformButtonSize + minPadding);
        }
        
        return Center(
          child: SizedBox(
            width: effectiveDiameter,
            height: effectiveDiameter,
            child: Container(
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: Stack(alignment: Alignment.center, children: allLetterWidgets),
            ),
          ),
        );
      },
    );
  }
}

// ~~~ WIDGET 2: A Stateless Button with InkWell Feedback ~~~

class _LetterCircleButton extends StatelessWidget {
  final String letter;
  final double size;
  final Function(String) onLetterTapped;
  final VoidCallback onBackspaceTapped;
  final VoidCallback onClearAllTapped;
  static const String _backspaceChar = '\u232B';

  const _LetterCircleButton({
    required this.letter,
    required this.size,
    required this.onLetterTapped,
    required this.onBackspaceTapped,
    required this.onClearAllTapped,
  });

  @override
  Widget build(BuildContext context) {
    final bool isBackspace = letter == _backspaceChar;
    
    final Color seatBackColor = isBackspace ? Colors.pink.shade800 : Colors.redAccent.shade400;
    final Color seatBaseColor = isBackspace ? Colors.pink.shade900.withOpacity(0.8) : Colors.redAccent;
    final Color armrestColor = isBackspace ? Colors.pink.shade900 : Colors.redAccent.shade700;

    final seatBackDecoration = BoxDecoration(
      color: seatBackColor,
      border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.5), width: 0.1)),
    );
    final armrestDecoration = BoxDecoration(color: armrestColor);

    final buttonVisuals = Container(
      color: seatBaseColor,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(children: [
            SizedBox(width: size * 0.15, child: Column(children: [Expanded(flex: 7, child: Container(decoration: armrestDecoration)), Expanded(flex: 2, child: Container())])),
            Expanded(child: Column(children: [Expanded(flex: 7, child: Container(decoration: seatBackDecoration)), Expanded(flex: 2, child: Container())])),
            SizedBox(width: size * 0.15, child: Column(children: [Expanded(flex: 7, child: Container(decoration: armrestDecoration)), Expanded(flex: 2, child: Container())])),
          ]),
          if (isBackspace)
            Icon(Icons.backspace_outlined, color: Colors.white70, size: size * 0.5)
          else
            Text(letter, style: TextStyle(color: Colors.white, fontSize: size * 0.55, fontWeight: FontWeight.bold, shadows: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 2, offset: const Offset(0, 1))]),),
        ],
      ),
    );

    return SizedBox(
      width: size,
      height: size,
      child: Material(
        elevation: 2.0,
        shadowColor: Colors.black.withOpacity(0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(size * 0.45)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            buttonVisuals,
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(size * 0.45),
                highlightColor: Colors.white.withOpacity(0.25),
                splashColor: Colors.white.withOpacity(0.2),
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (isBackspace) {
                    onBackspaceTapped();
                  } else {
                    onLetterTapped(letter);
                  }
                },
                onLongPress: () {
                  if (isBackspace) {
                    HapticFeedback.lightImpact();
                    onClearAllTapped();
                  }
                },
              ),
            ),
          ],
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
    Key? key,
    required this.radius,
    required this.strokeWidth,
    required this.onShiftTapped,
    required this.onSymbolsTapped,
    required this.onSpaceTapped,
    required this.onHintTapped,
  }) : super(key: key);

  @override
  State<ArcButtonController> createState() => _ArcButtonControllerState();
}

class _ArcButtonControllerState extends State<ArcButtonController> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  _TappedArc _tappedArc = _TappedArc.none;
  Offset? _tapPosition;

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
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details, MoneyController money, GameController game) {
    final tapPosition = details.localPosition;
    final center = Offset(widget.radius, widget.radius);
    final dx = tapPosition.dx - center.dx;
    final dy = tapPosition.dy - center.dy;

    final distance = sqrt(dx * dx + dy * dy);
    final double strokeWidth = widget.strokeWidth;
    final double innerRadius = widget.radius - strokeWidth;
    final double outerRadius = widget.radius;

    if (distance < innerRadius || distance > outerRadius) {
      return;
    }

    var angle = atan2(dy, dx); 
    if (angle < 0) angle += 2 * pi;
    final angleDeg = angle * 180 / pi;

    final bool isSymbolsTappable = angleDeg >= 5 && angleDeg <= 85;
    final bool isShiftTappable = angleDeg >= 95 && angleDeg <= 175;
    final bool isSpaceTappable = angleDeg >= 185 && angleDeg <= 265;
    final bool isHintTappable = angleDeg >= 275 && angleDeg <= 355;

    if (!isSymbolsTappable && !isShiftTappable && !isSpaceTappable && !isHintTappable) {
      return;
    }

    if (_animationController.isAnimating) return;
    
    _TappedArc currentTap;
    VoidCallback action;

    if (isSymbolsTappable) {
      currentTap = _TappedArc.symbols;
      action = widget.onSymbolsTapped;
    } else if (isShiftTappable) {
      currentTap = _TappedArc.shift;
      action = widget.onShiftTapped;
    } else if (isSpaceTappable) {
      currentTap = _TappedArc.space;
      action = widget.onSpaceTapped;
    } else { // isHintTappable must be true
      currentTap = _TappedArc.hint;
      if (money.isSubscribed()) {
        action = widget.onHintTapped;
      } else {
        action = money.purchaseSubscription;
      }
    }
    
    HapticFeedback.lightImpact();
    action();

    setState(() {
      _tappedArc = currentTap;
      _tapPosition = details.localPosition;
    });
    _animationController.forward(from: 0.0);
  }
  
  @override
  Widget build(BuildContext context) {
    final money = context.watch<MoneyController>();
    final game = context.watch<GameController>();

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
        ),
      ),
    );
  }
}


// ~~~ WIDGET 4: The Custom Painter (with Subtitles) ~~~
class _ArcPainter extends CustomPainter {
  final double strokeWidth;
  final _TappedArc tappedArc;
  final double animationValue;
  final Offset? tapPosition;
  final MoneyController moneyController;
  final GameController gameController;
  
  _ArcPainter({ 
    required this.strokeWidth,
    required this.tappedArc,
    required this.animationValue,
    required this.tapPosition,
    required this.moneyController,
    required this.gameController,
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

    final titleStyle = TextStyle(
      fontSize: 14,
      color: Colors.white.withOpacity(0.9),
      fontWeight: FontWeight.bold,
      fontFamily: "EpundaSlab"
    );
    final subtitleStyle = TextStyle(
      fontSize: 10,
      color: Colors.white.withOpacity(0.7),
      fontFamily: "EpundaSlab"
    );

    final List<Map<String, dynamic>> hintArcProperties = [
      {'startAngle': (pi / 36.0), 'flipText': true, 'arcType': _TappedArc.symbols},
      {'startAngle': (19 * pi / 36.0), 'flipText': true, 'arcType': _TappedArc.shift},
      {'startAngle': (37 * pi / 36.0), 'flipText': false, 'arcType': _TappedArc.space},
    ];

    List<Map<String, dynamic>> arcSections = [];

    final availableHints = gameController.availableHints;
    for (int i = 0; i < hintArcProperties.length; i++) {
      if (i < availableHints.length) {
        final hint = availableHints[i];
        arcSections.add({
          ...hintArcProperties[i],
          'text': hint.isRevealed ? hint.value : hint.label.toUpperCase(),
          'subtitle': 'Watch Ad',
          'baseColor': hint.isRevealed ? disabledColor : baseRed,
          'highlightColor': highlightRed,
        });
      }
    }

    final isSubscribed = moneyController.isSubscribed();
    final productInfo = moneyController.getProductFriendlyInfo();
    final productDescription = moneyController.getDescriptionOfProduct();
    arcSections.add({
      'text': isSubscribed ? 'GET HINT' : (productInfo ?? 'GET PREMIUM'),
      'subtitle': isSubscribed ? null : productDescription,
      'startAngle': (55 * pi / 36.0),
      'flipText': false,
      'arcType': _TappedArc.hint,
      'baseColor': baseGreen,
      'highlightColor': highlightGreen,
    });

    final double capAdjust = asin((strokeWidth / 2) / baseRadius);
    
    for (var section in arcSections) {
      final startAngle = section['startAngle'] as double;
      final currentArcType = section['arcType'] as _TappedArc;
      final baseColor = section['baseColor'] as Color;
      final highlightColor = section['highlightColor'] as Color;
      
      final color = (currentArcType == tappedArc)
        ? Color.lerp(highlightColor, baseColor, Curves.easeOut.transform(animationValue))!
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

      final String? title = section['text'] as String?;
      final String? subtitle = section['subtitle'] as String?;
      final bool hasSubtitle = subtitle != null && subtitle.isNotEmpty;

      final double titleRadius = hasSubtitle ? baseRadius - 7.0 : baseRadius;
      final double subtitleRadius = baseRadius + 7.0;

      if (title != null) {
          _drawCurvedText(
              // FIXED: Added the required named arguments 'canvas' and 'center'
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
              // FIXED: Added the required named arguments 'canvas' and 'center'
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

  // FIXED: Changed signature to use all named parameters for clarity
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
    if (radius <= 0) return;

    final String effectiveText = isUpsideDown ? text.split('').reversed.join('') : text;
    double totalTextAngle = 0;
    final List<TextPainter> charPainters = [];

    for (int i = 0; i < effectiveText.length; i++) {
        final painter = TextPainter(
            text: TextSpan(text: effectiveText[i], style: style),
            textDirection: TextDirection.ltr,
        )..layout();
        charPainters.add(painter);

        final asinValue = painter.width / (2 * radius);
        if (asinValue.abs() > 1) {
          return;
        }
        totalTextAngle += 2 * asin(asinValue);
    }

    if (totalTextAngle > sweepAngle) {
      return;
    }

    final double centeredStartAngle = startAngle + (sweepAngle - totalTextAngle) / 2;
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
      textPainter.paint(canvas, Offset(-charWidth / 2, -textPainter.height / 2));
      canvas.restore();
      currentAngle += alpha;
    }
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) {
    bool hintsChanged = false;
    if (gameController.availableHints.length != oldDelegate.gameController.availableHints.length) {
      hintsChanged = true;
    } else {
      for (int i = 0; i < gameController.availableHints.length; i++) {
        if (gameController.availableHints[i].isRevealed != oldDelegate.gameController.availableHints[i].isRevealed) {
          hintsChanged = true;
          break;
        }
      }
    }
    return tappedArc != oldDelegate.tappedArc || 
        animationValue != oldDelegate.animationValue || 
        moneyController.isSubscribed() != oldDelegate.moneyController.isSubscribed() || 
        hintsChanged;
  }
}