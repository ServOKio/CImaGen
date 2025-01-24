import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cimagen/main.dart';
import 'package:cimagen/pages/sub/DebugDevPage.dart';
import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../utils/Extra.dart';
import '../utils/ImageManager.dart';
import '../utils/SQLite.dart';

class CAppBar extends StatefulWidget implements PreferredSizeWidget {
  CAppBar({ Key? key }) : preferredSize = const Size.fromHeight(kToolbarHeight), super(key: key);

  @override
  final Size preferredSize;

  @override
  _CustomAppBarState createState() => _CustomAppBarState();
}

class _CustomAppBarState extends State<CAppBar>{
  final debug = true;
  bool open = false;
  double turns = 0.0;

  Future<List<ImageMeta>>? imagesList;

  Timer? timer;
  int removeMe = 0;

  final myController = TextEditingController();

  @override
  void dispose() {
    myController.dispose();
    super.dispose();
  }

  String cache = '';

  @override
  void initState() {
    super.initState();
    myController.addListener(() {
      final String text = myController.text;
      if(cache == text) return;
      cache = text;
      removeMe = 100;
      if(timer != null && timer!.isActive) timer?.cancel();
      timer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
        removeMe -= 10;
        if(removeMe <= 0){
          setState(() {
            turns += 1.3;
          });
          imagesList = context.read<SQLite>().findByTags(text.split(' ').map((e) => e.trim()).toList(growable: false));
          timer.cancel();
        }
      });
      if(open != text.trim().isNotEmpty){
        setState(() {
          open = text.trim().isNotEmpty;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ListenableBuilder(
          listenable: appBarController!,
          builder: (BuildContext context, Widget? child){
            return AppBar(
                clipBehavior: Clip.none,
                surfaceTintColor: Colors.transparent,
                centerTitle: true,
                backgroundColor: const Color(0xff0c0c0e),
                title: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 720,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: const Color(0xff15161a),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: myController,
                            style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(context)!.appbarSearch,
                              hintStyle: const TextStyle(color: Color(0xff8a8a8c), fontWeight: FontWeight.w400, fontSize: 14),
                              labelStyle: const TextStyle(color: Colors.red),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                            ),
                            maxLines: 1,
                          ),
                        ),
                        const Gap(8),
                        //https://stackoverflow.com/questions/55395641/outlined-transparent-button-with-gradient-border-in-flutter
                        AnimatedRotation(
                          turns: turns,
                          duration: const Duration(seconds: 2),
                          curve: Curves.ease,
                          child: UnicornOutlineButton(
                            strokeWidth: 3,
                            radius: 24,
                            gradient: const LinearGradient(
                                begin: Alignment.topRight,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xfffd01d3), Color(0xff1d04f5), Color(0xff729aff), Color(0xffffffff)],
                                stops: [0, 0.5, 0.9, 1]
                            ),
                            child: const SizedBox(
                              width: 20,
                              height: 20,
                            ),
                            onPressed: () {},
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                actions: appBarController!.actions.isEmpty ? <Widget>[
                  IconButton(
                    icon: const Icon(Icons.stadium_outlined),
                    tooltip: 'DEBUG PAGE',
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DebugDevPage())),
                  ),
                  IconButton(
                    icon: const Icon(Icons.bug_report),
                    tooltip: 'Report bug',
                    onPressed: () {
                      BetterFeedback.of(context).show((feedback) async {
                        final screenshotFilePath = await writeImageToStorage(feedback.screenshot);
                        
                        await Share.shareXFiles(
                          [XFile(screenshotFilePath)],
                          text: feedback.text,
                        );
                      },
                      );
                    },
                  ),
                  const Gap(8)
                ] : appBarController!.actions
            );
          }
        ),
        Positioned(
          left: MediaQuery.of(context).size.width / 2 - ((MediaQuery.of(context).size.width - 100) / 2),
          top: 60,
            child: AnimatedContainer(
              clipBehavior: Clip.antiAlias,
              width: MediaQuery.of(context).size.width - 100,
              height: open ? 234 : 0,
              duration: const Duration(seconds: 1),
              curve: Curves.fastOutSlowIn,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: const Color(0xff0c0c0e),
              ),
              child: ScrollConfiguration(
                  behavior: MyCustomScrollBehavior(),
                  child: FutureBuilder(
                      future: imagesList,
                      builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
                        Widget children;
                        if (snapshot.hasData) {
                          children = ListView.builder(
                              itemCount: snapshot.data.length,
                              scrollDirection: Axis.horizontal,
                              itemBuilder: (context, index) {
                                ImageMeta im = snapshot.data.elementAt(index);
                                return Container(
                                    margin: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(3),
                                        border: Border.all(color: Colors.white10)
                                    ),
                                    child: Stack(
                                      children: [
                                        Image.memory(gaplessPlayback: true, base64Decode(im.thumbnail ?? '')),
                                      ],
                                    )
                                );
                              }
                          );
                        } else {
                          children = CircularProgressIndicator();
                        }
                        return children;
                      }
                  )
              ),
            )
        )
      ],
    );
  }
}

Future<String> writeImageToStorage(Uint8List feedbackScreenshot) async {
  final Directory output = await getTemporaryDirectory();
  final String screenshotFilePath = '${output.path}/feedback.png';
  final File screenshotFile = File(screenshotFilePath);
  await screenshotFile.writeAsBytes(feedbackScreenshot);
  return screenshotFilePath;
}

class UnicornOutlineButton extends StatelessWidget {
  final _GradientPainter _painter;
  final Widget _child;
  final VoidCallback _callback;
  final double _radius;

  UnicornOutlineButton({super.key,
    required double strokeWidth,
    required double radius,
    required Gradient gradient,
    required Widget child,
    required VoidCallback onPressed,
  })  : _painter = _GradientPainter(strokeWidth: strokeWidth, radius: radius, gradient: gradient),
        _child = child,
        _callback = onPressed,
        _radius = radius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _painter,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _callback,
        child: InkWell(
          borderRadius: BorderRadius.circular(_radius),
          onTap: _callback,
          child: Container(
            constraints: const BoxConstraints(minWidth: 4, minHeight: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientPainter extends CustomPainter {
  final Paint _paint = Paint();
  final double radius;
  final double strokeWidth;
  final Gradient gradient;

  _GradientPainter({required this.strokeWidth, required this.radius, required this.gradient});

  @override
  void paint(Canvas canvas, Size size) {
    // create outer rectangle equals size
    Rect outerRect = Offset.zero & size;
    var outerRRect = RRect.fromRectAndRadius(outerRect, Radius.circular(radius));

    // create inner rectangle smaller by strokeWidth
    Rect innerRect = Rect.fromLTWH(strokeWidth, strokeWidth, size.width - strokeWidth * 2, size.height - strokeWidth * 2);
    var innerRRect = RRect.fromRectAndRadius(innerRect, Radius.circular(radius - strokeWidth));

    // apply gradient shader
    _paint.shader = gradient.createShader(outerRect);

    // create difference between outer and inner paths and draw it
    Path path1 = Path()..addRRect(outerRRect);
    Path path2 = Path()..addRRect(innerRRect);
    var path = Path.combine(PathOperation.difference, path1, path2);
    canvas.drawPath(path, _paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => oldDelegate != this;
}