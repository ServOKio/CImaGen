import 'dart:io';

import 'package:cimagen/components/CustomActionButton.dart';
import 'package:cimagen/main.dart';
import 'package:cimagen/modules/webUI/NNancy.dart';
import 'package:cimagen/pages/Timeline.dart';
import 'package:cimagen/utils/DataModel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:gap/gap.dart';
import 'package:image_compare_slider/image_compare_slider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/rendering.dart';

import '../Utils.dart';
import '../components/ImageInfo.dart';
import '../utils/Extra.dart';
import '../utils/ImageManager.dart';
import '../utils/NavigationService.dart';

import 'package:path/path.dart' as p;

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

int maxSize = 1280;

class Comparison extends StatefulWidget{
  const Comparison({ Key? key }): super(key: key);

  @override
  State<Comparison> createState() => _ComparisonState();
}

class _ComparisonState extends State<Comparison> {
  bool _snowJpeg = true;

  @override
  void initState(){
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appBarController!.setActions([
        CustomActionButton(
            getIcon: () => Icons.remove_red_eye,
            tooltip: 'Automatically use the last generated image as a test',
            onPress: (){
              NavigationService.navigatorKey.currentContext?.read<ImageManager>().toogleUseLastAsTest();
            },
            isActive: () => NavigationService.navigatorKey.currentContext?.read<ImageManager>().useLastAsTest
        ),
        CustomActionButton(getIcon: () => Icons.blur_linear, tooltip: 'Don\'t show .jp(e)+g', onPress: (){
          setState((){
            _snowJpeg = !_snowJpeg;
          });
        }, isActive: () => _snowJpeg),
        CustomActionButton(getIcon: () => Icons.image_search, tooltip: 'Show the difference', onPress: (){

        }, isActive: () => false)
      ]);
    });
  }

  @override
  void dispose(){
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataModel = Provider.of<DataModel>(context);
    bool most = dataModel.comparisonBlock.getImages.where((e) => e.size!.width < e.size!.height).length > dataModel.comparisonBlock.getImages.length;
    bool isScreenWide = most;
    return Scaffold(
      body: Flex(
        direction: isScreenWide ? Axis.horizontal : Axis.vertical,
        children: [
          ImageList(images: dataModel.comparisonBlock.getImages, showJpeg: _snowJpeg),
          const MainBlock()
        ],
      ),
    );
  }
}

class MainBlock extends StatefulWidget {
  const MainBlock({ Key? key }): super(key: key);

  @override
  _MainBlockState createState() => _MainBlockState();
}

class _MainBlockState extends State<MainBlock> {

  bool displayFull = true;

  @override
  Widget build(BuildContext context) {
    final dataModel = Provider.of<DataModel>(context);
    return Expanded(
        child: dataModel.comparisonBlock.oneSelected ? Stack(
          children: [
            const ViewBlock(),
            dataModel.comparisonBlock.firstSelected != null ? displayFull ? Align(
              alignment: Alignment.topLeft,
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(6),
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 300,
                  child: MyImageInfo(dataModel.comparisonBlock.firstSelected),
                ),
              ),
            ) : Positioned( //left
                top: 4,
                left: 4,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      border: Border.all(
                        color: Colors.black.withOpacity(0.5),
                      ),
                      borderRadius: const BorderRadius.all(Radius.circular(4))
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 6),
                  child: GetInfoOrShit(dataModel.comparisonBlock.firstSelected),
                )
            ) : const SizedBox.shrink(),
            dataModel.comparisonBlock.secondSelected != null ? displayFull ? Align(
              alignment: Alignment.topRight,
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(6),
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 300,
                  child: MyImageInfo(dataModel.comparisonBlock.secondSelected),
                ),
              ),
            ) : Positioned(
                top: 4,
                right: 4,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      border: Border.all(
                        color: Colors.black.withOpacity(0.5),
                      ),
                      borderRadius: const BorderRadius.all(Radius.circular(4))
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 6),
                  child: GetInfoOrShit(dataModel.comparisonBlock.secondSelected),
                )
            ) : const SizedBox.shrink()
          ],
        ) : const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.compare, size: 50, color: Colors.white),
              Gap(4),
              Text('What to compare?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              Text('First, select at least one image', style: TextStyle(color: Colors.grey)),
            ],
          ),
        )
    );
  }
}

