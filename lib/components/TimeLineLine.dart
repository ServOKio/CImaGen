import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

class TimeLineLine extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = Colors.orangeAccent.shade200
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.cubicTo(
      size.width / 4, size.height * 3 / 4,
      size.width * 3 / 4, size.height / 4,
      size.width, size.height / 2,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}