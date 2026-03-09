import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:cimagen/main.dart';
import 'package:cimagen/pages/sub/DebugDevPage.dart';
import 'package:cimagen/pages/sub/TestActivity.dart';
import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:gap/gap.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../constants.dart';
import '../pages/Gallery.dart';
import '../pages/sub/ImageView.dart';
import '../utils/Extra.dart';
import '../utils/ImageManager.dart';

class CAppBar extends StatefulWidget implements PreferredSizeWidget {
  CAppBar({ Key? key }) : preferredSize = const Size.fromHeight(kToolbarHeight+32), super(key: key);

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
          // TODO
          if(text.trim().isNotEmpty) imagesList = sqLite.search(text.trim(), context.read<ImageManager>().getter.host);
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
    return ListenableBuilder(
        listenable: appBarController!,
        builder: (BuildContext context, Widget? child){
          return Column(
            children: [
              if(isWindowed) Container(
                  color: const Color(0xff0c0c0e),
                  height: 32,
                  width: MediaQuery.of(context).size.width,
                  child: Stack(
                    children: [
                      Positioned(
                        height: 32,
                        left: 0,
                        right: 0,
                        child: MoveWindow(
                          child: appBarController!.windowBar,
                        ),
                      ),
                      Positioned(
                          top: 0,
                          left: Platform.isMacOS ? 0 : null,
                          right: !Platform.isMacOS ? 0 : null,
                          child: Row(children: Platform.isMacOS ? [
                            CloseWindowButton(),
                            MinimizeWindowButton(),
                            MaximizeWindowButton()
                          ] : [
                            MinimizeWindowButton(colors: WindowButtonColors(iconNormal: Theme.of(context).colorScheme.primary)),
                            MaximizeWindowButton(colors: WindowButtonColors(iconNormal: Theme.of(context).colorScheme.primary)),
                            CloseWindowButton(colors: WindowButtonColors(iconNormal: Theme.of(context).colorScheme.primary))
                          ]
                          )
                      )
                    ],
                  )
              ),
              AppBar(
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
                                hintText: FlutterI18n.translate(context, 'base.appBar.search'),
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
                    if(prefs.getBool('debug') ?? false) ...[
                      IconButton(
                        icon: const Icon(Icons.stadium_outlined),
                        tooltip: 'DEBUG PAGE',
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DebugDevPage())),
                      ),
                      IconButton(
                        icon: const Icon(Icons.plumbing),
                        tooltip: 'Test Activity',
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TestActivity())),
                      ),
                    ],
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
              ),
              Gap(14),
              AnimatedContainer(
                clipBehavior: Clip.antiAlias,
                width: MediaQuery.of(context).size.width - 100,
                height: open ? MediaQuery.of(context).size.height - 92 - 14: 0,
                duration: const Duration(seconds: 1),
                curve: Curves.fastOutSlowIn,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: const Color(0xff0c0c0e),
                ),
                child: ScrollConfiguration(
                    behavior: MyCustomScrollBehavior(),
                    child: FutureBuilder(
                        future: imagesList,
                        builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
                          Widget children;
                          if (snapshot.hasData) {
                            children = snapshot.data.length > 0 ? LayoutBuilder(
                              builder: (context, constraints) {
                                final crossAxisCount = (constraints.maxWidth / 180).floor();
                                return AlignedGridView.count(
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: snapshot.data.length,
                                  mainAxisSpacing: 5,
                                  crossAxisSpacing: 5,
                                  crossAxisCount: crossAxisCount,
                                  itemBuilder: (context, index) {
                                    ImageMeta imageMeta = snapshot.data.elementAt(index);
                                    return GestureDetector(
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ImageView(imageMeta: imageMeta))),
                                      child: AspectRatio(
                                          aspectRatio: imageMeta.size!.width / imageMeta.size!.height,
                                          child: Align(
                                              alignment: Alignment.bottomCenter,
                                              child: Stack(
                                                alignment: Alignment.topRight,
                                                children: [
                                                  ImageWidget(imageMeta, dontBlink: true),
                                                ],
                                              )
                                          )
                                      ),
                                    );
                                  },
                                );
                              }
                            ) : Text('Not found');
                          } else if(snapshot.hasError){
                            children = Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
                                  const SizedBox(height: 16),
                                  const Text('Something went wrong', style: TextStyle(fontSize: 18)),
                                  const SizedBox(height: 8),
                                  Expanded(child: SingleChildScrollView(child: SelectableText(snapshot.error.toString(), style: const TextStyle(color: Colors.grey)))),
                                ],
                              ),
                            );
                          } else {
                            children = Center(child: CircularProgressIndicator());
                          }
                          return children;
                        }
                    )
                ),
              ),
            ],
          );
        }
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

class DraggableAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget child;
  const DraggableAppBar({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return WindowTitleBarBox(
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: MoveWindow(child: Padding(padding: EdgeInsetsGeometry.all(3), child: child))),
            MinimizeWindowButton(),
            MaximizeWindowButton(),
            CloseWindowButton(),
          ]
      )
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}