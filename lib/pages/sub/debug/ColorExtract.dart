import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_background_remover/image_background_remover.dart';

import '../../../utils/ColorUtils.dart';
import '../../../utils/ImageManager.dart';

class ColorExtract extends StatefulWidget {
  final ImageMeta imageMeta;
  const ColorExtract({super.key, required this.imageMeta});

  @override
  State<ColorExtract> createState() => _ColorExtractState();
}

class _ColorExtractState extends State<ColorExtract> {
  Uint8List? _originalBytes;
  ui.Image? _resultImage;       
  Uint8List? _resultPngBytes;   
  List<Color>? palette;
  bool _isProcessing = false;
  String _status = 'Ready';

  @override
  void initState() {
    super.initState();
    _loadAndRemove();
  }

  @override
  void dispose() {
    _resultImage?.dispose();
    super.dispose();
  }

  Future<void> _loadAndRemove() async {
    setState(() => _isProcessing = true);

    try {
      if (widget.imageMeta.fullImage == null) {
        await widget.imageMeta.decodeToFull();
      }

      final bytes = widget.imageMeta.fullImage!;
      setState(() => _originalBytes = bytes);

      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final originalUi = frame.image;

      if (originalUi.width > 512) {
        final resized = await _resizeImage(originalUi, 512);
        final resizedBytes = await _imageToPng(resized);
        _resultImage = await BackgroundRemover.instance.removeBg(
          resizedBytes,
          threshold: 0.3,
          smoothMask: true,
          enhanceEdges: true,
        );
      } else {
        _resultImage = await BackgroundRemover.instance.removeBg(
          bytes,
          threshold: 0.45,
          smoothMask: true,
          enhanceEdges: true,
        );
      }

     
      _resultPngBytes = await _imageToPng(_resultImage!);
      palette = await extractPrimaryColors(_resultPngBytes!, desiredCount: 20, quantStep: 2, diversityThreshold: 80);

      setState(() => _status = 'Background removed (Photoshop style)');
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<ui.Image> _resizeImage(ui.Image image, int maxWidth) async {
    final ratio = maxWidth / image.width;
    final height = (image.height * ratio).round();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, maxWidth.toDouble(), height.toDouble()),
      Paint(),
    );
    final picture = recorder.endRecording();
    return picture.toImage(maxWidth, height);
  }

  Future<Uint8List> _imageToPng(ui.Image image) async {
    final pngData = await image.toByteData(format: ui.ImageByteFormat.png);
    return pngData!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Automatic Background Removal')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Original', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_originalBytes != null)
              Image.memory(_originalBytes!, fit: BoxFit.contain),

            const SizedBox(height: 32),

            const Text('Result (transparent background)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 8),

            if (_isProcessing)
              const Center(child: CircularProgressIndicator())
            else if (_resultPngBytes != null) ...[
             
              Image.memory(_resultPngBytes!, fit: BoxFit.contain),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: palette!.map((c) => Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadAndRemove,
                icon: const Icon(Icons.refresh),
                label: const Text('Re-process'),
              ),

             
             
            ] else
              Text(_status, style: const TextStyle(color: Colors.orange)),
          ],
        ),
      ),
    );
  }
}