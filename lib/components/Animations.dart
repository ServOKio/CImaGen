import 'dart:async';
import 'dart:math' as math;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class AnimatedText extends StatefulWidget {
  const AnimatedText(
      this.text, {
        super.key,
        this.style,
        this.textAlign,
        this.duration = const Duration(milliseconds: 420),
        this.curve = Curves.easeInOutCubicEmphasized,
        this.slideDistance = 32.0,
        this.useMonospaceDuringTransition = true,
      });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final Duration duration;
  final Curve curve;
  final double slideDistance;
  final bool useMonospaceDuringTransition;

  @override
  State<AnimatedText> createState() => _AnimatedTextState();
}

class _AnimatedTextState extends State<AnimatedText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String _currentText = '';
  String _previousText = '';

  @override
  void initState() {
    super.initState();
    _currentText = widget.text;
    _previousText = widget.text;

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
  }

  @override
  void didUpdateWidget(covariant AnimatedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      setState(() {
        _previousText = oldWidget.text;
        _currentText = widget.text;
      });
      _controller
        ..value = 0.0
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  TextStyle _getEffectiveStyle(bool isTransitioning) {
    final base = widget.style ?? Theme.of(context).textTheme.bodyMedium!;
    if (!widget.useMonospaceDuringTransition || !isTransitioning) {
      return base;
    }
    return base.copyWith(
      fontFamily: 'Roboto Mono'
     
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAnimating = _controller.isAnimating;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = widget.curve.transform(_controller.value);
        final style = _getEffectiveStyle(isAnimating);

        return IntrinsicWidth(
          child: Stack(
            alignment: Alignment.centerLeft,
            textDirection: TextDirection.ltr,
            children: [
              Opacity(
                opacity: 1.0 - t,
                child: Transform.translate(
                  offset: Offset(0, t * widget.slideDistance),
                  child: Text(
                    _previousText,
                    style: style,
                    textAlign: widget.textAlign,
                    softWrap: true,
                    maxLines: null,
                  ),
                ),
              ),

              Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, -widget.slideDistance * (1 - t)),
                  child: Text(
                    _currentText,
                    style: style,
                    textAlign: widget.textAlign,
                    softWrap: true,
                    maxLines: null,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ShowUp extends StatefulWidget {
  final Widget child;
  final int? delay;

  const ShowUp({super.key, required this.child, this.delay});

  @override
  State<ShowUp> createState() => _ShowUpState();
}

class _ShowUpState extends State<ShowUp> with TickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _animOffset;

  @override
  void initState() {
    super.initState();

    if(mounted){
      _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
      final curve = CurvedAnimation(curve: Curves.decelerate, parent: _animController);
      _animOffset = Tween<Offset>(begin: const Offset(0.0, 0.35), end: Offset.zero).animate(curve);

      if (widget.delay == null) {
        _animController.forward();
      } else {
        Timer(Duration(milliseconds: widget.delay!), () {
          _animController.forward();
        });
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animController,
      child: SlideTransition(
        position: _animOffset,
        child: widget.child,
      ),
    );
  }
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Animation<Offset>>('_animOffset', _animOffset));
  }
}

class WavyDotsLoader extends StatefulWidget {
  const WavyDotsLoader({
    super.key,
    this.size = const Size(360, 160),
    this.duration = const Duration(milliseconds: 4200),
    this.pathColor = const Color(0xFF2196F3),
    this.dotColor = Colors.white,
    this.gridColor = Colors.grey,
    this.gridOpacity = 0.15,
  });

  final Size size;
  final Duration duration;
  final Color pathColor;
  final Color dotColor;
  final Color gridColor;
  final double gridOpacity;

  @override
  State<WavyDotsLoader> createState() => _WavyDotsLoaderState();
}

class _WavyDotsLoaderState extends State<WavyDotsLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size.width,
      height: widget.size.height,
      color: const Color(0xFF0F0F0F),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _WavyDotsPainter(
              progress: _controller.value,
              pathColor: widget.pathColor,
              dotColor: widget.dotColor,
              gridColor: widget.gridColor.withOpacity(widget.gridOpacity),
            ),
            size: widget.size,
          );
        },
      ),
    );
  }
}

class _WavyDotsPainter extends CustomPainter {
  final double progress;
  final Color pathColor;
  final Color dotColor;
  final Color gridColor;

