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
  ].mapIndexed((id, data) => PointInfo(message: data[0] as String, color: data[1] as Color, offset: Offset(30, (30 * (id+1)).toDouble()))).toList();

  // Testicular volume
  bool _tvAutoByWidth = true;
  double _tvLong = 12;
  double _tvWide = 7.3;
  double _tvHigh = 7.3;


  final TransformationController _transformationController = TransformationController();
  final GlobalKey _key = GlobalKey();

  bool doned = false;
  PhotoViewScaleStateController scaleStateController = PhotoViewScaleStateController();
  final TextEditingController _characterHeight = TextEditingController();
  double _ch = 175.4;

  late final lotsOfData = _readImageFile(widget.imageMeta!);

  @override
  void initState(){
    // WidgetsBinding.instance.addPostFrameCallback((_){
    //   showDialog<String>(
    //     context: context,
    //     builder: (BuildContext context) => AlertDialog(
    //       title: ShowUp(
    //         delay: 100,
    //         child: Text('Be careful', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600, fontFamily: 'Montserrat')),
    //       ),
    //       icon: Icon(Icons.star),
    //       iconColor: Colors.yellow,
    //       content: Container(
    //         constraints: BoxConstraints(maxWidth: 300),
    //         child: const Text('Be sure to check carefully for any defects and artifacts before publishing - remember that once published to third-party resources, you will not be able to remove it from the users\' minds if they find it', style: TextStyle(fontFamily: 'Montserrat')),
    //       ),
    //       actions: <Widget>[
    //         TextButton(
    //           onPressed: () => Navigator.pop(context),
    //           child: const Text('Okay'),
    //         ),
    //       ],
    //     ),
    //   );
    //   audioController!.player.play(AssetSource('audio/open.wav'));
    // });
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
            child: screenWidth >= breakpoint ? Row(
              children: [
                Expanded(
                    child: _buildMain()
                ),
                _buildMenu()
              ],
            ) : _buildMain()
        )
    );
  }

  Widget _buildMain(){
    double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    double imageWidth = widget.imageMeta!.size!.width.toDouble();
    double imageHeight = widget.imageMeta!.size!.height.toDouble();

    List<AverageInfo> averages = [
      AverageInfo(a: mainPoints[1].offset, b: mainPoints[3].offset, message: '${percentFromNum(17, _ch).toStringAsFixed(1)}cm'),
      AverageInfo(a: mainPoints[2].offset, b: mainPoints[4].offset, message: '${percentFromNum(17, _ch).toStringAsFixed(1)}cm')
    ];

    return LayoutBuilder(
        builder: (__, constraint) {
          if(!doned) {
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
                onTapDown: (TapDownDetails event){
                  print(event.localPosition);
                },
                child: Stack(
                  children: [
                    ['png', 'jpeg', 'gif', 'webp', 'bmp', 'bmp'].contains(widget.imageMeta!.fileTypeExtension) ? Hero(
                      tag: widget.imageMeta!.fileName,
                      child: Image.file(
                        fit: BoxFit.cover,
                        File(widget.imageMeta!.fullPath ?? widget.imageMeta!.tempFilePath ?? widget.imageMeta!.cacheFilePath ?? 'e.png'),
                        //width: widget.imageMeta!.size!.width / devicePixelRatio,
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
                    ) : FutureBuilder(
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
                        }
                    ),
                    ...mainPoints.mapIndexed((id, pointInfo){
                      Widget c = Tooltip(message: pointInfo.message, child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: pointInfo.color), width: 30, height: 30));
                      return Positioned(
                        left: pointInfo.offset.dx,
                        top: pointInfo.offset.dy,
                        child: Draggable(
                          feedback: Transform.scale(
                              scale: _transformationController.value.getMaxScaleOnAxis(),
                              child: c
                          ),
                          childWhenDragging: Opacity(
                            opacity: .3,
                            child: c,
                          ),
                          onDragEnd: (detailsGlobalClicked){
                            //setState(() => mainPoints[id] = Offset(0, 0));
                            final RenderBox? box = _key.currentContext?.findRenderObject() as RenderBox?;
                            final Offset? position = box?.localToGlobal(Offset.zero);
                            var scale = _transformationController.value.getMaxScaleOnAxis();
                            Offset of = Offset(
                                (detailsGlobalClicked.offset.dx - position!.dx),
                                (detailsGlobalClicked.offset.dy - position.dy)
                            );
                            Offset add = Offset(
                              of.dx * (imageWidth / (imageWidth * scale)),
                              of.dy * (imageHeight / (imageHeight * scale))
                            );
                            if (position != null) {
                              setState(() => mainPoints[id].offset = add);
                            }
                          },
                          child: c,
                        ),
                      );
                    }),
                    Positioned(left: averages[0].offset.dx, top: averages[0].offset.dy, child: Transform.rotate(angle: averages[0].angle, child: Text(averages[0].message))),
                    Positioned(left: averages[1].offset.dx, top: averages[1].offset.dy, child: Transform.rotate(angle: averages[1].angle, child: Text(averages[1].message)))
                  ],
                ),
              )
          );
      }
    );
  }

  Widget _buildMenu(){
    double _tvVolume = volume(_tvWide, _tvLong, _tvHigh);
    double _tvDSP = 0.024 * (_tvVolume * 2) - 1.26;
    double _tvTVolume = 0.5233 * _tvLong * _tvWide * _tvHigh;
    double _tvDSP2 = 2.21 * (_tvWide * 2) - 6.4;

    return Container(
      padding: const EdgeInsets.all(6),
      width: 420,
      child: SingleChildScrollView(
        child: Column(
            children: [
              ExpansionTile(
                initiallyExpanded: true,
                tilePadding: EdgeInsets.zero,
                title:  Text('Main data', style: TextStyle(color: Colors.deepPurple.shade50, fontWeight: FontWeight.w600, fontSize: 18)),
                children: <Widget>[
                  Gap(7),
                  SegmentedButton<Gender>(
                    segments: const <ButtonSegment<Gender>>[
                      ButtonSegment<Gender>(
                          value: Gender.male,
                          label: Text('Male'),
                          icon: Icon(Icons.male)),
                      ButtonSegment<Gender>(
                          value: Gender.other,
                          label: Text('Other'),
                          icon: Icon(Icons.transgender)),
                      ButtonSegment<Gender>(
                          value: Gender.female,
                          label: Text('Female'),
                          icon: Icon(Icons.female)),
                    ],
                    selected: <Gender>{gender},
                    onSelectionChanged: (Set<Gender> newSelection) {
                      setState(() {
                        gender = newSelection.first;
                      });
                    },
                  ),
                  Gap(14),
                  TextField(
                    decoration: InputDecoration(
                      hintText: "175.4",
                      border: OutlineInputBorder(),
                      labelText: 'Character height (cm)',
                    ),
                    keyboardType: TextInputType.number,
                    controller: _characterHeight,
                    onChanged: (v) => setState(() {
                      _ch = double.parse(v);
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
                        Center(child: Icon(Icons.accessibility, color: Colors.grey, size: 400)),
                        Positioned(top: 22, left: 189, child: Tooltip(message: mainPoints[0].message, child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: mainPoints[0].color), width: 30, height: 30))),
                        Positioned(top: 118, left: 40, child: Tooltip(message: mainPoints[1].message, child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: mainPoints[1].color), width: 30, height: 30))),
                        Positioned(top: 118, right: 40, child: Tooltip(message: mainPoints[2].message, child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: mainPoints[2].color), width: 30, height: 30))),
                        Positioned(top: 118, left: 90, child: Tooltip(message: mainPoints[3].message, child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: mainPoints[3].color), width: 30, height: 30))),
                        Positioned(top: 118, right: 90, child: Tooltip(message: mainPoints[4].message, child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: mainPoints[4].color), width: 30, height: 30))),
                        Positioned(top: 118, left: 140, child: Tooltip(message: mainPoints[5].message, child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: mainPoints[5].color), width: 30, height: 30))),
                        Positioned(top: 118, right: 140, child: Tooltip(message: mainPoints[6].message, child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: mainPoints[6].color), width: 30, height: 30))),
                        Positioned(top: 240, left: 155, child: Tooltip(message: mainPoints[7].message, child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: mainPoints[7].color), width: 30, height: 30))),
                        Positioned(top: 240, right: 155, child: Tooltip(message: mainPoints[8].message, child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: mainPoints[8].color), width: 30, height: 30))),
                        Positioned(top: 295, left: 155, child: Tooltip(message: mainPoints[9].message, child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: mainPoints[9].color), width: 30, height: 30))),
                        Positioned(top: 295, right: 155, child: Tooltip(message: mainPoints[10].message, child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: mainPoints[10].color), width: 30, height: 30))),
                        Positioned(top: 350, left: 155, child: Tooltip(message: mainPoints[11].message, child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: mainPoints[11].color), width: 30, height: 30))),
                        Positioned(top: 350, right: 155, child: Tooltip(message: mainPoints[12].message, child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: mainPoints[12].color), width: 30, height: 30))),
                      ],
                    ),
                  )
                ],
              ),
              if(gender == Gender.male || gender == Gender.other) ExpansionTile(
                initiallyExpanded: true,
                tilePadding: EdgeInsets.zero,
                title:  Text('Testicular volume/size', style: TextStyle(color: Colors.deepPurple.shade50, fontWeight: FontWeight.w600, fontSize: 18)),
                children: <Widget>[
                  Gap(7),
                  SwitchListTile(
                    title: const Text('Proportional calculation'),
                    value: _tvAutoByWidth,
                    onChanged: (bool? value) => setState(() {
                      _tvAutoByWidth = value ?? false;
                    }),
                    secondary: const Icon(Icons.compare_arrows),
                  ),
                  Gap(3),
                  Text('Long ${_tvLong.toStringAsFixed(1)}cm'),
                  Slider(
                    activeColor: _tvAutoByWidth ? Colors.white10 : null,
                    value: _tvLong,
                    max: 100,
                    divisions: 200,
                    label: _tvLong.toStringAsFixed(1),
                    onChanged: (double value) => setState(() {_tvLong = value; _tvAutoByWidth = false;}),
                  ),
                  Gap(3),
                  Text('Wide ${_tvWide.toStringAsFixed(1)}cm'),
                  Slider(
                    value: _tvWide,
                    max: 100,
                    divisions: 200,
                    label: _tvWide.toStringAsFixed(1),
                    onChanged: (double value) {
                      setState(_tvAutoByWidth ? () {_tvWide = value; _tvLong = math.min(value * 2 - (value * 25 / 100), 100); _tvHigh = math.min(value * 20 / 100 + value, 100);} : () {_tvWide = value;});
                    },
                  ),
                  Gap(3),
                  Text('High ${_tvHigh.toStringAsFixed(1)}cm'),
                  Slider(
                    activeColor: _tvAutoByWidth ? Colors.white10 : null,
                    value: _tvHigh,
                    max: 100,
                    divisions: 200,
                    label: _tvHigh.toStringAsFixed(1),
                    onChanged: (double value) => setState(() {_tvHigh = value; _tvAutoByWidth = false;}),
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
                        Text('On volume'),
                        InfoBox(one: 'Vol per one (cm3)', two: '${_tvVolume.toStringAsFixed(3)}ml (both ${(_tvVolume*2).toStringAsFixed(3)}ml)', withGap: false),
                        InfoBox(one: Tooltip(message: 'Daily Sperm Production', child: Text('N (million spz/j)', style: TextStyle(fontSize: 12, color: Colors.white70))), two: _tvDSP.toStringAsFixed(3), withGap: false),
                        InfoBox(one: 'Testicular volume', two: '${_tvTVolume.toStringAsFixed(3)}ml', withGap: false),
                        InfoBox(one: 'Daily Sperm Output (×109)', two: ((0.024 * _tvTVolume) - 0.76).toStringAsFixed(3), withGap: false),
                        InfoBox(one: 'Jets count', two: ((volumeToJets(_tvVolume, sizes['horse']['testicles']) * 2) * 0.5).toStringAsFixed(1), withGap: false),
                        InfoBox(one: 'Weight (both)', two: '${(volumeToWeight(_tvVolume, sizes['horse']['testicles']) * 2).toStringAsFixed(2)}g (${(volumeToWeight(_tvVolume, sizes['horse']['testicles']) * 2 / 1000).toStringAsFixed(2)}kg)', withGap: false),
                        Text('On average width of the 2 testes'),
                        InfoBox(one: 'Width of both', two: '${(_tvWide * 2).toStringAsFixed(2)}cm', withGap: false),
                        InfoBox(one: Tooltip(message: 'Daily Sperm Production', child: Text('N (million spz/j)', style: TextStyle(fontSize: 12, color: Colors.white70))), two: _tvDSP2.toStringAsFixed(3), withGap: false),
                      ],
                    ),
                  ),
                  Gap(7)
                ],
              ),
              const Gap(7),
              MaterialButton(onPressed: () {
                _transformationController.value = Matrix4.identity() * 0.5;
              }, child: Text('fsdf')),
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
            ]
        ),
      ),
    );
  }
}

