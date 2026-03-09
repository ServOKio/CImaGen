import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:settings_ui/settings_ui.dart';

import 'package:image/image.dart' as img;

import '../../Utils.dart';
import '../../components/Animations.dart';
import '../../utils/ImageManager.dart';

Future<Uint8List?> _readImageFile(ImageMeta imageMeta) async {
  try {
    if (imageMeta.fullImage == null) {
      await imageMeta.makeFullImage();
    }
    return imageMeta.fullImage!;
  } on PathNotFoundException {
    throw 'We\'ll fix it later.';
  }
}

class PixelArtRebuilder extends StatefulWidget{
  final ImageMeta? imageMeta;
  const PixelArtRebuilder(this.imageMeta, {super.key});

  @override
  _PixelArtRebuilderState createState() => _PixelArtRebuilderState();
}

class _PixelArtRebuilderState extends State<PixelArtRebuilder> {
  final TransformationController _transformationController = TransformationController();
  late final lotsOfData = _readImageFile(widget.imageMeta!);
  int pixSizeX = 3;
  int pixSizeY = 3;
  int exportScale = 1;

  Uint8List? previewImage;
  bool generatingPreview = false;
  bool symmetric = true;


  Future<void> buildPreview() async {

    generatingPreview = true;
    setState(() {});

    previewImage = await buildPixelImage();

    generatingPreview = false;
    setState(() {});
  }

  Future<Uint8List> buildPixelImage() async {

    final bytes = await lotsOfData;
    img.Image original = img.decodeImage(bytes!)!;

    int newWidth  = original.width ~/ pixSizeX;
    int newHeight = original.height ~/ pixSizeY;

    img.Image small = img.Image(
      width: newWidth,
      height: newHeight,
    );

    for (int gx = 0; gx < newWidth; gx++) {
      for (int gy = 0; gy < newHeight; gy++) {

        int startX = gx * pixSizeX;
        int startY = gy * pixSizeY;

        int r = 0, g = 0, b = 0, count = 0;

        for (int x = startX; x < startX + pixSizeX; x++) {
          for (int y = startY; y < startY + pixSizeY; y++) {

            final p = original.getPixel(x, y);

            r += p.r.toInt();
            g += p.g.toInt();
            b += p.b.toInt();
            count++;
          }
        }

        r ~/= count;
        g ~/= count;
        b ~/= count;

        small.setPixelRgb(gx, gy, r, g, b);
      }
    }

    img.Image result = img.copyResize(
      small,
      width: small.width * exportScale,
      height: small.height * exportScale,
      interpolation: img.Interpolation.nearest,
    );

    return Uint8List.fromList(img.encodePng(result));
  }