class ViewBlock extends StatefulWidget {
  const ViewBlock({ Key? key }): super(key: key);

  @override
  State<ViewBlock> createState() => _ViewBlockState();
}

class _ViewBlockState extends State<ViewBlock> {
  GlobalKey stickyKey = GlobalKey();

  bool _showImageDifference = false;
  bool _asSplit = false;

  double _scale = 0;
  final TransformationController _transformationController = TransformationController();

  double x = 0.0;
  double y = 0.0;

  bool toBottom = false;

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
    final dataModel = Provider.of<DataModel>(context);

    final entries = <ContextMenuEntry>[
      MenuItem(
        label: 'Show as split',
        icon: Icons.splitscreen,
        onSelected: () {
          setState(() {
            _asSplit = !_asSplit;
          });
        },
      ),
      MenuItem(
        label: 'Show the visual difference',
        icon: Icons.image_search_rounded,
        onSelected: () {
          setState(() {
            _showImageDifference = !_showImageDifference;
          });
        },
      ),
      const MenuDivider(),
      MenuItem(
        label: 'Find difference ',
        icon: Icons.difference,
        onSelected: () {
          List<Difference>? difference;
          if(dataModel.comparisonBlock.bothHasGenerationParams) {
            difference = findDifference(dataModel.comparisonBlock.firstSelected as ImageMeta, dataModel.comparisonBlock.secondSelected);
          }
          bool hasDiff = difference != null && difference.isNotEmpty;

          if(hasDiff){
            Map<String, String> keysMap = {
              'cfgScale': 'cfgS',
              'size': 'w&h',
              'modelHash': 'mHash',
              'denoisingStrength': 'D.s.',
              'rng': 'RNG',
              'hiresSampler': 'hSampler',
              'hiresUpscale': 'hUpscale',
              'version': 'v'
            };

            showDialog<String>(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                icon: const Icon(Icons.remove_red_eye),
                iconColor: Colors.yellowAccent,
                title: const Text('The images have differences'),
                content: differenceBlock(difference!),
                  // difference!.map((ent){
                  //   return Padding(
                  //       padding: const EdgeInsets.only(bottom: 4),
                  //       child: ['positive', 'negative'].contains(ent.key) ?
                  //         TagBox(text: keysMap[ent.key] ?? ent.key) :
                  //         Container(
                  //           child: Row(
                  //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  //             children: [
                  //               Text(ent.oldValue),
                  //               Text(ent.key),
                  //               Text(ent.newValue)
                  //             ],
                  //           ),
                  //         )
                  //   );
                  // }).toList()
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'OK'),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          } else {
            showDialog<String>(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                icon: const Icon(Icons.question_mark),
                title: const Text('Seriously?'),
                content: const Text('The images have the same parameters'),
                actions: <Widget>[
                  TextButton(
                    onPressed: (){
                      Navigator.pop(context, 'Help');
                      NNancy.calculateTransformersCacheHash('F:/PC2/documents/TRANSFORMERS_CACHE');
                    },
                    child: const Text('Try to find the error'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'OK'),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        },
      ),
    ];

    final contextMenu = ContextMenu(
      entries: entries,
      padding: const EdgeInsets.all(8.0),
    );

    double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

    return Stack(
      children: [
        MouseRegion(
          key: stickyKey,
          onHover: _updateLocation,
          child: InteractiveViewer(
            boundaryMargin: const EdgeInsets.all(double.infinity),
            transformationController: _transformationController,
            panEnabled: true,
            scaleFactor: 1000,
            minScale: 0.000001,
            maxScale: 10,
            onInteractionUpdate: (ScaleUpdateDetails details){  // get the scale from the ScaleUpdateDetails callback
              setState(() {
                _scale = _transformationController.value.getMaxScaleOnAxis();
              });
            },
            child: SizedBox(
              child: Center(
                child: ContextMenuRegion(
                  contextMenu: contextMenu,
                  child: _asSplit ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.memory(dataModel.comparisonBlock.firstCache!, gaplessPlayback: true),
                        Image.memory(dataModel.comparisonBlock.secondCache!, gaplessPlayback: true),
                      ]
                  ) : _showImageDifference ? Stack(
                    children: [
                      Image.memory(dataModel.comparisonBlock.firstCache!, gaplessPlayback: true, color: Colors.grey, colorBlendMode: BlendMode.saturation),
                      BlendMask(
                        opacity: 1.0,
                        blendMode: BlendMode.difference,
                        child: Image.memory(dataModel.comparisonBlock.secondCache!, gaplessPlayback: true, color: Colors.grey, colorBlendMode: BlendMode.saturation),
                      ),
                    ],
                  ): ImageCompareSlider(
                      itemOne: Image.memory(dataModel.comparisonBlock.firstCache!, gaplessPlayback: true),
                      itemTwo: Image.memory(dataModel.comparisonBlock.secondCache!, gaplessPlayback: true),
                      dividerWidth: 1.5,
                      handleSize: const Size(0, 0),
                      handleRadius: const BorderRadius.all(Radius.circular(0))
                  ),
                ),
              ),
            ),
          ),
        ),
        //Samplers
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
        ),
      ],
    );
  }

