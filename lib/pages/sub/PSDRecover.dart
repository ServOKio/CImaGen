import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class _LiveSelectionPainter extends CustomPainter {
  final Offset start;
  final Offset end;

  _LiveSelectionPainter({required this.start, required this.end});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromPoints(start, end);
    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.red.withOpacity(0.35)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _ConfirmedSelectionPainter extends CustomPainter {
  final Rect imageRect;
  final double imageWidth;
  final double imageHeight;
  final double offsetX;
  final double offsetY;
  final double scale;

  _ConfirmedSelectionPainter({
    required this.imageRect,
    required this.imageWidth,
    required this.imageHeight,
    required this.offsetX,
    required this.offsetY,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final screenLeft = offsetX + imageRect.left * scale;
    final screenTop = offsetY + imageRect.top * scale;
    final screenW = imageRect.width * scale;
    final screenH = imageRect.height * scale;

    final screenRect = Rect.fromLTWH(screenLeft, screenTop, screenW, screenH);

    canvas.drawRect(
      screenRect,
      Paint()
        ..color = Colors.green.withOpacity(0.35)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      screenRect,
      Paint()
        ..color = Colors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class PSDRecover extends StatefulWidget {
  const PSDRecover({super.key});

  @override
  _PSDRecoverState createState() => _PSDRecoverState();
}

class _PSDRecoverState extends State<PSDRecover> {
  img.Image? finalImage;
  String? finalImagePath;

  List<Map<String, dynamic>> layers = [];

  Rect? selectedRect;
  Offset? _selectionDragStart;
  Offset? _selectionDragCurrent;

  String? bestMatchName;
  double? bestMatchScore;
  img.Image? bestCroppedFinal;
  img.Image? bestCroppedLayer;
  img.Image? restoredMask;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickFinalImage() async {
    setState(() => isLoading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final bytes = await File(path).readAsBytes();
        final decoded = img.decodeImage(bytes);

        setState(() {
          finalImage = decoded;
          finalImagePath = path;
          selectedRect = null;
          _selectionDragStart = null;
          _selectionDragCurrent = null;
          bestMatchName = null;
          bestMatchScore = null;
          bestCroppedFinal = null;
          bestCroppedLayer = null;
          restoredMask = null;
        });
      }
    } catch (e) {
      _showSnackBar('Error loading final image: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _pickLayersFolder() async {
    setState(() => isLoading = true);
    try {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) return;

      final dir = Directory(selectedDirectory);
      final files = dir
          .listSync(recursive: false)
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('-mask-composite.png'))
          .toList();

      if (files.isEmpty) {
        _showSnackBar('No "-mask-composite.png" files found in the folder.');
        return;
      }

      final List<Map<String, dynamic>> loaded = [];
      for (final file in files) {
        try {
          final bytes = await File(file.path).readAsBytes();
          final decoded = img.decodeImage(bytes);
          loaded.add({
            'name': file.path.split(Platform.pathSeparator).last,
            'path': file.path,
            'image': decoded,
          });
        } catch (_) {}
      }

      setState(() {
        layers = loaded;
        bestMatchName = null;
        bestMatchScore = null;
        bestCroppedFinal = null;
        bestCroppedLayer = null;
        restoredMask = null;
      });

      _showSnackBar('${loaded.length} mask-composite layers loaded successfully.');
    } catch (e) {
      _showSnackBar('Error loading layers folder: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  img.Image _crop(img.Image source, int x, int y, int w, int h) {
    final safeX = x.clamp(0, source.width - 1).toInt();
    final safeY = y.clamp(0, source.height - 1).toInt();
    final safeW = w.clamp(1, source.width - safeX).toInt();
    final safeH = h.clamp(1, source.height - safeY).toInt();

    return img.copyCrop(
      source,
      x: safeX,
      y: safeY,
      width: safeW,
      height: safeH,
    );
  }

  double _computeMSE(img.Image a, img.Image b) {
    if (a.width != b.width || a.height != b.height) return double.infinity;

    double totalDiff = 0;
    final pixels = a.width * a.height;

    for (int y = 0; y < a.height; y++) {
      for (int x = 0; x < a.width; x++) {
        final p1 = a.getPixel(x, y);
        final p2 = b.getPixel(x, y);

        final r1 = p1.r;
        final g1 = p1.g;
        final b1 = p1.b;
        final a1 = p1.a;

        final r2 = p2.r;
        final g2 = p2.g;
        final b2 = p2.b;
        final a2 = p2.a;

        totalDiff += (r1 - r2) * (r1 - r2) +
            (g1 - g2) * (g1 - g2) +
            (b1 - b2) * (b1 - b2) +
            (a1 - a2) * (a1 - a2);
      }
    }

    return totalDiff / (pixels * 4.0);
  }

  img.Image? _generateRestoredMask(img.Image finalImg, img.Image layerImg) {
    if (finalImg.width != layerImg.width || finalImg.height != layerImg.height) {
      return null;
    }

    final mask = img.Image(
      width: finalImg.width,
      height: finalImg.height,
      format: img.Format.uint8,
      numChannels: 4,
    );

    for (int y = 0; y < finalImg.height; y++) {
      for (int x = 0; x < finalImg.width; x++) {
        final pFinal = finalImg.getPixel(x, y);
        final pLayer = layerImg.getPixel(x, y);

        final dr = (pFinal.r - pLayer.r).abs();
        final dg = (pFinal.g - pLayer.g).abs();
        final db = (pFinal.b - pLayer.b).abs();
        final avgDiff = (dr + dg + db) / 3.0;

        // Soft mask: low difference → white (visible), high difference → black (masked)
        final maskVal = (255 - avgDiff).clamp(0, 255).toInt();

        // Modern v4+ way: get pixel reference and set its channels directly
        final pMask = mask.getPixel(x, y);
        pMask.r = maskVal;
        pMask.g = maskVal;
        pMask.b = maskVal;
        pMask.a = 255;
      }
    }
    return mask;
  }

  Future<void> _findBestMatch() async {
    if (finalImage == null || layers.isEmpty) {
      _showSnackBar('Please load both the final image and layers folder.');
      return;
    }
    if (selectedRect == null) {
      _showSnackBar('Please drag to select a region on the image first.');
      return;
    }

    setState(() => isLoading = true);

    try {
      final x = selectedRect!.left.toInt();
      final y = selectedRect!.top.toInt();
      final w = selectedRect!.width.toInt();
      final h = selectedRect!.height.toInt();

      final croppedFinal = _crop(finalImage!, x, y, w, h);

      double bestScore = double.infinity;
      String? bestName;
      img.Image? bestLayerImgFull;   // full layer for mask generation

      for (final layer in layers) {
        final layerImg = layer['image'] as img.Image?;
        if (layerImg == null) continue;

        final croppedLayer = _crop(layerImg, x, y, w, h);
        final score = _computeMSE(croppedFinal, croppedLayer);

        if (score < bestScore) {
          bestScore = score;
          bestName = layer['name'] as String;
          bestLayerImgFull = layerImg;
        }
      }

      img.Image? mask;
      if (bestLayerImgFull != null &&
          finalImage!.width == bestLayerImgFull.width &&
          finalImage!.height == bestLayerImgFull.height) {
        mask = _generateRestoredMask(finalImage!, bestLayerImgFull);
      }

      setState(() {
        bestMatchName = bestName;
        bestMatchScore = bestScore;
        bestCroppedFinal = croppedFinal;
        bestCroppedLayer = bestLayerImgFull != null ? _crop(bestLayerImgFull, x, y, w, h) : null;
        restoredMask = mask;
      });

      if (bestName == null) {
        _showSnackBar('No matching layer found.');
      } else if (mask == null) {
        _showSnackBar('Layer found, but size mismatch — cannot restore mask.');
      }
    } catch (e) {
      _showSnackBar('Error during matching: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget _buildImagePreview(img.Image? image, {String label = ''}) {
    if (image == null) return const SizedBox.shrink();
    final pngBytes = img.encodePng(image);
    return Column(
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
        Expanded(
          child: Image.memory(
            Uint8List.fromList(pngBytes),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Text('Failed to display'),
          ),
        ),
      ],
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: const Color(0xaa000000),
        elevation: 0,
        title: const Text('PSD Recovery Tool'),
        actions: [
          if (finalImage != null && layers.isNotEmpty)
            TextButton.icon(
              onPressed: isLoading ? null : _findBestMatch,
              icon: const Icon(Icons.search),
              label: const Text('Find Best Match'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
        ],
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // File selection
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickFinalImage,
                      icon: const Icon(Icons.image),
                      label: const Text('1. Select Final Image'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickLayersFolder,
                      icon: const Icon(Icons.folder),
                      label: const Text('2. Select Layers Folder'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              if (finalImage != null) ...[
                Text(
                  'Final Image: ${finalImagePath?.split(Platform.pathSeparator).last ?? ''}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 300,
                  width: double.infinity,
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 8,
                    child: _buildImagePreview(finalImage, label: 'Final (merged) - zoom & pan here'),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              if (layers.isNotEmpty)
                Text(
                  '${layers.length} layers loaded (${layers.where((l) => l['image'] != null).length} valid)',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),

              const SizedBox(height: 24),

              // Drag selection tool
              if (finalImage != null && layers.isNotEmpty) ...[
                const Text(
                  '3. Drag to select region on the image',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Draw a rectangle directly on the image below. Green = confirmed selection.',
                  style: TextStyle(color: Colors.amber, fontSize: 13),
                ),
                const SizedBox(height: 12),

                Container(
                  height: 420,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double displayW = constraints.maxWidth;
                      final double displayH = constraints.maxHeight;

                      final double imgW = finalImage!.width.toDouble();
                      final double imgH = finalImage!.height.toDouble();

                      final double scaleX = displayW / imgW;
                      final double scaleY = displayH / imgH;
                      final double scale = scaleX < scaleY ? scaleX : scaleY;

                      final double offsetX = (displayW - imgW * scale) / 2;
                      final double offsetY = (displayH - imgH * scale) / 2;

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (details) {
                          final local = details.localPosition;
                          if (local.dx >= offsetX &&
                              local.dx <= offsetX + imgW * scale &&
                              local.dy >= offsetY &&
                              local.dy <= offsetY + imgH * scale) {
                            setState(() {
                              _selectionDragStart = local;
                              _selectionDragCurrent = local;
                            });
                          }
                        },
                        onPanUpdate: (details) {
                          if (_selectionDragStart != null) {
                            setState(() {
                              _selectionDragCurrent = details.localPosition;
                            });
                          }
                        },
                        onPanEnd: (_) {
                          if (_selectionDragStart == null || _selectionDragCurrent == null) return;

                          final dragRect = Rect.fromPoints(_selectionDragStart!, _selectionDragCurrent!);
                          final imageArea = Rect.fromLTWH(offsetX, offsetY, imgW * scale, imgH * scale);
                          final visibleRect = dragRect.intersect(imageArea);

                          if (visibleRect.isEmpty) {
                            setState(() {
                              _selectionDragStart = null;
                              _selectionDragCurrent = null;
                            });
                            return;
                          }

                          final pixelLeft = ((visibleRect.left - offsetX) / scale).clamp(0.0, imgW);
                          final pixelTop = ((visibleRect.top - offsetY) / scale).clamp(0.0, imgH);
                          final pixelRight = ((visibleRect.right - offsetX) / scale).clamp(0.0, imgW);
                          final pixelBottom = ((visibleRect.bottom - offsetY) / scale).clamp(0.0, imgH);

                          setState(() {
                            selectedRect = Rect.fromLTRB(
                              pixelLeft,
                              pixelTop,
                              pixelRight,
                              pixelBottom,
                            );
                            _selectionDragStart = null;
                            _selectionDragCurrent = null;
                          });
                        },
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: Image.memory(
                                  Uint8List.fromList(img.encodePng(finalImage!)),
                                ),
                              ),
                            ),
                            if (_selectionDragStart != null && _selectionDragCurrent != null)
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _LiveSelectionPainter(
                                    start: _selectionDragStart!,
                                    end: _selectionDragCurrent!,
                                  ),
                                ),
                              ),
                            if (selectedRect != null)
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _ConfirmedSelectionPainter(
                                    imageRect: selectedRect!,
                                    imageWidth: imgW,
                                    imageHeight: imgH,
                                    offsetX: offsetX,
                                    offsetY: offsetY,
                                    scale: scale,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                if (selectedRect != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Selected region: '
                        'X: ${selectedRect!.left.toInt()}  '
                        'Y: ${selectedRect!.top.toInt()}  '
                        'W: ${selectedRect!.width.toInt()}  '
                        'H: ${selectedRect!.height.toInt()}',
                    style: const TextStyle(color: Colors.green, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => selectedRect = null),
                    icon: const Icon(Icons.clear, color: Colors.white70),
                    label: const Text('Clear selection', style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ],

              const SizedBox(height: 24),

              if (bestMatchName != null) ...[
                const Divider(color: Colors.white24),
                const Text(
                  'Best Match Found',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Layer: $bestMatchName',
                  style: const TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  'MSE Score: ${bestMatchScore?.toStringAsFixed(4) ?? ''} (lower = better)',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),

                // Side-by-side crops
                SizedBox(
                  height: 220,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildImagePreview(bestCroppedFinal, label: 'Selected Section (Final)'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildImagePreview(bestCroppedLayer, label: 'Best Matching Layer Crop'),
                      ),
                    ],
                  ),
                ),

                if (restoredMask != null) ...[
                  const SizedBox(height: 32),
                  const Text(
                    'Restored Layer Mask',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Black-and-white mask computed from global pixel differences\n'
                        'White = layer visible in final image\n'
                        'Black = masked out (difference detected)',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 300,
                    width: double.infinity,
                    child: _buildImagePreview(
                      restoredMask,
                      label: 'Estimated Mask (full resolution)',
                    ),
                  ),
                ],
              ],

              if (finalImage == null && layers.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: Text(
                      'Select a final image and a folder containing *-mask-composite.png files to begin recovery.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}