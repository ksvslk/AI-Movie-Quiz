// concentric_letter_circle.dart

// ConcentricLetterCircle with gap-filling logic
import 'package:flutter/material.dart';
import 'dart:math';

import 'package:operation_sunrise/arc_button_controller.dart';

class ConcentricLetterCircle extends StatelessWidget {
  final Function(String) onLetterTapped;
  final double letterButtonSize;

  final List<String> _alphabet = List.generate(39, (index) => String.fromCharCode('A'.codeUnitAt(0) + index));

  ConcentricLetterCircle({
    super.key,
    required this.onLetterTapped,
    this.letterButtonSize = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final List<Widget> allLetterWidgets = [];
        int alphabetIndex = 0;
        
        // --- MODIFICATION START ---

        // Define constants for the outer ring containing the arcs.
        const double arcStrokeWidth = 30.0; // As defined in ArcButtonPainter
        const double desiredPadding = 4.0;

        // Calculate the total radius available from the parent widget.
        final double totalAvailableRadius = min(constraints.maxWidth, constraints.maxHeight) / 2;

        // Reserve space for the arcs and padding by subtracting it from the total available radius.
        // The space needed is the full thickness of the arc plus the padding.
        final double maxRadius = totalAvailableRadius - arcStrokeWidth - desiredPadding;

        // If there's no space for the letters after reserving space for the arcs, build nothing.
        if (maxRadius <= 0) return const SizedBox.shrink();

        // --- MODIFICATION END ---

        for (int layer = 0; layer < 5; layer++) {
          final double layerPadding = letterButtonSize * 0.1; 
          // The radius for letters is now based on the new, smaller maxRadius.
          final double currentRadius = maxRadius - (letterButtonSize / 2) - (layer * (letterButtonSize + layerPadding));

          if (currentRadius < letterButtonSize / 2) break;

          // --- NEW "GAP-FILLING" LOGIC ---
          // 1. Define the absolute minimum padding you find acceptable.
          const double minimumPadding = 2.0; 
          
          // 2. Calculate the circumference and how many letters can fit with that minimal padding.
          final double circumference = 2 * pi * currentRadius;
          final int maxLettersOnThisLayer = (circumference / (letterButtonSize + minimumPadding)).floor();
          
          if (maxLettersOnThisLayer <= 0) continue;

          // 3. This is the key: we use maxLettersOnThisLayer to calculate the *actual* angle
          // for perfect distribution. This divides the full 360 degrees by the number
          // of items, ensuring no large gaps are left at the end.
          final double anglePerLetter = (2 * pi) / maxLettersOnThisLayer;
          // --- END OF NEW LOGIC ---

          final double angleOffset = (layer % 2 == 0) ? 0.0 : anglePerLetter / 2;

          for (int i = 0; i < maxLettersOnThisLayer; i++) {
            if (alphabetIndex >= _alphabet.length) break;

            final String letter = _alphabet[alphabetIndex];
            // Use the newly calculated angle for precise, even placement
            final double angle = angleOffset + (i * anglePerLetter);
            final double x = cos(angle) * currentRadius;
            final double y = sin(angle) * currentRadius;

            allLetterWidgets.add(
              Transform.translate(
                offset: Offset(x, y),
                child: Material(
                  color: Colors.orangeAccent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: () => onLetterTapped(letter),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: letterButtonSize,
                      height: letterButtonSize,
                      alignment: Alignment.center,
                      child: Text(
                        letter,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: letterButtonSize * 0.6,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            alphabetIndex++;
          }
          if (alphabetIndex >= _alphabet.length) break;
        }

        if (alphabetIndex < _alphabet.length) {
          final String centerLetter = _alphabet[alphabetIndex];
          allLetterWidgets.add(
            Material(
         color: Colors.orangeAccent,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: () => onLetterTapped(centerLetter),
                customBorder: const CircleBorder(),
                child: Container(
                  width: letterButtonSize,
                  height: letterButtonSize,
                  alignment: Alignment.center,
                  child: Text(
                    centerLetter,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: letterButtonSize * 0.6,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        
        // Calculate the arc radius to place it in the reserved space.
        // Its center is outside the letter area (maxRadius) by the padding amount plus half its own thickness.
        final arcButtonRadius = maxRadius + desiredPadding + (arcStrokeWidth / 2);
        
        allLetterWidgets.add(
          ArcButtonController(radius: arcButtonRadius),
        );
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: allLetterWidgets,
          ),
        );
      },
    );
  }
}