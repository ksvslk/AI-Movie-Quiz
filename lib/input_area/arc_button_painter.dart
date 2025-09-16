// arc_button_painter.dart

import 'dart:math';

import 'package:flutter/material.dart';

class ArcButtonPainter extends CustomPainter {
  final double radius;
  final double strokeWidth;

  ArcButtonPainter({required this.radius, this.strokeWidth = 30.0});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Define the paint for each arc
    final paint1 = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt; // Use butt for flat ends

    final paint2 = Paint()
      ..color = Colors.white38
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final paint3 = Paint()
      ..color = Colors.white38
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // The bounding box for our circle
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Define the angle for each arc (60 degrees or pi/3 radians)
    const double sweepAngle = pi / 3;

    // The total angle for all three arcs is pi (180 degrees).
    // To center this block at the top (-pi/2), we start at -pi.

    // Draw the left arc (purple)
    canvas.drawArc(rect, -pi, sweepAngle, false, paint3);

    // Draw the middle arc (red)
    canvas.drawArc(rect, -pi + sweepAngle, sweepAngle, false, paint1);

    // Draw the right arc (green)
    canvas.drawArc(rect, -pi + (2 * sweepAngle), sweepAngle, false, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}