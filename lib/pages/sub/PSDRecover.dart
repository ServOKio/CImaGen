import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_compare_slider/image_compare_slider.dart';

import '../../components/Animations.dart';

class PSDRecover extends StatefulWidget {
  const PSDRecover({super.key});

  @override
  _PSDRecoverState createState() => _PSDRecoverState();
}

class _PSDRecoverState extends State<PSDRecover> {
  img.Image? finalImage;
  String? finalImagePath;

  img.Image? mainImage;
  String? mainImagePath;

  List<Map<String, dynamic>> sourceLayers = [];

  List<Map<String, dynamic>> recoveredLayers = [];
  img.Image? reconstructedImage;

  bool isLoading = false;
  String _progressText = 'Ready';
  double _progressValue = 0.0;

  bool _filterSmallerImages = true;

  img.Image _normalize(img.Image? src) {
    if (src == null) return img.Image(width: 1, height: 1);
    if (src.format != img.Format.uint8 || src.numChannels != 4) {
      return src.convert(numChannels: 4, format: img.Format.uint8);
    }
    return src;
  }

  Future<void> _pickMainImage() async {
    setState(() => isLoading = true);
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final decoded = img.decodeImage(await File(path).readAsBytes());
        setState(() {
          mainImage = _normalize(decoded);
          mainImagePath = path;
        });
      }
    } catch (e) {
      _showSnackBar('Error loading base image: $e');
    } finally {
      if(mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _pickFinalImage() async {
    setState(() => isLoading = true);
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final decoded = img.decodeImage(await File(path).readAsBytes());
        setState(() {
          finalImage = _normalize(decoded);
          finalImagePath = path;
          reconstructedImage = null;
          recoveredLayers.clear();
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
      final allFiles = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.png'))
          .toList();

      if (allFiles.isEmpty) {
        _showSnackBar('No PNG files found in the folder.');
        return;
      }

      final Map<String, List<File>> baseFiles = {};
      final Map<String, List<File>> maskFiles = {};

      for (final file in allFiles) {
        final name = file.uri.pathSegments.last;
        final parts = name.split('-');
        if (parts.length < 2) continue;

        final seed = parts[1].replaceAll(RegExp(r'[^0-9]'), '');
        if (seed.isEmpty) continue;

        final lowerName = name.toLowerCase();
        if (lowerName.contains('composite')) {
          continue;
        } else if (lowerName.contains('mask')) {
          maskFiles.putIfAbsent(seed, () => []).add(file);
        } else {
          baseFiles.putIfAbsent(seed, () => []).add(file);
        }
      }

      final List<Map<String, dynamic>> loaded = [];
      for (var seed in baseFiles.keys) {
        if (maskFiles.containsKey(seed)) {
          for (int i = 0; i < baseFiles[seed]!.length; i++) {
            final baseFile = baseFiles[seed]![i];
            final maskFile = i < maskFiles[seed]!.length ? maskFiles[seed]![i] : maskFiles[seed]!.first;

            final layerImg = _normalize(img.decodeImage(await baseFile.readAsBytes()));
            final maskImg = _normalize(img.decodeImage(await maskFile.readAsBytes()));

            loaded.add({
              'name': baseFile.uri.pathSegments.last,
              'image': layerImg,
              'mask': maskImg,
            });
          }
        }
      }

      loaded.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      if (loaded.isEmpty) {
        _showSnackBar('0 layer/mask pairs loaded. Check folder contents.');
        return;
      }

      setState(() {
        sourceLayers = loaded;
        reconstructedImage = null;
        recoveredLayers.clear();
      });

      _showSnackBar('${loaded.length} layer/mask pairs loaded successfully.');
    } catch (e) {
      _showSnackBar('Error loading layers folder: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _autoRecover() async {
    if (mainImage == null || finalImage == null || sourceLayers.isEmpty) {
      _showSnackBar('Please load main image, final image, and source folder.');
      return;
    }

    setState(() {
      isLoading = true;
      _progressText = 'Starting recovery...';
      _progressValue = 0.0;
    });

    final ReceivePort receivePort = ReceivePort();

    try {
      await Isolate.spawn(
        _runRecoverIsolate,
        {
          'sendPort': receivePort.sendPort,
          'finalImage': finalImage!,
          'mainImage': mainImage!,
          'filterSmaller': _filterSmallerImages,
          'layers': sourceLayers.map((l) => {
            'name': l['name'],
            'image': l['image'],
            'mask': l['mask'],
            }).toList(),
        },
      );

      await for (var msg in receivePort) {
        if (msg['type'] == 'progress') {
          setState(() {
            _progressText = msg['text'] ?? 'Processing...';
            _progressValue = msg['value'] ?? _progressValue;
          });
        } else if (msg['type'] == 'done') {
          final Uint8List reconBytes = msg['reconBytes'];
          final List<dynamic> selectedData = msg['selected'];

          List<Map<String, dynamic>> selected = [];
          for (var item in selectedData) {
            int origIdx = item['origIdx'];
            Uint8List maskBytes = item['maskBytes'];
            Uint8List imgThumbBytes = item['imgThumbBytes'];
            Uint8List maskThumbBytes = item['maskThumbBytes'];

            selected.add({
              'name': sourceLayers[origIdx]['name'],
              'image': sourceLayers[origIdx]['image'],
              'thumbImage': imgThumbBytes,
              'thumbMask': maskThumbBytes,
              'mask': img.Image.fromBytes(
                  width: finalImage!.width,
                  height: finalImage!.height,
                  bytes: maskBytes.buffer,
                  numChannels: 4,
                  format: img.Format.uint8
              ),
            });
          }

          setState(() {
            recoveredLayers = selected;
            reconstructedImage = img.Image.fromBytes(
                width: finalImage!.width,
                height: finalImage!.height,
                bytes: reconBytes.buffer,
                numChannels: 4,
                format: img.Format.uint8
            );
            isLoading = false;
          });

          receivePort.close();
          _showSnackBar('🟢 Recovered ${selected.length} layers successfully!');
          break;
        } else if (msg['type'] == 'error') {
          receivePort.close();
          setState(() => isLoading = false);
          _showSnackBar('Error: ${msg['message']}');
          break;
        }
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showSnackBar('Error during recovery: $e');
    }
  }

  static void _runRecoverIsolate(Map<String, dynamic> data) async {
    final SendPort sendPort = data['sendPort'];
    try {
      final img.Image finalImg = data['finalImage'] as img.Image;
      final img.Image mainImg = data['mainImage'] as img.Image;
      final bool filterSmaller = data['filterSmaller'] as bool;
      final List<dynamic> rawLayers = data['layers'] as List<dynamic>;

      final int width = finalImg.width;
      final int height = finalImg.height;
      final int totalPixels = width * height;

      img.Image baseCanvas = img.Image(width: width, height: height, numChannels: 4, format: img.Format.uint8);
      img.compositeImage(baseCanvas, mainImg);

      Uint8List currentReconBytes = baseCanvas.getBytes();
      final finalBytes = finalImg.getBytes();

      // Pre-process layers (crop/filter) so we don't do it repeatedly in the loop
      List<Map<String, dynamic>> processableLayers = [];
      for(int i=0; i<rawLayers.length; i++) {
        img.Image layerImg = rawLayers[i]['image'] as img.Image;
        img.Image maskImg = rawLayers[i]['mask'] as img.Image;

        if (filterSmaller && (layerImg.width < width || layerImg.height < height)) continue;
        if (layerImg.width > width || layerImg.height > height) {
          int x = (layerImg.width - width) ~/ 2;
          int y = (layerImg.height - height) ~/ 2;
          layerImg = img.copyCrop(layerImg, x: x, y: y, width: width, height: height);
          maskImg = img.copyCrop(maskImg, x: x, y: y, width: width, height: height);
        }
        if (layerImg.width != width || layerImg.height != height) continue;

        processableLayers.add({
          'origIdx': i,
          'image': layerImg,
          'mask': maskImg,
        });
      }

      List<Map<String, dynamic>> selectedLayers = [];
      int iteration = 0;

      // GREEDY LOOP: Find best layer, apply it, repeat.
      while (processableLayers.isNotEmpty) {
        iteration++;
        double maxPossibleIterations = rawLayers.length.toDouble();
        sendPort.send({
          'type': 'progress',
          'text': 'Iteration $iteration: Evaluating ${processableLayers.length} layers...',
          'value': (iteration / maxPossibleIterations).clamp(0.0, 1.0)
        });

        double bestErrorRemoved = 0.0;
        int bestLayerIdx = -1;

        // 1. Fast Evaluation: Find the layer that removes the most error
        for (int l = 0; l < processableLayers.length; l++) {
          final layer = processableLayers[l];
          final layerBytes = (layer['image'] as img.Image).getBytes();
          final maskBytes = (layer['mask'] as img.Image).getBytes();
          double errorRemoved = 0.0;

          for (int p = 0; p < totalPixels; p++) {
            int idx = p * 4;
            if (maskBytes[idx] > 10) {
              double bR = currentReconBytes[idx].toDouble();
              double bG = currentReconBytes[idx + 1].toDouble();
              double bB = currentReconBytes[idx + 2].toDouble();

              double fR = finalBytes[idx].toDouble();
              double fG = finalBytes[idx + 1].toDouble();
              double fB = finalBytes[idx + 2].toDouble();

              double lR = layerBytes[idx].toDouble();
              double lG = layerBytes[idx + 1].toDouble();
              double lB = layerBytes[idx + 2].toDouble();

              double dr_lb = lR - bR;
              double dg_lb = lG - bG;
              double db_lb = lB - bB;
              double dist_lb_sq = dr_lb * dr_lb + dg_lb * dg_lb + db_lb * db_lb;

              if (dist_lb_sq > 1.0) {
                double dr_fb = fR - bR;
                double dg_fb = fG - bG;
                double db_fb = fB - bB;
                double dot = dr_fb * dr_lb + dg_fb * dg_lb + db_fb * db_lb;
                double alpha = (dot / dist_lb_sq).clamp(0.0, 1.0);

                double blendR = lR * alpha + bR * (1.0 - alpha);
                double blendG = lG * alpha + bG * (1.0 - alpha);
                double blendB = lB * alpha + bB * (1.0 - alpha);

                double dr_bf = blendR - fR;
                double dg_bf = blendG - fG;
                double db_bf = blendB - fB;
                double dist_bf = math.sqrt(dr_bf * dr_bf + dg_bf * dg_bf + db_bf * db_bf);

                if (dist_bf <= 1.0) {
                  double dist_fb = math.sqrt(dr_fb * dr_fb + dg_fb * dg_fb + db_fb * db_fb);
                  double errRemoved = dist_fb - dist_bf;
                  if (errRemoved > 0.1) {
                    errorRemoved += errRemoved;
                  }
                }
              }
            }
          }

          if (errorRemoved > bestErrorRemoved) {
            bestErrorRemoved = errorRemoved;
            bestLayerIdx = l;
          }
        }

        // If no layer can improve the image, stop searching
        if (bestLayerIdx == -1 || bestErrorRemoved < 1.0) {
          break;
        }

        sendPort.send({
          'type': 'progress',
          'text': 'Iteration $iteration: Applying best layer (Error reduced: ${bestErrorRemoved.toStringAsFixed(2)})...',
          'value': (iteration / maxPossibleIterations).clamp(0.0, 1.0)
        });

        // 2. Generate Full Mask for the Winning Layer
        final layer = processableLayers[bestLayerIdx];
        final img.Image layerImg = layer['image'] as img.Image;
        final img.Image maskImg = layer['mask'] as img.Image;
        final layerBytes = layerImg.getBytes();
        final maskBytes = maskImg.getBytes();

        Uint8List optMask = Uint8List(width * height * 4);
        Uint8List matchFlags = Uint8List(totalPixels);

        for (int p = 0; p < totalPixels; p++) {
          int idx = p * 4;
          if (maskBytes[idx] > 10) {
            double bR = currentReconBytes[idx].toDouble();
            double bG = currentReconBytes[idx + 1].toDouble();
            double bB = currentReconBytes[idx + 2].toDouble();

            double fR = finalBytes[idx].toDouble();
            double fG = finalBytes[idx + 1].toDouble();
            double fB = finalBytes[idx + 2].toDouble();

            double lR = layerBytes[idx].toDouble();
            double lG = layerBytes[idx + 1].toDouble();
            double lB = layerBytes[idx + 2].toDouble();

            double dr_lb = lR - bR;
            double dg_lb = lG - bG;
            double db_lb = lB - bB;
            double dist_lb_sq = dr_lb * dr_lb + dg_lb * dg_lb + db_lb * db_lb;

            if (dist_lb_sq > 1.0) {
              double dr_fb = fR - bR;
              double dg_fb = fG - bG;
              double db_fb = fB - bB;
              double dot = dr_fb * dr_lb + dg_fb * dg_lb + db_fb * db_lb;
              double alpha = (dot / dist_lb_sq).clamp(0.0, 1.0);

              double blendR = lR * alpha + bR * (1.0 - alpha);
              double blendG = lG * alpha + bG * (1.0 - alpha);
              double blendB = lB * alpha + bB * (1.0 - alpha);

              double dr_bf = blendR - fR;
              double dg_bf = blendG - fG;
              double db_bf = blendB - fB;
              double dist_bf = math.sqrt(dr_bf * dr_bf + dg_bf * dg_bf + db_bf * db_bf);

              if (dist_bf <= 1.0) {
                double dist_fb = math.sqrt(dr_fb * dr_fb + dg_fb * dg_fb + db_fb * db_fb);
                double errRemoved = dist_fb - dist_bf;
                if (errRemoved > 0.1) {
                  optMask[idx] = (alpha * 255).round();
                  optMask[idx + 1] = (alpha * 255).round();
                  optMask[idx + 2] = (alpha * 255).round();
                  optMask[idx + 3] = 255;
                  matchFlags[p] = 1;
                }
              }
            }
          }
        }

        // 3. Morphological Cleaning (Brush Stroke Simulation)
        for (int iter = 0; iter < 4; iter++) {
          Uint8List newFlags = Uint8List.fromList(matchFlags);
          bool changed = false;
          for (int y = 1; y < height - 1; y++) {
            for (int x = 1; x < width - 1; x++) {
              int p = y * width + x;
              if (maskBytes[p * 4] > 10) {
                int count = 0;
                if (matchFlags[p - 1] == 1) count++;
                if (matchFlags[p + 1] == 1) count++;
                if (matchFlags[p - width] == 1) count++;
                if (matchFlags[p + width] == 1) count++;
                if (matchFlags[p - width - 1] == 1) count++;
                if (matchFlags[p - width + 1] == 1) count++;
                if (matchFlags[p + width - 1] == 1) count++;
                if (matchFlags[p + width + 1] == 1) count++;

                if (matchFlags[p] == 1) {
                  if (count < 2) {
                    newFlags[p] = 0;
                    optMask[p * 4] = 0; optMask[p * 4 + 1] = 0; optMask[p * 4 + 2] = 0; optMask[p * 4 + 3] = 0;
                    changed = true;
                  }
                } else {
                  if (count >= 5) {
                    newFlags[p] = 1;
                    int idx = p * 4;
                    double bR = currentReconBytes[idx].toDouble();
                    double bG = currentReconBytes[idx + 1].toDouble();
                    double bB = currentReconBytes[idx + 2].toDouble();
                    double fR = finalBytes[idx].toDouble();
                    double fG = finalBytes[idx + 1].toDouble();
                    double fB = finalBytes[idx + 2].toDouble();
                    double lR = layerBytes[idx].toDouble();
                    double lG = layerBytes[idx + 1].toDouble();
                    double lB = layerBytes[idx + 2].toDouble();

                    double dr_lb = lR - bR;
                    double dg_lb = lG - bG;
                    double db_lb = lB - bB;
                    double dist_lb_sq = dr_lb * dr_lb + dg_lb * dg_lb + db_lb * db_lb;
                    if (dist_lb_sq > 1.0) {
                      double dr_fb = fR - bR;
                      double dg_fb = fG - bG;
                      double db_fb = fB - bB;
                      double dot = dr_fb * dr_lb + dg_fb * dg_lb + db_fb * db_lb;
                      double alpha = (dot / dist_lb_sq).clamp(0.0, 1.0);
                      optMask[idx] = (alpha * 255).round();
                      optMask[idx + 1] = (alpha * 255).round();
                      optMask[idx + 2] = (alpha * 255).round();
                      optMask[idx + 3] = 255;
                    } else {
                      optMask[idx] = 255; optMask[idx + 1] = 255; optMask[idx + 2] = 255; optMask[idx + 3] = 255;
                    }
                    changed = true;
                  }
                }
              }
            }
          }
          matchFlags = newFlags;
          if (!changed) break;
        }

        // 4. Soft Blur & Apply to Reconstruction
        img.Image optMaskImg = img.Image.fromBytes(width: width, height: height, bytes: optMask.buffer, numChannels: 4, format: img.Format.uint8);
        optMaskImg = img.gaussianBlur(optMaskImg, radius: 3);
        optMask = Uint8List.fromList(optMaskImg.getBytes());

        for (int p = 0; p < totalPixels; p++) {
          int idx = p * 4;
          double maskVal = optMask[idx] / 255.0;
          if (maskVal > 0.01) {
            double srcA = (layerBytes[idx + 3] / 255.0) * maskVal;
            if (srcA > 0.01) {
              double bR = currentReconBytes[idx].toDouble();
              double bG = currentReconBytes[idx + 1].toDouble();
              double bB = currentReconBytes[idx + 2].toDouble();

              double lR = layerBytes[idx].toDouble();
              double lG = layerBytes[idx + 1].toDouble();
              double lB = layerBytes[idx + 2].toDouble();

              currentReconBytes[idx] = (lR * srcA + bR * (1.0 - srcA)).round().clamp(0, 255);
              currentReconBytes[idx + 1] = (lG * srcA + bG * (1.0 - srcA)).round().clamp(0, 255);
              currentReconBytes[idx + 2] = (lB * srcA + bB * (1.0 - srcA)).round().clamp(0, 255);
              currentReconBytes[idx + 3] = 255;
            }
          }
        }

        // 5. Save Results & Remove from Pool
        final img.Image imgThumb = img.copyResize(layerImg, width: 100, height: 100, maintainAspect: false);
        final img.Image maskThumb = img.copyResize(optMaskImg, width: 100, height: 100, maintainAspect: false);

        selectedLayers.add({
          'origIdx': layer['origIdx'],
          'maskBytes': optMask,
          'imgThumbBytes': Uint8List.fromList(img.encodePng(imgThumb)),
          'maskThumbBytes': Uint8List.fromList(img.encodePng(maskThumb)),
        });

        processableLayers.removeAt(bestLayerIdx);
      }

      sendPort.send({
        'type': 'done',
        'reconBytes': currentReconBytes,
        'selected': selectedLayers,
      });
    } catch (e) {
      sendPort.send({'type': 'error', 'message': e.toString()});
    }
  }

  Future<void> _exportToPsd() async {
    if (mainImage == null || recoveredLayers.isEmpty) {
      _showSnackBar('No layers to export.');
      return;
    }

    setState(() {
      isLoading = true;
      _progressText = 'Preparing PSD bytes...';
      _progressValue = 0.0;
    });

    try {
      String? path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save PSD File',
        fileName: 'recovered.psd',
        type: FileType.custom,
        allowedExtensions: ['psd'],
      );

      if (path == null) {
        setState(() => isLoading = false);
        return;
      }

      final int width = mainImage!.width;
      final int height = mainImage!.height;

      final payload = {
        'width': width,
        'height': height,
        'mainBytes': Uint8List.fromList(mainImage!.getBytes()),
        'reconBytes': Uint8List.fromList(reconstructedImage!.getBytes()),
        'layers': recoveredLayers.map((l) => {
          'name': l['name'],
          'imageBytes': Uint8List.fromList((l['image'] as img.Image).getBytes()),
          'maskBytes': Uint8List.fromList((l['mask'] as img.Image).getBytes()),
        }).toList(),
      };

      final Uint8List psdBytes = await compute(_buildPsdBytes, payload);

      setState(() {
        _progressText = 'Saving file to disk...';
        _progressValue = 1.0;
      });

      final file = File(path);
      await file.writeAsBytes(psdBytes);

      _showSnackBar('PSD Exported successfully!');
    } catch (e) {
      _showSnackBar('Error exporting PSD: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  static Uint8List _buildPsdBytes(Map<String, dynamic> data) {
    final int width = data['width'];
    final int height = data['height'];
    final Uint8List mainBytes = data['mainBytes'];
    final Uint8List reconBytes = data['reconBytes'];
    final List<Map<String, dynamic>> layers = List<Map<String, dynamic>>.from(data['layers']);

    final builder = BytesBuilder();

    void addU16(int val) => builder.add((ByteData(2)..setUint16(0, val, Endian.big)).buffer.asUint8List());
    void addU32(int val) => builder.add((ByteData(4)..setUint32(0, val, Endian.big)).buffer.asUint8List());
    void addBytes(List<int> bytes) => builder.add(bytes);
    void addString(String s) => builder.add(utf8.encode(s));

    Uint8List extractChannel(Uint8List rgba, int offset) {
      Uint8List res = Uint8List(rgba.length ~/ 4);
      for (int i = 0; i < res.length; i++) {
        res[i] = rgba[i * 4 + offset];
      }
      return res;
    }

    addString('8BPS');
    addU16(1); addBytes(List.filled(6, 0)); addU16(3); addU32(height); addU32(width); addU16(8); addU16(3);
    addU32(0); addU32(0);

    final layerDataBuilder = BytesBuilder();
    int numLayers = layers.length + 1;
    layerDataBuilder.add((ByteData(2)..setUint16(0, numLayers, Endian.big)).buffer.asUint8List());

    for (int i = 0; i < numLayers; i++) {
      layerDataBuilder.add((ByteData(16)..setUint32(0, 0, Endian.big)..setUint32(4, 0, Endian.big)..setUint32(8, height, Endian.big)..setUint32(12, width, Endian.big)).buffer.asUint8List());
      layerDataBuilder.add((ByteData(2)..setUint16(0, 4, Endian.big)).buffer.asUint8List());

      int channelLen = width * height + 2;
      layerDataBuilder.add((ByteData(6)..setUint16(0, 0, Endian.big)..setUint32(2, channelLen, Endian.big)).buffer.asUint8List());
      layerDataBuilder.add((ByteData(6)..setUint16(0, 1, Endian.big)..setUint32(2, channelLen, Endian.big)).buffer.asUint8List());
      layerDataBuilder.add((ByteData(6)..setUint16(0, 2, Endian.big)..setUint32(2, channelLen, Endian.big)).buffer.asUint8List());
      if (i == 0) {
        layerDataBuilder.add((ByteData(6)..setUint16(0, 0xFFFF, Endian.big)..setUint32(2, channelLen, Endian.big)).buffer.asUint8List());
      } else {
        layerDataBuilder.add((ByteData(6)..setUint16(0, 0xFFFE, Endian.big)..setUint32(2, channelLen, Endian.big)).buffer.asUint8List());
      }

      layerDataBuilder.add(utf8.encode('8BIM')); layerDataBuilder.add(utf8.encode('norm'));
      layerDataBuilder.addByte(255); layerDataBuilder.addByte(0); layerDataBuilder.addByte(0); layerDataBuilder.addByte(0);

      String name = (i == 0) ? "Base Image" : layers[i - 1]['name'];
      int nameLen = name.length;
      int nameTotal = nameLen + 1;
      int namePad = (4 - (nameTotal % 4)) % 4;
      int maskDataLen = (i > 0) ? 20 : 0;
      int luniCount = nameLen;
      int luniDataLen = 4 + luniCount * 2;
      int luniPad = (4 - (luniDataLen % 4)) % 4;
      int luniTotal = 4 + 4 + 4 + luniDataLen + luniPad;
      int extraDataLen = 4 + maskDataLen + 4 + 0 + (nameTotal + namePad) + luniTotal;

      layerDataBuilder.add((ByteData(4)..setUint32(0, extraDataLen, Endian.big)).buffer.asUint8List());
      layerDataBuilder.add((ByteData(4)..setUint32(0, maskDataLen, Endian.big)).buffer.asUint8List());
      if (i > 0) {
        layerDataBuilder.add((ByteData(16)..setUint32(0, 0, Endian.big)..setUint32(4, 0, Endian.big)..setUint32(8, height, Endian.big)..setUint32(12, width, Endian.big)).buffer.asUint8List());
        layerDataBuilder.addByte(0); layerDataBuilder.addByte(0); layerDataBuilder.add((ByteData(2)..setUint16(0, 0, Endian.big)).buffer.asUint8List());
      }
      layerDataBuilder.add((ByteData(4)..setUint32(0, 0, Endian.big)).buffer.asUint8List());
      layerDataBuilder.addByte(nameLen); layerDataBuilder.add(utf8.encode(name));
      for (int j = 0; j < namePad; j++) layerDataBuilder.addByte(0);

      layerDataBuilder.add(utf8.encode('8BIM')); layerDataBuilder.add(utf8.encode('luni'));
      layerDataBuilder.add((ByteData(4)..setUint32(0, luniDataLen, Endian.big)).buffer.asUint8List());
      layerDataBuilder.add((ByteData(4)..setUint32(0, luniCount, Endian.big)).buffer.asUint8List());
      for (var c in name.codeUnits) { layerDataBuilder.add((ByteData(2)..setUint16(0, c, Endian.big)).buffer.asUint8List()); }
      for (int j = 0; j < luniPad; j++) layerDataBuilder.addByte(0);
    }

    for (int i = 0; i < numLayers; i++) {
      Uint8List rgbaBytes = (i == 0) ? mainBytes : (layers[i - 1]['imageBytes'] as Uint8List);
      layerDataBuilder.add((ByteData(2)..setUint16(0, 0, Endian.big)).buffer.asUint8List());
      layerDataBuilder.add(extractChannel(rgbaBytes, 0));
      layerDataBuilder.add((ByteData(2)..setUint16(0, 0, Endian.big)).buffer.asUint8List());
      layerDataBuilder.add(extractChannel(rgbaBytes, 1));
      layerDataBuilder.add((ByteData(2)..setUint16(0, 0, Endian.big)).buffer.asUint8List());
      layerDataBuilder.add(extractChannel(rgbaBytes, 2));
      if (i == 0) {
        layerDataBuilder.add((ByteData(2)..setUint16(0, 0, Endian.big)).buffer.asUint8List());
        layerDataBuilder.add(extractChannel(rgbaBytes, 3));
      } else {
        Uint8List maskBytes = layers[i - 1]['maskBytes'] as Uint8List;
        layerDataBuilder.add((ByteData(2)..setUint16(0, 0, Endian.big)).buffer.asUint8List());
        layerDataBuilder.add(extractChannel(maskBytes, 0));
      }
    }

    final layerDataBytes = layerDataBuilder.toBytes();
    int l2Length = layerDataBytes.length;
    int padL2 = l2Length % 2;
    int l2PaddedLength = l2Length + padL2;

    addU32(l2PaddedLength + 8); addU32(l2PaddedLength); addBytes(layerDataBytes);
    for(int i=0; i<padL2; i++) addBytes([0]); addU32(0);

    addU16(0);
    addBytes(extractChannel(reconBytes, 0)); addBytes(extractChannel(reconBytes, 1)); addBytes(extractChannel(reconBytes, 2));

    return builder.toBytes();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: SelectableText(message), duration: const Duration(seconds: 3)),
    );
  }

  Widget _buildThumbFromBytes(Uint8List? bytes) {
    if (bytes == null) return const SizedBox.shrink();
    return Image.memory(bytes, fit: BoxFit.cover);
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
        title: const ShowUp(
          delay: 100,
          child: Text('PSD Recovery', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600, fontFamily: 'Montserrat')),
        ),
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
        ) : _buildMain(),
      ),
    );
  }

  Widget _buildMain() {
    if (isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WavyDotsLoader(
                duration: const Duration(milliseconds: 3800), // slower = calmer
              ),
              const SizedBox(height: 24),
              Text(_progressText, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _progressValue, backgroundColor: Colors.white24, color: Colors.blue, minHeight: 8),
            ],
          ),
        ),
      );
    }
    if (finalImage == null) return const Center(child: Text('Select final image', style: TextStyle(color: Colors.white)));
    if (reconstructedImage == null) return const Center(child: Text('Press "Try restore" to reconstruct', style: TextStyle(color: Colors.white)));

    return InteractiveViewer(
      boundaryMargin: const EdgeInsets.all(double.infinity),
      panEnabled: true,
      minScale: 0.1,
      maxScale: 10,
      child: Center(
        child: ImageCompareSlider(
          itemOne: Image.memory(Uint8List.fromList(img.encodePng(finalImage!)), gaplessPlayback: true),
          itemTwo: Image.memory(Uint8List.fromList(img.encodePng(reconstructedImage!)), gaplessPlayback: true),
          dividerWidth: 1.5,
          handleSize: const Size(0, 0),
          handleRadius: const BorderRadius.all(Radius.circular(0)),
        ),
      ),
    );
  }

  Widget _buildMenu() {
    return Container(
      padding: const EdgeInsets.all(6),
      width: 420,
      color: Colors.black.withOpacity(0.8),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: isLoading ? null : _pickMainImage,
              child: Text(mainImagePath != null ? 'Base: ${mainImagePath!.split(Platform.pathSeparator).last}' : '1. Select Base Image'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: isLoading ? null : _pickFinalImage,
              child: Text(finalImagePath != null ? 'Final: ${finalImagePath!.split(Platform.pathSeparator).last}' : '2. Select Final Image'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: isLoading ? null : _pickLayersFolder,
              child: Text(sourceLayers.isEmpty ? '3. Select Source Folder' : '${sourceLayers.length} Layers Loaded'),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Skip smaller images', style: TextStyle(color: Colors.white, fontSize: 14)),
              value: _filterSmallerImages,
              onChanged: isLoading ? null : (val) => setState(() => _filterSmallerImages = val),
              activeColor: Colors.blue,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
              dense: true,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: isLoading ? null : _autoRecover,
              child: const Text('Restore Layers', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            if (recoveredLayers.isNotEmpty) ...[
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                onPressed: isLoading ? null : _exportToPsd,
                child: const Text('Export to .psd', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 24),
              const Divider(color: Colors.white24),
              const Text('Recovered Layers (Best Match Order)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Column(
                children: recoveredLayers.asMap().entries.map((entry) {
                  int idx = entry.key + 1;
                  var el = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        CircleAvatar(backgroundColor: Colors.blue, child: Text('$idx', style: const TextStyle(color: Colors.white, fontSize: 12))),
                        const SizedBox(width: 8),
                        Expanded(flex: 2, child: Text(el['name'], style: const TextStyle(color: Colors.white70, fontSize: 11), overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        Container(color: Colors.black, width: 60, height: 60, child: _buildThumbFromBytes(el['thumbImage'])),
                        const SizedBox(width: 4),
                        Container(color: Colors.black, width: 60, height: 60, child: _buildThumbFromBytes(el['thumbMask'])),
                      ],
                    ),
                  );
                }).toList(),
              )
            ]
          ],
        ),
      ),
    );
  }
}