  _WavyDotsPainter({
    required this.progress,
    required this.pathColor,
    required this.dotColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final midY = h / 2;

   
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    const gridStep = 20.0;
    for (double x = 0; x <= w; x += gridStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }
    for (double y = 0; y <= h; y += gridStep) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

   
    const laneCount = 5;
    const maxAmplitude = 28.0;     
    const safeMargin = 12.0;       
    const frequency = 1.35;        
    const phaseOffsetPerLane = 0.55;

    final pathPaint = Paint()
      ..color = pathColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < laneCount; i++) {
      final t = i / (laneCount - 1).toDouble();
      final laneAmplitude = maxAmplitude * (0.7 + 0.3 * (1 - (t - 0.5).abs() * 2));
      final yCenter = lerpDouble(h * 0.22, h * 0.78, t)!;

      final path = Path();

     
      double x = 0;
      double y = yCenter + math.sin(x * frequency * 0.02 + i * phaseOffsetPerLane) * laneAmplitude;
      path.moveTo(x, y.clamp(safeMargin, h - safeMargin));

     
      const step = 6.0;
      while (x < w) {
        final nextX = (x + step).clamp(0, w);
        final nextY = yCenter + math.sin(nextX * frequency * 0.02 + i * phaseOffsetPerLane) * laneAmplitude;

        final cpX = (x + nextX) / 2;
        final cpY = (y + nextY) / 2;

        path.quadraticBezierTo(cpX, cpY.clamp(safeMargin, h - safeMargin), nextX.toDouble(), nextY.clamp(safeMargin, h - safeMargin));

        x = nextX.toDouble();
        y = nextY;
      }

      canvas.drawPath(path, pathPaint);

     
      final laneProgress = (progress + i * 0.14) % 1.0;
      final dotX = w * laneProgress;
      final dotY = yCenter + math.sin(dotX * frequency * 0.02 + i * phaseOffsetPerLane) * laneAmplitude;

     
      final clampedY = dotY.clamp(safeMargin + 4, h - safeMargin - 4);
      canvas.drawCircle(Offset(dotX, clampedY), 5.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavyDotsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

double lerpDouble(double a, double b, double t) => a + (b - a) * t;

class FadingCurveLoader extends StatefulWidget {
  const FadingCurveLoader({
    super.key,
    this.cycleDuration = const Duration(milliseconds: 3400),
    this.pathColor = const Color(0xFF2196F3),
    this.dotColor = Colors.white,
    this.gridColor = Colors.grey
  });

  final Duration cycleDuration;
  final Color pathColor;
  final Color dotColor;
  final Color gridColor;

  @override
  State<FadingCurveLoader> createState() => _FadingCurveLoaderState();
}

class _FadingCurveLoaderState extends State<FadingCurveLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.cycleDuration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: _FadingCurvePainter(
          globalProgress: _controller.value,
          pathColor: widget.pathColor,
          dotColor: widget.dotColor,
          gridColor: widget.gridColor,
        ),
      ),
    );
  }
}

class LaneState {
  late double startY;
  late double endY;

  LaneState.random(double height) {
    final r = math.Random();
    startY = 30 + r.nextDouble() * (height - 60);
    endY   = 30 + r.nextDouble() * (height - 60);
  }

  static LaneState createNew(double h) => LaneState.random(h);
}

class _FadingCurvePainter extends CustomPainter {
  final double globalProgress;
  final Color pathColor;
  final Color dotColor;
  final Color gridColor;

  static final List<double> _laneProgress = List.filled(5, 0.0);
  static final List<LaneState> _current = [];
  static final List<LaneState> _target = [];
  static final List<bool> _transitioning = List.filled(5, false);
  static final List<double> _transProgress = List.filled(5, 0.0);

  static bool _initialized = false;

