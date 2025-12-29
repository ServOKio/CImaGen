import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

img.Image decodeImageIsolate(Uint8List data) {
  final image = img.decodeImage(data);
  if (image == null) {
    throw Exception('Failed to decode image');
  }
  return image;
}

class HistogramWidget extends StatelessWidget {
  final Uint8List imageBytes;
  const HistogramWidget(this.imageBytes, {super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<img.Image>(
      future: compute(decodeImageIsolate, imageBytes),
      builder: (context, imageSnap) {
        if (!imageSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return FutureBuilder<HistogramData>(
          future: compute(computeHistogram, imageSnap.data!),
          builder: (context, histSnap) {
            if (!histSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return HistogramView(histSnap.data!);
          },
        );
      },
    );
  }
}


class HistogramPainter extends CustomPainter {
  final HistogramData data;
  final bool logScale;

  HistogramPainter(this.data, {this.logScale = true});

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF3A3A3A),
    );

    // Histogram channels
    _drawChannel(
      canvas,
      size,
      data.r,
      data.max,
      const Color.fromARGB(180, 255, 80, 80),
    );
    _drawChannel(
      canvas,
      size,
      data.g,
      data.max,
      const Color.fromARGB(180, 80, 255, 80),
    );
    _drawChannel(
      canvas,
      size,
      data.b,
      data.max,
      const Color.fromARGB(180, 80, 80, 255),
    );

    _drawClipping(canvas, size, data);
  }

  void _drawChannel(
      Canvas canvas,
      Size size,
      Uint32List src,
      int max,
      Color color,
      ) {
    final paint = Paint()
      ..color = color
      ..blendMode = BlendMode.screen
      ..style = PaintingStyle.fill;

    final bins = src.length;
    final columns = size.width.toInt();
    final binsPerColumn = bins / columns;

    final values = List<double>.filled(columns, 0);

    // Aggregate (MAX per column)
    for (int x = 0; x < columns; x++) {
      final start = (x * binsPerColumn).floor();
      final end = ((x + 1) * binsPerColumn).ceil().clamp(0, bins);

      int peak = 0;
      for (int i = start; i < end; i++) {
        if (src[i] > peak) peak = src[i];
      }

      double v = peak / max;
      if (logScale && v > 0) {
        v = math.log(v * 1000 + 1) / math.log(1001);
      }

      values[x] = v;
    }

    // Simple horizontal smoothing
    const radius = 2;
    final smooth = List<double>.filled(columns, 0);
    for (int i = 0; i < columns; i++) {
      double sum = 0;
      int count = 0;
      for (int j = i - radius; j <= i + radius; j++) {
        if (j >= 0 && j < columns) {
          sum += values[j];
          count++;
        }
      }
      smooth[i] = sum / count;
    }

    // Filled path
    final path = Path()..moveTo(0, size.height);
    for (int x = 0; x < columns; x++) {
      final y = size.height * (1 - smooth[x]);
      path.lineTo(x.toDouble(), y);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  void _drawClipping(Canvas canvas, Size size, HistogramData data) {
    final paint = Paint()..color = Colors.white;

    // Left (shadows clipped)
    if (data.clipLow) {
      final path = Path()
        ..moveTo(6, size.height - 6)
        ..lineTo(14, size.height - 6)
        ..lineTo(10, size.height - 14)
        ..close();
      canvas.drawPath(path, paint);
    }

    // Right (highlights clipped)
    if (data.clipHigh) {
      final path = Path()
        ..moveTo(size.width - 6, size.height - 6)
        ..lineTo(size.width - 14, size.height - 6)
        ..lineTo(size.width - 10, size.height - 14)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(HistogramPainter old) =>
      old.data != data || old.logScale != logScale;
}


class HistogramData {
  final Uint32List r, g, b;
  final int max;

  final bool clipLow;
  final bool clipHigh;

  HistogramData(
      this.r,
      this.g,
      this.b,
      this.max, {
        required this.clipLow,
        required this.clipHigh,
      });
}

HistogramData computeHistogram(img.Image image) {
  final int bins = image.bitsPerChannel == 16
      ? 65536
      : image.bitsPerChannel == 32
      ? 16777216
      : 256;

  final r = Uint32List(bins);
  final g = Uint32List(bins);
  final b = Uint32List(bins);

  int maxVal = 0;
  bool clipLow = false;
  bool clipHigh = false;

  for (final p in image) {
    final ri = p.r.toInt();
    final gi = p.g.toInt();
    final bi = p.b.toInt();

    if (ri == 0 || gi == 0 || bi == 0) clipLow = true;
    if (ri == bins - 1 || gi == bins - 1 || bi == bins - 1) clipHigh = true;

    maxVal = [
      ++r[ri],
      ++g[gi],
      ++b[bi],
      maxVal
    ].reduce((a, b) => a > b ? a : b);
  }

  return HistogramData(
    r,
    g,
    b,
    maxVal,
    clipLow: clipLow,
    clipHigh: clipHigh,
  );
}

class HistogramView extends StatefulWidget {
  final HistogramData data;
  const HistogramView(this.data, {super.key});

  @override
  State<HistogramView> createState() => _HistogramViewState();
}

class _HistogramViewState extends State<HistogramView> {
  bool logScale = true;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: ()=> setState(() => logScale = !logScale),
      child: HistogramCanvas(
        data: widget.data,
        logScale: logScale,
      )
    );
  }
}

class HistogramHover {
  final int bin;
  final int r, g, b;
  final double luminance;

  HistogramHover(this.bin, this.r, this.g, this.b, this.luminance);
}

class HistogramCanvas extends StatefulWidget {
  final HistogramData data;
  final bool logScale;

  const HistogramCanvas({
    super.key,
    required this.data,
    required this.logScale,
  });

  @override
  State<HistogramCanvas> createState() => _HistogramCanvasState();
}

class _HistogramCanvasState extends State<HistogramCanvas> {
  HistogramHover? hover;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) {
        final box = context.findRenderObject() as RenderBox;
        final local = box.globalToLocal(event.position);
        final width = box.size.width;

        final bin = ((local.dx / width) * widget.data.r.length)
            .clamp(0, widget.data.r.length - 1)
            .toInt();

        final r = widget.data.r[bin];
        final g = widget.data.g[bin];
        final b = widget.data.b[bin];

        final lum =
            0.2126 * r + 0.7152 * g + 0.0722 * b;

        setState(() {
          hover = HistogramHover(bin, r, g, b, lum);
        });
      },
      onExit: (_) => setState(() => hover = null),
      child: Stack(
        children: [
          CustomPaint(
            painter: HistogramPainter(
              widget.data,
              logScale: widget.logScale,
            ),
            size: Size.infinite,
          ),
          if (hover != null) _HoverOverlay(hover!)
        ],
      ),
    );
  }
}

class _HoverOverlay extends StatelessWidget {
  final HistogramHover h;
  const _HoverOverlay(this.h);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 8,
      top: 8,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white, fontSize: 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bin: ${h.bin}'),
              Text('R: ${h.r}'),
              Text('G: ${h.g}'),
              Text('B: ${h.b}'),
              Text('Lum: ${h.luminance.toStringAsFixed(1)}'),
            ],
          ),
        ),
      ),
    );
  }
}
