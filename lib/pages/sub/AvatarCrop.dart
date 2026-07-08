import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:gap/gap.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:image/image.dart' as img;
import 'package:cimagen/utils/ImageManager.dart';

import '../../Utils.dart';

class AvatarCrop extends StatefulWidget {
  final ImageMeta? imageMeta;
  const AvatarCrop({super.key, this.imageMeta});

  @override
  _AvatarCropState createState() => _AvatarCropState();
}

class _AvatarCropState extends State<AvatarCrop> {
  final TransformationController _transformationController = TransformationController();

  late Future<Uint8List?> _imageDataFuture;

  // Render sizes for export calculation
  double _renderWidth = 0;
  double _renderHeight = 0;

  // Crop UI Settings
  bool _isCircle = true;
  bool _showGrid = true;
  bool _flipH = false;
  bool _flipV = false;
  double _rotation = 0.0;

  // Crop Frame State
  Rect _localCropRect = Rect.zero;
  static const double _outputResolution = 512.0;

  @override
  void initState() {
    super.initState();
    if (widget.imageMeta != null) {
      _imageDataFuture = _readImageFile(widget.imageMeta!);
    } else {
      _imageDataFuture = Future.error('No image provided');
    }
  }

  Future<Uint8List?> _readImageFile(ImageMeta imageMeta) async {
    try {
      if (imageMeta.fullImage == null) {
        await imageMeta.makeFullImage();
      }
      return imageMeta.fullImage!;
    } on PathNotFoundException {
      throw 'We\'ll fix it later.';
    }
  }

