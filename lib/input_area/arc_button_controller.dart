import 'package:flutter/material.dart';
import 'package:operation_sunrise/input_area/arc_button_painter.dart';

class ArcButtonController extends StatefulWidget {
  final double radius;

  const ArcButtonController({super.key, required this.radius});

  @override
  State<ArcButtonController> createState() => _ArcButtonControllerState();
}

class _ArcButtonControllerState extends State<ArcButtonController> {

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: CustomPaint(
        // The painter draws the visual arcs
        painter: ArcButtonPainter(radius: widget.radius),
        // The CustomPaint widget needs a size
        size: Size(widget.radius * 2, widget.radius * 2),
      ),
    );
  }
}