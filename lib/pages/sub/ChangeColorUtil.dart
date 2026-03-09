import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image/image.dart' as img;

import '../../utils/ImageManager.dart';

class ColorReplacementScreen extends StatefulWidget {
  final ImageMeta imageMeta;
  const ColorReplacementScreen({super.key, required this.imageMeta});

  @override
  State<ColorReplacementScreen> createState() => _ColorReplacementScreenState();
}

class _ColorReplacementScreenState extends State<ColorReplacementScreen> {
  Uint8List? _originalImageBytes;
  Uint8List? _processedImageBytes;
  img.Image? _originalImage;
  img.Image? _processedImage;

  Color _targetColor = Colors.red;
  Color _replacementColor = Colors.yellow;

  double _tolerance = 30.0;
  double _brightness = 0.0;
  double _contrast = 1.0;
  double _hueShift = 0.0;

  Rect? _selectionRect;
  Offset? _startDrag;
  Offset? _endDrag;

  bool _isEyedropperMode = false;
  bool _isSelectingArea = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Color Replacement Tool'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _loadImage,
            tooltip: 'Load Image',
          ),
          IconButton(
            icon: const Icon(Icons.colorize),
            color: _isEyedropperMode ? Colors.blue : null,
            onPressed: () => setState(() => _isEyedropperMode = !_isEyedropperMode),
            tooltip: 'Eyedropper',
          ),
          IconButton(
            icon: const Icon(Icons.crop),
            color: _isSelectingArea ? Colors.blue : null,
            onPressed: () => setState(() => _isSelectingArea = !_isSelectingArea),
            tooltip: 'Select Area',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reset,
            tooltip: 'Reset',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveImage,
            tooltip: 'Save',
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 4,
            child: _buildImageArea(),
          ),
          const VerticalDivider(width: 1),
          SizedBox(
            width: 320,
            child: _buildControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildImageArea() {
    if (_processedImageBytes == null) {
      return const Center(child: Text('Load an image to begin', style: TextStyle(fontSize: 18)));
    }

    return GestureDetector(
      onTapDown: (details) {
        if (_isEyedropperMode) _pickColorFromPosition(details.localPosition);
      },
      onPanStart: _isSelectingArea ? (d) => setState(() => _startDrag = d.localPosition) : null,
      onPanUpdate: _isSelectingArea ? (d) => setState(() => _endDrag = d.localPosition) : null,
      onPanEnd: (_) {
        if (_isSelectingArea && _startDrag != null && _endDrag != null) {
          _selectionRect = Rect.fromPoints(_startDrag!, _endDrag!);
          _processImage();
        }
        _startDrag = _endDrag = null;
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(_processedImageBytes!, fit: BoxFit.contain),
          if (_startDrag != null && _endDrag != null)
            Positioned(
              left: math.min(_startDrag!.dx, _endDrag!.dx),
              top: math.min(_startDrag!.dy, _endDrag!.dy),
              width: (_endDrag!.dx - _startDrag!.dx).abs(),
              height: (_endDrag!.dy - _startDrag!.dy).abs(),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blueAccent, width: 2),
                  color: Colors.blue.withOpacity(0.18),
                ),
              ),
            ),
          if (_selectionRect != null)
            Positioned.fromRect(
              rect: _selectionRect!,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.greenAccent, width: 2),
                  color: Colors.green.withOpacity(0.12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Target Color'),
        ColorPickerPreview(color: _targetColor, label: 'Target', onTap: () => _pickColor(_targetColor, (c) {
          _targetColor = c;
          _processImage();
        })),

        const SizedBox(height: 16),
        _buildSectionHeader('Replacement Color'),
        ColorPickerPreview(color: _replacementColor, label: 'Replace with', onTap: () => _pickColor(_replacementColor, (c) {
          _replacementColor = c;
          _processImage();
        })),

        const SizedBox(height: 24),
        _buildSectionHeader('Tolerance'),
        Slider(
          value: _tolerance,
          min: 0,
          max: 90,
          divisions: 18,
          label: _tolerance.round().toString(),
          onChanged: (v) {
            setState(() => _tolerance = v);
            _processImage();
          },
        ),

        const SizedBox(height: 24),
        _buildSectionHeader('Adjustments (applied to replaced area)'),
        _buildSlider('Brightness', _brightness, -100, 100, (v) {
          _brightness = v;
          _processImage();
        }),
        _buildSlider('Contrast', _contrast, 0.5, 2.0, (v) {
          _contrast = v;
          _processImage();
        }),
        _buildSlider('Hue Shift', _hueShift, -180, 180, (v) {
          _hueShift = v;
          _processImage();
        }),

        const SizedBox(height: 24),
        FilledButton.icon(
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Apply'),
          onPressed: _processImage,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
  );

  Widget ColorPickerPreview({
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade700),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 16),
            Text(label, style: const TextStyle(fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toStringAsFixed(label == 'Contrast' ? 2 : 0)}'),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: label == 'Contrast' ? 30 : null,
          onChanged: (v) {
            onChanged(v);
            setState(() {});
          },
        ),
      ],
    );
  }

  Future<void> _loadImage() async {
    if(widget.imageMeta.fullImage == null) await widget.imageMeta.makeFullImage();
    Uint8List result = widget.imageMeta.fullImage!;

    setState(() {
      _originalImageBytes = result;
      _processedImageBytes = Uint8List.fromList(_originalImageBytes!);
      _originalImage = img.decodeImage(_originalImageBytes!);
      _processedImage = _originalImage?.clone();
      _selectionRect = null;
    });
  }

  void _pickColorFromPosition(Offset localPos) {
    if (_originalImage == null) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final imageSize = Size(_originalImage!.width.toDouble(), _originalImage!.height.toDouble());
    final widgetSize = renderBox.size;

    final scaleX = imageSize.width / widgetSize.width;
    final scaleY = imageSize.height / widgetSize.height;

    final imgX = (localPos.dx * scaleX).clamp(0.0, imageSize.width - 1).toInt();
    final imgY = (localPos.dy * scaleY).clamp(0.0, imageSize.height - 1).toInt();

    final pixel = _originalImage!.getPixel(imgX, imgY);
    final color = Color.fromARGB(pixel.a.toInt(), pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt());

    setState(() => _targetColor = color);
    _processImage();
  }

  Future<void> _pickColor(Color initial, ValueChanged<Color> onSelect) async {
    Color temp = initial;
    final picked = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick Color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: initial,
            onColorChanged: (c) => temp = c,
            colorPickerWidth: 300,
            pickerAreaHeightPercent: 0.7,
            labelTypes: [ColorLabelType.hex],
            // displayThumbColor: _displayThumbColor,
            // paletteType: _paletteType,
            pickerAreaBorderRadius: const BorderRadius.only(
              topLeft: Radius.circular(2),
              topRight: Radius.circular(2),
            ),
            hexInputBar: true,
            // colorHistory: widget.colorHistory,
            // onHistoryChanged: widget.onHistoryChanged,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, temp),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (picked != null) {
      onSelect(picked);
    }
  }

  Future<void> _processImage() async {
    if (_originalImage == null || _originalImage!.isEmpty) return;

    var working = _originalImage!.clone();

    final targetHsv = rgbToHsv(_targetColor);
    final replaceHsv = rgbToHsv(_replacementColor);

    for (int y = 0; y < working.height; y++) {
      for (int x = 0; x < working.width; x++) {
        if (_selectionRect != null && !_selectionRect!.contains(Offset(x.toDouble(), y.toDouble()))) {
          continue;
        }

        final p = working.getPixel(x, y);
        final pixelColor = Color.fromARGB(p.a.toInt(), p.r.toInt(), p.g.toInt(), p.b.toInt());
        final pixelHsv = rgbToHsv(pixelColor);

        final hueDiff = (pixelHsv[0] - targetHsv[0]).abs();
        final minHueDist = math.min(hueDiff, 360 - hueDiff);

        if (minHueDist <= _tolerance) {
          var newHsv = [
            (replaceHsv[0] + _hueShift) % 360,
            pixelHsv[1].clamp(0.0, 1.0),
            pixelHsv[2].clamp(0.0, 1.0),
          ];

          final newRgb = hsvToRgb(newHsv);
          working.setPixelRgb(x, y, newRgb[0], newRgb[1], newRgb[2]);
        }
      }
    }

    final brightnessOffset = (_brightness * 100).round().clamp(-100, 100);
    final contrastPercent   = (_contrast * 100).round().clamp(50, 200);

    // working = img.adjustColor(
    //   working,
    //   brightness: brightnessOffset,
    //   contrast: contrastPercent,
    // );

    try {
      final pngBytes = img.encodePng(working);

      print('Processed: ${working.width}x${working.height}, PNG bytes: ${pngBytes.length}');

      if (pngBytes.isEmpty || pngBytes.length < 200) {
        print('encodePng failed → fallback to original');
        setState(() {
          _processedImageBytes = Uint8List.fromList(_originalImageBytes!);
        });
        return;
      }

      setState(() {
        _processedImageBytes = Uint8List.fromList(pngBytes);
      });
    } catch (e, stack) {
      print('Processing error: $e\n$stack');
      setState(() {
        _processedImageBytes = Uint8List.fromList(_originalImageBytes!);
      });
    }
  }

  void _reset() {
    setState(() {
      _processedImageBytes = _originalImageBytes != null ? Uint8List.fromList(_originalImageBytes!) : null;
      _processedImage = _originalImage?.clone();
      _selectionRect = null;
      _startDrag = _endDrag = null;
    });
  }

  Future<void> _saveImage() async {
    if (_processedImageBytes == null) return;

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save processed image',
      fileName: 'edited.png',
      type: FileType.image,
    );

    if (path != null) {
      File(path).writeAsBytesSync(_processedImageBytes!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image saved successfully')),
        );
      }
    }
  }

  List<double> rgbToHsv(Color c) {
    final r = c.red / 255.0;
    final g = c.green / 255.0;
    final b = c.blue / 255.0;

    final max = math.max(r, math.max(g, b));
    final min = math.min(r, math.min(g, b));
    final delta = max - min;

    double h = 0;
    if (delta != 0) {
      if (max == r) h = (g - b) / delta + (g < b ? 6 : 0);
      if (max == g) h = (b - r) / delta + 2;
      if (max == b) h = (r - g) / delta + 4;
      h *= 60;
    }

    final s = max == 0 ? 0.0 : delta / max;
    final v = max;

    return [h, s, v];
  }

  List<int> hsvToRgb(List<double> hsv) {
    final h = hsv[0] % 360;
    final s = hsv[1].clamp(0.0, 1.0);
    final v = hsv[2].clamp(0.0, 1.0);

    final c = v * s;
    final x = c * (1 - ((h / 60) % 2 - 1).abs());
    final m = v - c;

    double r = 0, g = 0, b = 0;
    if (h < 60) { r = c; g = x; }
    else if (h < 120) { r = x; g = c; }
    else if (h < 180) { g = c; b = x; }
    else if (h < 240) { g = x; b = c; }
    else if (h < 300) { r = x; b = c; }
    else { r = c; b = x; }

    return [
      ((r + m) * 255).round(),
      ((g + m) * 255).round(),
      ((b + m) * 255).round(),
    ];
  }
}