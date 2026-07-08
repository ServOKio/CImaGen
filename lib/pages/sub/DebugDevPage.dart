import 'dart:io';

import 'package:cimagen/main.dart';
import 'package:cimagen/modules/Objectbox.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:snowflake_dart/snowflake_dart.dart';

import '../../Utils.dart';
import '../../components/Animations.dart';
import '../../components/wcg_image.dart';
import '../../modules/libpuzzle/libPuzzle.dart';
import '../../utils/ImageManager.dart';
import '../../utils/Tokenizer.dart';

import 'dart:math' as math;

class DebugDevPage extends StatefulWidget {
  DebugDevPage({Key? key}) : super(key: key);

  @override
  _DebugDevPageState createState() => _DebugDevPageState();
}

class _DebugDevPageState extends State<DebugDevPage> {
  bool loaded = false;
  Snowflake snowflake = Snowflake(epoch: 1420070400000, nodeId: 0);
  TokenizerModule tokenizerModule = TokenizerModule();

  LibPuzzle puzzle = LibPuzzle();

  @override
  void initState() {
    super.initState();
    puzzle.puzzle_init_context();
    puzzle.puzzle_init_cvec();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
        length: 3,
        child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
            title: const Text('Debug'),
            backgroundColor: const Color(0xaa000000),
            elevation: 0,
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.one_k)),
                Tab(icon: Icon(Icons.two_k)),
                Tab(icon: Icon(Icons.three_k)),
              ],
            ),
        ),
        body: SafeArea(child: TabBarView(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  TextButton(
                    onPressed: (){
                      print(DateTime.fromMillisecondsSinceEpoch(snowflake.getTimeFromId(1332201808214364314)));
                    },
                    child: Text('Print epoch'),
                  ),
                  TextButton(
                    onPressed: (){
                      context.read<ImageManager>().changeGetter(2);
                    },
                    child: Text('Change getter to OnWeb'),
                  ),
                  TextButton(
                    onPressed: (){
                      sqLite.testDB().then((value) {

                      }, onError: (error) {
                        print(error);
                      });
                    },
                    child: Text('Test db'),
                  ),
                  TextButton(
                    onPressed: (){
                      objectbox.fixDB(DBErrorsForFix.image_size_missmatch);
                    },
                    child: Text('Fix db: broken cached image size'),
                  ),
                  TextButton(
                    onPressed: () async {
                      int res = await puzzle.puzzle_fill_cvec_from_file(File('W:/00906-3163105554.png'));
                      print(res);
                    },
                    child: Text('Test libpuzzle'),
                  ),
                  TextButton(
                    onPressed: () async {
                      List<Map<String, dynamic>> res = await tokenizerModule.tokenize('runwayml/stable-diffusion-v1-5', 'by blotch, by (darkgem:1.3), by mystikfox61, by strange-fox, by (nawka:0.7), (by rayliicious:0.8)');
                      print(res);
                    },
                    child: Text('Test tokenizerModule'),
                  ),
                  TextButton(
                    onPressed: () async {
                      objectbox.getBiggestAss();
                    },
                    child: Text('get big ass'),
                  ),
                  // TextButton(
                  //   onPressed: () async {
                  //     sqLite.updatePosts(File('D:\\PC\\Documents\\CImaGen\\csv\\posts-2026-02-25.csv'));
                  //   },
                  //   child: Text('Import eFile'),
                  // ),
                  TextButton(
                    onPressed: () async {
                      print(isImage('sdfsf/fdsaf.png'));
                      print(isImage('.png'));
                      print(isImage('png'));
                    },
                    child: Text('Test path'),
                  ),
                  Text("Jobs"),
                  Column(
                    children: context.read<ImageManager>().getter.getJobs.keys.map((key){
                      ParseJob j = context.read<ImageManager>().getter.getJobs[key]!;
                      return Container(
                        margin: EdgeInsets.all(7),
                        color: Colors.blueGrey,
                        child: Column(
                          children: [
                            SelectableText('JobID: ${j.jobID}'),
                            SelectableText('controller.isClosed: ${j.controller.isClosed}'),
                            SelectableText('host: ${j.host}'),
                            SelectableText('isDone: ${j.isDone}'),
                            TextButton(
                              onPressed: () => j.forceStop(),
                              child: Text('Force stop'),
                            ),
                          ],
                        ),
                      );
                    }).toList(growable: false),
                  ),
                  WavyDotsLoader(
                    duration: const Duration(milliseconds: 3800), // slower = calmer
                  ),
                  Gap(10),
                  SizedBox(
                    width: 100,
                    height: 200,
                    child: FadingCurveLoader(
                      pathColor: Theme.of(context).colorScheme.primary,
                      gridColor: Colors.transparent,
                    ),
                  )
                ],
              ),
            ),
            two(),
            three()
          ],
        ))
    )
    );
  }

  Widget two(){
    double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    return Expanded(child: InteractiveViewer(
      constrained: false,
      child: Image.file(
        File('W:/750_chunie_beach_treat.png'),
        width: 2021 / devicePixelRatio,
        height: 3000 / devicePixelRatio,
      ),
    ));
  }

  Widget three(){
    double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    return WcgImage.file('W:/image-red-P3.jpg');
  }
}

class SuperellipseRectangleBorder extends OutlinedBorder {
  final double cornerRadius;
  final double exponent;

  const SuperellipseRectangleBorder({
    required this.cornerRadius,
    this.exponent = 4,
    super.side = BorderSide.none,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  SuperellipseRectangleBorder copyWith({
    BorderSide? side,
  }) {
    return SuperellipseRectangleBorder(
      cornerRadius: cornerRadius,
      exponent: exponent,
      side: side ?? this.side,
    );
  }


  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return _buildPath(rect);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return _buildPath(rect.deflate(side.width));
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side == BorderSide.none) return;

    final path = getOuterPath(rect);

    final paint = side.toPaint();
    canvas.drawPath(path, paint);
  }

  Path _buildPath(Rect rect) {
    final r = cornerRadius.clamp(
      0.0,
      math.min(rect.width, rect.height) / 2,
    );

    final n = exponent;

    final left = rect.left;
    final right = rect.right;
    final top = rect.top;
    final bottom = rect.bottom;

    final path = Path();

    path.moveTo(left + r, top);
    path.lineTo(right - r, top);

    _addCorner(path, Offset(right - r, top + r), r, n, -math.pi / 2);

    path.lineTo(right, bottom - r);

    _addCorner(path, Offset(right - r, bottom - r), r, n, 0);

    path.lineTo(left + r, bottom);

    _addCorner(path, Offset(left + r, bottom - r), r, n, math.pi / 2);

    path.lineTo(left, top + r);

    _addCorner(path, Offset(left + r, top + r), r, n, math.pi);

    path.close();

    return path;
  }

  void _addCorner(
      Path path,
      Offset center,
      double radius,
      double exponent,
      double startAngle,
      ) {
    const steps = 24;

    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final angle = startAngle + t * (math.pi / 2);

      final cosT = math.cos(angle);
      final sinT = math.sin(angle);

      final x = radius *
          math.pow(cosT.abs(), 2 / exponent) *
          (cosT >= 0 ? 1 : -1);

      final y = radius *
          math.pow(sinT.abs(), 2 / exponent) *
          (sinT >= 0 ? 1 : -1);

      path.lineTo(center.dx + x, center.dy + y);
    }
  }

  @override
  ShapeBorder scale(double t) {
    return SuperellipseRectangleBorder(
      cornerRadius: cornerRadius * t,
      exponent: exponent,
      side: side.scale(t),
    );
  }
}