import 'dart:io';

import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';

import '../../Utils.dart';
import '../../components/ImageInfo.dart';
import '../../utils/DataModel.dart';

import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;

class ImageView extends StatefulWidget{
  ImageMeta? imageMeta;
  ImageView({ Key? key, this.imageMeta}): super(key: key);

  @override
  _ImageViewState createState() => _ImageViewState();
}

class _ImageViewState extends State<ImageView> {
  //Text(widget.imageMeta!.fullPath)

  bool showOriginalSize = true;
  PhotoViewScaleStateController scaleStateController = PhotoViewScaleStateController();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const breakpoint = 600.0;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          title: Text(widget.imageMeta!.fileName),
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
                  String clean = cleanUpUrl(widget.imageMeta!.fullNetworkPath!);
                  http.Response res = await http.get(Uri.parse(clean));
                  if(res.statusCode == 200){
                    await f.writeAsBytes(res.bodyBytes);
                  }
                }
              }
          ) : const SizedBox.shrink(),
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
        onSelected: () {
          imageManager.toogleFavorite(widget.imageMeta!.fullPath, host: widget.imageMeta!.host);
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
          showInExplorer(widget.imageMeta!.fullPath);
        },
      ),
    ];

    final contextMenu = ContextMenu(
      entries: entries,
      padding: const EdgeInsets.all(8.0),
    );

    return InteractiveViewer(
      panEnabled: true,
      scaleFactor: 1000,
      minScale: 0.000001,
      maxScale: 10,
      onInteractionUpdate: (ScaleUpdateDetails details){  // get the scale from the ScaleUpdateDetails callback
        // setState(() {
        //   _scale = _transformationController.value.getMaxScaleOnAxis();
        // });
      },
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: Center(
            child: ContextMenuRegion(
                contextMenu: contextMenu,
                child: Image.file(
                  File(widget.imageMeta!.fullPath ?? widget.imageMeta!.tempFilePath),
                  gaplessPlayback: false,
                ),
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