import 'dart:io';

import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';

import '../../Utils.dart';
import '../../components/ImageInfo.dart';
import '../../utils/DataModel.dart';

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

class Publish extends StatefulWidget{
  final ImageMeta? imageMeta;
  const Publish({ super.key, this.imageMeta});

  @override
  _PublishState createState() => _PublishState();
}

class _PublishState extends State<Publish> {
  final TransformationController _transformationController = TransformationController();

  bool showOriginalSize = true;
  PhotoViewScaleStateController scaleStateController = PhotoViewScaleStateController();

  late final lotsOfData = _readImageFile(widget.imageMeta!.fullPath ?? widget.imageMeta!.tempFilePath ?? widget.imageMeta!.cacheFilePath);

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
            child: ['png', 'jpeg', 'gif', 'webp', 'bmp', 'wbmp'].contains(widget.imageMeta!.fileTypeExtension) ? Hero(
              tag: widget.imageMeta!.fileName,
              child: Stack(
                children: [
                  Image.file(
                    File(widget.imageMeta!.fullPath ?? widget.imageMeta!.tempFilePath ?? widget.imageMeta!.cacheFilePath ?? 'e.png'),
                    width: widget.imageMeta!.size!.width / devicePixelRatio,
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
                  ),
                  Positioned(
                    bottom: 14,
                    right: 14,
                    width: 120,
                    child: Opacity(opacity: 0.5, child: Image.file(File('F:\\PC2\\documents\\React\\github\\ServOKio-App\\public\\assets\\icons\\1920.png'))),
                  )
                ],
              )
            ) : FutureBuilder(
                future: lotsOfData,
                builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
                  Widget children;
                  if (snapshot.hasData) {
                    children = Image.memory(snapshot.data, gaplessPlayback: true);
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
      width: 300,
      child: Column(
          children: [
            ExpansionTile(
              initiallyExpanded: false, //gp == null && im.specific?['comfUINodes'] == null,
              tilePadding: EdgeInsets.zero,
              title:  Text('Watermark', style: TextStyle(color: Colors.deepPurple.shade50, fontWeight: FontWeight.w600, fontSize: 18)),
              children: <Widget>[

              ],
            )
          ]
      ),
    );
  }
}