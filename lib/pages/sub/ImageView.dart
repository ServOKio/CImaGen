import 'dart:io';

import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/material.dart';

import '../../components/ImageInfo.dart';

class ImageView extends StatefulWidget{
  ImageMeta? imageMeta;
  ImageView({ Key? key, this.imageMeta}): super(key: key);

  @override
  _ImageViewState createState() => _ImageViewState();
}

class _ImageViewState extends State<ImageView> {
  //Text(widget.imageMeta!.fullPath)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          title: Text(widget.imageMeta!.fileName),
          backgroundColor: const Color(0xaa000000),
          elevation: 0,
          actions: []
      ),
      body: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: InteractiveViewer(
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
                      child: Image.file(File(widget.imageMeta!.fullPath))
                  ),
                ),
              )
            ),
            Container(
              padding: const EdgeInsets.all(6),
              color: Theme.of(context).scaffoldBackgroundColor,
              width: 300,
              child: SingleChildScrollView(
                child: MyImageInfo(widget.imageMeta),
              ),
            )
          ],
        )
      )
    );
  }
}