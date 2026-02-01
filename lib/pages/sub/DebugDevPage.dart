import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cimagen/main.dart';
import 'package:cimagen/modules/Objectbox.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:snowflake_dart/snowflake_dart.dart';

import '../../modules/libpuzzle/libPuzzle.dart';
import '../../utils/ImageManager.dart';
import '../../utils/Tokenizer.dart';

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
    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
            title: const Text('Debug'),
            backgroundColor: const Color(0xaa000000),
            elevation: 0,
            actions: [
            ]
        ),
        body: SafeArea(
          child: SingleChildScrollView(
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
                Container(
                  width: 350,
                  height: 500,
                  clipBehavior: Clip.antiAlias,
                  decoration: ShapeDecoration(
                    shape: SuperellipseRectangleBorder(
                      cornerRadius: 28,
                      exponent: 4,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 7,
                        right: 50,
                        child: Container(
                          width: 100,
                          height: 90,
                          color: Color(0xFFf280de),
                        ),
                      ),
                      Positioned(
                        top: 5,
                        right: 5,
                        child: Container(
                          width: 60,
                          height: 60,
                          color: Color(0xFF60a4f9),
                        ),
                      ),
                      ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 30.0, sigmaY: 30.0),
                          child: Container(
                            padding: EdgeInsetsGeometry.all(7),
                            decoration: ShapeDecoration(
                              //color: Colors.grey.shade200.withOpacity(0.5),
                              shape: SuperellipseRectangleBorder(
                                cornerRadius: 28,
                                exponent: 4,
                                side: const BorderSide(
                                  color: Color(0xcb3c3c3c),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Column(
                              children: [
                                Padding(padding: EdgeInsetsGeometry.only(top: 9, left: 14, right: 14, bottom: 2), child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.white.withAlpha(80),
                                            spreadRadius: 3,
                                            blurRadius: 0,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Gap(12),
                                    Text('Node Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, fontFamily: 'Montserrat', color: Colors.white))
                                  ],
                                )),
                                Gap(14),
                                Expanded(
                                  child: Container(
                                      decoration: ShapeDecoration(
                                        color: Color(0xFF2d2d2d),
                                        shape: SuperellipseRectangleBorder(
                                          cornerRadius: 28,
                                          exponent: 4,
                                          side: const BorderSide(
                                            color: Color(0xcb3c3c3c),
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsetsGeometry.all(14),
                                        child: Column(
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // INPUTS on the left
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: ['model', 'positive', 'negative'].map((item) => Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Container(
                                                        width: 8,
                                                        height: 8,
                                                        decoration: BoxDecoration(
                                                          color: Color(0xFF70b6f5),
                                                          shape: BoxShape.circle,
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Color(0xFF70b6f5).withAlpha(80),
                                                              spreadRadius: 3,
                                                              blurRadius: 0,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Gap(10),
                                                      Text(item, style: const TextStyle(color: Color(0xFFA6A6A6), fontSize: 12))
                                                    ],
                                                  )).expand((x) => [const Gap(7), x]).skip(1).toList()
                                                ),

                                                // OUTPUTS on the right
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Text('image', style: const TextStyle(color: Color(0xFFA6A6A6), fontSize: 12)),
                                                        Gap(10),
                                                        Container(
                                                          width: 8,
                                                          height: 8,
                                                          decoration: BoxDecoration(
                                                            color: Color(0xFFf9b955),
                                                            shape: BoxShape.circle,
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: Color(0xFFf9b955).withAlpha(80),
                                                                spreadRadius: 3,
                                                                blurRadius: 0,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    )
                                                  ]
                                                ),
                                              ],
                                            ),
                                            Gap(21),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: ['Seed', 'Sampling method'].map((item) => SizedBox(
                                                    height: 48,
                                                    child: Center(child: Text(item, style: const TextStyle(color: Color(0xFFA6A6A6), fontSize: 14), textAlign: TextAlign.left)),
                                                  )).expand((x) => [const Gap(7), x]).skip(1).toList()
                                                ),
                                                Gap(14),
                                                Expanded(
                                                  child: Column(
                                                    children: [
                                                      Container(
                                                          decoration: ShapeDecoration(
                                                            color: Color(0xFF171717),
                                                            shape: SuperellipseRectangleBorder(
                                                              cornerRadius: 28,
                                                              exponent: 4,
                                                              side: const BorderSide(
                                                                color: Color(0xcb3c3c3c),
                                                                width: 1,
                                                              ),
                                                            ),
                                                          ),
                                                          child: TextField(
                                                            decoration: InputDecoration(
                                                              filled: true,
                                                              hintStyle: TextStyle(color: Color(0xFF787878), fontSize: 14),
                                                              hintText: "Seed",
                                                              fillColor: Colors.transparent,
                                                              border: InputBorder.none,
                                                            ),
                                                            maxLines: 1,
                                                            keyboardType: TextInputType.number,
                                                            inputFormatters: <TextInputFormatter>[
                                                              FilteringTextInputFormatter.digitsOnly
                                                            ], // Only numbers can be entered
                                                          )
                                                      ),
                                                      Gap(7),
                                                      Container(
                                                          decoration: ShapeDecoration(
                                                            color: Color(0xFF171717),
                                                            shape: SuperellipseRectangleBorder(
                                                              cornerRadius: 28,
                                                              exponent: 4,
                                                              side: const BorderSide(
                                                                color: Color(0xcb3c3c3c),
                                                                width: 1,
                                                              ),
                                                            ),
                                                          ),
                                                          child: DropdownButton<String>(
                                                            underline: SizedBox(),
                                                            value: 'DPM++ 2M',
                                                            items: <String>['DPM++ 2M', 'DPM++ SDE'].map((String value) {
                                                              return DropdownMenuItem<String>(
                                                                value: value,
                                                                child: Text(value, style: TextStyle(color: Color(0xFFA6A6A6), fontSize: 14)),
                                                              );
                                                            }).toList(),
                                                            onChanged: (_) {},
                                                          )
                                                      )
                                                    ],
                                                  ),
                                                )
                                              ],
                                            )
                                          ],
                                        ),
                                      )
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
          )
        )
    );
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