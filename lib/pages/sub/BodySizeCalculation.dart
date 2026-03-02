import 'dart:io';

import 'package:cimagen/utils/ImageManager.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:photo_view/photo_view.dart';
import 'package:flutter/foundation.dart';

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
      // crotalWidths: [9, 13],
      // jets: [5, 7]
    }
    // 5.7 × 5.5 × 4.5 cm
    // 5.7 × 5.5 × 4.5 cm and 4.0 × 3.3 × 2.2 cm,

    // Total sperm counts 283.5 × 106 and 1.26 × 106,

    //50-51 g) and size (60-70 mm length and 40-50 mm width

  },
  'fox': {
    'name': 'Red fox',
    'testicles': {
      'long': [1.95, 3.040], // legth
      'wide': [1.259, 1.901],  // width
      'high': [1.188, 1.822],  // height
      'gram': [30.35, 52.80],
      // We have assessed the allometric relationship between mass of testes and body mass using data from 133 mammalian species.
      // The logarithmically transformed data were fitted by a regression (r2=0.86) that is described by the power function: Y=0.035 X0.72,
      // where Y is mass of both testes in grams and X is body mass in grams

      // crotalWidths: [9, 13],
      // jets: [5, 7]
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
  final ImageMeta? imageMeta;
  const BodySizeCalculation({ super.key, this.imageMeta});

  @override
  _BodySizeCalculationState createState() => _BodySizeCalculationState();
}

class _BodySizeCalculationState extends State<BodySizeCalculation> {
  // Settings

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
    ['Mid-shaft 1', Colors.orangeAccent],
    ['Mid-shaft 2', Colors.yellowAccent],
    ['Tip of penis', Colors.blueAccent],
  ].mapIndexed((id, data) => PointInfo(
    message: data[0] as String,
    color: data[1] as Color,
    offset: Offset(100 + id * 40, 100.0 + 30.0 * id), // slightly better initial spread
  )).toList();

  // Testicular volume
  bool _tvAutoByWidth = true;
  double _tvLong = 12;
  double _tvWide = 7.3;
  double _tvHigh = 7.3;

  bool _penileExpanded = false;

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
    _characterHeight.text = _ch.toString();
    super.initState();
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

    double cmPerPixel = 0.0;
    double heightPixel = 0.0;
    try {
      bool headVisible = isVisible(mainPoints[0].offset, imageWidth, imageHeight);
      double headY = mainPoints[0].offset.dy;
      if (!headVisible) {
        cmPerPixel = 0.0;
      } else {
        double fraction = 0.0;
        double bottomY = headY;
        List<double> ankleYs = [];
        if (isVisible(mainPoints[11].offset, imageWidth, imageHeight)) ankleYs.add(mainPoints[11].offset.dy);
        if (isVisible(mainPoints[12].offset, imageWidth, imageHeight)) ankleYs.add(mainPoints[12].offset.dy);
        if (ankleYs.isNotEmpty) {
          bottomY = ankleYs.reduce((a, b) => a + b) / ankleYs.length;
          fraction = 1.0;
        } else {
          List<double> kneeYs = [];
          if (isVisible(mainPoints[9].offset, imageWidth, imageHeight)) kneeYs.add(mainPoints[9].offset.dy);
          if (isVisible(mainPoints[10].offset, imageWidth, imageHeight)) kneeYs.add(mainPoints[10].offset.dy);
          if (kneeYs.isNotEmpty) {
            bottomY = kneeYs.reduce((a, b) => a + b) / kneeYs.length;
            fraction = 0.76;
          } else {
            List<double> hipYs = [];
            if (isVisible(mainPoints[7].offset, imageWidth, imageHeight)) hipYs.add(mainPoints[7].offset.dy);
            if (isVisible(mainPoints[8].offset, imageWidth, imageHeight)) hipYs.add(mainPoints[8].offset.dy);
            if (hipYs.isNotEmpty) {
              bottomY = hipYs.reduce((a, b) => a + b) / hipYs.length;
              fraction = 0.52;
            }
          }
        }
        heightPixel = bottomY - headY;
        if (heightPixel > 0 && fraction > 0) {
          double measuredCm = _ch * fraction;
          cmPerPixel = measuredCm / heightPixel;
        }
      }
    } catch (e) {

    }

    List<AverageInfo> averages = [];

    void addSegment(int idx1, int idx2, String prefix, {required List<PointInfo> points}) {
      if (isVisible(points[idx1].offset, imageWidth, imageHeight) && isVisible(points[idx2].offset, imageWidth, imageHeight)) {
        Offset p1 = points[idx1].offset;
        Offset p2 = points[idx2].offset;
        double distPixel = (p1 - p2).distance;
        double distCm = distPixel * cmPerPixel;
        String message = '$prefix ${distCm.toStringAsFixed(1)}cm';
        averages.add(AverageInfo(a: p1, b: p2, message: message));
      }
    }

    // Add limb segments
    addSegment(5, 3, 'Right upper arm:', points: mainPoints);
    addSegment(3, 1, 'Right forearm:', points: mainPoints);
    addSegment(6, 4, 'Left upper arm:', points: mainPoints);
    addSegment(4, 2, 'Left forearm:', points: mainPoints);
    addSegment(7, 9, 'Right thigh:', points: mainPoints);
    addSegment(9, 11, 'Right lower leg:', points: mainPoints);
    addSegment(8, 10, 'Left thigh:', points: mainPoints);
    addSegment(10, 12, 'Left lower leg:', points: mainPoints);

    // Torso and head
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

      // Head
      if (isVisible(mainPoints[0].offset, imageWidth, imageHeight)) {
        double headPixel = avgShoulder.dy - mainPoints[0].offset.dy;
        double headCm = headPixel * cmPerPixel;
        averages.add(AverageInfo(
          a: mainPoints[0].offset,
          b: avgShoulder,
          message: 'Head (approx): ${headCm.toStringAsFixed(1)}cm',
        ));
      }

      // Torso
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
        double torsoPixel = avgHip.dy - avgShoulder.dy;
        double torsoCm = torsoPixel * cmPerPixel;
        averages.add(AverageInfo(
          a: avgShoulder,
          b: avgHip,
          message: 'Torso: ${torsoCm.toStringAsFixed(1)}cm',
        ));
      }
    }

    double penileLength = 0.0;
    if (_penileExpanded) {
      for (int i = 0; i < penilePoints.length - 1; i++) {
        if (isVisible(penilePoints[i].offset, imageWidth, imageHeight) &&
            isVisible(penilePoints[i + 1].offset, imageWidth, imageHeight)) {
          double distPixel = (penilePoints[i].offset - penilePoints[i + 1].offset).distance;
          penileLength += distPixel * cmPerPixel;
        }
      }
      // Optional: one floating total label near middle point (index 1 or 2)
      if (penilePoints.length >= 2 && penileLength > 0) {
        int mid = penilePoints.length ~/ 2;
        Offset labelPos = penilePoints[mid].offset;
        averages.add(AverageInfo(
          a: labelPos,
          b: labelPos.translate(0, -50), // higher above to avoid overlap
          message: '${penileLength.toStringAsFixed(1)} cm',
        ));
      }
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
            onTapDown: (TapDownDetails event) {
              //print(event.localPosition);
            },
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
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 60,
                            ),
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
                        children = const CircularProgressIndicator();
                      }
                      return children;
                    },
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
                      left: pointInfo.offset.dx,
                      top: pointInfo.offset.dy,
                      child: Draggable(
                        feedback: Transform.scale(
                          scale: _transformationController.value.getMaxScaleOnAxis(),
                          child: c,
                        ),
                        childWhenDragging: Opacity(
                          opacity: .3,
                          child: c,
                        ),
                        onDragEnd: (detailsGlobalClicked) {
                          final RenderBox? box = _key.currentContext?.findRenderObject() as RenderBox?;
                          final Offset? position = box?.localToGlobal(Offset.zero);
                          var scale = _transformationController.value.getMaxScaleOnAxis();
                          Offset of = Offset(
                            (detailsGlobalClicked.offset.dx - position!.dx),
                            (detailsGlobalClicked.offset.dy - position.dy),
                          );
                          Offset add = Offset(
                            of.dx / scale,
                            of.dy / scale,
                          );
                          if (position != null) {
                            setState(() => mainPoints[id].offset = add);
                          }
                        },
                        child: c,
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
                        left: pointInfo.offset.dx,
                        top: pointInfo.offset.dy,
                        child: Draggable(
                          feedback: Transform.scale(
                            scale: _transformationController.value.getMaxScaleOnAxis(),
                            child: c,
                          ),
                          childWhenDragging: Opacity(
                            opacity: .3,
                            child: c,
                          ),
                          onDragEnd: (detailsGlobalClicked) {
                            final RenderBox? box = _key.currentContext?.findRenderObject() as RenderBox?;
                            final Offset? position = box?.localToGlobal(Offset.zero);
                            var scale = _transformationController.value.getMaxScaleOnAxis();
                            Offset of = Offset(
                              (detailsGlobalClicked.offset.dx - position!.dx),
                              (detailsGlobalClicked.offset.dy - position.dy),
                            );
                            Offset add = Offset(
                              of.dx / scale,
                              of.dy / scale,
                            );
                            if (position != null) {
                              setState(() => penilePoints[id].offset = add);
                            }
                          },
                          child: c,
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

  Widget _buildMenu() {
    double _tvVolume = volume(_tvWide, _tvLong, _tvHigh);
    double _tvDSP = 0.024 * (_tvVolume * 2) - 1.26;
    double _tvTVolume = 0.5233 * _tvLong * _tvWide * _tvHigh;
    double _tvDSP2 = 2.21 * (_tvWide * 2) - 6.4;

    double imageWidth = widget.imageMeta!.size!.width.toDouble();
    double imageHeight = widget.imageMeta!.size!.height.toDouble();

    double cmPerPixel = 0.0;

    double penileLength = 0.0;
    if (_penileExpanded) {
      for (int i = 0; i < penilePoints.length - 1; i++) {
        if (isVisible(penilePoints[i].offset, imageWidth, imageHeight) && isVisible(penilePoints[i + 1].offset, imageWidth, imageHeight)) {
          double distPixel = (penilePoints[i].offset - penilePoints[i + 1].offset).distance;
          penileLength += distPixel * cmPerPixel;
        }
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
                        InfoBox(one: Tooltip(message: 'Daily Sperm Production', child: Text('N (million spz/j)', style: TextStyle(fontSize: 12, color: Colors.white70))), two: _tvDSP.toStringAsFixed(3), withGap: false),
                        InfoBox(one: 'Testicular volume', two: '${_tvTVolume.toStringAsFixed(3)}ml', withGap: false),
                        InfoBox(one: 'Daily Sperm Output (×109)', two: ((0.024 * _tvTVolume) - 0.76).toStringAsFixed(3), withGap: false),
                        InfoBox(one: 'Jets count', two: ((volumeToJets(_tvVolume, sizes['horse']['testicles']) * 2) * 0.5).toStringAsFixed(1), withGap: false),
                        InfoBox(one: 'Weight (both)', two: '${(volumeToWeight(_tvVolume, sizes['horse']['testicles']) * 2).toStringAsFixed(2)}g (${(volumeToWeight(_tvVolume, sizes['horse']['testicles']) * 2 / 1000).toStringAsFixed(2)}kg)', withGap: false),
                        const Text('On average width of the 2 testes'),
                        InfoBox(one: 'Width of both', two: '${(_tvWide * 2).toStringAsFixed(2)}cm', withGap: false),
                        InfoBox(one: Tooltip(message: 'Daily Sperm Production', child: Text('N (million spz/j)', style: TextStyle(fontSize: 12, color: Colors.white70))), two: _tvDSP2.toStringAsFixed(3), withGap: false),
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
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Place 5 points along the visible length from base to tip',
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