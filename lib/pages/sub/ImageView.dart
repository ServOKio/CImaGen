import 'dart:io';

import 'package:cimagen/modules/SauceNAO.dart';
import 'package:cimagen/pages/sub/BodySizeCalculation.dart';
import 'package:cimagen/pages/sub/PixelArtRebuilder.dart';
import 'package:cimagen/pages/sub/PromptAnalyzer.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:gap/gap.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

import '../../Utils.dart';
import '../../components/AppBar.dart';
import '../../components/ICCPreview.dart';
import '../../main.dart';
import 'DevicePreview.dart';
import '../../components/ImageInfo.dart';
import '../../utils/DataModel.dart';

import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import 'JointTaggerProject.dart';
import 'Publish.dart';

Future<Uint8List?> _readImageFile(ImageMeta imageMeta) async {
  Uint8List? fi;
  if(imageMeta.mine?.split('/')[1] == 'vnd.adobe.photoshop'){
    fi = imageMeta.fullImage;
  } else {
    try {
      String? pathToImage = imageMeta.fullPath ?? imageMeta.tempFilePath ?? imageMeta.cacheFilePath;
      if(pathToImage == null) return null;
      final Uint8List bytes = imageMeta.fullImage ?? await compute(readAsBytesSync, pathToImage);
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

class ImageView extends StatefulWidget{
  final ImageMeta imageMeta;
  const ImageView({ super.key, required this.imageMeta});

  @override
  _ImageViewState createState() => _ImageViewState();
}

class _ImageViewState extends State<ImageView> with SingleTickerProviderStateMixin {
  final TransformationController _transformationController = TransformationController();
  final GlobalKey _cK = GlobalKey();

  bool showOriginalSize = true;
  PhotoViewScaleStateController scaleStateController = PhotoViewScaleStateController();

  late final lotsOfData = _readImageFile(widget.imageMeta);
  final photoSender = Rx<double>(100);

  late AnimationController _animationController;
  Animation<Matrix4>? _animation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(() {
      _transformationController.value = _animation!.value;
      photoSender.value = _animation!.value.entry(0, 0) * 100;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
      final w = widget.imageMeta.size!.width / devicePixelRatio;
      final h = widget.imageMeta.size!.height / devicePixelRatio;

      final renderBox = _cK.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) return;

      final scale = renderBox.size.width > w && renderBox.size.height > h ? 1.0 : w > h
          ? renderBox.size.width / w
          : renderBox.size.height / h;

      setState(() {
        showOriginalSize = scale != 1;
      });

      _transformationController.value = Matrix4.identity()
        ..scale(scale, scale, 1.0)
        ..translate(
          renderBox.size.width / (2 * scale) - w / 2,
          renderBox.size.height / (2 * scale) - h / 2,
        );

      photoSender.value = _transformationController.value.entry(0, 0) * 100;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void animateZoom(double targetScale) {
    final Matrix4 begin = _transformationController.value.clone();

    final double currentScale = begin.entry(0, 0);
    final double scaleFactor = targetScale / currentScale;
    RenderBox? renderBox;
    if (_cK.currentContext?.findRenderObject() != null) {
      renderBox = _cK.currentContext!.findRenderObject() as RenderBox;
    }

    final Offset center = Offset(renderBox!.size.width / 2, renderBox.size.height / 2);
    final Offset scenePoint = _transformationController.toScene(center);

    final Matrix4 end = begin.clone()
      ..translateByDouble(scenePoint.dx, scenePoint.dy, 0, 1)
      ..scaleByDouble(scaleFactor, scaleFactor, 1, 1)
      ..translateByDouble(-scenePoint.dx, -scenePoint.dy, 0, 1);

    _animation = Matrix4Tween(
      begin: begin,
      end: end,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.forward(from: 0);
  }

  void animateToSize(bool full){

    if(full){
      final Matrix4 begin = _transformationController.value.clone();

      final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
      final w = widget.imageMeta.size!.width / devicePixelRatio;
      final h = widget.imageMeta.size!.height / devicePixelRatio;
      final renderBox = _cK.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) return;

      final scale = w > h
          ? renderBox.size.width / w
          : renderBox.size.height / h;

      final Matrix4 end = Matrix4.identity()
        ..scale(scale, scale, 1.0)
        ..translate(
          renderBox.size.width / (2 * scale) - w / 2,
          renderBox.size.height / (2 * scale) - h / 2,
        );

      _animation = Matrix4Tween(
        begin: begin,
        end: end,
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeInOut,
        ),
      );

      _animationController.forward(from: 0);
    } else {
      animateZoom(1);
    }
  }


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const breakpoint = 600.0;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: DraggableAppBar(
        child: Row(
          children: [
            Gap(7),
            IconButton(
                padding: EdgeInsetsGeometry.all(0),
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context)
            ),
            Gap(7),
            Expanded(child: Obx(()=>Text('${widget.imageMeta.fileName} ${photoSender.value.toStringAsFixed(0)}%', style: TextStyle(fontSize: 18)))),
            if(!widget.imageMeta.isLocal) IconButton(
                padding: EdgeInsetsGeometry.all(0),
                icon: const Icon(Icons.download),
                onPressed: () async {
                  dynamic appDownloadDir = await getDownloadsDirectory();
                  if(appDownloadDir != null) appDownloadDir = appDownloadDir.path;
                  String pa = p.join(appDownloadDir, widget.imageMeta.fileName);
                  File f = File(pa);
                  if(!f.existsSync()){
                    if(widget.imageMeta.tempFilePath != null){
                      File(widget.imageMeta.tempFilePath!).copy(pa);
                    } else {
                      String clean = cleanUpUrl(widget.imageMeta.fullNetworkPath!);
                      http.Response res = await http.get(Uri.parse(clean));
                      if(res.statusCode == 200){
                        await f.writeAsBytes(res.bodyBytes);
                      }
                    }
                  }
                }
            ),
            IconButton(
              padding: EdgeInsetsGeometry.all(0),
              icon: const Icon(Icons.devices_other),
                tooltip: 'Device preview',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DevicePreview(imageMeta: widget.imageMeta)))
            ),
            IconButton(
                padding: EdgeInsetsGeometry.all(0),
                icon: const Icon(Icons.accessibility),
                tooltip: 'Calculate body dimensions',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => BodySizeCalculation(imageMeta: widget.imageMeta)))
            ),
            IconButton(
                padding: EdgeInsetsGeometry.all(0),
                icon: const Icon(Icons.share),
                tooltip: 'Publish',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => Publish(imageMeta: widget.imageMeta)))
            ),
            IconButton(
                padding: EdgeInsetsGeometry.all(0),
                tooltip: 'Display size',
                icon: Icon(showOriginalSize ? Icons.width_full : Icons.fit_screen),
                onPressed: (){
                  setState(() {
                    showOriginalSize = !showOriginalSize;
                  });
                  animateToSize(showOriginalSize);
                }
            ),
            Gap(7)
          ],
        )
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
        label: Text(imageManager.favoritePaths.contains(widget.imageMeta.fullPath) ? 'UnLike': 'Like'),
        icon: Icon(imageManager.favoritePaths.contains(widget.imageMeta.fullPath) ? Icons.star : Icons.star_outline),
        onSelected: (_) => imageManager.toogleFavorite(widget.imageMeta.fullPath!, host: widget.imageMeta.host),
      ),
      const MenuDivider(),
      MenuItem.submenu(
        label: const Text('Send to comparison'),
        icon: const Icon(Icons.edit),
        items: [
          MenuItem(
            label: const Text('Go to viewer'),
            icon: const Icon(Icons.compare),
            onSelected: (_) {
              Navigator.pop(context);
              dataModel.jumpToTab(3);
            },
          ),
          const MenuDivider(),
          MenuItem(
            label: const Text('As main'),
            icon: const Icon(Icons.swipe_left),
            onSelected: (_) {
              dataModel.comparisonBlock.addImage(widget.imageMeta);
              dataModel.comparisonBlock.changeSelected(1, widget.imageMeta);
              // implement redo
            },
          ),
          MenuItem(
            label: const Text('As test'),
            icon: const Icon(Icons.swipe_right),
            onSelected: (_) {
              dataModel.comparisonBlock.addImage(widget.imageMeta);
              dataModel.comparisonBlock.changeSelected(2, widget.imageMeta);
            },
          ),
        ],
      ),
      if(widget.imageMeta.generationParams != null) MenuItem.submenu(
        label: const Text('View in timeline'),
        icon: const Icon(Icons.view_timeline_outlined),
        items: [
          if(widget.imageMeta.generationParams!.seed != null) MenuItem(
            label: const Text('by seed'),
            icon: const Icon(Icons.compare),
            onSelected: (_) {
              dataModel.timelineBlock.setSeed(widget.imageMeta.generationParams!.seed!);
              dataModel.jumpToTab(2);
            },
          ),
        ],
      ),
      const MenuDivider(),
      MenuItem.submenu(
        label: const Text('Utils...'),
        icon: const Icon(Icons.apps),
        items: [
          MenuItem(
            label: const Text('Make Lora'),
            icon: const Icon(Icons.auto_graph),
            onSelected: (_) => Navigator.push(context, MaterialPageRoute(builder: (context) => SauceNAO(imageMeta: widget.imageMeta))),
          ),
          MenuItem(
            label: const Text('Joint Tagger Project'),
            icon: const Icon(Icons.tag),
            onSelected: (_) => Navigator.push(context, MaterialPageRoute(builder: (context) => JointTaggerProject(imageMeta: widget.imageMeta))),
          ),
          MenuItem(
            label: const Text('SauceNAO'),
            icon: const Icon(Icons.find_in_page),
            onSelected: (_) => Navigator.push(context, MaterialPageRoute(builder: (context) => SauceNAO(imageMeta: widget.imageMeta))),
          ),
          MenuItem(
            label: const Text('View in ICC profile'),
            icon: const Icon(Icons.monitor),
            onSelected: (_) => Navigator.push(context, MaterialPageRoute(builder: (context) => ICCPreview(widget.imageMeta))),
          ),
          MenuItem(
            label: const Text('Pixel Art Rebuilder'),
            icon: const Icon(Icons.grid_on_sharp),
            onSelected: (_) => Navigator.push(context, MaterialPageRoute(builder: (context) => PixelArtRebuilder(widget.imageMeta))),
          ),
          if(prefs.getBool('debug') ?? false) MenuItem.submenu(
            label: const Text('Debug'),
            icon: const Icon(Icons.bug_report),
            items: [
              MenuItem(
                label: const Text('Print raw tags'),
                icon: const Icon(Icons.text_increase),
                onSelected: (_) => print(getRawTags(widget.imageMeta.generationParams!.positive!)),
              ),
            ],
          ),
        ],
      ),
      const MenuDivider(),
      MenuItem(
        label: const Text('Show in explorer'),
        icon: const Icon(Icons.compare),
        onSelected: (_) {
          showInExplorer(widget.imageMeta.fullPath!);
        },
      ),
    ];

    final contextMenu = ContextMenu(
      entries: entries,
      padding: const EdgeInsets.all(8.0),
    );

    double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

    return InteractiveViewer(
      key: _cK,
      transformationController: _transformationController,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      panEnabled: true,
      scaleFactor: 1000,
      minScale: 0.000001,
      constrained: false,
      maxScale: double.infinity,
      onInteractionUpdate: (ScaleUpdateDetails details) => photoSender.value = _transformationController.value.entry(0, 0) * 100,
      child: ContextMenuRegion(
          contextMenu: contextMenu,
          child: ['png', 'jpeg', 'jpg', 'gif', 'webp', 'bmp', 'wbmp'].contains(widget.imageMeta.fileTypeExtension) ? ContextMenuRegion(
            contextMenu: contextMenu,
            child: Hero(
                tag: widget.imageMeta.fileName,
                child: !widget.imageMeta.isLocal && widget.imageMeta.tempFilePath == null ?
                Image.memory(
                    widget.imageMeta.fullImage ?? widget.imageMeta.thumbnail!,
                    width: widget.imageMeta.size!.width / devicePixelRatio,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.none,
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
                    errorBuilder: (context, exception, stack) => Center(
                        child: Container(
                          constraints: BoxConstraints(
                              maxWidth: 310
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 60,
                              ),
                              SelectableText('Error: $exception')
                            ],
                          ),
                        )
                    )
                ) : Image.file(
                    File(widget.imageMeta.fullPath ?? widget.imageMeta.tempFilePath ?? 'e.png'),
                    width: widget.imageMeta.size!.width / devicePixelRatio,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.none,
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
                    errorBuilder: (context, exception, stack) => Center(
                        child: Container(
                          constraints: BoxConstraints(
                              maxWidth: 310
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 60,
                              ),
                              SelectableText('Error: $exception')
                            ],
                          ),
                        )
                    )
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
                    child: Container(
                      constraints: BoxConstraints(
                          maxWidth: 310
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 60,
                          ),
                          SelectableText('Error: ${snapshot.error}')
                        ],
                      ),
                    )
                );
              } else {
                children = const CircularProgressIndicator();
              }
              return children;
            }
        ),
      )
    );
  }

  Widget _buildMenu(){
    return Container(
      padding: const EdgeInsets.all(6),
      color: Theme.of(context).scaffoldBackgroundColor,
      width: 300,
      child: SingleChildScrollView(
        child: MyImageInfo(widget.imageMeta),
      ),
    );
  }
}