  Widget differenceBlock(List<Difference> difference){
    return DataTable(
        dataRowMaxHeight: double.infinity,
        columns: const <DataColumn>[
          DataColumn(
            label: Text(
              'From',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Key',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'To',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
        rows: difference.map((ent){
          if(['positive', 'negative'].contains(ent.key)){
            Color c = ent.key == 'positive' ? Colors.green : Colors.redAccent;
            return DataRow(
                cells: [
                  DataCell(Container(
                      padding: const EdgeInsets.all(4.0),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: c.withAlpha(40),
                        border: Border.all(color: c, width: 1),
                        borderRadius: const BorderRadius.all(Radius.circular(5.0)),
                      ),
                      child: FractionallySizedBox(
                          widthFactor: 1.0,
                          child: SelectableText(ent.oldValue ?? '', style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 12))
                      )
                  )),
                  DataCell(SelectableText(ent.key, maxLines: 1, textAlign: TextAlign.center)),
                  DataCell(Container(
                      padding: const EdgeInsets.all(4.0),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: c.withAlpha(40),
                        border: Border.all(color: c, width: 1),
                        borderRadius: const BorderRadius.all(Radius.circular(5.0)),
                      ),
                      child: FractionallySizedBox(
                          widthFactor: 1.0,
                          child: SelectableText(ent.newValue ?? '', style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 12))
                      )
                  )),
                ]
            );
          }
          return DataRow(
              cells: [
                DataCell(SelectableText(ent.oldValue)),
                DataCell(SelectableText(ent.key, maxLines: 1, textAlign: TextAlign.center)),
                DataCell(SelectableText(ent.newValue)),
              ]
          );
        }).toList()
    );
  }
}

class GetInfoOrShit extends StatelessWidget {
  dynamic firstSelected;
  GetInfoOrShit(this.firstSelected, {super.key});

  @override
  Widget build(BuildContext context) {
    bool im = firstSelected.runtimeType == ImageMeta;
    if(im){
      ImageMeta i = firstSelected as ImageMeta;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if(i.generationParams!.sampler != null) i.generationParams?.sampler != null ? Text(i.generationParams!.sampler!) : const SizedBox.shrink(),
          Text(i.size.toString()),
          i.generationParams?.hiresSampler != null ? Text(i.generationParams?.hiresSampler ?? 'none') : const SizedBox.shrink(),
          i.generationParams?.hiresUpscale != null ? Text('x${i.generationParams!.hiresUpscale.toString()}') : const SizedBox.shrink(),
          i.generationParams?.seed != null ? Text(i.generationParams!.seed.toString()) : const SizedBox.shrink(),
        ],
      );
    } else {
      return Text(firstSelected as String);
    }
  }

}

class ImageList extends StatefulWidget {
  final List<ImageMeta> images;
  final bool showJpeg;

  const ImageList({ super.key, required this.images, required this.showJpeg});

  @override
  State<ImageList> createState() => _ImageListStateStateful();
}

class _ImageListStateStateful extends State<ImageList>{

  final ScrollController controller = ScrollController();