  Future<void> buildExport() async {

    final png = await buildPixelImage();

    File f = File('W:\\${getRandomString(32)}.png');
    await f.writeAsBytes(png);
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
            child: Text('Pixel Art Rebuilder', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600, fontFamily: 'Montserrat')),
          ),
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
    return InteractiveViewer(
      transformationController: _transformationController,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      panEnabled: true,
      scaleFactor: 1000,
      minScale: 0.000001,
      maxScale: double.infinity,
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: Center(
            child: Stack(
              children: [
                Hero(
                  tag: widget.imageMeta!.fileName,
                  child: FutureBuilder(
                      future: lotsOfData,
                      builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
                        Widget children;
                        if (snapshot.hasData) {
                          children = Image.memory(
                            width: widget.imageMeta!.size!.width / devicePixelRatio,
                            snapshot.data,
                            gaplessPlayback: true
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
                ),
                IgnorePointer(
                  child: CustomPaint(
                    size: Size(
                      widget.imageMeta!.size!.width / devicePixelRatio,
                      widget.imageMeta!.size!.height / devicePixelRatio,
                    ),
                    painter: PixelGridPainter(
                      pixSizeX: pixSizeX,
                      pixSizeY: pixSizeY,
                      scale: 1 / devicePixelRatio,
                      imageWidth: widget.imageMeta!.size!.width.toInt(),
                      imageHeight: widget.imageMeta!.size!.height.toInt(),
                    ),
                  ),
                ),
              ],
            )
        ),
      ),
    );
  }

  Widget _buildMenu(){
    return Container(
      padding: const EdgeInsets.all(6),
      width: 420,
      child: SingleChildScrollView(
        child: Column(
            children: [
              if (previewImage != null || generatingPreview) Container(
                margin: const EdgeInsets.only(top: 8),
                width: 420,
                child: generatingPreview
                    ? const Center(child: CircularProgressIndicator())
                    :
                Image.memory(
                  previewImage!,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                ),
              ),
              SettingsList(
                darkTheme: SettingsThemeData(
                    leadingIconsColor: Theme.of(context).colorScheme.primary,
                    settingsListBackground: Colors.transparent,
                    titleTextColor: Theme.of(context).colorScheme.primary,
                    tileDescriptionTextColor: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                    settingsTileTextColor: Theme.of(context).textTheme.bodyMedium?.color
                ),
                shrinkWrap: true,
                platform: DevicePlatform.fuchsia,
                sections: [
                  SettingsSection(
                    title: Text('Grid Mapping'),
                    tiles:[
                      SettingsTile.switchTile(
                        leading: const Icon(Icons.crop_square_sharp),
                        title: Text('X = Y'),
                        onToggle: (v) {
                          setState(() {
                            symmetric = v;
                          });
                        }, initialValue: symmetric,
                      ),
                      SettingsTile(
                        leading: Icon(Icons.arrow_forward_rounded),
                        title: Text('X $pixSizeX'),
                        description: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Slider(
                              value: pixSizeX.toDouble(),
                              min: 1,
                              max: 100,
                              divisions: 99,
                              label: pixSizeX.toString(),
                              onChanged: (double v) {
                                setState(() {
                                  pixSizeX = v.toInt();
                                  if(symmetric) pixSizeY = v.toInt();
                                });
                              },
                              onChangeEnd: (v) => buildPreview(),
                            )
                          ],
                        ),
                      ),
                      SettingsTile(
                        enabled: !symmetric,
                        leading: Icon(Icons.arrow_downward_rounded),
                        title: Text('Y $pixSizeY'),
                        description: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Slider(
                              value: pixSizeY.toDouble(),
                              min: 1,
                              max: 100,
                              divisions: 99,
                              label: pixSizeY.toString(),
                              onChanged: (double v) {
                                setState(() {
                                  pixSizeY = v.toInt();
                                });
                              },
                              onChangeEnd: (v) => buildPreview(),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: Text('Export'),
                    tiles:[
                      SettingsTile(
                        leading: Icon(Icons.zoom_out_map),
                        title: Text('Magnification'),
                        description: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Slider(
                              value: exportScale.toDouble(),
                              min: 1,
                              max: 100,
                              divisions: 99,
                              label: '${exportScale}x',
                              onChanged: (double v) {
                                setState(() {
                                  exportScale = v.toInt();
                                });
                              },
                              onChangeEnd: (_) => buildPreview(),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Gap(7),
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
                    InfoBox(one: 'Rebuilded WxH', two: '${pixSizeX}x$pixSizeY', withGap: false),
                    InfoBox(one: 'Final WxH', two: '${(widget.imageMeta!.size!.width ~/ pixSizeX)*exportScale}x${(widget.imageMeta!.size!.height ~/ pixSizeY)*exportScale}', withGap: false),
                    InfoBox(one: 'Size', two: readableFileSize(widget.imageMeta!.fileSize ?? 0), withGap: false),
                  ],
                ),
              ),
              const Gap(7),
              ElevatedButton(
                  style: ButtonStyle(
                      foregroundColor: WidgetStateProperty.all<Color>(Theme.of(context).colorScheme.onPrimary),
                      backgroundColor: WidgetStateProperty.all<Color>(Theme.of(context).colorScheme.primary),
                      shape: WidgetStateProperty.all<RoundedRectangleBorder>(const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))))
                  ),
                  onPressed: () => buildExport(),
                  child: Text('Export', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Montserrat'))
              )
            ]
        ),
      ),
    );
  }
}

class InfoBox extends StatelessWidget{
  final String one;
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
                SelectableText(one, style: const TextStyle(fontSize: 12, color: Colors.white70)),
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

class PixelGridPainter extends CustomPainter {
  final int pixSizeX;
  final int pixSizeY;
  final double scale;
  final int imageWidth;
  final int imageHeight;

  PixelGridPainter({
    required this.pixSizeX,
    required this.pixSizeY,
    required this.scale,
    required this.imageWidth,
    required this.imageHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..strokeWidth = 1;

    // convert original pixels -> screen pixels
    double stepX = pixSizeX * scale;
    double stepY = pixSizeY * scale;

    for (double x = 0; x <= imageWidth * scale; x += stepX) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, imageHeight * scale),
        paint,
      );
    }

    for (double y = 0; y <= imageHeight * scale; y += stepY) {
      canvas.drawLine(
        Offset(0, y),
        Offset(imageWidth * scale, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PixelGridPainter oldDelegate) {
    return oldDelegate.pixSizeX != pixSizeX ||
        oldDelegate.pixSizeY != pixSizeY;
  }
}