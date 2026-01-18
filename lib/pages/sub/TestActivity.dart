import 'dart:io';
import 'dart:math';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:image/image.dart' as img;
import 'package:json_annotation/json_annotation.dart';
import 'package:palette_generator/palette_generator.dart';

class TestActivity extends StatefulWidget{
  const TestActivity({ super.key });

  @override
  State<TestActivity> createState() => _TestActivityState();
}

class _TestActivityState extends State<TestActivity> {
  bool vertical = false;
  Uint8List? weekImageData;
  ColorScheme c = ColorScheme.dark();
  late PaletteGenerator p;
  late img.Image weekImage;

  bool loaded = false;

  String path = 'K:\\pictures\\sd\\Арты\\00000-3570347650 copy.png';

  @override
  void initState(){
    super.initState();
    init();
  }

  Future<void> init() async {
    weekImageData = await File(path).readAsBytes();
    weekImage = img.decodeImage(weekImageData!)!;
    vertical = weekImage.width < weekImage.height;

    p = await PaletteGenerator.fromImageProvider(
        maximumColorCount: 10,
        Image.memory(weekImageData!).image
    );
    setState(() {
      c = ColorScheme.fromSeed(seedColor: p.dominantColor!.color, brightness: Brightness.dark);
      loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: loaded ? Padding(
          padding: EdgeInsetsGeometry.all(20),
          child: Column(
            children: [
              Flexible(
                flex: 2,
                fit: FlexFit.tight,
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Flexible(
                      //   flex: 1,
                      //   fit: FlexFit.tight,
                      //   child: Container(
                      //       decoration: BoxDecoration(
                      //         borderRadius: BorderRadius.circular(10),
                      //         color: Colors.cyan,
                      //       ) //BoxDecoration
                      //   ), //Container
                      // ),
                      // Gap(20),
                      Flexible(
                        flex: 2,
                        fit: FlexFit.tight,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            color: c.primary,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final containerW = constraints.maxWidth;
                                final containerH = constraints.maxHeight;

                                final imageW = weekImage.width.toDouble();
                                final imageH = weekImage.height.toDouble();

                                final scale = math.max(
                                  containerW / imageW,
                                  containerH / imageH,
                                );

                                final scaledW = imageW * scale;
                                final scaledH = imageH * scale;

                                final dx = (containerW - scaledW) / 2;
                                final dy = (containerH - scaledH) / 2;

                                return Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Image.memory(
                                        weekImageData!,
                                        fit: BoxFit.cover,
                                      ),
                                    ),

                                    Positioned(
                                      left: dx,
                                      top: dy,
                                      //width: scaledW,
                                      height: scaledH,
                                      child: GlassShader.memory(
                                        weekImageData!,
                                        width: imageW / 3,
                                        height: imageH,
                                        top: 0,
                                        left: 0,
                                        multiply: 15,
                                      ),
                                    ),
                                    Positioned(
                                      top: 20,
                                      left: 20,
                                      bottom: 20,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(15)
                                            ),
                                            padding: EdgeInsets.only(left: 15, right: 15, top: 5, bottom: 3),
                                            child: Text('Jan 29, 2026', style: TextStyle(color: Colors.black87, fontFamily: 'Montserrat', fontWeight: FontWeight.bold)),
                                          ),
                                          Gap(12),
                                          Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(15),
                                              border: BoxBorder.all(color: Colors.white, width: 1)
                                            ),
                                            padding: EdgeInsets.only(left: 15, right: 15, top: 5, bottom: 3),
                                            child: Row(
                                              children: [
                                                Container(
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Colors.white
                                                  ),
                                                  width: 4,
                                                  height: 4,
                                                ),
                                                Gap(8),
                                                Text('Custom', style: TextStyle(color: Colors.white, fontFamily: 'Montserrat')),
                                              ],
                                            ),
                                          ),
                                          Spacer(),
                                          AdaptiveBubbleText(
                                            text: 'Bigger. Stronger. Better.\nAnd All Yours',
                                            maxWidth: containerW/2,
                                            style: const TextStyle(
                                              fontSize: 38,
                                              fontFamily: 'Montserrat',
                                              fontWeight: FontWeight.w600,
                                              height: 1.25,
                                              color: Colors.black,
                                            ),
                                            radius: 14,
                                            innerPadding: 15,
                                            backgroundColor: Colors.white,
                                          ),
                                          Spacer(flex: 3),
                                          Row(
                                            children: [
                                              Icon(Icons.center_focus_weak_rounded),
                                              Gap(5),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('Picture of the Week', style: TextStyle(color: Colors.white.withAlpha(200), height: 1, fontSize: 12)),
                                                  GestureDetector(
                                                    child: Text('By Brack', style: TextStyle(color: Colors.white, height: 1, fontFamily: 'ShareTechMono')),
                                                  )
                                                ],
                                              )
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                    Positioned(
                                      top: 20,
                                      right: 20,
                                      child: GestureDetector(
                                        child: Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white
                                          ),
                                          child: Transform.rotate(angle: -45 * pi / 180, child: Icon(Icons.arrow_forward_rounded, color: Colors.black87)),
                                        ),
                                      ),
                                    )
                                  ],
                                );
                              },
                            ),
                          ),
                        )
                      ),
                    ]
                )
              ),
              Gap(20),
              Flexible(
                flex: 1,
                fit: FlexFit.tight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Flexible(
                      flex: 2,
                      fit: FlexFit.tight,
                      child: Container(
                        decoration: BoxDecoration(
                          image: DecorationImage(image: FileImage(File('F:\\PC2\\РабСто\\тестировать\\img3.png')), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withAlpha(100), BlendMode.dstATop)),
                          borderRadius: BorderRadius.circular(10),
                          color: p.dominantColor?.color,
                        ),
                        child: Padding(padding: EdgeInsetsGeometry.all(20), child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white
                                  ),
                                  width: 4,
                                  height: 4,
                                ),
                                Gap(8),
                                Text('Related', style: TextStyle(color: Colors.white, fontFamily: 'Montserrat', fontWeight: FontWeight.w500)),
                              ],
                            ),
                            Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Navigate through workflow with ease to get better results',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.w500,
                                      fontSize: 22,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Gap(10),
                                GestureDetector(
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(width: 1, color: Colors.white),
                                    ),
                                    child: Transform.rotate(
                                      angle: 45 * pi / 180,
                                      child: const Icon(
                                        Icons.arrow_forward_rounded,
                                        color: Colors.white,
                                        size: 30,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          ],
                        )),
                      ), //Container
                    ),
                    Gap(20),
                    Flexible(
                      flex: 1,
                      fit: FlexFit.tight,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: c.secondary,
                        ), //BoxDecoration
                      ), //Container
                    ),
                    Gap(20),
                    Flexible(
                      flex: 1,
                      fit: FlexFit.tight,
                      child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: c.surface,
                          ) //BoxDecoration
                      ), //Container
                    )
                  ],
                ), //Row
              ),
            ],
          ),
        ) : Center(child: CircularProgressIndicator())
        // body: SafeArea(
        //     child: Stack(
        //       children: [
        //         Image.file(File(path), fit: BoxFit.contain),
        //         GlassShader.file(
        //           path,
        //           width: 600,
        //           height: 400,
        //           left: 200,
        //           top: 150,
        //         ),
        //       ],
        //     )
        //     //WcgImage.file("W:\\image-red-P3.jpg")
        // )
    );
  }
}

