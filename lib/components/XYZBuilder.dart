import 'dart:collection';
import 'dart:io';

import 'package:cimagen/components/ImageInfo.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

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
  String? selected;

  HashMap<String, XYZVariant> list = HashMap();

  @override
  void initState(){
    super.initState();
    analyze();
  }

  Future<void> analyze() async {
    setState(() {
      loaded = false;
      // keys = [];
      // keysValues = [];
      // toTest = [];
    });

    list.clear();

    // Сначала ищем тупо все отличия и записываем в карту
    List<String> has = [];
    for (var i = 0; i < widget.images.length; i++) {
      ImageMeta main = widget.images[i];
      for (var i2 = 0; i2 < widget.images.length; i2++) {
        ImageMeta test = widget.images[i2];
        if(i != i2){
          List<Difference> d = findDifference(main, test);
          if(d.isNotEmpty){
            String dHash = getDifferencesHash(d);
            if(!list.containsKey(dHash)){
              // Если нет, ебашим новое
              List<List<String>> keysValues = [];
              for (var i3 = 0; i3 < d.length; i3++) {
                Difference diff = d[i3];
                keysValues.add([diff.oldValue.toString(), diff.newValue.toString()]);
              }
              list[dHash] = XYZVariant(dHash: dHash, keys: d.map((e) => e.key).toList(growable: false), count: 1, keysValues: keysValues, images: [main, test]);
              has.addAll(['$dHash-${main.keyup}', '$dHash-${test.keyup}']);
            } else if(!has.contains('$dHash-${test.keyup}')){
              list[dHash]!.count++;
              List<List<String>> keysValues = [];
              for (var i3 = 0; i3 < d.length; i3++) {
                Difference diff = d[i3];
                keysValues.add([diff.oldValue.toString(), diff.newValue.toString()]);
              }
              list[dHash]!.keysValues.addAll(keysValues);
              list[dHash]!.images.add(test);
              has.add('$dHash-${test.keyup}');
            }
          }
          // if(d.length == 2 && !two){
          //   two = true;
          //   dHash = getDifferencesHash(d);
          //   keys = d.map((e) => e.key).toList(growable: false);
          //   for (var i3 = 0; i3 < d.length; i3++) {
          //     Difference diff = d[i3];
          //     keysValues.add([diff.oldValue.toString(), diff.newValue.toString()]);
          //   }
          // } else {
          //   print('no');
          // }
          // if(d.length == 1 && !keys.contains(d[0].key)){
          //   keys.add(d[0].key);
          // }
        }
      }
    }

    print(list.length);

    // for (var i = 0; i < widget.images.length; i++) {
    //   ImageMeta main = widget.images[i];
    //   for (var i2 = 0; i2 < widget.images.length; i2++) {
    //     ImageMeta test = widget.images[i2];
    //     if(i != i2){
    //       List<Difference> d = findDifference(main, test);
    //       if(two && d.length == 2 && getDifferencesHash(d) == dHash && !has.contains(main.keyup)){
    //         toTest.add(main);
    //         has.add(main.keyup);
    //       } else if(!two && d.length == 1){
    //
    //       }
    //       // if(d.length == 1 && !keys.contains(d[0].key)){
    //       //   keys.add(d[0].key);
    //       // }
    //     }
    //   }
    // }

    setState(() {
      loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    AppBar appBar = AppBar(
        title: ShowUp(
          delay: 100,
          child: Text('XYZ plot - ${list.length}', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600, fontFamily: 'Montserrat')),
        ),
        backgroundColor: const Color(0xaa000000),
        elevation: 0,
        actions: []
    );

    XYZVariant? selectedXYZ = list[selected];

    List<dynamic>? firstValues;
    List<ImageMeta>? finalImages;
    double newHeight = 10;
    if(selectedXYZ != null){
      firstValues = selectedXYZ.images.where(selectedXYZ.keys.length == 1 ? (e) => true : (e) => e.generationParams!.toMap()[selectedXYZ.keys.first] == selectedXYZ.keysValues[0][0]).map((e) => e.generationParams!.toMap()[selectedXYZ.keys.last]).toList(growable: false);
      newHeight = (MediaQuery.of(context).size.height-appBar.preferredSize.height) / (firstValues.length + 1);
    }
    // List<ImageMeta> sorted = toTest.where((e) => e.generationParams!.toMap()[keys.first] == keysValues[0][1]).toList(growable: false)..sort((a, b) => firstValues.indexOf(a.generationParams!.toMap()[keys.last]) - firstValues.indexOf(b.generationParams!.toMap()[keys.last]));
    List<String> sortedKeys = list.keys.toList(growable: false);
    sortedKeys.sort((a, b) => list[a]!.keys.length.compareTo(list[b]!.keys.length));
    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: appBar,
        body: SafeArea(
            child: loaded ? Row(
              children: <Widget>[
                SizedBox(
                  width: 200,
                  child: ListView(
                    children: sortedKeys.map<Widget>((key)=> InkWell(
                      onTap: () {
                        setState(() {
                          selected = key;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(7),
                            color: selected == key ? Colors.blueGrey : Colors.black
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Keys: ${list[key]!.keys.join(', ')}'),
                            Text('Count: ${list[key]!.count}')
                          ],
                        ),
                      ),
                    )
                    ).toList(),
                  ),
                ),
                Expanded(
                  child: selected != null ? InteractiveViewer(
                    boundaryMargin: EdgeInsets.all(double.infinity),
                    panEnabled: true,
                    scaleFactor: 1000,
                    minScale: 0.000001,
                    maxScale: 100,
                    constrained: false,
                    child: SizedBox(
                        height: newHeight * (firstValues!.length + 1),
                        child: Center(
                          //child: Text(toTest.length.toString()),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Column(
                                    children: [
                                      Container(
                                        height: newHeight,
                                        color: Colors.white,
                                        child: AspectRatio(
                                            aspectRatio: selectedXYZ!.images.first.size!.aspectRatio(),
                                            child: Center(
                                                child: Text('test', style: TextStyle(color: Colors.black, fontSize: newHeight * 0.06))
                                            )
                                        )
                                      ),
                                      ...selectedXYZ.images.where(selectedXYZ.keys.length == 1 ? (e) => true : (e) => e.generationParams!.toMap()[selectedXYZ.keys.first] == selectedXYZ.keysValues[0][0]).map((e) => Container(
                                        height: newHeight,
                                        color: Colors.white,
                                        child: AspectRatio(
                                            aspectRatio: e.size!.aspectRatio(),
                                            child: Center(child: Text('${selectedXYZ.keys.last}: ${e.generationParams!.toMap()[selectedXYZ.keys.last]}', style: TextStyle(color: Colors.black, fontSize: newHeight * 0.06)))
                                        )
                                      ))
                                    ]
                                ),
                                Column(
                                    children: [
                                      Container(
                                        height: newHeight,
                                        color: Colors.white,
                                        child: AspectRatio(
                                            aspectRatio: selectedXYZ.images.first.size!.aspectRatio(),
                                            child: Center(child: Text(selectedXYZ.keys.length == 1 ? selectedXYZ.keys.first : selectedXYZ.keysValues[0][0], style: TextStyle(color: Colors.black, fontSize: newHeight * 0.06)))
                                        )
                                      ),
                                      ...selectedXYZ.images.where(selectedXYZ.keys.length == 1 ? (e) => true : (e) => e.generationParams!.toMap()[selectedXYZ.keys.first] == selectedXYZ.keysValues[0][0]).map((e) => SizedBox(
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
                                if(selectedXYZ.keys.length > 2) ...selectedXYZ.keys.slice(1).asMap().map((i, e) => MapEntry(i, Column(
                                    children: [
                                      Container(
                                          height: newHeight,
                                          color: Colors.white,
                                          child: AspectRatio(
                                              aspectRatio: selectedXYZ.images.first.size!.aspectRatio(),
                                              child: Center(child: Text(selectedXYZ.keysValues[i+1][1], style: TextStyle(color: Colors.black, fontSize: newHeight * 0.06)))
                                          )
                                      ),
                                      // ...selectedXYZ.images.where((e) => e.generationParams!.toMap()[selectedXYZ.keys.first] == selectedXYZ.keysValues[0][i]).map((e) => SizedBox(
                                      //     height: newHeight,
                                      //     child: AspectRatio(
                                      //         aspectRatio: e.size!.aspectRatio(),
                                      //         child: GestureDetector(
                                      //             onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ImageView(imageMeta: e))),
                                      //             child: Image.file(File(e.fullPath), gaplessPlayback: true)
                                      //         )
                                      //     )
                                      // ))
                                    ]
                                ))).values
                                // Column(
                                //     children: [Container(
                                //         height: newHeight,
                                //         color: Colors.white,
                                //         child: AspectRatio(
                                //             aspectRatio: toTest.first.size!.aspectRatio(),
                                //             child: Center(child: Text(keysValues[0][1], style: TextStyle(color: Colors.black, fontSize: newHeight * 0.06)))
                                //         )
                                //     ),
                                //       ...sorted.map((e) => SizedBox(
                                //         height: newHeight,
                                //         child: GestureDetector(
                                //             onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ImageView(imageMeta: e))),
                                //             child: Image.file(File(e.fullPath), gaplessPlayback: true)
                                //         )
                                //     ))]
                                // )
                              ],
                            )
                        )
                    ),
                  ) : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.grid_view, size: 50, color: Colors.white),
                        Gap(4),
                        Text('Too much >~<', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        Text('Select the desired grid to view', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                )
              ]
            ) : Center(
              child: CircularProgressIndicator(),
            )
        )
    );
  }
}

class XYZVariant {
  final String dHash;
  final List<String> keys;
  List<ImageMeta> images;
  int count;
  List<List<String>> keysValues;

  XYZVariant({
    required this.dHash,
    required this.keys,
    required this.count,
    required this.keysValues,
    required this.images
  });
}