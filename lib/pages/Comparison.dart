import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:image_compare_slider/image_compare_slider.dart';
import 'package:png_chunks_extract/png_chunks_extract.dart' as pngExtract;
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

import '../Utils.dart';
import '../utils/ImageManager.dart';

SliderDirection direction = SliderDirection.leftToRight;
Color dividerColor = Colors.white;
Color handleColor = Colors.white;
Color handleOutlineColor = Colors.white;
double dividerWidth = 2;
bool reactOnHover = false;
bool hideHandle = false;
double position = 0.5;
double handlePosition = 0.5;
double handleSizeHeight = 75;
double handleSizeWidth = 7.5;
bool handleFollowsP = false;
bool fillHandle = true;
double handleRadius = 10;
Color? itemOneColor;
Color? itemTwoColor;
BlendMode itemOneBlendMode = BlendMode.overlay;
BlendMode itemTwoBlendMode = BlendMode.darken;
Widget Function(Widget)? itemOneWrapper;
Widget Function(Widget)? itemTwoWrapper;

class Comparison extends StatefulWidget{
  const Comparison({ Key? key }): super(key: key);

  @override
  _ComparisonState createState() => _ComparisonState();
}

class _ComparisonState extends State<Comparison> {
  double _scale = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ImageList(path: 'K:\\pictures\\sd\\outputs\\img2img-images\\2023-08-10', seed: 857482875),
          Expanded(
            child: Stack(
              children: [
                InteractiveViewer(
                  panEnabled: true,
                  scaleFactor: 1000,
                  minScale: 0.1,
                  maxScale: 4,
                  constrained: false,
                  onInteractionUpdate: (ScaleUpdateDetails details){  // get the scale from the ScaleUpdateDetails callback
                    setState(() {
                      _scale = details.scale;
                    });
                  },
                  child: ImageCompareSlider(
                    itemOne: Image.file(
                      File('K:/pictures/sd/outputs/img2img-images/2024-01-30/00084-DPM++ 3M SDE-1624605927.png'),
                      colorBlendMode: itemOneBlendMode,
                      color: itemOneColor,
                    ),
                    itemTwo: Image.file(
                      File('K:/pictures/sd/outputs/img2img-images/2024-01-30/00085-DPM++ SDE Karras-1624605927.png'),
                      colorBlendMode: itemTwoBlendMode,
                      color: itemTwoColor,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Align(
                      alignment: Alignment.topCenter,
                      child: Text(_scale.toString(), style: TextStyle(fontSize: 10, color: Colors.white)),
                  ),
                ),
                Positioned(
                  child: Container(
                    color: Colors.black,
                    child: const Column(
                      children: [
                        Text('fsdf'),
                      ],
                    ),
                  )
                ),
              ],
            )
          )
        ],
      ),
    );
  }
}

class ImageList extends StatefulWidget {
  final String path;
  final int seed;

  const ImageList({ Key? key, required this.path, required this.seed }): super(key: key);

  @override
  _ImageListStateStateful createState() => _ImageListStateStateful();
}

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  // Override behavior methods and getters like dragDevices
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    // etc.
  };
}

Future<dynamic> _loadImages(String path) async {
  print('get');
  List<ImageParams> images = [];

  var dir = Directory(path);
  final List<FileSystemEntity> files = dir.listSync();
  for (final FileSystemEntity file in files) {
    final ex = p.extension(file.path);
    GenerationParams? gp;

    //This shit
    final fileBytes = await compute(readAsBytesSync, file.absolute.path);

    if(ex == '.png'){
      final trunk = pngExtract.extractChunks(fileBytes).where((e) => e["name"] == 'tEXt').toList(growable: false);
      Uint8List uint8List = Uint8List.fromList(trunk[0]['data']);
      String text = utf8.decode(uint8List);

      gp = parseSDParameters(text);
      if(gp != null){
      }
    }


    images.add(ImageParams(path: file.path, fileName: p.basename(file.path), hasExif: gp != null, generationParams: gp));

    // if (data.isEmpty) {
    //   images.add(ImageMeta(path: file.path, fileName: basename(file.path), hasExif: false, exif: {}, sampler: 'none', seed: 0));
    // } else {
    //   images.add(ImageMeta(path: file.path, fileName: basename(file.path), hasExif: true, exif: {}, sampler: 'none', seed: 0));
    // }
  }
  print('return');
  return images;
}

class _ImageListStateStateful extends State<ImageList>{
  bool loaded = false;

  late Future<dynamic> dataFuture;

  @override
  void initState() {
    super.initState();
    dataFuture = _loadImages(widget.path);
    //load();
  }

  final ScrollController controller = ScrollController();

  @override
  Widget build(BuildContext ctx) {
    return Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        height: 150,
        child: FutureBuilder(
          builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot){
            Widget children;
            if (snapshot.hasData) {
              print(snapshot.data.length);
              final filter = snapshot.data.where((e) => e.generationParams != null && e.generationParams.seed == widget.seed).toList();
              print(filter.length);
              children = ScrollConfiguration(
                  behavior: MyCustomScrollBehavior(),
                  child: ListView.builder(
                      itemCount: filter.length,
                      scrollDirection: Axis.horizontal,
                      controller: controller,
                      itemBuilder: (context, index) {
                        ImageParams im = filter[index];
                        return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: Colors.white10)
                            ),
                            child: Stack(
                              children: [
                                Image.file(File(im.path)),
                                Padding(
                                    padding: EdgeInsets.all(5),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          height: 10,
                                          width: 10,
                                          decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: im.hasExif
                                                  ? Colors.green
                                                  : Colors.red
                                          ),
                                        ),
                                        im.generationParams != null ? Text(im.generationParams!.sampler.toString(), style: const TextStyle(fontSize: 10, color: Colors.white)) : const SizedBox.shrink(),
                                        im.generationParams != null ? Text(im.generationParams!.denoisingStrength.toString(), style: const TextStyle(fontSize: 10, color: Colors.white)) : const SizedBox.shrink(),
                                        im.generationParams != null ? Text((im.generationParams!.seed).toString(), style: const TextStyle(fontSize: 10, color: Colors.white)) : const SizedBox.shrink()
                                        //{steps: 35, sampler: DPM adaptive, cfg_scale: 7, seed: 1624605927, size: 2567x1454, model_hash: a679b318bd, model: 0.7(bb95FurryMix_v100) + 0.3(crosskemonoFurryModel_crosskemono25), denoising_strength: 0.35, rng: NV, ti_hashes: "easynegative, version: 1.7.0}
                                      ],
                                    )
                                )
                              ],
                            )
                        );
                      }
                  )
              );
            } else if (snapshot.hasError) {
              print(snapshot.stackTrace);
              children = Column(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 60,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text('Error: ${snapshot.error}'),
                  ),
                ],
              );
            } else {
              children = const Column(
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text('Awaiting result...'),
                  ),
                ],
              );
            }
            return children;
          },
          future: dataFuture,
        )
    );
  }
}

extension RegExpExtension on RegExp {
  List<String> allMatchesWithSep(String input, [int start = 0]) {
    var result = <String>[];
    for (var match in allMatches(input, start)) {
      result.add(input.substring(start, match.start));
      result.add(match[0]!);
      start = match.end;
    }
    result.add(input.substring(start));
    return result;
  }
}

extension StringExtension on String {
  List<String> splitWithDelim(RegExp pattern) => pattern.allMatchesWithSep(this);
}