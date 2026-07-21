import 'dart:convert';
import 'dart:io';

import 'package:cimagen/utils/ImageManager.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

// Added for Depth Map
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:external_path/external_path.dart';

import '../../Utils.dart';

import 'package:image/image.dart' as img;
import 'dart:math' as math;

enum Gender { male, female, other }
Map<String, dynamic> sizes = {
  'horse': {
    'name': 'Stallion',
    'testicles': { //  left testis – height 7.3, length 10.4 and width 7.3 in Tori breed stallions, and 5.9, 8.1 and 5.9
      // right testis – height 7.4, length 10.6 and width 7.4 in Tori breed stallions, and 5.5, 7.4 and 5.3
      'long': [7.4, 12.toDouble()], // length
      'wide': [5.3, 7.3],  // width
      'high': [5.5, 7.3],  // height
      'gram': [150, 400],
      'scrotalWidths': [9, 13],
      'jets': [5, 7]
    }
  },
  'tiger': {
    'name': 'Tiger',
    'testicles': {
      'long': [4.3, 7], // legth
      'wide': [3.2, 5],  // width
      'high': [3.54, 3.59],  // height
      'gram': [50, 51],
    }
  },
  'fox': {
    'name': 'Red fox',
    'testicles': {
      'long': [1.95, 3.040], // legth
      'wide': [1.259, 1.901],  // width
      'high': [1.188, 1.822],  // height
      'gram': [30.35, 52.80],
    }
  }
};

Future<Uint8List?> _readImageFile(ImageMeta imageMeta) async {
  Uint8List? fi;
  if(imageMeta.mine?.split('/')[1] == 'vnd.adobe.photoshop'){
    fi = imageMeta.fullImage;
  } else {
    try {
      String? pathToImage = imageMeta.fullPath ?? imageMeta.tempFilePath ?? imageMeta.cacheFilePath;
      if(pathToImage == null) return null;
      final Uint8List bytes = await compute(readAsBytesSync, pathToImage);
      img.Image? image = await compute(img.decodeImage, bytes);
      if(image != null){
        return img.encodePng(image);
      }
    } on PathNotFoundException catch (e){
      throw 'We\'ll fix it later.'; // TODO
    }
  }
  return fi;
}

class BodySizeCalculation extends StatefulWidget{
  final ImageMeta imageMeta;
  const BodySizeCalculation({ super.key, required this.imageMeta});

  @override
  _BodySizeCalculationState createState() => _BodySizeCalculationState();
}

class _BodySizeCalculationState extends State<BodySizeCalculation> {
  // Settings
  String METADATA_KEY = 'X-BodySizePoints'; // custom key, avoid conflict with other tools
  String CURRENT_VERSION = '1.0.0';          // bump when format changes

  // Depth Map State
  Interpreter? _depthInterpreter;
  List<List<double>>? _depthMap;
  bool _isDepthLoaded = false;
  bool _isDepthLoading = false;
  Uint8List? _depthPreviewPng;
  double _depthScaleK = 500.0; // Tunable scale factor for relative depth

  Map<String, dynamic> get pointsInfo => {
    'version': CURRENT_VERSION,
    'characterHeightCm': _ch,
    'gender': gender.toString().split('.').last, // 'male', 'female', 'other'
    'mainPoints': mainPoints.map((p) => {
      'message': p.message,
      'color': p.color.value,           // store as int (ARGB)
      'offset': {'dx': p.offset.dx, 'dy': p.offset.dy},
    }).toList(),
    'penilePoints': penilePoints.map((p) => {
      'message': p.message,
      'color': p.color.value,
      'offset': {'dx': p.offset.dx, 'dy': p.offset.dy},
    }).toList(),
    // You can add more later: timestamp, devicePixelRatio, etc.
  };

  // Data
  Gender gender = Gender.male;
  List<PointInfo> mainPoints = [
    ['Top of head (without ears)', Colors.purple],
    ['Beginning of the right hand (bend)', Colors.red],
    ['Beginning of the left hand (bend)', Colors.orange],
    ['Right elbow', Colors.yellow],
    ['Left elbow', Colors.lightGreenAccent],
    ['Right shoulder', Colors.cyan],
    ['Left shoulder', Colors.blue],
    ['Beginning of the right leg (side)', Colors.purpleAccent],
    ['Beginning of the left leg (side)', Colors.brown],
    ['Right knee', Colors.deepOrange],
    ['Left knee', Colors.tealAccent],
    ['Beginning of the right foot (between the foot and the leg)', Colors.indigo],
    ['Beginning of the left foot (between the foot and the leg)', Colors.pink]
  ].mapIndexed((id, data) => PointInfo(message: data[0] as String, color: data[1] as Color, offset: Offset(30, (30 * (id + 1)).toDouble()))).toList();

  List<PointInfo> penilePoints = [
    ['Base of penis', Colors.redAccent],
    ['Mid-shaft', Colors.orangeAccent],
    ['Tip of penis', Colors.blueAccent],
  ].mapIndexed((id, data) => PointInfo(
    message: data[0] as String,
    color: data[1] as Color,
    offset: Offset(100 + id * 40, 100.0 + 30.0 * id),
  )).toList();