  @override
  void initState(){
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.animateTo(
        controller.position.maxScrollExtent,
        curve: Curves.easeOut,
        duration: const Duration(milliseconds: 300),
      );
    });
  }

  @override
  Widget build(BuildContext ctx){
    bool most = widget.images.where((e) => e.size!.width < e.size!.height).length > widget.images.length;
    bool isScreenWide = most;// MediaQuery.sizeOf(context).width >= maxSize;
    List<ImageMeta> fi = widget.showJpeg ? widget.images :  widget.images.where((e) => e.fileTypeExtension != 'jpeg').toList(growable: false);
    return Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        height: !isScreenWide ? 156 : null,
        width: isScreenWide ? 206 : null,
        child: ScrollConfiguration(
            behavior: MyCustomScrollBehavior(),
            child: ListView.builder(
                itemCount: fi.length,
                scrollDirection: isScreenWide ? Axis.vertical : Axis.horizontal,
                controller: controller,
                itemBuilder: (context, index) {
                  ImageMeta im = fi.elementAt(index);
                  final imageManager = Provider.of<ImageManager>(context);
                  final dataModel = Provider.of<DataModel>(context, listen: false);
                  final entries = <ContextMenuEntry>[
                    MenuItem(
                      label: 'As main',
                      value: 'comparison_as_main',
                      icon: Icons.swipe_left,
                      onSelected: () {
                        dataModel.comparisonBlock.changeSelected(0, im);
                        // implement redo
                      },
                    ),
                    MenuItem(
                      label: 'As test',
                      value: 'comparison_as_test',
                      icon: Icons.swipe_right,
                      onSelected: () {
                        dataModel.comparisonBlock.changeSelected(1, im);
                      },
                    ),
                    const MenuDivider(),
                    MenuItem(
                      label: imageManager.favoritePaths.contains(im.fullPath) ? 'UnLike': 'Like',
                      icon: imageManager.favoritePaths.contains(im.fullPath) ? Icons.star : Icons.star_outline,
                      onSelected: () {
                        imageManager.toogleFavorite(im.fullPath!, host: im.host);
                      },
                    ),
                    const MenuDivider(),
                    MenuItem(
                      label: 'View render tree',
                      icon: Icons.account_tree_sharp,
                      onSelected: () {
                        // implement copy
                      },
                    ),
                    // MenuItem.submenu(
                    //   label: 'Send to comparison',
                    //   icon: Icons.edit,
                    //   items: [
                    //     // MenuItem( // TODO I WANT
                    //     //   label: 'View only favorite',
                    //     //   value: 'comparison_view_favorite',
                    //     //   icon: Icons.compare,
                    //     //   onSelected: () {
                    //     //     if(sp.selectedCo == 0){
                    //     //       dataModel.comparisonBlock.addAllImages(imagesList.where((el) => imageManager.favoritePaths.contains(el.fullPath)).toList());
                    //     //     }
                    //     //     dataModel.jumpToTab(3);
                    //     //   },
                    //     // ),
                    //     const MenuDivider(),
                    //
                    //   ],
                    // ),
                    if(im.generationParams?.seed != null ) MenuItem.submenu(
                      label: 'View in timeline',
                      icon: Icons.view_timeline_outlined,
                      items: [
                        MenuItem(
                          label: 'by seed',
                          value: 'timeline_by_seed',
                          icon: Icons.compare,
                          onSelected: () {
                            dataModel.timelineBlock.setSeed(im.generationParams!.seed!);
                            dataModel.jumpToTab(2);
                          },
                        ),
                      ],
                    ),
                    const MenuDivider(),
                    MenuItem(
                      label: 'Show in explorer',
                      value: 'show_in_explorer',
                      icon: Icons.compare,
                      onSelected: () {
                        showInExplorer(im.fullPath!);
                      },
                    ),
                    MenuItem.submenu(
                      label: 'Copy...',
                      icon: Icons.copy,
                      items: [
                        if(im.generationParams?.seed != null) MenuItem(
                          label: 'Seed',
                          icon: Icons.abc,
                          onSelected: () async {
                            String seed = im.generationParams!.seed.toString();
                            Clipboard.setData(ClipboardData(text: seed)).then((value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Seed $seed copied'),
                            )));
                          },
                        ),
                        MenuItem(
                          label: 'Folder/file.name',
                          icon: Icons.arrow_forward,
                          onSelected: () {
                            Clipboard.setData(ClipboardData(text: '${File(im.fullPath!).parent}/${im.fileName}')).then((value) => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('Copied'),
                            )));
                          },
                        ),
                        MenuItem(
                          label: 'Favorite images to folder...',
                          icon: Icons.star,
                          onSelected: () async {
                            // imagesList.where((el) => imageManager.favoritePaths.contains(el.fullPath)
                            String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
                            if (selectedDirectory != null) {
                              Iterable<ImageMeta> l = widget.images.where((el) => imageManager.favoritePaths.contains(el.fullPath));
                              if(l.isNotEmpty){
                                int notID = notificationManager!.show(
                                    title: 'Copying files',
                                    description: 'Now we will copy ${l.length} files to\n$selectedDirectory',
                                    content: Container(
                                      margin: const EdgeInsets.only(top: 7),
                                      width: 100,
                                      child: const LinearProgressIndicator(),
                                    )
                                );
                                for(ImageMeta m in l){
                                  await File(m.fullPath!).copy(p.join(selectedDirectory, m.fileName));
                                }
                                notificationManager!.close(notID);
                              }
                            }
                          },
                        )
                      ],
                    ),
                  ];

                  final contextMenu = ContextMenu(
                    entries: entries,
                    padding: const EdgeInsets.all(8.0),
                  );
                  bool isMain = !isRaw(dataModel.comparisonBlock.firstSelected) && (dataModel.comparisonBlock.firstSelected as ImageMeta).keyup == im.keyup;
                  bool isTest = !isRaw(dataModel.comparisonBlock.secondSelected) && (dataModel.comparisonBlock.secondSelected as ImageMeta).keyup == im.keyup;
                  bool b = isMain && isTest;
                  return ContextMenuRegion(
                      contextMenu: contextMenu,
                      child: Container(
                          margin: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: Colors.white10)
                          ),
                          child: Stack(
                            children: [
                              AspectRatio(
                                aspectRatio: im.size!.width / im.size!.height,
                                child: im.isLocal ? im.thumbnail != null ? Image.memory(
                                    gaplessPlayback: true,
                                    im.thumbnail!
                                ) : Icon(Icons.error) : Image.network(im.networkThumbnail!),
                              ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                        colors: [
                                          Color.fromRGBO(0, 0, 0, 0.0),
                                          Color.fromRGBO(0, 0, 0, 0.4),
                                          Color.fromRGBO(0, 0, 0, 0.8)
                                        ],
                                        stops: [0, 0.2, 1.0],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter
                                    ),
                                  ),
                                  child: Padding(
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
                                          im.generationParams != null && im.generationParams!.denoisingStrength != null ? Text('${im.generationParams?.hiresUpscale != null ? '${im.generationParams!.hiresUpscale} ${im.generationParams!.hiresUpscaler ?? 'None (Lanczos)'}, ' : ''}${im.generationParams!.denoisingStrength}', style: const TextStyle(fontSize: 10, color: Colors.white)) : const SizedBox.shrink(),
                                          im.generationParams != null ? Row(
                                            children: [
                                              im.generationParams!.denoisingStrength != null && im.generationParams?.hiresUpscale != null ? Container(
                                                padding: const EdgeInsets.only(left: 2, right: 2, bottom: 1),
                                                decoration: BoxDecoration(
                                                    borderRadius: const BorderRadius.all(Radius.circular(2)),
                                                    color: (im.generationParams?.hiresSampler != null ? Color(0xffa69955) : Color(0xff5f55a6)).withAlpha(180)
                                                ),
                                                child: Text('Hi-Res', style: TextStyle(color: im.generationParams?.hiresSampler != null ? Color(0xfff5e7c4) : Color(0xffc8c4f5), fontSize: 8)),
                                              ) : const SizedBox.shrink(),
                                              im.generationParams!.denoisingStrength != null && im.generationParams?.hiresUpscale != null ? const Gap(3) : const SizedBox.shrink(),
                                              Text(im.generationParams!.size.toString(), style: const TextStyle(fontSize: 10, color: Colors.white))
                                            ],
                                          ) : const SizedBox.shrink(),
                                          Row(
                                            children: [
                                              Text(im.fileName.split('-').first, style: const TextStyle(fontSize: 10, color: Colors.white)),
                                              const Gap(4),
                                              im.fileTypeExtension == 'jpeg' ? Container(
                                                padding: const EdgeInsets.only(left: 2, right: 2, bottom: 1),
                                                decoration: BoxDecoration(
                                                    borderRadius: const BorderRadius.all(Radius.circular(2)),
                                                    color: const Color(0xff08272b).withOpacity(0.7)
                                                ),
                                                child: const Text('JPEG', style: TextStyle(color: Color(0xffd4ecdf), fontSize: 10)),
                                              ) : const SizedBox.shrink()
                                            ],
                                          ),
                                          //im.generationParams != null ? Text((im.generationParams!.seed).toString(), style: const TextStyle(fontSize: 10, color: Colors.white)) : const SizedBox.shrink()
                                          //{steps: 35, sampler: DPM adaptive, cfg_scale: 7, seed: 1624605927, size: 2567x1454, model_hash: a679b318bd, model: 0.7(bb95FurryMix_v100) + 0.3(crosskemonoFurryModel_crosskemono25), denoising_strength: 0.35, rng: NV, ti_hashes: "easynegative, version: 1.7.0}
                                        ],
                                      )
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                  child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: (){
                                          dataModel.comparisonBlock.changeSelected(1, im);
                                        },
                                      )
                                  )
                              ),
                              b ? Positioned(
                                left: 4,
                                top: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  decoration: const BoxDecoration(
                                      borderRadius: BorderRadius.all(Radius.circular(2)),
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: <Color>[
                                        Color(0xffff6a00),
                                        Color(0xff00adef)
                                      ],
                                    ),
                                  ),
                                  child: const Text('M & T', style: TextStyle(color: Colors.white, fontSize: 9)),
                                ),
                              ) : isMain ? Positioned(
                                left: 4,
                                top: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  decoration: const BoxDecoration(
                                      borderRadius: BorderRadius.all(Radius.circular(2)),
                                      color: Color(0xffff6a00)
                                  ),
                                  child: const Text('Main', style: TextStyle(color: Colors.white, fontSize: 9)),
                                ),
                              ) : isTest ? Positioned(
                                left: 4,
                                top: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  decoration: const BoxDecoration(
                                      borderRadius: BorderRadius.all(Radius.circular(2)),
                                      color: Color(0xff00adef)
                                  ),
                                  child: const Text('Test', style: TextStyle(color: Colors.white, fontSize: 9)),
                                ),
                              ) : const SizedBox.shrink(),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: AnimatedScale(
                                  scale: imageManager
                                      .favoritePaths
                                      .contains(im.fullPath)
                                      ? 1
                                      : 0,
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.ease,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(3),
                                    child: Icon(Icons.star, size: 10, color: Theme.of(context).colorScheme.onSecondary),
                                  ),
                                ),
                              )
                            ],
                          )
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

class BlendMask extends SingleChildRenderObjectWidget {
  final BlendMode blendMode;
  final double opacity;

  const BlendMask({
    required this.blendMode,
    this.opacity = 1.0,
    super.key,
    super.child,
  });

  @override
  RenderObject createRenderObject(context) {
    return RenderBlendMask(blendMode, opacity);
  }

  @override
  void updateRenderObject(BuildContext context, RenderBlendMask renderObject) {
    renderObject.blendMode = blendMode;
    renderObject.opacity = opacity;
  }
}

class RenderBlendMask extends RenderProxyBox {
  BlendMode blendMode;
  double opacity;

  RenderBlendMask(this.blendMode, this.opacity);

  @override
  void paint(context, offset) {
    // Create a new layer and specify the blend mode and opacity to composite it with:
    context.canvas.saveLayer(
      offset & size,
      Paint()
        ..blendMode = blendMode
        ..color = Color.fromARGB((opacity * 255).round(), 255, 255, 255),
    );

    super.paint(context, offset);

    // Composite the layer back into the canvas using the blendmode:
    context.canvas.restore();
  }
}