class InfoBox extends StatelessWidget{
  final dynamic one;
  final dynamic two;
  final bool inner;
  final bool withGap;

  const InfoBox({ Key? key, required this.one, required this.two, this.inner = false, this.withGap = true}): super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
        margin: withGap ? const EdgeInsets.only(top: 4) : null,
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            child: Row( // This shit killed four hours of my life.
              children: [
                one.runtimeType == String ? SelectableText(one, style: const TextStyle(fontSize: 12, color: Colors.white70)) : one,
                const Gap(6),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: two.runtimeType == String ? SelectableText(two, style: const TextStyle(fontSize: 13)) : two,
                    ),
                  ),
                )
              ],
            )
        )
    );
  }
}

double volume(num wide, num long, num high){
  return 4/3*math.pi*(wide / 2 * long /2 * high /2);
}

double volumeToJets(double V, Map<String, List<num>> data){
  num v1 = volume(data['wide']![0], data['long']![0], data['high']![0]);
  num v2 = volume(data['wide']![1], data['long']![1], data['high']![1]);
  return extrapolate(v1, data['jets']![0], v2, data['jets']![1], V);
}
double extrapolate(num x1, num y1, num x2, num y2, num value){
  return y1 + (value - x1) / (x2 - x1) * (y2 - y1);
}
double volumeToWeight(double V, data){
  double v1 = volume(data['wide'][0], data['long'][0], data['high'][0]);
  double  v2 = volume(data['wide'][1], data['long'][1], data['high'][1]);
  return extrapolate(v1, data['gram'][0], v2, data['gram'][1], V);
}

class PointInfo{
  String message;
  Color color;
  Offset offset;

  PointInfo({
    required this.message,
    required this.color,
    required this.offset
  });
}

class AverageInfo{
  Offset a;
  Offset b;
  String message;
  // double cm;
  // Offset offset;
  // double angle;

  AverageInfo({
    required this.a,
    required this.b,
    required this.message
  });

  Offset get offset => averageOffset(a, b);
  double get angle => math.atan2(b.dy - a.dy, b.dx - a.dx) * 180 / math.pi;
}

Offset averageOffset(Offset one, Offset two){
  return Offset(
    (one.dx + two.dx) / 2,
    (one.dy + two.dy) / 2,
  );
}