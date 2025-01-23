import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:image/image.dart' as img;
import 'dart:ui' as ui;

import '../Utils.dart';

class Vectorscope extends StatefulWidget {
  final String path;
  const Vectorscope({super.key, required this.path});

  @override
  State<Vectorscope> createState() => _VectorscopeState();
}

class _VectorscopeState extends State<Vectorscope> {
  late img.Image photo;
  String last = '';

  bool debug = false;

  Future<img.Image?>? data;

  @override
  void initState() {
    super.initState();
  }

  Future<Uint8List?> _calculation(String imagePath, BoxConstraints size) async {
    img.Image? data;
    if(false){
      data = await img.decodePngFile(imagePath);
    } else {
      try {
        final Uint8List bytes = await compute(readAsBytesSync, imagePath);
        data = await compute(img.decodeImage, bytes);
      } on PathNotFoundException catch (e){
        throw 'We\'ll fix it later.'; // TODO
      }
    }
    if(data != null) data = img.copyResize(data, width: 512);
    // Cack
    int r, g, b;
    var hsv, xy2d, xy1d;
    img.Image image = img.Image(width: size.maxWidth.round(), height: size.maxHeight.round());

    Offset center = Offset(size.maxWidth / 2, size.maxHeight / 2);
    double radius = math.max(math.min(size.maxWidth, size.maxHeight), 10) / 2 - 10;

    void hudReferencePoint(int r, int g, int b) {
      var hsv, xy2d;

      Paint pointStyle = Paint()..color = Color.fromRGBO(r, g, b, 1)..style = PaintingStyle.fill;
      hsv  = convertRGBtoHSV(r, g, b);
      xy2d = convertPolarToCartesian((hsv['s'] as double) * radius + 5, correction(hsv['h'] as double));
      img.fillCircle(image, x: (xy2d.x + center.dx).round(), y: (xy2d.y + center.dy).round(), color: img.ColorRgb8(r, g, b), radius: 3);
    }

    // lines
    Paint lineStyle = Paint()..color = const Color(0xFF666666)..strokeWidth = .24;
    img.drawLine(image, x1: (center.dx - radius).round(), y1: center.dy.round(), x2: (center.dx + radius).round(), y2: center.dy.round(), thickness: 0.24, color: img.ColorRgb8(102, 102, 102));
    img.drawLine(image, x1: center.dx.round(), y1: (center.dy - radius).round(), x2: center.dx.round(), y2: (center.dy + radius).round(), thickness: 0.24, color: img.ColorRgb8(102, 102, 102));
    //
    // circles
    //Paint circleLineStyle = Paint()..color = const Color(0xFF666666)..style = PaintingStyle.stroke..strokeWidth = .5;
    //hudCtx.setLineDash([3]); TODO
    img.drawCircle(image, x: center.dx.round(), y: center.dy.round(), radius: radius.round(), color: img.ColorRgb8(102, 102, 102), antialias: true);
    img.drawCircle(image, x: center.dx.round(), y: center.dy.round(), radius: (radius * 0.75).round(), color: img.ColorRgb8(102, 102, 102), antialias: true);
    img.drawCircle(image, x: center.dx.round(), y: center.dy.round(), radius: (radius * 0.5).round(), color: img.ColorRgb8(102, 102, 102), antialias: true);
    img.drawCircle(image, x: center.dx.round(), y: center.dy.round(), radius: (radius * 0.25).round(), color: img.ColorRgb8(102, 102, 102), antialias: true);

    // reference points
    hudReferencePoint(255,0,0);
    hudReferencePoint(255,255,0);
    hudReferencePoint(0,255,0);
    hudReferencePoint(0,255,255);
    hudReferencePoint(0,0,255);
    hudReferencePoint(255,0,255);

    Iterator<img.Pixel> d = data!.clone().getRange(0, 0, data.width, data.height);
    while (d.moveNext()) {
      final pixel = d.current;
      r = pixel.r.toInt();
      g = pixel.g.toInt();
      b = pixel.b.toInt();

      hsv  = convertRGBtoHSV(r, g, b);
      xy2d = convertPolarToCartesian(hsv['s'] * radius, correction(hsv['h'] as double));
      int x = (xy2d.x + center.dx).round();
      int y = (xy2d.y + center.dy).round();

      image.getPixel(x, y)..r = r..g = g..b = b;
    }
    return img.encodePng(image);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return Container(
        color: Colors.black,
        child: FutureBuilder(
          future: _calculation(widget.path, constraints), // a previously-obtained Future<String> or null
          builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
            Widget children;
            if (snapshot.hasData) {
              if(debug){
                return const Text('done');
              }
              children = Image.memory(snapshot.data);
            } else if (snapshot.hasError) {
              children = Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 60,
                    ),
                    Text('Error: ${snapshot.error}')
                  ],
                ),
              );
            } else {
              children = const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LinearProgressIndicator(),
                    Gap(2),
                    Text('Awaiting result...')
                  ],
                ),
              );
            }
            return children;
          },
        ),
      ); // Create a function here to adapt to the parent widget's constraints
    });
  }
}