  // Testicular volume
  bool _tvAutoByWidth = true;
  double _tvLong = 12;
  double _tvWide = 7.3;
  double _tvHigh = 7.3;

  bool _penileExpanded = false;
  double _desiredLength = 0.0;
  final TextEditingController _desiredLengthController = TextEditingController();

  final TransformationController _transformationController = TransformationController();
  final GlobalKey _key = GlobalKey();

  bool doned = false;
  final TextEditingController _characterHeight = TextEditingController();
  double _ch = 175.4;

  late final lotsOfData = _readImageFile(widget.imageMeta!);

  double skeletonWidth = 420.0;
  double skeletonHeight = 400.0;
  late List<double> skeletonTops = [22, 118, 118, 118, 118, 118, 118, 240, 240, 295, 295, 350, 350];
  late List<double> skeletonLefts = [
    189, // 0
    40, // 1
    skeletonWidth - 40 - 30, // 2
    90, // 3
    skeletonWidth - 90 - 30, // 4
    140, // 5
    skeletonWidth - 140 - 30, // 6
    155, // 7
    skeletonWidth - 155 - 30, // 8
    155, // 9
    skeletonWidth - 155 - 30, // 10
    155, // 11
    skeletonWidth - 155 - 30, // 12
  ];

  @override
  void initState() {
    super.initState();
    _characterHeight.text = _ch.toString();
    _desiredLengthController.text = _desiredLength.toString();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadMeta(); // try to restore on first build
      _initDepthModel(); // Load TFLite model on start
    });
  }

  @override
  void dispose() {
    _depthInterpreter?.close();
    super.dispose();
  }

  // --- DEPTH MAP LOGIC ---
  Future<void> _initDepthModel() async {
    try {
      Directory? dD;
      if (Platform.isAndroid) {
        dD = Directory(await ExternalPath.getExternalStoragePublicDirectory(ExternalPath.DIRECTORY_DOCUMENTS));
      } else {
        dD = await getApplicationDocumentsDirectory();
      }

      File floatModel = File(p.join(dD.path, 'CImaGen', 'tflite', 'midas-tflite-float', 'midas.tflite'));
      File quantModel = File(p.join(dD.path, 'CImaGen', 'tflite', 'midas-tflite-w8a8', 'midas.tflite'));

      File modelFile = floatModel.existsSync() ? floatModel : (quantModel.existsSync() ? quantModel : floatModel);

      if (await modelFile.exists()) {
        _depthInterpreter = await Interpreter.fromFile(modelFile);
        _generateDepthMap();
      } else {
        debugPrint("Depth model not found at ${modelFile.path}");
      }
    } catch (e) {
      debugPrint("Failed to load depth model: $e");
    }
  }

  Future<void> _generateDepthMap() async {
    if (_depthInterpreter == null || _isDepthLoading) return;
    setState(() => _isDepthLoading = true);

    try {
      Uint8List? imageBytes = widget.imageMeta?.fullImage;
      if (imageBytes == null && widget.imageMeta?.fullPath != null) {
        imageBytes = await compute(readAsBytesSync, widget.imageMeta!.fullPath!);
      }
      if (imageBytes == null) return;

      img.Image? orig = await compute(img.decodeImage, imageBytes);
      if (orig == null) return;

      int inputSize = 256; // MiDaS small standard
      img.Image resized = img.copyResize(orig, width: inputSize, height: inputSize);

      // Prepare input tensor
      var input = List.generate(1, (i) => List.generate(inputSize, (y) => List.generate(inputSize, (x) {
        var px = resized.getPixel(x, y);
        return [px.r / 255.0, px.g / 255.0, px.b / 255.0];
      })));

      var output = List.generate(1, (i) => List.generate(inputSize, (y) => List.generate(inputSize, (x) => [0.0])));

      _depthInterpreter!.run(input, output);

      // Find min/max for normalization
      double minVal = double.infinity;
      double maxVal = -double.infinity;
      for (int y = 0; y < inputSize; y++) {
        for (int x = 0; x < inputSize; x++) {
          double val = output[0][y][x][0];
          if (val < minVal) minVal = val;
          if (val > maxVal) maxVal = val;
        }
      }

      // Generate 2D Depth Array and Preview Image
      img.Image depthImg = img.Image(width: orig.width, height: orig.height);
      _depthMap = List.generate(orig.height, (y) => List.generate(orig.width, (x) => 0.0));

      for (int y = 0; y < orig.height; y++) {
        for (int x = 0; x < orig.width; x++) {
          int sx = (x / orig.width * inputSize).toInt().clamp(0, inputSize - 1);
          int sy = (y / orig.height * inputSize).toInt().clamp(0, inputSize - 1);
          double val = output[0][sy][sx][0];

          // Normalize 0.0 to 1.0
          double normalized = (val - minVal) / (maxVal - minVal);
          _depthMap![y][x] = normalized;

          int gray = (normalized * 255).toInt().clamp(0, 255);
          depthImg.setPixelRgba(x, y, gray, gray, gray, 255);
        }
      }

      setState(() {
        _depthPreviewPng = img.encodePng(depthImg);
        _isDepthLoaded = true;
        _isDepthLoading = false;
      });
    } catch (e) {
      debugPrint("Error generating depth map: $e");
      setState(() => _isDepthLoading = false);
    }
  }

  double getRelativeDepth(Offset pixel) {
    if (_depthMap == null) return 0.0;
    int x = pixel.dx.toInt().clamp(0, _depthMap![0].length - 1);
    int y = pixel.dy.toInt().clamp(0, _depthMap!.length - 1);
    return _depthMap![y][x];
  }

  // True 3D distance in pixels
  double calculate3DPixels(Offset p1, Offset p2) {
    double d2D = (p1 - p2).distance;
    if (!_isDepthLoaded) return d2D;

    double z1 = getRelativeDepth(p1);
    double z2 = getRelativeDepth(p2);
    double deltaZ = (z1 - z2).abs() * _depthScaleK; // Multiply by user scale

    return math.sqrt((d2D * d2D) + (deltaZ * deltaZ));
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
            Expanded(
              child: _buildMain(),
            ),
            _buildMenu()
          ],
        )
            : _buildMain(),
      ),
    );
  }

  bool isVisible(Offset offset, double imageWidth, double imageHeight) {
    return offset.dx >= 0 && offset.dx <= imageWidth && offset.dy >= 0 && offset.dy <= imageHeight;
  }

  Widget _buildMain() {
    double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    double imageWidth = widget.imageMeta!.size!.width.toDouble();
    double imageHeight = widget.imageMeta!.size!.height.toDouble();

    double heightPixel = 0.0;
    double cmPerPixel = 0.0;
    try {
      bool isVis(int idx) => isVisible(mainPoints[idx].offset, imageWidth, imageHeight);
      double totalBodyPathPixels3D = 0.0;

      // 1. Head to Shoulders
      if (isVis(0) && isVis(5) && isVis(6)) {
        Offset midShoulder = averageOffset(mainPoints[5].offset, mainPoints[6].offset);
        totalBodyPathPixels3D += calculate3DPixels(mainPoints[0].offset, midShoulder);
      }

      // 2. Shoulders to Hips (Torso)
      if (isVis(5) && isVis(6) && isVis(7) && isVis(8)) {
        Offset midShoulder = averageOffset(mainPoints[5].offset, mainPoints[6].offset);
        Offset midHip = averageOffset(mainPoints[7].offset, mainPoints[8].offset);
        totalBodyPathPixels3D += calculate3DPixels(midShoulder, midHip);
      }

      // 3. Legs (Hip -> Knee -> Ankle)
      double rightLegPath = 0.0;
      if (isVis(7) && isVis(9)) rightLegPath += calculate3DPixels(mainPoints[7].offset, mainPoints[9].offset);
      if (isVis(9) && isVis(11)) rightLegPath += calculate3DPixels(mainPoints[9].offset, mainPoints[11].offset);

      double leftLegPath = 0.0;
      if (isVis(8) && isVis(10)) leftLegPath += calculate3DPixels(mainPoints[8].offset, mainPoints[10].offset);
      if (isVis(10) && isVis(12)) leftLegPath += calculate3DPixels(mainPoints[10].offset, mainPoints[12].offset);

      double legPath = 0.0;
      if (rightLegPath > 0 && leftLegPath > 0) {
        legPath = (rightLegPath + leftLegPath) / 2.0;
      } else {
        legPath = math.max(rightLegPath, leftLegPath);
      }

      totalBodyPathPixels3D += legPath;

      if (totalBodyPathPixels3D > 0) {
        cmPerPixel = _ch / totalBodyPathPixels3D;
      }
    } catch (e) {}

    List<AverageInfo> averages = [];

    void addSegment(int idx1, int idx2, String prefix, {required List<PointInfo> points}) {
      if (isVisible(points[idx1].offset, imageWidth, imageHeight) && isVisible(points[idx2].offset, imageWidth, imageHeight)) {
        Offset p1 = points[idx1].offset;
        Offset p2 = points[idx2].offset;
        // Use 3D distance in pixels, then convert to cm
        double distPixel = calculate3DPixels(p1, p2);
        double distCm = distPixel * cmPerPixel;
        String message = '$prefix ${distCm.toStringAsFixed(1)}cm';
        averages.add(AverageInfo(a: p1, b: p2, message: message));
      }
    }

    addSegment(5, 3, 'Right upper arm:', points: mainPoints);
    addSegment(3, 1, 'Right forearm:', points: mainPoints);
    addSegment(6, 4, 'Left upper arm:', points: mainPoints);
    addSegment(4, 2, 'Left forearm:', points: mainPoints);
    addSegment(7, 9, 'Right thigh:', points: mainPoints);
    addSegment(9, 11, 'Right lower leg:', points: mainPoints);
    addSegment(8, 10, 'Left thigh:', points: mainPoints);
    addSegment(10, 12, 'Left lower leg:', points: mainPoints);

    List<Offset> visibleShoulders = [];
    if (isVisible(mainPoints[5].offset, imageWidth, imageHeight)) visibleShoulders.add(mainPoints[5].offset);
    if (isVisible(mainPoints[6].offset, imageWidth, imageHeight)) visibleShoulders.add(mainPoints[6].offset);
    if (visibleShoulders.isNotEmpty) {
      double sumX = 0, sumY = 0;
      for (var o in visibleShoulders) {
        sumX += o.dx;
        sumY += o.dy;
      }
      Offset avgShoulder = Offset(sumX / visibleShoulders.length, sumY / visibleShoulders.length);

      if (isVisible(mainPoints[0].offset, imageWidth, imageHeight)) {
        double headPixel = calculate3DPixels(mainPoints[0].offset, avgShoulder);
        double headCm = headPixel * cmPerPixel;
        averages.add(AverageInfo(
          a: mainPoints[0].offset,
          b: avgShoulder,
          message: 'Head (approx): ${headCm.toStringAsFixed(1)}cm',
        ));
      }

      List<Offset> visibleHips = [];
      if (isVisible(mainPoints[7].offset, imageWidth, imageHeight)) visibleHips.add(mainPoints[7].offset);
      if (isVisible(mainPoints[8].offset, imageWidth, imageHeight)) visibleHips.add(mainPoints[8].offset);
      if (visibleHips.isNotEmpty) {
        sumX = 0;
        sumY = 0;
        for (var o in visibleHips) {
          sumX += o.dx;
          sumY += o.dy;
        }
        Offset avgHip = Offset(sumX / visibleHips.length, sumY / visibleHips.length);
        double torsoPixel = calculate3DPixels(avgShoulder, avgHip);
        double torsoCm = torsoPixel * cmPerPixel;
        averages.add(AverageInfo(
          a: avgShoulder,
          b: avgHip,
          message: 'Torso: ${torsoCm.toStringAsFixed(1)}cm',
        ));
      }
    }

    double penileLength = 0.0;
    List<Offset> visiblePenilePoints = penilePoints.where((p) => isVisible(p.offset, imageWidth, imageHeight)).map((p) => p.offset).toList();
    if (_penileExpanded && visiblePenilePoints.length >= 3) {
      for (int i = 0; i < visiblePenilePoints.length - 1; i++) {
        double distPixel = calculate3DPixels(visiblePenilePoints[i], visiblePenilePoints[i + 1]);
        penileLength += distPixel * cmPerPixel;
      }
      int mid = visiblePenilePoints.length ~/ 2;
      Offset labelPos = visiblePenilePoints[mid];
      averages.add(AverageInfo(
        a: labelPos,
        b: labelPos.translate(0, -50),
        message: '${penileLength.toStringAsFixed(1)} cm',
      ));
    }

    return LayoutBuilder(
      builder: (__, constraint) {
        if (!doned) {
          _transformationController.value = Matrix4.identity() * (imageWidth > imageHeight ? constraint.biggest.width / imageWidth : constraint.biggest.height / imageHeight);
          double scale = _transformationController.value.getMaxScaleOnAxis();
          _transformationController.value.setTranslationRaw((constraint.biggest.width / 2 - imageWidth * scale / 2), (constraint.biggest.height / 2 - imageHeight * scale / 2), 0);
          doned = true;
        }
        return InteractiveViewer(
          transformationController: _transformationController,
          boundaryMargin: const EdgeInsets.all(double.infinity),
          panEnabled: true,
          scaleFactor: 1000,
          minScale: 0.000001,
          maxScale: double.infinity,
          constrained: false,
          child: GestureDetector(
            key: _key,
            onTapDown: (TapDownDetails event) {},
            child: Stack(
              children: [
                if (['png', 'jpeg', 'jpg', 'gif', 'webp', 'bmp'].contains(widget.imageMeta!.fileTypeExtension))
                  Hero(
                    tag: widget.imageMeta!.fileName,
                    child: Image.file(
                      File(widget.imageMeta!.fullPath ?? widget.imageMeta!.tempFilePath ?? widget.imageMeta!.cacheFilePath ?? 'e.png'),
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.none,
                      errorBuilder: (context, exception, stack) => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 60),
                            Text('Error: $exception')
                          ],
                        ),
                      ),
                      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                        if (wasSynchronouslyLoaded) {
                          return child;
                        } else {
                          return AnimatedOpacity(
                            opacity: frame == null ? 0 : 1,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            child: child,
                          );
                        }
                      },
                    ),
                  )
                else
                  FutureBuilder(
                    future: lotsOfData,
                    builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
                      Widget children;
                      if (snapshot.hasData) {
                        children = Image.memory(
                          snapshot.data,
                          gaplessPlayback: true,
                          width: widget.imageMeta!.size!.width / devicePixelRatio,
                        );
                      } else if (snapshot.hasError) {
                        children = Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 60),
                              Text('Error: ${snapshot.error}')
                            ],
                          ),
                        );
                      } else {
                        children = const CircularProgressIndicator();
                      }
                      return children;
                    },
                  ),
                if (_penileExpanded && visiblePenilePoints.length >= 3)
                  CustomPaint(
                    painter: CurvePainter(
                      points: visiblePenilePoints,
                      desiredFraction: penileLength > 0 ? _desiredLength / penileLength : 0,
                    ),
                    size: Size(imageWidth, imageHeight),
                  ),
                ...mainPoints.mapIndexed(
                      (id, pointInfo) {
                    if (!isVisible(pointInfo.offset, imageWidth, imageHeight)) {
                      return const SizedBox.shrink();
                    }
                    Widget c = Tooltip(
                      message: pointInfo.message,
                      child: Container(
                        decoration: BoxDecoration(shape: BoxShape.circle, color: pointInfo.color),
                        width: 30,
                        height: 30,
                      ),
                    );
                    return Positioned(
                      left: pointInfo.offset.dx - 15,
                      top: pointInfo.offset.dy - 15,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanUpdate: (details) {
                          setState(() {
                            mainPoints[id].offset += details.delta / _transformationController.value.getMaxScaleOnAxis();
                            mainPoints[id].offset = Offset(
                              mainPoints[id].offset.dx.clamp(0.0, imageWidth),
                              mainPoints[id].offset.dy.clamp(0.0, imageHeight),
                            );
                          });
                        },
                        child: SizedBox(
                          width: 30,
                          height: 30,
                          child: c,
                        ),
                      ),
                    );
                  },
                ),
                if (_penileExpanded)
                  ...penilePoints.mapIndexed(
                        (id, pointInfo) {
                      if (!isVisible(pointInfo.offset, imageWidth, imageHeight)) {
                        return const SizedBox.shrink();
                      }
                      Widget c = Tooltip(
                        message: pointInfo.message,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: pointInfo.color,
                          ),
                          width: 15,
                          height: 15,
                        ),
                      );
                      return Positioned(
                        left: pointInfo.offset.dx - 7.5,
                        top: pointInfo.offset.dy - 7.5,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanUpdate: (details) {
                            setState(() {
                              penilePoints[id].offset += details.delta / _transformationController.value.getMaxScaleOnAxis();
                              penilePoints[id].offset = Offset(
                                penilePoints[id].offset.dx.clamp(0.0, imageWidth),
                                penilePoints[id].offset.dy.clamp(0.0, imageHeight),
                              );
                            });
                          },
                          child: SizedBox(
                            width: 15,
                            height: 15,
                            child: c,
                          ),
                        ),
                      );
                    },
                  ),
                ...averages.map(
                      (avg) => Positioned(
                    left: avg.offset.dx,
                    top: avg.offset.dy,
                    child: Transform.rotate(
                      angle: avg.angle,
                      child: Text(
                        avg.message,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
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

  Future<void> saveMeta() async {
    try {
      if (widget.imageMeta!.fullImage == null) {
        await widget.imageMeta!.makeFullImage();
      }
      Uint8List originalBytes = widget.imageMeta!.fullImage!;

      img.Image? image = img.decodeImage(originalBytes);
      if (image == null) {
        debugPrint('Failed to decode image for metadata save');
        return;
      }

      image.textData?.clear();

      image.textData ??= {};
      image.textData![METADATA_KEY] = jsonEncode(pointsInfo);

      Uint8List newBytes = img.encodePng(image);

      final file = File(widget.imageMeta!.fullPath!);
      await file.writeAsBytes(newBytes);

      debugPrint('Metadata saved successfully (version $CURRENT_VERSION)');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Point positions saved into image')),
      );
    } catch (e, st) {
      debugPrint('Error saving metadata: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save metadata: $e')),
      );
    }
  }

  Future<void> loadMeta() async {
    try {
      if (widget.imageMeta!.fullImage == null) {
        await widget.imageMeta!.makeFullImage();
      }
      Uint8List bytes = widget.imageMeta!.fullImage!;

      img.Image? image = img.decodeImage(bytes);
      if (image == null) {
        debugPrint('Failed to decode image for metadata load');
        return;
      }

      final String? jsonStr = image.textData?[METADATA_KEY];
      if (jsonStr == null || jsonStr.isEmpty) {
        debugPrint('No metadata found in image');
        return;
      }

      final Map<String, dynamic> data = jsonDecode(jsonStr);

      final String version = data['version'] ?? 'unknown';
      if (version != CURRENT_VERSION) {
        debugPrint('Warning: metadata version mismatch ($version vs $CURRENT_VERSION)');
      }

      setState(() {
        _ch = (data['characterHeightCm'] as num?)?.toDouble() ?? _ch;
        _characterHeight.text = _ch.toStringAsFixed(1);

        final genderStr = data['gender'] as String?;
        if (genderStr != null) {
          gender = Gender.values.firstWhere(
                (g) => g.toString().split('.').last == genderStr,
            orElse: () => Gender.male,
          );
        }

        final mainList = data['mainPoints'] as List<dynamic>? ?? [];
        if (mainList.length == mainPoints.length) {
          for (int i = 0; i < mainList.length; i++) {
            final p = mainList[i] as Map<String, dynamic>;
            mainPoints[i].offset = Offset(
              (p['offset']['dx'] as num).toDouble(),
              (p['offset']['dy'] as num).toDouble(),
            );
          }
        }

        final penileList = data['penilePoints'] as List<dynamic>? ?? [];
        if (penileList.length == penilePoints.length) {
          for (int i = 0; i < penileList.length; i++) {
            final p = penileList[i] as Map<String, dynamic>;
            penilePoints[i].offset = Offset(
              (p['offset']['dx'] as num).toDouble(),
              (p['offset']['dy'] as num).toDouble(),
            );
          }
        }
      });

      debugPrint('Metadata loaded (version $version)');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Point positions loaded from image')),
      );
    } catch (e, st) {
      debugPrint('Error loading metadata: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load metadata: $e')),
      );
    }
  }

  Widget _buildMenu() {
    double _tvVolume = volume(_tvWide, _tvLong, _tvHigh);
    double _tvDSP = 0.024 * (_tvVolume * 2) - 1.26;
    double _tvTVolume = 0.5233 * _tvLong * _tvWide * _tvHigh;
    double _tvDSP2 = 2.21 * (_tvWide * 2) - 6.4;

    double _tvVolumeAlt = _tvLong * _tvWide * _tvHigh * 0.71;

    double imageWidth = widget.imageMeta!.size!.width.toDouble();
    double imageHeight = widget.imageMeta!.size!.height.toDouble();

    double cmPerPixel = 0.0;
    double penileLength = 0.0;
    List<Offset> visiblePenilePoints = penilePoints.where((p) => isVisible(p.offset, imageWidth, imageHeight)).map((p) => p.offset).toList();
    if (_penileExpanded && visiblePenilePoints.length >= 3) {
      for (int i = 0; i < visiblePenilePoints.length - 1; i++) {
        double distPixel = calculate3DPixels(visiblePenilePoints[i], visiblePenilePoints[i + 1]);
        penileLength += distPixel * cmPerPixel;
      }
    }

    Widget buildPoint(int id, double top, double? left, double? right) {
      double calculatedLeft;
      if (left != null) {
        calculatedLeft = left;
      } else if (right != null) {
        calculatedLeft = skeletonWidth - right - 30;
      } else {
        calculatedLeft = 155;
      }

      return Positioned(
        top: top,
        left: calculatedLeft,
        child: GestureDetector(
          onTap: () => setState(() {
            mainPoints[id].offset = Offset(
              calculatedLeft / skeletonWidth * imageWidth,
              top / skeletonHeight * imageHeight,
            );
          }),
          child: Tooltip(
            message: mainPoints[id].message,
            child: Container(
              decoration: BoxDecoration(shape: BoxShape.circle, color: mainPoints[id].color),
              width: 30,
              height: 30,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(6),
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          children: [
            // --- ADDED DEPTH MAP UI ---
            ExpansionTile(
              initiallyExpanded: false,
              tilePadding: EdgeInsets.zero,
              title: Text('3D Depth Map (Perspective Fix)', style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.w600, fontSize: 18)),
              children: <Widget>[
                const SizedBox(height: 7),
                if (_isDepthLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_depthPreviewPng != null)
                  Container(
                    decoration: BoxDecoration(border: Border.all(color: Colors.white24)),
                    child: Image.memory(_depthPreviewPng!, height: 200, fit: BoxFit.contain),
                  )
                else
                  const Text('No depth map loaded. Make sure midas.tflite is in the correct folder.', style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 10),
                Text('Depth Scale (K): ${_depthScaleK.toStringAsFixed(0)}'),
                Slider(
                  value: _depthScaleK,
                  min: 0,
                  max: 2000,
                  divisions: 200,
                  label: _depthScaleK.toStringAsFixed(0),
                  onChanged: (v) => setState(() => _depthScaleK = v),
                ),
                ElevatedButton(
                  onPressed: _generateDepthMap,
                  child: const Text('Regenerate Depth Map'),
                ),
                const SizedBox(height: 7),
              ],
            ),
            ExpansionTile(
              initiallyExpanded: true,
              tilePadding: EdgeInsets.zero,
              title: Text('Main data', style: TextStyle(color: Colors.deepPurple.shade50, fontWeight: FontWeight.w600, fontSize: 18)),
              children: <Widget>[
                const SizedBox(height: 7),
                SegmentedButton<Gender>(
                  segments: const <ButtonSegment<Gender>>[
                    ButtonSegment<Gender>(value: Gender.male, label: Text('Male'), icon: Icon(Icons.male)),
                    ButtonSegment<Gender>(value: Gender.other, label: Text('Other'), icon: Icon(Icons.transgender)),
                    ButtonSegment<Gender>(value: Gender.female, label: Text('Female'), icon: Icon(Icons.female)),
                  ],
                  selected: <Gender>{gender},
                  onSelectionChanged: (Set<Gender> newSelection) {
                    setState(() {
                      gender = newSelection.first;
                    });
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  decoration: const InputDecoration(
                    hintText: "175.4",
                    border: OutlineInputBorder(),
                    labelText: 'Character height (cm)',
                  ),
                  keyboardType: TextInputType.number,
                  controller: _characterHeight,
                  onChanged: (v) => setState(() {
                    _ch = double.tryParse(v) ?? 175.4;
                  }),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r"[0-9.]")),
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      try {
                        String text = newValue.text;
                        if (text.startsWith('.')) text = '0$text';
                        if (text.isNotEmpty) double.parse(text);
                        return newValue;
                      } catch (e) {}
                      return oldValue;
                    }),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Stack(
                    children: [
                      const Center(child: Icon(Icons.accessibility, color: Colors.grey, size: 400)),
                      buildPoint(0, 22, 189, null),                    // head center
                      buildPoint(1, 118, 40, null),                    // left arm start
                      buildPoint(2, 118, null, 40),                    // right arm start
                      buildPoint(3, 118, 90, null),                    // left elbow
                      buildPoint(4, 118, null, 90),                    // right elbow
                      buildPoint(5, 118, 140, null),                   // left shoulder
                      buildPoint(6, 118, null, 140),                   // right shoulder
                      buildPoint(7, 240, 155, null),                   // left hip
                      buildPoint(8, 240, null, 155),                   // right hip
                      buildPoint(9, 295, 155, null),                   // left knee
                      buildPoint(10, 295, null, 155),                  // right knee
                      buildPoint(11, 350, 155, null),                  // left ankle/foot start
                      buildPoint(12, 350, null, 155),                  // right ankle/foot start
                    ],
                  ),
                )
              ],
            ),
            if (gender == Gender.male || gender == Gender.other)
              ExpansionTile(
                initiallyExpanded: true,
                tilePadding: EdgeInsets.zero,
                title: Text('Testicular volume/size', style: TextStyle(color: Colors.deepPurple.shade50, fontWeight: FontWeight.w600, fontSize: 18)),
                children: <Widget>[
                  const SizedBox(height: 7),
                  SwitchListTile(
                    title: const Text('Proportional calculation'),
                    value: _tvAutoByWidth,
                    onChanged: (bool? value) => setState(() {
                      _tvAutoByWidth = value ?? false;
                    }),
                    secondary: const Icon(Icons.compare_arrows),
                  ),
                  const SizedBox(height: 3),
                  Text('Long ${_tvLong.toStringAsFixed(1)}cm'),
                  Slider(
                    activeColor: _tvAutoByWidth ? Colors.white10 : null,
                    value: _tvLong,
                    max: 100,
                    divisions: 200,
                    label: _tvLong.toStringAsFixed(1),
                    onChanged: (double value) => setState(() {
                      _tvLong = value;
                      _tvAutoByWidth = false;
                    }),
                  ),
                  const SizedBox(height: 3),
                  Text('Wide ${_tvWide.toStringAsFixed(1)}cm'),
                  Slider(
                    value: _tvWide,
                    max: 100,
                    divisions: 200,
                    label: _tvWide.toStringAsFixed(1),
                    onChanged: (double value) {
                      setState(() {
                        _tvWide = value;
                        if (_tvAutoByWidth) {
                          _tvLong = math.min(value * 2 - (value * 25 / 100), 100);
                          _tvHigh = math.min(value * 20 / 100 + value, 100);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 3),
                  Text('High ${_tvHigh.toStringAsFixed(1)}cm'),
                  Slider(
                    activeColor: _tvAutoByWidth ? Colors.white10 : null,
                    value: _tvHigh,
                    max: 100,
                    divisions: 200,
                    label: _tvHigh.toStringAsFixed(1),
                    onChanged: (double value) => setState(() {
                      _tvHigh = value;
                      _tvAutoByWidth = false;
                    }),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        InfoBox(one: 'Long x Wide x High', two: '${_tvLong.toStringAsFixed(1)}x${_tvWide.toStringAsFixed(1)}x${_tvHigh.toStringAsFixed(1)}cm', withGap: false),
                        const Text('On volume'),
                        InfoBox(one: 'Vol per one (cm3)', two: '${_tvVolume.toStringAsFixed(3)}ml (both ${(_tvVolume * 2).toStringAsFixed(3)}ml)', withGap: false),
                        InfoBox(one: 'Alt Vol (LWH*0.71)', two: '${_tvVolumeAlt.toStringAsFixed(3)}ml', withGap: false),
                        InfoBox(one: Tooltip(message: 'Daily Sperm Production', child: Text('N (million spz/j)', style: TextStyle(fontSize: 12, color: Colors.white70))), two: _tvDSP.toStringAsFixed(3), withGap: false),
                        InfoBox(one: 'Testicular volume', two: '${_tvTVolume.toStringAsFixed(3)}ml', withGap: false),
                        InfoBox(one: 'Daily Sperm Output (×109)', two: ((0.024 * _tvTVolume) - 0.76).toStringAsFixed(3), withGap: false),
                        InfoBox(one: 'Jets count', two: ((volumeToJets(_tvVolume, sizes['horse']['testicles']) * 2) * 0.5).toStringAsFixed(1), withGap: false),
                        InfoBox(one: 'Weight (both)', two: '${(volumeToWeight(_tvVolume, sizes['horse']['testicles']) * 2).toStringAsFixed(2)}g (${(volumeToWeight(_tvVolume, sizes['horse']['testicles']) * 2 / 1000).toStringAsFixed(2)}kg)', withGap: false),
                        const Text('On average width of the 2 testes'),
                        InfoBox(one: 'Width of both', two: '${(_tvWide * 2).toStringAsFixed(2)}cm', withGap: false),
                        InfoBox(one: Tooltip(message: 'Daily Sperm Production', child: Text('N (million spz/j)', style: TextStyle(fontSize: 12, color: Colors.white70))), two: _tvDSP2.toStringAsFixed(3), withGap: false),
                        const Text('Additional info (humans)'),
                        InfoBox(one: 'Refractory period', two: '15 min (young) to 20 hours (older)', withGap: false),
                        InfoBox(one: 'Semen recovery after ejac', two: '24-48 hours for count/volume', withGap: false),
                        InfoBox(one: 'Full sperm cycle', two: '64-74 days', withGap: false),
                        InfoBox(one: 'High viscosity causes', two: 'Prostate issues, infection, dehydration', withGap: false),
                      ],
                    ),
                  ),
                  const SizedBox(height: 7),
                ],
              ),
            if (gender == Gender.male || gender == Gender.other)
              ExpansionTile(
                initiallyExpanded: false,
                tilePadding: EdgeInsets.zero,
                title: Text('Penile size', style: TextStyle(color: Colors.deepPurple.shade50, fontWeight: FontWeight.w600, fontSize: 18)),
                onExpansionChanged: (bool expanded) {
                  setState(() {
                    _penileExpanded = expanded;
                  });
                },
                children: <Widget>[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Estimated length:',
                          style: TextStyle(color: Colors.white70, fontSize: 15),
                        ),
                        Text(
                          penileLength > 0 ? '${penileLength.toStringAsFixed(1)} cm' : '—',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Desired length (cm)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      controller: _desiredLengthController,
                      onChanged: (v) => setState(() {
                        _desiredLength = double.tryParse(v) ?? 0.0;
                      }),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (penileLength > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Slider(
                        value: _desiredLength.clamp(0, penileLength),
                        min: 0,
                        max: penileLength,
                        label: _desiredLength.toStringAsFixed(1),
                        onChanged: (value) => setState(() {
                          _desiredLength = value;
                          _desiredLengthController.text = value.toStringAsFixed(1);
                        }),
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Place 3 points along the visible length from base to tip. Calculations use 3D depth map.',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            const SizedBox(height: 7),
            ElevatedButton(
              onPressed: () {
                _transformationController.value = Matrix4.identity() * 0.5;
              },
              child: const Text('Reset Zoom'),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  InfoBox(one: 'Width x Height', two: widget.imageMeta!.size.toString(), withGap: false),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: saveMeta,
                  child: const Text('Save points to image'),
                ),
                ElevatedButton(
                  onPressed: loadMeta,
                  child: const Text('Load points from image'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class InfoBox extends StatelessWidget {
  final dynamic one;
  final dynamic two;
  final bool withGap;

  const InfoBox({Key? key, required this.one, required this.two, this.withGap = true}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: withGap ? const EdgeInsets.only(top: 4) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        child: Row(
          children: [
            one is String ? SelectableText(one, style: const TextStyle(fontSize: 12, color: Colors.white70)) : one,
            const SizedBox(width: 6),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: two is String ? SelectableText(two, style: const TextStyle(fontSize: 13)) : two,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

double volume(num wide, num long, num high) {
  return 4 / 3 * math.pi * (wide / 2 * long / 2 * high / 2);
}

double volumeToJets(double V, Map<String, List<num>> data){
  num v1 = volume(data['wide']![0], data['long']![0], data['high']![0]);
  num v2 = volume(data['wide']![1], data['long']![1], data['high']![1]);
  return extrapolate(v1, data['jets']![0], v2, data['jets']![1], V);
}

double volumeToWeight(double V, dynamic data) {
  double v1 = volume(data['wide'][0], data['long'][0], data['high'][0]);
  double  v2 = volume(data['wide'][1], data['long'][1], data['high'][1]);
  return extrapolate(v1, data['gram'][0], v2, data['gram'][1], V);
}

double extrapolate(num x1, num y1, num x2, num y2, num value) {
  return y1 + (value - x1) / (x2 - x1) * (y2 - y1);
}

class PointInfo {
  String message;
  Color color;
  Offset offset;

  PointInfo({
    required this.message,
    required this.color,
    required this.offset,
  });
}

class AverageInfo {
  Offset a;
  Offset b;
  String message;

  AverageInfo({
    required this.a,
    required this.b,
    required this.message,
  });

  Offset get offset => averageOffset(a, b);
  double get angle => math.atan2(b.dy - a.dy, b.dx - a.dx);
}

Offset averageOffset(Offset one, Offset two) {
  return Offset(
    (one.dx + two.dx) / 2,
    (one.dy + two.dy) / 2,
  );
}

class CurvePainter extends CustomPainter {
  final List<Offset> points;
  final double desiredFraction;

  CurvePainter({required this.points, required this.desiredFraction});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    path.quadraticBezierTo(
      points[1].dx,
      points[1].dy,
      points[2].dx,
      points[2].dy,
    );
    canvas.drawPath(path, paint);

    if (desiredFraction > 0 && desiredFraction < 1) {
      Offset markerPos = _getPointOnQuadraticBezier(desiredFraction, points[0], points[1], points[2]);

      double t_tang = desiredFraction + 0.01;
      if (t_tang > 1) t_tang = 1;
      Offset nextPos = _getPointOnQuadraticBezier(t_tang, points[0], points[1], points[2]);
      Offset tangent = nextPos - markerPos;

      final perpVec = Offset(-tangent.dy, tangent.dx);
      final perpLength = perpVec.distance;
      final perp = perpLength > 0 ? perpVec * (20 / perpLength) : perpVec;

      final markerPaint = Paint()
        ..color = Colors.red
        ..strokeWidth = 2;
      canvas.drawLine(markerPos - perp, markerPos + perp, markerPaint);
    }
  }

  Offset _getPointOnQuadraticBezier(double t, Offset p0, Offset p1, Offset p2) {
    double u = 1 - t;
    return p0 * (u * u) + p1 * (2 * u * t) + p2 * (t * t);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}