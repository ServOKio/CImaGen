import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:icc_parser/icc_parser.dart';
import '../Utils.dart';
import '../modules/Animations.dart';

import 'package:image/image.dart' as img;

class TestActity extends StatefulWidget{
  const TestActity({ super.key });

  @override
  State<TestActity> createState() => _TestActityState();
}

class _TestActityState extends State<TestActity> {
  bool loaded = false;
  Uint8List? bytes;
  String path = 'F:\\PC2\\РабСто\\тестировать\\6543949048.jpg';
  String icc_path = 'C:\\Windows\\System32\\spool\\drivers\\color\\CN_PRO-200_S1_PhotoPaperPlusGlossyIIA.icc';

  Future<void> rebuild() async {
    setState(() {
      loaded = false;
      bytes = null;
    });

    img.Image? data;
    try {
      final Uint8List bytes = await compute(readAsBytesSync, path);
      data = await compute(img.decodeImage, bytes);
    } on PathNotFoundException catch (e){
      throw 'We\'ll fix it later.'; // TODO
    }
    if(data != null){
      img.Image secondImage = img.Image(width: data.width, height: data.height);

      final cmm = ColorProfileCmm();
      final bytes1 = ByteData.view(File(icc_path).readAsBytesSync().buffer);
      final stream = DataStream(data: bytes1, offset: 0, length: bytes1.lengthInBytes);
      final profile = ColorProfile.fromBytes(stream);
      print('Loading from $icc_path');
      final finalTransformations = cmm.buildTransformations([ColorProfileTransform.create(
        profile: profile,
        isInput: true,
        intent: ColorProfileRenderingIntent.icRelativeColorimetric,
        interpolation: ColorProfileInterpolation.tetrahedral,
        lutType: ColorProfileTransformLutType.color,
        useD2BTags: true,
      )]);
      print("Got transformations: $finalTransformations");

      final range = data.clone().getRange(0, 0, data.width, data.height);
      while (range.moveNext()) {

        final pixel = range.current;
        List<double> cmyk = rgb2cmyk(pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt());

        final rgb = cmm.apply(finalTransformations, Float64List.fromList(cmyk)).map((e) => (e * 255).round().clamp(0, 255)).toList();

        secondImage.setPixel(pixel.x, pixel.y, img.ColorUint8.rgb(rgb[0], rgb[1], rgb[2]));
      }
      setState(() {
        loaded = true;
        bytes = img.encodePng(secondImage);
      });
    }
  }

  void printColor(List<double> color) {
    print(color.map((e) => (e * 255).round().clamp(0, 255)).toList());
  }

  void printFloatColor(List<double> color) {
    print(color);
  }

  @override
  Widget build(BuildContext context) {
    AppBar appBar = AppBar(
        title: ShowUp(
          delay: 100,
          child: Text('TestActity', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600, fontFamily: 'Montserrat')),
        ),
        backgroundColor: const Color(0xaa000000),
        elevation: 0,
        actions: []
    );

    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: appBar,
        backgroundColor: Color(0xFFecebe9),
        body: SafeArea(
            child: Column(
              children: [
                SizedBox(
                  width: 700,
                  child: Column(
                    children: [
                      Image.file(File(path)),
                      if(bytes != null) Image.memory(bytes!),
                    ],
                  ),
                ),
                IconButton(onPressed: () => rebuild(), icon: Icon(Icons.edit_road))
              ],
            )
        )
    );
  }
}