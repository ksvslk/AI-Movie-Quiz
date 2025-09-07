// You can replace your existing LetterCircle widget with this new version.

import 'package:flutter/material.dart';
import 'dart:math';

class LetterCircle extends StatelessWidget {
  final Function(String) onLetterTapped;
  final double letterButtonSize;

  // The full alphabet that we can draw letters from.
  final List<String> _alphabet = List.generate(26, (index) => String.fromCharCode('A'.codeUnitAt(0) + index));

  LetterCircle({
    super.key,
    required this.onLetterTapped,
    this.letterButtonSize = 45.0, // Adjust the size of the letter buttons
  });

  @override
  Widget build(BuildContext context) {
    // Use LayoutBuilder to make the widget responsive.
    return LayoutBuilder(
      builder: (context, constraints) {
        // --- 1. DYNAMIC CALCULATIONS ---
        final double diameter = min(constraints.maxWidth, constraints.maxHeight);
        
        // If there's no space, draw nothing.
        if (diameter <= 0) {
          return const SizedBox.shrink();
        }

        // Estimate how many buttons can fit in the circle's area.
        // This is an approximation but works well for this layout.
        final double circleArea = pi * pow(diameter / 2, 2);
        final num buttonArea = pow(letterButtonSize, 2);
        // We reduce the count slightly (e.g., * 0.7) to account for the circle's
        // shape and the square-like arrangement of the Wrap widget.
        final int numberOfLetters = (circleArea / buttonArea * 0.7).floor();
        final int letterCount = min(numberOfLetters, _alphabet.length);
        final List<String> lettersToShow = _alphabet.sublist(0, letterCount);

        // --- 2. THE RENDERING LOGIC ---
        return SizedBox(
          width: diameter,
          height: diameter,
          // ClipOval makes its child widget have a circular shape.
          child: ClipOval(
            child: Container(
              color: Colors.grey.shade300, // Background color for the circle area
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                // Wrap widget automatically arranges children, wrapping to the next line.
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8.0, // Horizontal space between buttons
                  runSpacing: 8.0, // Vertical space between lines of buttons
                  children: List.generate(lettersToShow.length, (index) {
                    return Material(
                      color: Colors.orangeAccent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: () => onLetterTapped(lettersToShow[index]),
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: letterButtonSize,
                          height: letterButtonSize,
                          alignment: Alignment.center,
                          child: Text(
                            lettersToShow[index],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}