import 'dart:io';

import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/material.dart';

import '../modules/Animations.dart';
import '../pages/Timeline.dart';
import '../pages/sub/ImageView.dart';

class XYZBuilder extends StatefulWidget{
  final List<ImageMeta> images;

  const XYZBuilder({ super.key, required this.images});

  @override
  State<XYZBuilder> createState() => _XYZBuilderState();
}

class _XYZBuilderState extends State<XYZBuilder> {
  bool loaded = false;
  List<String> keys = [];
  List<List<String>> keysValues = [];
  List<ImageMeta> toTest = [];

  bool two = false;
  String dHash = '';

  @override
  void initState(){
    super.initState();
    analyze();
  }

  Future<void> analyze() async {
    setState(() {
      loaded = false;
      keys = [];
      keysValues = [];
      toTest = [];
    });

    for (var i = 0; i < widget.images.length; i++) {
      ImageMeta main = widget.images[i];
      for (var i2 = 0; i2 < widget.images.length; i2++) {
        ImageMeta test = widget.images[i2];
        if(i != i2){
          List<Difference> d = findDifference(main, test);
          if(d.length == 2 && !two){
            two = true;
            dHash = getDifferencesHash(d);
            keys = d.map((e) => e.key).toList(growable: false);
            for (var i3 = 0; i3 < d.length; i3++) {
              Difference diff = d[i3];
              keysValues.add([diff.oldValue.toString(), diff.newValue.toString()]);
            }
          }
          // if(d.length == 1 && !keys.contains(d[0].key)){
          //   keys.add(d[0].key);
          // }
        }
      }
    }

    print(two);
    
    List<String> has = [];

    for (var i = 0; i < widget.images.length; i++) {
      ImageMeta main = widget.images[i];
      for (var i2 = 0; i2 < widget.images.length; i2++) {
        ImageMeta test = widget.images[i2];
        if(i != i2){
          List<Difference> d = findDifference(main, test);
          if(two && d.length == 2 && getDifferencesHash(d) == dHash && !has.contains(main.keyup)){
            toTest.add(main);
            has.add(main.keyup);
          } else if(!two && d.length == 1){

          }
          // if(d.length == 1 && !keys.contains(d[0].key)){
          //   keys.add(d[0].key);
          // }
        }
      }
    }

    print(toTest.length);
    print(keys);
    print(keysValues);

    setState(() {
      loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    AppBar appBar = AppBar(
        title: ShowUp(
          delay: 100,
          child: Text('XYZ plot - ${keys.join(', ')}', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600, fontFamily: 'Montserrat')),
        ),
        backgroundColor: const Color(0xaa000000),
        elevation: 0,
        actions: []
    );
    List<dynamic> firstValues = toTest.where((e) => e.generationParams!.toMap()[keys.first] == keysValues[0][0]).map((e) => e.generationParams!.toMap()[keys.last]).toList(growable: false);
    List<ImageMeta> sorted = toTest.where((e) => e.generationParams!.toMap()[keys.first] == keysValues[0][1]).toList(growable: false)..sort((a, b) => firstValues.indexOf(a.generationParams!.toMap()[keys.last]) - firstValues.indexOf(b.generationParams!.toMap()[keys.last]));
    double newHeight = (MediaQuery.of(context).size.height-appBar.preferredSize.height) / (firstValues.length + 1);
    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: appBar,
        body: SafeArea(
            child: loaded ? keys.isNotEmpty ? InteractiveViewer(
            panEnabled: true,
            scaleFactor: 1000,
            minScale: 0.000001,
            maxScale: 100,
            constrained: false,
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              height: newHeight * (firstValues.length + 1),
              child: Center(
                //child: Text(toTest.length.toString()),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      children: [Container(
                          height: newHeight,
                          color: Colors.white,
                          child: AspectRatio(
                              aspectRatio: toTest.first.size!.aspectRatio(),
                              child: Center(child: Text('', style: TextStyle(color: Colors.black, fontSize: newHeight * 0.06)))
                          )
                      ),...toTest.where((e) => e.generationParams!.toMap()[keys.first] == keysValues[0][0]).map((e) => Container(
                          height: newHeight,
                          color: Colors.white,
                          child: AspectRatio(
                              aspectRatio: e.size!.aspectRatio(),
                              child: Center(child: Text('${keys.last}: ${e.generationParams!.toMap()[keys.last]}', style: TextStyle(color: Colors.black, fontSize: newHeight * 0.06)))
                          )
                      ))]
                    ),
                    Column(
                        children: [Container(
                            height: newHeight,
                            color: Colors.white,
                            child: AspectRatio(
                                aspectRatio: toTest.first.size!.aspectRatio(),
                                child: Center(child: Text(keysValues[0][0], style: TextStyle(color: Colors.black, fontSize: newHeight * 0.06)))
                            )
                        ),...toTest.where((e) => e.generationParams!.toMap()[keys.first] == keysValues[0][0]).map((e) => SizedBox(
                            height: newHeight,
                            child: AspectRatio(
                                aspectRatio: e.size!.aspectRatio(),
                                child: GestureDetector(
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ImageView(imageMeta: e))),
                                  child: Image.file(File(e.fullPath), gaplessPlayback: true)
                                )
                            )
                        ))]
                    ),
                    Column(
                        children: [Container(
                            height: newHeight,
                            color: Colors.white,
                            child: AspectRatio(
                                aspectRatio: toTest.first.size!.aspectRatio(),
                                child: Center(child: Text(keysValues[0][1], style: TextStyle(color: Colors.black, fontSize: newHeight * 0.06)))
                            )
                        ),...sorted.map((e) => SizedBox(
                            height: newHeight,
                            child: GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ImageView(imageMeta: e))),
                                child: Image.file(File(e.fullPath), gaplessPlayback: true)
                            )
                        ))]
                    )
                  ],
                )
              )
            ),
          ) : Text('No data') : CircularProgressIndicator()
        )
    );
  }
}