Map<String, dynamic> jsonTest = {
  'imageOfWeek': {
    'url': ''
  }
};

@JsonSerializable()
class DayInfo{
  final String json;
  final double width;
  final double height;
  final double top;
  final double left;

  const DayInfo({
    required this.json,
    required this.width,
    required this.height,
    required this.top,
    required this.left
  });
}

class GlassShader extends StatefulWidget {
  final Uint8List? bytes;
  final String? path;
  final double width;
  final double height;
  final double top;
  final double left;
  final int multiply;

  const GlassShader.file(
      this.path, {
        super.key,
        required this.width,
        required this.height,
        required this.top,
        required this.left,
        this.multiply = 0
      }) : bytes = null;

  const GlassShader.memory(
      this.bytes, {
        super.key,
        required this.width,
        required this.height,
        required this.top,
        required this.left,
        this.multiply = 0,
      }) : path = null;

  @override
  State<GlassShader> createState() => _GlassShaderState();
}

class _GlassShaderState extends State<GlassShader> {
  Uint8List? _result;

  @override
  void initState() {
    super.initState();
    _process();
  }

  Future<void> _process() async {
    final Uint8List sourceBytes;

    if (widget.bytes != null) {
      sourceBytes = widget.bytes!;
    } else {
      sourceBytes = await File(widget.path!).readAsBytes();
    }

    final original = img.decodeImage(sourceBytes)!;

    final cropped = img.copyCrop(
      original,
      x: widget.left.round(),
      y: widget.top.round(),
      width: widget.width.round(),
      height: widget.height.round(),
    );

    final glass = ribbedGlass(
      cropped,
      sliceWidth: 6 * widget.multiply,
      sampleWidth: 40 * (widget.multiply / 2).round(),
      chromaShift: 2 * (widget.multiply / 4).round(),
      jitter: 1,
    );

    setState(() {
      _result = Uint8List.fromList(img.encodePng(glass));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_result == null) return const SizedBox.shrink();

    return Image.memory(
      _result!,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
    );
  }
}

img.Image ribbedGlass(img.Image src, {int sliceWidth = 8, int sampleWidth = 32, int jitter = 2, int chromaShift = 2, int noiseAmount = 6,}) {
  final w = src.width;
  final h = src.height;
  final dst = img.Image(width: w, height: h);

  final rand = Random(42);

  int x = 0;
  while (x < w) {
    int srcX = x + rand.nextInt(jitter * 2 + 1) - jitter;
    srcX = srcX.clamp(0, w - sampleWidth);

    for (int dx = 0; dx < sliceWidth && x + dx < w; dx++) {
      final t = dx / sliceWidth;
      final baseX = srcX + (t * sampleWidth).floor();

      for (int y = 0; y < h; y++) {
        // Chromatic aberration sampling
        final rX = (baseX + chromaShift).clamp(0, w - 1);
        final gX = baseX.clamp(0, w - 1);
        final bX = (baseX - chromaShift).clamp(0, w - 1);

        final r = src.getPixel(rX, y).r.toInt();
        final g = src.getPixel(gX, y).g.toInt();
        final b = src.getPixel(bX, y).b.toInt();
        final a = src.getPixel(gX, y).a.toInt();

        // Noise (fine grain)
        final n = rand.nextInt(noiseAmount * 2 + 1) - noiseAmount;

        dst.setPixelRgba(
          x + dx,
          y,
          (r + n).clamp(0, 255),
          (g + n).clamp(0, 255),
          (b + n).clamp(0, 255),
          a,
        );
      }
    }
    x += sliceWidth;
  }

  return dst;
}

class AdaptiveBubbleText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final double maxWidth;
  final double radius;
  final Color backgroundColor;
  final double innerPadding;