  _FadingCurvePainter({
    required this.globalProgress,
    required this.pathColor,
    required this.dotColor,
    required this.gridColor,
  }) {
    if (!_initialized) {
      final h = 160.0;
      _current.addAll(List.generate(5, (_) => LaneState.createNew(h)));
      _target.addAll(List.generate(5, (_) => LaneState.createNew(h)));
      _initialized = true;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if(gridColor != Colors.transparent){
      final gridPaint = Paint()..color = gridColor..strokeWidth = 1.0;
      const step = 20.0;
      for (double x = 0; x <= w; x += step) canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
      for (double y = 0; y <= h; y += step) canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    final pathPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()..color = dotColor..style = PaintingStyle.fill;

    const laneCount = 5;
    const marginY = 24.0;
    const transitionTime = 0.18;
    const fadeOutShare = 0.5;

    for (int i = 0; i < laneCount; i++) {
      _laneProgress[i] += 0.0045 + i * 0.0004;
      if (_laneProgress[i] > 1.0 + transitionTime) {
        _laneProgress[i] -= 1.0 + transitionTime;
        _current[i] = _target[i];
        _target[i] = LaneState.createNew(h);
        _transitioning[i] = false;
        _transProgress[i] = 0.0;
      }

      final laneT = _laneProgress[i].clamp(0.0, 1.0);
      final inTransition = _laneProgress[i] > 1.0;

      if (inTransition) {
        _transitioning[i] = true;
        _transProgress[i] = (_laneProgress[i] - 1.0) / transitionTime;
      }

      final curr = _current[i];
      final targ = _target[i];

     
      if (!inTransition) {
       
        pathPaint.color = pathColor.withOpacity(1.0);
        canvas.drawPath(_createPath(w, curr.startY, curr.endY), pathPaint);
      } else {
        final t = _transProgress[i];

       
        if (t < fadeOutShare) {
          pathPaint.color = pathColor.withOpacity(1.0 - t / fadeOutShare);
          canvas.drawPath(_createPath(w, curr.startY, curr.endY), pathPaint);
        }

       
        if (t > fadeOutShare) {
          final appear = (t - fadeOutShare) / (1.0 - fadeOutShare);
          pathPaint.color = pathColor.withOpacity(appear);
          canvas.drawPath(_createPath(w, targ.startY, targ.endY), pathPaint);
        }
      }

      double dotT = laneT;

      if (!inTransition) {
        final x = _cubicBezier(dotT, 0, w * 0.25, w * 0.75, w);
        final y = _cubicBezier(dotT, curr.startY, curr.startY, curr.endY, curr.endY);
        canvas.drawCircle(Offset(x, y.clamp(marginY, h - marginY)), 6.0, dotPaint);
      }
    }
  }

  Path _createPath(double w, double sy, double ey) {
    final p = Path()..moveTo(0, sy);
    p.cubicTo(w * 0.25, sy, w * 0.75, ey, w, ey);
    return p;
  }

  double _cubicBezier(double t, double a, double b, double c, double d) {
    final u = 1 - t;
    final tt = t * t, uu = u * u;
    return uu*u*a + 3*uu*t*b + 3*u*tt*c + tt*t*d;
  }

  @override
  bool shouldRepaint(covariant _FadingCurvePainter oldDelegate) {
    return oldDelegate.globalProgress != globalProgress;
  }
}

// class ShiftingCurveLoader extends StatefulWidget {
//   const ShiftingCurveLoader({
//     super.key,
//     this.size = const Size(360, 160),
//     this.cycleDuration = const Duration(milliseconds: 3200),
//     this.pathColor = const Color(0xFF2196F3),
//     this.dotColor = Colors.white,
//     this.gridColor = Colors.grey,
//     this.gridOpacity = 0.14,
//   });
//
//   final Size size;
//   final Duration cycleDuration;
//   final Color pathColor;
//   final Color dotColor;
//   final Color gridColor;
//   final double gridOpacity;
//
//   @override
//   State<ShiftingCurveLoader> createState() => _ShiftingCurveLoaderState();
// }
//
// class _ShiftingCurveLoaderState extends State<ShiftingCurveLoader>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//
//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       vsync: this,
//       duration: widget.cycleDuration,
//     )..repeat();
//   }
//
//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: widget.size.width,
//       height: widget.size.height,
//       color: const Color(0xFF0F0F0F),
//       child: AnimatedBuilder(
//         animation: _controller,
//         builder: (context, _) {
//           return CustomPaint(
//             painter: _ShiftingCurvePainter(
//               progress: _controller.value,
//               pathColor: widget.pathColor,
//               dotColor: widget.dotColor,
//               gridColor: widget.gridColor.withOpacity(widget.gridOpacity),
//             ),
//             size: widget.size,
//           );
//         },
//       ),
//     );
//   }
// }
//
// // ── Per-lane configuration ────────────────────────────────────────────────
// class LaneState {
//   double startY     = 0.0;
//   double endY       = 0.0;
//   double cp1xFactor = 0.0;
//   double cp1yOffset = 0.0;
//   double cp2xFactor = 0.0;
//   double cp2yOffset = 0.0;
//
//   LaneState.random(double height) {
//     final r = math.Random();
//     startY = 30 + r.nextDouble() * (height - 60);
//     endY   = 30 + r.nextDouble() * (height - 60);
//     cp1xFactor = 0.25 + r.nextDouble() * 0.35;     // 25–60%
//     cp2xFactor = 0.65 + r.nextDouble() * 0.25;     // 65–90%
//     cp1yOffset = -40 + r.nextDouble() * 80;        // moderate vertical pull
//     cp2yOffset = -50 + r.nextDouble() * 100;
//   }
// }
//
// class _ShiftingCurvePainter extends CustomPainter {
//   final double progress;
//   final Color pathColor;
//   final Color dotColor;
//   final Color gridColor;
//
//   static final List<LaneState> _lanes = [];
//   static final List<double> _lastCycle = List.filled(5, -1.0);
//
//   _ShiftingCurvePainter({
//     required this.progress,
//     required this.pathColor,
//     required this.dotColor,
//     required this.gridColor,
//   }) {
//     // Initialize on first paint
//     if (_lanes.isEmpty) {
//       _lanes.addAll(List.generate(5, (_) => LaneState.random(160)));
//     }
//   }
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     final w = size.width;
//     final h = size.height;
//
//     // Grid
//     final gridPaint = Paint()
//       ..color = gridColor
//       ..strokeWidth = 1.0;
//
//     const step = 20.0;
//     for (double x = 0; x <= w; x += step) {
//       canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
//     }
//     for (double y = 0; y <= h; y += step) {
//       canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
//     }
//
//     final pathPaint = Paint()
//       ..color = pathColor
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 3.2
//       ..strokeCap = StrokeCap.round;
//
//     final dotPaint = Paint()
//       ..color = dotColor
//       ..style = PaintingStyle.fill;
//
//     const laneCount = 5;
//     const marginY = 24.0;
//
//     for (int i = 0; i < laneCount; i++) {
//       final laneProg = (progress + i * 0.24) % 1.0;
//
//       // When dot reaches ~end → regenerate this lane's positions
//       if (laneProg < _lastCycle[i]) {
//         _lanes[i] = LaneState.random(h);
//       }
//       _lastCycle[i] = laneProg;
//
//       // Inside the for loop for each lane:
//
//       final lane = _lanes[i];
//
// // Start and end exactly at the sides, horizontal entry/exit
//       final path = Path();
//       path.moveTo(0, lane.startY);
//
// // Cubic with horizontal tangents at both ends
// // cp1 → far enough right + same y as start → flat start
// // cp2 → far enough left + same y as end   → flat end
//       path.cubicTo(
//         w * 0.25,               lane.startY,                    // cp1 x = 25%, y = startY → horizontal out
//         w * 0.75,               lane.endY,                      // cp2 x = 75%, y = endY   → horizontal in
//         w,                      lane.endY,                      // end point
//       );
//
// // Optional: make the middle bend more/less aggressive
// // You can still randomize the y-offset of the "bulge" if desired, e.g.:
//       double midYOffset = -60 + math.Random().nextDouble() * 120; // example range
// // Then adjust cp1.y and cp2.y like:
// // path.cubicTo(w * 0.25, lane.startY + midYOffset * 0.4, w * 0.75, lane.endY + midYOffset * 0.6, w, lane.endY);
//
//       canvas.drawPath(path, pathPaint);
//
// // ── Dot position (same cubic interpolation as before)
//       final t = laneProg.clamp(0.0, 1.0);
//       final x = _cubic(t, 0, w * 0.25, w * 0.75, w);
//       final y = _cubic(t, lane.startY, lane.startY, lane.endY, lane.endY);
// // Note: because control y == anchor y at both ends, the curve is flat there
//
//       canvas.drawCircle(
//         Offset(x, y.clamp(marginY, h - marginY)),
//         6.0,
//         dotPaint,
//       );
//     }
//   }
//
//   double _cubic(double t, double a, double b, double c, double d) {
//     final u = 1 - t;
//     final tt = t * t;
//     final uu = u * u;
//     return uu * u * a + 3 * uu * t * b + 3 * u * tt * c + tt * t * d;
//   }
//
//   @override
//   bool shouldRepaint(covariant _ShiftingCurvePainter old) => old.progress != progress;
// }

class CImaGenLinearProgressIndicator extends StatefulWidget {
  final double? value;
  const CImaGenLinearProgressIndicator({
    super.key,
    this.value
  });

  @override
  State<CImaGenLinearProgressIndicator> createState() => _CImaGenLinearProgressIndicatorState();
}

class _CImaGenLinearProgressIndicatorState extends State<CImaGenLinearProgressIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        double? pro = widget.value != null ? widget.value! * constraints.maxWidth / 1 : null;
        return Stack(
          children: [
            Container(
              height: 5,
              width: constraints.maxWidth,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2.5),
                  gradient: LinearGradient(colors: [
                    Theme.of(context).colorScheme.primary.withAlpha(100),
                    Color(0xFFFFFFFF).withAlpha(50),
                  ], stops: [0, 1])
              ),
            ),
            Container(
              clipBehavior: Clip.antiAlias,
              height: 5,
              width: pro,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2.5),
                  gradient: LinearGradient(colors: [
                    Theme.of(context).colorScheme.primaryContainer.withAlpha(120),
                    Theme.of(context).colorScheme.primary
                  ], stops: [0, 1])
              ),
              child: Shimmer.fromColors(
                baseColor: Colors.transparent,
                highlightColor: Colors.white.withAlpha(200),
                child: Container(
                  width: pro,
                  color: Colors.white,
                ),
              ),
            )
          ],
        );
      },
    );
  }
}