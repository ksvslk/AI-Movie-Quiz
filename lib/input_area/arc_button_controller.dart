// arc_button_controller.dart

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:operation_sunrise/input_area/arc_button_painter.dart';

class ArcButtonController extends StatefulWidget {
  final double radius;

  const ArcButtonController({super.key, required this.radius});

  @override
  State<ArcButtonController> createState() => _ArcButtonControllerState();
}

class _ArcButtonControllerState extends State<ArcButtonController> {
  void _handleTap(Offset localPosition) {
    // The center of the CustomPaint widget is at (radius, radius)
    final double dx = localPosition.dx - widget.radius;
    final double dy = localPosition.dy - widget.radius;
    
    // Calculate the angle of the tap.
    // atan2 gives an angle in radians from -pi to pi.
    // 0 is to the right, pi/2 is down, pi or -pi is to the left, -pi/2 is up.
    final double angle = atan2(dy, dx);

    // Check which arc segment the angle falls into, based on the new painter logic.
    // The top area is from -pi to 0.

    // Top-left arc (Purple): from -pi to -2pi/3
    if (angle >= -pi && angle < -2 * pi / 3) {
      print('Tapped Top-Left Button (Purple)');
    } 
    // Top-middle arc (Red): from -2pi/3 to -pi/3
    else if (angle >= -2 * pi / 3 && angle < -pi / 3) {
      print('Tapped Top-Middle Button (Red)');
    } 
    // Top-right arc (Green): from -pi/3 to 0
    else if (angle >= -pi / 3 && angle < 0) {
       print('Tapped Top-Right Button (Green)');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) => _handleTap(details.localPosition),
      child: CustomPaint(
        // The painter draws the visual arcs
        painter: ArcButtonPainter(radius: widget.radius),
        // The CustomPaint widget needs a size
        size: Size(widget.radius * 2, widget.radius * 2),
      ),
    );
  }
}