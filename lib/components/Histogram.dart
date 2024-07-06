import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:image/image.dart' as img;

import '../Utils.dart';

class Histogram extends StatefulWidget {
  final String path;
  const Histogram({super.key, required this.path});

  @override
  State<Histogram> createState() => _HistogramState();
}

class _HistogramState extends State<Histogram> {
  late img.Image photo;
  String last = '';

  bool debug = false;

  Future<img.Image?>? data;

  @override
  void initState() {
    super.initState();
  }

  Map<String, dynamic> getColourFrequencies(img.Image data) {

    int maxF_R = 0;
    int maxF_G = 0;
    int maxF_B = 0;

    List<int> cF_R = List<int>.generate(256, (i) => 0);
    List<int> cF_G = List<int>.generate(256, (i) => 0);
    List<int> cF_B = List<int>.generate(256, (i) => 0);

    // Iterate bitmap and count frequencies of specified component values

    //fuck
    final range = data.clone().getRange(0, 0, data.width, data.height);
    while (range.moveNext()) {
      final pixel = range.current;

      cF_R[pixel.r.toInt()]++;
      cF_G[pixel.g.toInt()]++;
      cF_B[pixel.b.toInt()]++;

      if(cF_R[pixel.r.toInt()] > maxF_R) maxF_R++;
      if(cF_G[pixel.g.toInt()] > maxF_G) maxF_G++;
      if(cF_B[pixel.b.toInt()] > maxF_B) maxF_B++;
    }

    return {
      'colourFrequencies': {
        'r': cF_R,
        'g': cF_G,
        'b': cF_B
      },
      'maxFrequency': {
        'r': maxF_R,
        'g': maxF_G,
        'b': maxF_B
      }
    };
  }

  Future<img.Image?> _calculation(String imagePath, BoxConstraints constraints) async {
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
    return data;
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
              List<Line> lines = [];
              double boxHeight = constraints.maxHeight;
              double lineWidth = constraints.maxWidth / 255;

              Map<String, dynamic> colourFrequencies = getColourFrequencies(snapshot.data);
              double x = 0.0;
              // //R
              for(int i = 0; i <= 255; i++) {

                Color colour = Colors.red;
                double pixelsPerUnit = boxHeight / colourFrequencies['maxFrequency']['r'];
                double columnHeight = (colourFrequencies['colourFrequencies']['r'] as List<int>)[i] * pixelsPerUnit;
                lines.add(Line(color: colour, width: lineWidth, height: columnHeight, x: x, y: boxHeight - columnHeight));
                x += lineWidth;
              }
              x = 0.0;
              //G
              for(int i = 0; i <= 255; i++) {

                Color colour = Colors.green;
                double pixelsPerUnit = boxHeight / colourFrequencies['maxFrequency']['g'];
                double columnHeight = (colourFrequencies['colourFrequencies']['g'] as List<int>)[i] * pixelsPerUnit;
                lines.add(Line(color: colour, width: lineWidth, height: columnHeight, x: x, y: boxHeight - columnHeight));
                x += lineWidth;
              }
              x = 0.0;
              //B
              for(int i = 0; i <= 255; i++) {

                Color colour = Colors.blue;
                double pixelsPerUnit = boxHeight / colourFrequencies['maxFrequency']['b'];
                double columnHeight = (colourFrequencies['colourFrequencies']['b'] as List<int>)[i] * pixelsPerUnit;
                lines.add(Line(color: colour, width: lineWidth, height: columnHeight, x: x, y: boxHeight - columnHeight));
                x += lineWidth;
              }
              //lines.add(Line(color: Colors.red, width: 2, height: 50, x: 0, y: 50)); //debug
              //print('${widget.path} ${lines[0].height}');
              children = CustomPaint(painter: DemoPainter(lines));
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


class DemoPainter extends CustomPainter{
  final List<Line> lines;

  DemoPainter(this.lines);

  @override
  void paint(Canvas canvas, Size size) {
    final paintObj = Paint();

    for(final line in lines){
      paintObj.blendMode = BlendMode.screen;
      paintObj.color = line.color;
      canvas.drawRect(Rect.fromLTWH(
        line.x,
        line.y,
        line.width,
        line.height,
      ),paintObj);
    }
  }

  @override
  bool shouldRepaint(DemoPainter oldDelegate) {
    return lines != oldDelegate.lines;
  }
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