double correction(double phi) => -phi * 2 * math.pi - math.pi * 3/5;

class HudPainter extends CustomPainter{

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }

  @override
  void paint(Canvas canvas, Size size) {
    Offset center = Offset(size.width / 2, size.height / 2);
    double radius = math.max(math.min(size.width, size.height), 10) / 2 - 10;

    void hudReferencePoint(int r, int g, int b) {
      var hsv, xy2d;

      Paint pointStyle = Paint()..color = Color.fromRGBO(r, g, b, 1)..style = PaintingStyle.fill;
      hsv  = convertRGBtoHSV(r, g, b);
      xy2d = convertPolarToCartesian((hsv['s'] as double) * radius + 5, correction(hsv['h'] as double));
      canvas.drawCircle(Offset(xy2d.x + center.dx, xy2d.y + center.dy), 3, pointStyle);
    }

    // init
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = Colors.black..style = PaintingStyle.fill);
    // lines
    Paint lineStyle = Paint()..color = const Color(0xFF666666)..strokeWidth = .24;
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), lineStyle);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), lineStyle);

    // circles
    Paint circleLineStyle = Paint()..color = const Color(0xFF666666)..style = PaintingStyle.stroke..strokeWidth = .5;
    // hudCtx.setLineDash([3]); TODO

    canvas.drawCircle(center, radius, circleLineStyle);
    canvas.drawCircle(center, radius * 0.75, circleLineStyle);
    canvas.drawCircle(center, radius * 0.5, circleLineStyle);
    canvas.drawCircle(center, radius * 0.25, circleLineStyle);

    // reference points
    hudReferencePoint(255,0,0);
    hudReferencePoint(255,255,0);
    hudReferencePoint(0,255,0);
    hudReferencePoint(0,255,255);
    hudReferencePoint(0,0,255);
    hudReferencePoint(255,0,255);
  }
}

Future shit(Uint8List data) async {
  Completer c = Completer();
  ui.decodeImageFromList(data, (ui.Image s) {
    c.complete(s);
  });
  return c.future;
}

class Line {
  final Color color;
  final double width;
  final double height;
  final double x;
  final double y;

  Line({
    required this.color,
    required this.width,
    required this.height,
    required this.x,
    required this.y
  });
}

int truncate(int x) {
  return x < 0 ? (-(-x).floor()) : (x.floor());
}

double nonIntRem(double x, double y) {
  return x - y * (x / y).truncate();
}

Object convertRGBtoHSV(int rIn, int gIn, int bIn) {
  var r = rIn / 255,
      g = gIn / 255,
      b = bIn / 255,
      minRGB = math.min(r, math.min(g, b)),
      maxRGB = math.max(r, math.max(g, b)),
      delta  = maxRGB - minRGB,
      H      = delta == 0 ? 0 : (
          r == maxRGB ? nonIntRem(((g - b) / delta), 6) : (
              g == maxRGB ? ((b - r) / delta + 2) : (
                  (r - g) / delta + 4
              ))),
      h      = (H >= 0 ? H : H + 6) / 6,
      s      = maxRGB == 0 ? 0 : delta / maxRGB,
      v      = maxRGB;

  return {'h': h, 's': s, 'v': v};
}

math.Point convertPolarToCartesian(double r, double phi) {
  return math.Point(r * math.cos(phi), r * math.sin(phi));
}