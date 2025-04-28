import 'dart:io';
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
  String path = 'F:\\PC2\\РабСто\\тестировать\\58146c24217971.57455a52e5971.png';
  String icc_path = 'C:\\Windows\\System32\\spool\\drivers\\color\\CN_PRO-1000_500_PhotoPaperPlusGlossyII.icc';
  String icc_path2 = 'W:\\sRGB_v4_ICC_preference.icc';

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

      final bytes1 = ByteData.view(File(icc_path).readAsBytesSync().buffer);
      final stream1 = DataStream(data: bytes1, offset: 0, length: bytes1.lengthInBytes);
      final profile1 = ColorProfile.fromBytes(stream1);
      print('Loading from $icc_path');

      final bytes2 = ByteData.view(File(icc_path2).readAsBytesSync().buffer);
      final stream2 = DataStream(data: bytes2, offset: 0, length: bytes2.lengthInBytes);
      final profile2 = ColorProfile.fromBytes(stream2);

      final cmm = ColorProfileCmm();
      final finalTransformations = cmm.buildTransformations([ColorProfileTransform.create(
        profile: profile1,
        isInput: true,
        intent: ColorProfileRenderingIntent.icRelativeColorimetric,
        interpolation: ColorProfileInterpolation.linear,
        lutType: ColorProfileTransformLutType.color,
        useD2BTags: true,
      )]);

      final reverseCMM  = ColorProfileCmm();
      final finalReverseTransformations  = reverseCMM.buildTransformations([ColorProfileTransform.create(
        profile: profile1,
        isInput: false,
        intent: ColorProfileRenderingIntent.icRelativeColorimetric,
        interpolation: ColorProfileInterpolation.linear,
        lutType: ColorProfileTransformLutType.color,
        useD2BTags: true,
      )]);

      final range = data.clone().getRange(0, 0, data.width, data.height);
      while (range.moveNext()) {

        final pixel = range.current;
        List<double> cmyk = rgb2cmyk(pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()).map((e) => e / 100).toList();

        final rgb = cmm.apply(finalTransformations, Float64List.fromList(cmyk));
        final norm = reverseCMM.apply(finalReverseTransformations, rgb).map((e) => 255 - ((e * 100) * 255 / 100).round()).toList();

        secondImage.setPixel(pixel.x, pixel.y, img.ColorUint8.rgb(norm[0], norm[1], norm[2]));
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
            child: Row(
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

void printColor(List<double> color) {
  print(color.map((e) => (e * 255).round().clamp(0, 255)).toList());
}

void printFloatColor(List<double> color) {
  print(color);
}