import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class InkJetUnclog extends StatefulWidget{
  const InkJetUnclog({ super.key });

  @override
  _InkJetUnclogState createState() => _InkJetUnclogState();
}

class _InkJetUnclogState extends State<InkJetUnclog> {
  final TransformationController _transformationController =
  TransformationController();

  ui.Image? _generatedImage;
  Uint8List? unclogImage;

  bool magenta = true;
  bool cyan = true;
  bool yellow = true;
  bool black = true;
  bool red = false;
  bool green = false;

  double stripeWidth = 8;
  double density = 1.0;

  final int pageWidth = 2480;
  final int pageHeight = 3508;

  @override
  void initState() {
    super.initState();
    _generatePattern();
  }

  Future<void> _generatePattern() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(
        Rect.fromLTWH(0, 0, pageWidth.toDouble(), pageHeight.toDouble()),
        bgPaint);

    final activeColors = _getActiveColors();

    final double w = pageWidth.toDouble();
    final double h = pageHeight.toDouble();

    // ===== Micro Grid Settings =====
    double lineSpacing = 6;
    double thinLineWidth = 0.6;
    double diagonalSpacing = 10;

    for (int c = 0; c < activeColors.length; c++) {
      final sectionWidth = w / activeColors.length;
      final offsetX = c * sectionWidth;

      final paint = Paint()
        ..color = activeColors[c]
        ..strokeWidth = thinLineWidth
        ..style = PaintingStyle.stroke
        ..isAntiAlias = false;

      // ---- Vertical micro lines ----
      for (double x = 0; x < sectionWidth; x += lineSpacing) {
        canvas.drawLine(
          Offset(offsetX + x, 0),
          Offset(offsetX + x, h),
          paint,
        );
      }

      // ---- Horizontal micro lines ----
      for (double y = 0; y < h; y += lineSpacing) {
        canvas.drawLine(
          Offset(offsetX, y),
          Offset(offsetX + sectionWidth, y),
          paint,
        );
      }

      // ---- Diagonal forward ----
      for (double x = -h; x < sectionWidth; x += diagonalSpacing) {
        canvas.drawLine(
          Offset(offsetX + x, 0),
          Offset(offsetX + x + h, h),
          paint,
        );
      }

      // ---- Diagonal backward ----
      for (double x = 0; x < sectionWidth + h; x += diagonalSpacing) {
        canvas.drawLine(
          Offset(offsetX + x, 0),
          Offset(offsetX + x - h, h),
          paint,
        );
      }

      // ---- Micro dot layer (forces burst firing) ----
      final dotPaint = Paint()
        ..color = activeColors[c]
        ..style = PaintingStyle.fill;

      for (double y = 0; y < h; y += 12) {
        for (double x = 0; x < sectionWidth; x += 12) {
          canvas.drawCircle(
            Offset(offsetX + x, y),
            0.8,
            dotPaint,
          );
        }
      }
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(pageWidth, pageHeight);

    _generatedImage = image;

    final byteData =
    await image.toByteData(format: ui.ImageByteFormat.png);

    setState(() {
      unclogImage = byteData!.buffer.asUint8List();
    });
  }

  Future<void> exportTiff() async {
    if (_generatedImage == null) return;

    final byteData = await _generatedImage!
        .toByteData(format: ui.ImageByteFormat.rawRgba);

    final buffer = byteData!.buffer;

    final width = _generatedImage!.width;
    final height = _generatedImage!.height;

    final image = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: buffer,
      order: img.ChannelOrder.rgba,
    );

    final tiffBytes = img.encodeTiff(image);

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/unclog_export.tiff');

    await file.writeAsBytes(tiffBytes);

    debugPrint("TIFF exported to: ${file.path}");
  }


  List<Color> _getActiveColors() {
    List<Color> colors = [];

    if (cyan) colors.add(const Color(0xFF00FFFF));
    if (magenta) colors.add(const Color(0xFFFF00FF));
    if (yellow) colors.add(const Color(0xFFFFFF00));
    if (black) colors.add(Colors.black);
    if (red) colors.add(Colors.red);
    if (green) colors.add(Colors.green);

    if (colors.isEmpty) {
      colors.add(Colors.black);
    }

    return colors;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const breakpoint = 600.0;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: const Color(0xaa000000),
        elevation: 0,
      ),
      endDrawer: screenWidth >= breakpoint ? null : _buildMenu(),
      drawerEdgeDragWidth:
      screenWidth >= breakpoint ? null : MediaQuery.of(context).size.width / 2,
      body: SafeArea(
        child: screenWidth >= breakpoint
            ? Row(
          children: [
            Expanded(child: _buildMain()),
            _buildMenu()
          ],
        )
            : _buildMain(),
      ),
    );
  }

  Widget _buildMain() {
    if (unclogImage == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return InteractiveViewer(
      transformationController: _transformationController,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      panEnabled: true,
      scaleFactor: 1000,
      minScale: 0.000001,
      maxScale: double.infinity,
      child: Center(
        child: Image.memory(
          unclogImage!,
          gaplessPlayback: true,
          filterQuality: FilterQuality.none,
        ),
      ),
    );
  }

  Widget _buildMenu() {
    return Container(
      padding: const EdgeInsets.all(12),
      width: 420,
      color: const Color(0xff111111),
      child: SingleChildScrollView(
        child: Column(
          children: [
            ExpansionTile(
              initiallyExpanded: true,
              tilePadding: EdgeInsets.zero,
              title: Text(
                'Main',
                style: TextStyle(
                    color: Colors.deepPurple.shade50,
                    fontWeight: FontWeight.w600,
                    fontSize: 18),
              ),
              children: [
                _colorSwitch("Cyan", cyan, (v) {
                  setState(() => cyan = v);
                  _generatePattern();
                }),
                _colorSwitch("Magenta", magenta, (v) {
                  setState(() => magenta = v);
                  _generatePattern();
                }),
                _colorSwitch("Yellow", yellow, (v) {
                  setState(() => yellow = v);
                  _generatePattern();
                }),
                _colorSwitch("Black", black, (v) {
                  setState(() => black = v);
                  _generatePattern();
                }),
                _colorSwitch("Red", red, (v) {
                  setState(() => red = v);
                  _generatePattern();
                }),
                _colorSwitch("Green", green, (v) {
                  setState(() => green = v);
                  _generatePattern();
                }),
                const SizedBox(height: 20),
                const Text("Stripe Width",
                    style: TextStyle(color: Colors.white)),
                Slider(
                  value: stripeWidth,
                  min: 2,
                  max: 50,
                  onChanged: (v) {
                    setState(() => stripeWidth = v);
                    _generatePattern();
                  },
                ),
                const SizedBox(height: 20),
                const Text("Density",
                    style: TextStyle(color: Colors.white)),
                Slider(
                  value: density,
                  min: 0.1,
                  max: 1.0,
                  onChanged: (v) {
                    setState(() => density = v);
                    _generatePattern();
                  },
                ),
                ElevatedButton(
                    style: ButtonStyle(
                        foregroundColor: WidgetStateProperty.all<Color>(Theme.of(context).colorScheme.onPrimary),
                        backgroundColor: WidgetStateProperty.all<Color>(Theme.of(context).colorScheme.primary),
                        shape: WidgetStateProperty.all<RoundedRectangleBorder>(const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))))
                    ),
                    onPressed: () => exportTiff(),
                    child: Text('Export', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Montserrat'))
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorSwitch(String title, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(title, style: const TextStyle(color: Colors.white)),
    );
  }
}