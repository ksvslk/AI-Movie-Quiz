// concentric_letter_circle.dart

// Final version with correct text orientation for all arc sections.
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:operation_sunrise/audio/audio_controller.dart';
import 'package:operation_sunrise/audio/sounds.dart';
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
  static const String _backspaceChar = '\u232B';

  const _LetterCircleButton({
    required this.letter,
    required this.size,
    required this.onLetterTapped,
    required this.onBackspaceTapped,
  });

  @override
  Widget build(BuildContext context) {
    final bool isBackspace = letter == _backspaceChar;
    
    final Color seatBackColor = isBackspace ? Colors.red.shade800 : Colors.redAccent.shade400;
    final Color seatBaseColor = isBackspace ? Colors.red.shade900.withOpacity(0.8) : Colors.redAccent;
    final Color armrestColor = isBackspace ? Colors.red.shade900 : Colors.redAccent.shade700;

    final seatBackDecoration = BoxDecoration(
      color: seatBackColor,
      border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.5), width: 0.1)),
    );
    final seatBaseDecoration = BoxDecoration(color: seatBaseColor);
    final armrestDecoration = BoxDecoration(color: armrestColor);

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.45),
        child: Material(
          color: seatBaseColor,
          elevation: 2.0,
          shadowColor: Colors.black.withOpacity(0.5),
          child: InkWell(
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
          ),
        ),
      ),
    );
  }
}


// ~~~ WIDGET 3: The Arc Button Controller ~~~
class ArcButtonController extends StatelessWidget {
  final double radius;
  final double strokeWidth;
  final VoidCallback onShiftTapped;
  final VoidCallback onSymbolsTapped;
  final VoidCallback onSpaceTapped;

  const ArcButtonController({
    Key? key,
    required this.radius,
    required this.strokeWidth,
    required this.onShiftTapped,
    required this.onSymbolsTapped,
    required this.onSpaceTapped,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        final tapPosition = details.localPosition;
        final center = Offset(radius, radius);
        final dx = tapPosition.dx - center.dx;
        final dy = tapPosition.dy - center.dy;
        
        var angle = atan2(dy, dx); 
        if (angle < 0) angle += 2 * pi;

        final angleDeg = angle * 180 / pi;

        if (angleDeg > 30 && angleDeg <= 150) {
            onSymbolsTapped(); 
        } else if (angleDeg > 150 && angleDeg <= 270) {
            onShiftTapped(); 
        } else {
            onSpaceTapped();
        }
      },
      child: CustomPaint(
        size: Size.fromRadius(radius),
        painter: _ArcPainter(strokeWidth: strokeWidth),
      ),
    );
  }
}

// ~~~ WIDGET 4: The Custom Painter for Arcs and Text ~~~
class _ArcPainter extends CustomPainter {
  final double strokeWidth;
  
  _ArcPainter({ required this.strokeWidth });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth / 2;
    
    const double gap = pi / 18.0;
    const double sweepAngle = (2 * pi / 3) - gap;
    
    // --- FIX: Selectively flip text based on its position on the circle ---
    final arcSections = [
      {'startAngle': (pi / 6), 'text': 'SYMBOLS', 'flipText': true}, // Text on top needs to be flipped
      {'startAngle': (5 * pi / 6), 'text': 'SHIFT',   'flipText': false},
      {'startAngle': (9 * pi / 6), 'text': 'SPACE',   'flipText': false},
    ];

    final paint = Paint()
      ..color = const Color(0xFF5d1919)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final double capAdjust = asin((strokeWidth / 2) / radius);
    
    for (var section in arcSections) {
      final startAngle = section['startAngle'] as double;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + capAdjust,
        sweepAngle - (2 * capAdjust),
        false,
        paint,
      );

      _drawCurvedText(canvas, center, radius, section, sweepAngle);
    }
  }

  void _drawCurvedText(Canvas canvas, Offset center, double radius, Map<String, dynamic> section, double sweepAngle) {
    final textStyle = TextStyle(
      fontSize: 14,
      color: Colors.white.withOpacity(0.8),
      fontWeight: FontWeight.bold,
    );
    
    final String text = section['text'] as String;
    final double startAngle = section['startAngle'] as double;
    final bool isUpsideDown = section['flipText'] as bool;

    // Reverse the string for flipped text so it reads left-to-right along the curve
    final String effectiveText = isUpsideDown ? text.split('').reversed.join('') : text;
    
    double totalTextAngle = 0;
    final List<TextPainter> charPainters = [];
    for (int i = 0; i < effectiveText.length; i++) {
        final painter = TextPainter(
            text: TextSpan(text: effectiveText[i], style: textStyle),
            textDirection: TextDirection.ltr,
        )..layout();
        charPainters.add(painter);
        totalTextAngle += 2 * asin(painter.width / (2 * radius));
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

      // Add 180 degrees (pi radians) for flipped text
      final rotation = angleForThisChar + (pi / 2) + (isUpsideDown ? pi : 0);
      canvas.rotate(rotation);
      
      textPainter.paint(canvas, Offset(-charWidth / 2, -textPainter.height / 2));
      canvas.restore();

      currentAngle += alpha;
    }
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) =>
      strokeWidth != oldDelegate.strokeWidth;
}