  Future<void> buildExport() async {
    try {
      final Uint8List? imgBytes = await _imageDataFuture;
      if (imgBytes == null) throw Exception("Image data is null");

      // 1. Decode original image
      img.Image? original = img.decodeImage(imgBytes);
      if (original == null) throw Exception("Failed to decode image");

      // 2. Apply UI transforms to the original image buffer to match what's on screen
      if (_flipH) original = img.flipHorizontal(original);
      if (_flipV) original = img.flipVertical(original);
      if (_rotation != 0) {
        original = img.copyRotate(original, angle: (_rotation * 180 / math.pi).round());
      }

      // 3. Calculate BoxFit.contain scale based on the rendered widget size
      double scale = math.min(_renderWidth / original.width, _renderHeight / original.height);
      double paintedWidth = original.width * scale;
      double paintedHeight = original.height * scale;

      // Because it's centered in the SizedBox
      double offsetX = (_renderWidth - paintedWidth) / 2;
      double offsetY = (_renderHeight - paintedHeight) / 2;

      // 4. Map Local Crop Rect to Image Pixel Coordinates
      int px = ((_localCropRect.left - offsetX) / scale).round().clamp(0, original.width - 1);
      int py = ((_localCropRect.top - offsetY) / scale).round().clamp(0, original.height - 1);
      int pw = (_localCropRect.width / scale).round().clamp(1, original.width - px);
      int ph = (_localCropRect.height / scale).round().clamp(1, original.height - py);

      // 5. Crop and Resize
      img.Image cropped = img.copyCrop(original, x: px, y: py, width: pw, height: ph);
      img.Image resized = img.copyResize(cropped, width: _outputResolution.toInt(), height: _outputResolution.toInt(), maintainAspect: false);

      // 6. Circle mask if needed
      Uint8List finalBytes;
      if (_isCircle) {
        finalBytes = await compute(_makeCircleTransparent, img.encodePng(resized));
      } else {
        finalBytes = img.encodePng(resized);
      }

      // 7. Save
      File f = File('W:\\${getRandomString(32)}.png');
      await f.writeAsBytes(finalBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Avatar exported successfully!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  static Uint8List _makeCircleTransparent(Uint8List pngBytes) {
    img.Image? image = img.decodePng(pngBytes);
    if (image == null) return pngBytes;

    img.Image masked = img.Image(width: image.width, height: image.height);
    int centerX = image.width ~/ 2;
    int centerY = image.height ~/ 2;
    int radius = image.width ~/ 2;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        int dx = x - centerX;
        int dy = y - centerY;
        double distance = math.sqrt(dx * dx + dy * dy);

        if (distance <= radius) {
          masked.setPixel(x, y, image.getPixel(x, y));
        } else {
          masked.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0)); // Transparent
        }
      }
    }
    return img.encodePng(masked);
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
        drawerEdgeDragWidth: screenWidth >= breakpoint ? null : MediaQuery.of(context).size.width / 2,
        body: SafeArea(
            child: screenWidth >= breakpoint
                ? Row(
              children: [
                Expanded(child: _buildMain()),
                _buildMenu(),
              ],
            )
                : _buildMain()));
  }

  Widget _buildMain() {
    return LayoutBuilder(
      builder: (context, constraints) {
        _renderWidth = constraints.maxWidth;
        _renderHeight = constraints.maxHeight;

        if (_localCropRect == Rect.zero) {
          double cropSize = math.min(_renderWidth, _renderHeight) * 0.6;
          _localCropRect = Rect.fromCenter(
            center: Offset(_renderWidth / 2, _renderHeight / 2),
            width: cropSize,
            height: cropSize,
          );
        }

        return InteractiveViewer(
          transformationController: _transformationController,
          boundaryMargin: const EdgeInsets.all(double.infinity),
          minScale: 0.1,
          maxScale: 8.0,
          child: SizedBox(
            width: _renderWidth,
            height: _renderHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. Image with Visual Transforms
                Center(
                  child: Transform.rotate(
                    angle: _rotation,
                    child: Transform.flip(
                      flipX: _flipH,
                      flipY: _flipV,
                      child: FutureBuilder<Uint8List?>(
                        future: _imageDataFuture,
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return Image.memory(
                              snapshot.data!,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                            );
                          } else if (snapshot.hasError) {
                            return Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red));
                          }
                          return const CircularProgressIndicator();
                        },
                      ),
                    ),
                  ),
                ),

                // 2. Dark Overlay outside crop area
                CustomPaint(
                  size: Size.infinite,
                  painter: DarkOverlayPainter(cropRect: _localCropRect),
                ),

                // 3. Draggable Crop Frame
                Positioned.fromRect(
                  rect: _localCropRect,
                  child: GestureDetector(
                    // 1 finger drags the crop area.
                    // 2 fingers will bypass this and zoom the InteractiveViewer.
                    onPanUpdate: (details) {
                      setState(() {
                        _localCropRect = _localCropRect.translate(details.delta.dx, details.delta.dy);
                      });
                    },
                    child: Stack(
                      children: [
                        // Border
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                        // Grid
                        if (_showGrid)
                          CustomPaint(
                            size: Size.infinite,
                            painter: GridPainter(),
                          ),
                        // Circle Overlay
                        if (_isCircle)
                          Center(
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenu() {
    return Container(
      padding: const EdgeInsets.all(6),
      width: 420,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        child: Column(
          children: [
            SettingsList(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              sections: [
                SettingsSection(
                  title: const Text('Crop Settings'),
                  tiles: [
                    SettingsTile.switchTile(
                      title: const Text('Circular Crop'),
                      leading: const Icon(Icons.circle_outlined),
                      initialValue: _isCircle,
                      onToggle: (v) => setState(() => _isCircle = v),
                    ),
                    SettingsTile.switchTile(
                      title: const Text('Show Guidelines'),
                      leading: const Icon(Icons.grid_3x3),
                      initialValue: _showGrid,
                      onToggle: (v) => setState(() => _showGrid = v),
                    ),
                    SettingsTile.navigation(
                      title: const Text('Crop Size'),
                      leading: const Icon(Icons.aspect_ratio),
                      trailing: SizedBox(
                        width: 150,
                        child: Slider(
                          // Safely clamp the value to prevent range errors
                          value: _localCropRect.width.clamp(80.0, math.max(81.0, math.min(_renderWidth, _renderHeight) * 0.9)),
                          min: 80.0,
                          // Ensure max is never less than min (80.0)
                          max: math.max(81.0, math.min(_renderWidth, _renderHeight) * 0.9),
                          onChanged: (v) {
                            setState(() {
                              final center = _localCropRect.center;
                              _localCropRect = Rect.fromCenter(center: center, width: v, height: v);
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                SettingsSection(
                  title: const Text('Transform'),
                  tiles: [
                    SettingsTile.navigation(
                      title: const Text('Rotate'),
                      leading: const Icon(Icons.rotate_right),
                      trailing: SizedBox(
                        width: 150,
                        child: Slider(
                          value: _rotation,
                          min: -math.pi,
                          max: math.pi,
                          onChanged: (v) => setState(() => _rotation = v),
                        ),
                      ),
                    ),
                    SettingsTile.switchTile(
                      title: const Text('Flip Horizontal'),
                      leading: const Icon(Icons.flip),
                      initialValue: _flipH,
                      onToggle: (v) => setState(() => _flipH = v),
                    ),
                    SettingsTile.switchTile(
                      title: const Text('Flip Vertical'),
                      leading: const Icon(Icons.flip_outlined),
                      initialValue: _flipV,
                      onToggle: (v) => setState(() => _flipV = v),
                    ),
                    SettingsTile(
                      title: const Text('Reset Transform'),
                      leading: const Icon(Icons.restart_alt),
                      onPressed: (_) {
                        setState(() {
                          _rotation = 0;
                          _flipH = false;
                          _flipV = false;
                          _transformationController.value = Matrix4.identity();
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            const Gap(16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              onPressed: buildExport,
              child: const Text('Export Avatar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            )
          ],
        ),
      ),
    );
  }
}

class DarkOverlayPainter extends CustomPainter {
  final Rect cropRect;
  DarkOverlayPainter({required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.65);

    // Top
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, cropRect.top), paint);
    // Bottom
    canvas.drawRect(Rect.fromLTWH(0, cropRect.bottom, size.width, size.height - cropRect.bottom), paint);
    // Left
    canvas.drawRect(Rect.fromLTWH(0, cropRect.top, cropRect.left, cropRect.height), paint);
    // Right
    canvas.drawRect(Rect.fromLTWH(cropRect.right, cropRect.top, size.width - cropRect.right, cropRect.height), paint);
  }

  @override
  bool shouldRepaint(covariant DarkOverlayPainter oldDelegate) => oldDelegate.cropRect != cropRect;
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    double stepW = size.width / 3;
    double stepH = size.height / 3;

    canvas.drawLine(Offset(stepW, 0), Offset(stepW, size.height), paint);
    canvas.drawLine(Offset(stepW * 2, 0), Offset(stepW * 2, size.height), paint);
    canvas.drawLine(Offset(0, stepH), Offset(size.width, stepH), paint);
    canvas.drawLine(Offset(0, stepH * 2), Offset(size.width, stepH * 2), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}