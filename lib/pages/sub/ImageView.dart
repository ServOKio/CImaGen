import 'dart:io';

import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';

import '../../Utils.dart';
import '../../components/DevicePreview.dart';
import '../../components/ImageInfo.dart';
import '../../utils/DataModel.dart';

import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

Future<Uint8List?> _readImageFile(String? imagePath) async {
  if(imagePath == null) return null;
  Uint8List? fi;
  try {
    final Uint8List bytes = await compute(readAsBytesSync, imagePath);
    img.Image? image = await compute(img.decodeImage, bytes);
    if(image != null){
      return img.encodePng(image);
    }
  } on PathNotFoundException catch (e){
    throw 'We\'ll fix it later.'; // TODO
  }
  return fi;
}

class ImageView extends StatefulWidget{
  final ImageMeta? imageMeta;
  const ImageView({ super.key, this.imageMeta});

  @override
  _ImageViewState createState() => _ImageViewState();
}

class _ImageViewState extends State<ImageView> {
  final TransformationController _transformationController = TransformationController();

  bool showOriginalSize = true;
  PhotoViewScaleStateController scaleStateController = PhotoViewScaleStateController();

  late final lotsOfData = _readImageFile(widget.imageMeta!.fullPath ?? widget.imageMeta!.tempFilePath ?? widget.imageMeta!.cacheFilePath);
  final photoSender = Rx<String>('1.00');

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const breakpoint = 600.0;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          title: Obx(()=>Text('${widget.imageMeta!.fileName} x${photoSender.value}')),
          backgroundColor: const Color(0xaa000000),
          elevation: 0,
        actions: [
          !widget.imageMeta!.isLocal ? IconButton(
              icon: const Icon(Icons.download),
              onPressed: () async {
                dynamic appDownloadDir = await getDownloadsDirectory();
                if(appDownloadDir != null) appDownloadDir = appDownloadDir.path;
                String pa = p.join(appDownloadDir, '${widget.imageMeta?.fileName}');
                File f = File(pa);
                if(!f.existsSync()){
                  if(widget.imageMeta?.tempFilePath != null){
                    File(widget.imageMeta!.tempFilePath!).copy(pa);
                  } else {
                    String clean = cleanUpUrl(widget.imageMeta!.fullNetworkPath!);
                    http.Response res = await http.get(Uri.parse(clean));
                    if(res.statusCode == 200){
                      await f.writeAsBytes(res.bodyBytes);
                    }
                  }
                }
              }
          ) : const SizedBox.shrink(),
          IconButton(
              icon: const Icon(Icons.devices_other),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DevicePreview(imageMeta: widget.imageMeta!)))
          ),
          IconButton(
              icon: Icon(
                showOriginalSize ? Icons.photo_size_select_large_rounded : Icons.photo_size_select_actual_rounded,
              ),
              onPressed: (){
                setState(() {
                  showOriginalSize = !showOriginalSize;
                  scaleStateController.scaleState = showOriginalSize ? PhotoViewScaleState.originalSize : PhotoViewScaleState.initial;
                });
              }
          )
        ],
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
    final imageManager = Provider.of<ImageManager>(context, listen: false);
    final dataModel = Provider.of<DataModel>(context, listen: false);
    final entries = <ContextMenuEntry>[
      MenuItem(
        label: imageManager.favoritePaths.contains(widget.imageMeta?.fullPath) ? 'UnLike': 'Like',
        icon: imageManager.favoritePaths.contains(widget.imageMeta?.fullPath) ? Icons.star : Icons.star_outline,
        onSelected: () => imageManager.toogleFavorite(widget.imageMeta!.fullPath!, host: widget.imageMeta!.host),
      ),
      const MenuDivider(),
      MenuItem(
        label: 'View render tree',
        icon: Icons.account_tree_sharp,
        onSelected: () {
          // TODO
        },
      ),
      MenuItem.submenu(
        label: 'Send to comparison',
        icon: Icons.edit,
        items: [
          MenuItem(
            label: 'Go to viewer',
            value: 'comparison_view',
            icon: Icons.compare,
            onSelected: () {
              dataModel.jumpToTab(3);
            },
          ),
          const MenuDivider(),
          MenuItem(
            label: 'As main',
            value: 'comparison_as_main',
            icon: Icons.swipe_left,
            onSelected: () {
              dataModel.comparisonBlock.addImage(widget.imageMeta!);
              dataModel.comparisonBlock.changeSelected(0, widget.imageMeta);
              // implement redo
            },
          ),
          MenuItem(
            label: 'As test',
            value: 'comparison_as_test',
            icon: Icons.swipe_right,
            onSelected: () {
              dataModel.comparisonBlock.addImage(widget.imageMeta!);
              dataModel.comparisonBlock.changeSelected(1, widget.imageMeta);
            },
          ),
        ],
      ),
      // MenuItem.submenu(
      //   label: 'View in timeline',
      //   icon: Icons.view_timeline_outlined,
      //   items: [
      //     MenuItem(
      //       label: 'by seed',
      //       value: 'timeline_by_seed',
      //       icon: Icons.compare,
      //       onSelected: () {
      //         dataModel.timelineBlock.setSeed(widget.imageMeta!.generationParams?.seed);
      //         dataModel.jumpToTab(2);
      //       },
      //     ),
      //   ],
      // ),
      const MenuDivider(),
      // MenuItem(
      //   label: 'Send to MiniSD',
      //   value: 'send_to_minisd',
      //   icon: Icons.web_rounded,
      //   onSelected: () {
      //     Navigator.push(context, MaterialPageRoute(builder: (context) => MiniSD(imageMeta: imageMeta)));
      //     // implement redo
      //   },
      // ),
      // const MenuDivider(),
      MenuItem(
        label: 'Show in explorer',
        value: 'show_in_explorer',
        icon: Icons.compare,
        onSelected: () {
          showInExplorer(widget.imageMeta!.fullPath!);
        },
      ),
    ];

    final contextMenu = ContextMenu(
      entries: entries,
      padding: const EdgeInsets.all(8.0),
    );

    double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

    return InteractiveViewer(
      transformationController: _transformationController,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      panEnabled: true,
      scaleFactor: 1000,
      minScale: 0.000001,
      maxScale: double.infinity,
      onInteractionUpdate: (ScaleUpdateDetails details) => photoSender.value = _transformationController.value.getMaxScaleOnAxis().toStringAsFixed(2),
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: Center(
            child: ['png', 'jpeg', 'gif', 'webp', 'bmp', 'wbmp'].contains(widget.imageMeta!.fileTypeExtension) ? ContextMenuRegion(
                contextMenu: contextMenu,
                child: Hero(tag: widget.imageMeta!.fileName, child: Image.file(
                  width: widget.imageMeta!.size!.width / devicePixelRatio,
                  File(widget.imageMeta!.fullPath ?? widget.imageMeta!.tempFilePath ?? widget.imageMeta!.cacheFilePath ?? 'e.png'),
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
                )
            )) : FutureBuilder(
              future: lotsOfData,
              builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
                Widget children;
                if (snapshot.hasData) {
                  children = ContextMenuRegion(
                    contextMenu: contextMenu,
                    child: Image.memory(snapshot.data, gaplessPlayback: true)
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
            )
        ),
      ),
    );
  }

  Widget _buildMenu(){
    return Container(
      padding: const EdgeInsets.all(6),
      color: Theme.of(context).scaffoldBackgroundColor,
      width: 300,
      child: SingleChildScrollView(
        child: MyImageInfo(widget.imageMeta!),
      ),
    );
  }
}