  const AdaptiveBubbleText({
    super.key,
    required this.text,
    required this.style,
    required this.maxWidth,
    this.radius = 14,
    this.backgroundColor = Colors.white,
    this.innerPadding = 0
  });

  @override
  Widget build(BuildContext context) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    final metrics = tp.computeLineMetrics();

    final width = metrics
        .map((m) => m.width)
        .fold<double>(0, (a, b) => a > b ? a : b);

    final height = metrics.fold<double>(0, (sum, m) => sum + m.height);

    return CustomPaint(
      size: Size(width + innerPadding * 2, height + innerPadding * 2),
      painter: _BubblePainter(
        text: text,
        style: style,
        maxWidth: maxWidth,
        innerPadding: innerPadding,
        radius: radius,
        backgroundColor: backgroundColor,
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  final String text;
  final TextStyle style;
  final double maxWidth;
  final double innerPadding;
  final double radius;
  final Color backgroundColor;

  _BubblePainter({
    required this.text,
    required this.style,
    required this.maxWidth,
    required this.radius,
    required this.backgroundColor,
    required this.innerPadding
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(maxWidth: maxWidth);

    final metrics = textPainter.computeLineMetrics();

    final lines = <Rect>[];
    double y = 0;

    for (final m in metrics) {
      lines.add(Rect.fromLTWH(
        0,
        y,
        m.width,
        m.height,
      ));
      y += m.height;
    }

    final path = _buildBubblePath(lines, radius, innerPadding);

    canvas.drawPath(
      path,
      Paint()..color = backgroundColor,
    );

    textPainter.paint(canvas, Offset(innerPadding, innerPadding));
  }

  Path _buildBubblePath(List<Rect> lines, double r, double padding) {
    final p = Path();

    final first = lines.first;
    final last = lines.last;
    final leftX = lines.map((l) => l.left).reduce((a, b) => a < b ? a : b);

    // ── TOP EDGE - OK
    p.moveTo(leftX + r, first.top);
    p.lineTo(first.right + padding * 2 - r, first.top);
    p.arcToPoint(
      Offset(first.right + padding * 2, first.top + r),
      radius: Radius.circular(r),
    );

    // ── RIGHT EDGE (SMART STEPPED)
    for (int i = 0; i < lines.length; i++) {
      final cur = lines[i];
      final next = i + 1 < lines.length ? lines[i + 1] : null;

      if (next == null) {
        // last line - OK
        p.lineTo(cur.right + padding * 2, cur.bottom + padding * 2 - r);
        p.arcToPoint(
          Offset(cur.right + padding * 2 - r, cur.bottom + padding * 2),
          radius: Radius.circular(r),
        );
        break;
      }

      if (next.right == cur.right) {
        // straight vertical
        p.lineTo(cur.right, next.top); // x3
      } else if (next.right < cur.right) {
        // shrink → inward ╭ - OK
        p.lineTo(cur.right + padding * 2, cur.bottom + padding * 2 - r);

        p.arcToPoint(
          Offset(cur.right + padding * 2 - r, cur.bottom + padding * 2),
          radius: Radius.circular(r),
          clockwise: true,
        );

        p.lineTo(next.right + padding * 2 + r, cur.bottom + padding * 2);

        p.arcToPoint(
          Offset(next.right + padding * 2, next.top + padding * 2 + r),
          radius: Radius.circular(r),
          clockwise: false,
        );
      } else {
        // grow → outward ╮ // TODO
        p.lineTo(cur.right, cur.bottom - r);

        p.arcToPoint(
          Offset(cur.right + r, cur.bottom),
          radius: Radius.circular(r),
          clockwise: false,
        );

        p.lineTo(next.right - r, cur.bottom);

        p.arcToPoint(
          Offset(next.right, next.top + r),
          radius: Radius.circular(r),
          clockwise: true,
        );
      }
    }


    // ── BOTTOM EDGE
    p.lineTo(leftX + r, last.bottom + padding * 2);
    p.arcToPoint(
      Offset(leftX, last.bottom + padding * 2 - r),
      radius: Radius.circular(r),
    );
    //
    // ── LEFT EDGE (SINGLE WALL) - OK
    p.lineTo(leftX, first.top + r);
    p.arcToPoint(
      Offset(leftX + r, first.top),
      radius: Radius.circular(r),
    );

    p.close();
    return p;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}