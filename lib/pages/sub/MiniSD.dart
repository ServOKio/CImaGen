import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/material.dart';

class MiniSD extends StatefulWidget{
  ImageMeta? imageMeta;
  MiniSD({ Key? key, this.imageMeta}): super(key: key);

  @override
  _MiniSDState createState() => _MiniSDState();
}

class _MiniSDState extends State<MiniSD> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
            title: const Text('SD'),
            backgroundColor: const Color(0xaa000000),
            elevation: 0,
            actions: []
        ),
        body: SafeArea(
          child: Text(widget.imageMeta!.fullPath)
        )
    );
  }
}