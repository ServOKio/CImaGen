import 'dart:io';
import 'dart:ui';

import 'package:cimagen/utils/DataModel.dart';
import 'package:flutter/material.dart';
import 'package:image_compare_slider/image_compare_slider.dart';
import 'package:provider/provider.dart';

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
  final TransformationController _transformationController = TransformationController();
  GlobalKey stickyKey = GlobalKey();

  double x = 0.0;
  double y = 0.0;

  bool toBottom = false;

// fetches mouse pointer location
  void _updateLocation(PointerEvent details) {
    final keyContext = stickyKey.currentContext;
    if (keyContext != null) {
      final box = keyContext.findRenderObject() as RenderBox;
      final pos = box.localToGlobal(Offset.zero);

      bool t = details.position.dy < pos.dy + box.size.height / 2;
      if(t != toBottom){
        setState(() {
          toBottom = t;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataModel = Provider.of<DataModel>(context, listen: true);
    return Scaffold(
      body: Column(
        children: [
          ImageList(images: dataModel.comparisonBlock.getImages),
          Expanded(
            child: dataModel.comparisonBlock.oneSelected ? Stack(
              children: [
                MouseRegion(
                  key: stickyKey,
                  // onEnter: _incrementEnter,
                  onHover: _updateLocation,
                  // onExit: _incrementExit,
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    panEnabled: true,
                    scaleFactor: 1000,
                    minScale: 0.1,
                    maxScale: 4,
                    constrained: false,
                    onInteractionUpdate: (ScaleUpdateDetails details){  // get the scale from the ScaleUpdateDetails callback
                      setState(() {
                        _scale = _transformationController.value.getMaxScaleOnAxis();
                      });
                    },
                    child: ImageCompareSlider(
                      itemOne: dataModel.comparisonBlock.firstCache!,
                      itemTwo: dataModel.comparisonBlock.secondCache!,
                    ),
                  ),
                ),
                AnimatedAlign(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeInOut,
                    alignment: toBottom ? Alignment.bottomCenter : Alignment.topCenter,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          border: Border.all(
                            color: Colors.black.withOpacity(0.5),
                          ),
                          borderRadius: const BorderRadius.all(Radius.circular(20))
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('x${_scale.toStringAsFixed(2)}'),
                        ],
                      ),
                    )
                )
              ],
            ) : const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('First, you must select at least one image')
                ],
              ),
            )
          )
        ],
      ),
    );
  }
}

class ImageList extends StatefulWidget {
  final List<ImageMeta> images;

  const ImageList({ Key? key, required this.images }): super(key: key);

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

class _ImageListStateStateful extends State<ImageList>{
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    // dataFuture = _loadImages(widget.path);
    //load();
  }

  final ScrollController controller = ScrollController();

  @override
  Widget build(BuildContext ctx) {
    return Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        height: 150,
        child: ScrollConfiguration(
            behavior: MyCustomScrollBehavior(),
            child: ListView.builder(
                itemCount: widget.images.length,
                scrollDirection: Axis.horizontal,
                controller: controller,
                itemBuilder: (context, index) {
                  ImageMeta im = widget.images.elementAt(index);
                  return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: Colors.white10)
                      ),
                      child: Stack(
                        children: [
                          Image.file(File(im.fullPath)),
                          Padding(
                              padding: const EdgeInsets.all(5),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    height: 10,
                                    width: 10,
                                    decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: im.generationParams != null
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