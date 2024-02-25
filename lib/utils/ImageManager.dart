import 'dart:convert';

import 'package:cimagen/utils/SQLite.dart';
import 'package:flutter/foundation.dart';

import '../Utils.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:png_chunks_extract/png_chunks_extract.dart' as pngExtract;

import 'NavigationService.dart';

class ImageManager{

  void init(BuildContext context){
    var outdir_txt2img = context.read<ConfigManager>().config['outdir_txt2img_samples'];
    var outdir_img2img = context.read<ConfigManager>().config['outdir_img2img_samples'];
    if(outdir_txt2img != null) watchDir(RenderEngine.txt2img, outdir_txt2img as String);
    if(outdir_img2img != null) watchDir(RenderEngine.img2img, outdir_img2img as String);
  }

  Future<void> updateIfNado(RenderEngine re, String imagePath) async {
    // Check file type
    final String e = p.extension(imagePath);
    if(!['png', 'jpg', 'webp', 'jpeg'].contains(e.replaceFirst('.', ''))) return;
    final String b = p.basename(imagePath);
    for(String d in ['before-color-correction', 'mask', 'mask-composite']){
      if(b.contains(d)) {
        if (kDebugMode) print('skip $b');
        return;
      }
    }

    GenerationParams? gp;

    // Read
    final fileBytes = await compute(readAsBytesSync, imagePath);
    final File f = File(imagePath);

    if(e == '.png') {
      final List<Map<String, dynamic>> chunks = pngExtract.extractChunks(fileBytes);
      // http://www.libpng.org/pub/png/spec/1.2/PNG-Chunks.html
      // [IHDR, tEXt, IDAT, IEND], [13, 1009, 25524, 0]

      // IHDR
      final IHDRtrunk = chunks.where((e) => e["name"] == 'IHDR').toList(growable: false)[0]['data'];
      Uint8List IHDRu8List = Uint8List.fromList(IHDRtrunk);
      var bdata = ByteData.view(Uint8List.fromList(IHDRtrunk).buffer);
      // [
      //  0, 0, 0, 128, Width               4 bytes
      //  0, 0, 0, 128, Height              4 bytes
      //  8,            Bit depth           1 byte
      //  2,            Color type          1 byte
      //  0,            Compression method  1 byte - always 0
      //  0,            Filter method       1 byte
      //  0             Interlace method    1 byte
      // ]

      // tEXt
      final tEXtTrunk = chunks.where((e) => e["name"] == 'tEXt').toList(growable: false);
      if(tEXtTrunk.isNotEmpty){
        String text = utf8.decode(Uint8List.fromList(tEXtTrunk[0]['data']));
        gp = parseSDParameters(text);
      }

      final String mine = lookupMimeType(imagePath, headerBytes: [0xFF, 0xD8]) ?? 'unknown';
      final fte = e.replaceFirst('.', '');
      var fileStat = await f.stat();

      NavigationService.navigatorKey.currentContext?.read<SQLite>().updateImages(re, ImageMeta(
        re: re,
        mine: mine,
        fileTypeExtension: fte,
        fileSize: fileStat.size,
        dateModified: fileStat.modified,
        size: Size(width: bdata.getInt32(0), height: bdata.getInt32(4)),
        bitDepth: IHDRu8List[8],
        colorType: IHDRu8List[9],
        compression: IHDRu8List[10],
        filter: IHDRu8List[11],
        colorMode: IHDRu8List[12], // 13 bytes - ok
        imageParams: ImageParams(
          path: imagePath,
          fileName: p.basename(imagePath),
          hasExif: gp != null,
          generationParams: gp
        )
      ));
      // print(text);
    }
  }

  void watchDir(RenderEngine re, String path){
    final tempFolder = File(path);
    print('watch '+path);
    tempFolder.watch(events: FileSystemEvent.all, recursive: true).listen((event) {
      if (event is FileSystemModifyEvent && !event.isDirectory) {
        updateIfNado(re, event.path);
        //print(lookupMimeType(event.path ?? "", headerBytes: [0xFF, 0xD8]));
      }
    });
  }
}

class ImageKey{
  String keyup = '';
  final RenderEngine type;
  final String parent;
  final String name;

  ImageKey({
    required this.type,
    required this.parent,
    required this.name
  }){
    keyup = genHash(type, parent, name);
  }
}

enum ColorType{
  greyscale,           // 0
  unknown1,            // 1 - null
  truecolor,           // 2
  indexedColor, 	     // 3
  greyscaleWithAlpha,  //	4
  unknown5,            // 5 - null
  truecolorWithAlpha 	 // 6
}

enum InterlaceMethod{
  nullMethod,
  adam7,
}

enum FilterTypes{
  none,
  sub,
  up,
  average,
  paeth
}

class ImageParams {
  final String path;
  String? parent;
  final String fileName;
  bool hasExif = false;
  Map<String, Object>? exif;
  GenerationParams? generationParams;

  ImageParams({
    required this.path,
    required this.fileName,
    required this.hasExif,
    this.exif,
    this.generationParams
  }){
    parent = p.basename(File(path).parent.path);
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> f = {
      'path': path,
      'fileName': fileName
    };

    if(generationParams != null) f['generationParams'] = generationParams?.toMap();
    return f;
  }

  String toJsonString(){
    return jsonEncode(toMap());
  }
}

class ImageMeta {
  final RenderEngine re;
  final String? mine;
  final String fileTypeExtension;
  final DateTime dateModified;
  final int fileSize;
  final Size size;
  final int bitDepth;
  final int colorType;
  final int compression;
  final int filter;
  final int colorMode;
  String pathHash = '';
  final ImageParams imageParams;

  ImageMeta({
    required this.re,
    required this.mine,
    required this.fileTypeExtension,
    required this.fileSize,
    required this.dateModified,
    required this.size,
    required this.bitDepth,
    required this.colorType,
    required this.compression,
    required this.filter,
    required this.colorMode,
    required this.imageParams
  }){
    pathHash = genPathHash(imageParams.path);
  }

  Map<String, dynamic> toMap({required bool forSQL}) {
    final String parentFolder = p.basename(File(imageParams.path).parent.path);
    return {
      'keyup': genHash(re, parentFolder, imageParams.fileName),
      'type': re.index,
      'parent': parentFolder,
      'name': imageParams.fileName,
      'pathHash': pathHash,

      'seed': imageParams.generationParams?.seed,
      'dateModified': dateModified.toIso8601String(),

      'mine': mine,
      'fileTypeExtension': fileTypeExtension,
      'fileSize': fileSize,
      'size': size.toString(),
      'bitDepth': bitDepth,
      'colorType': colorType,
      'compression': compression,
      'filter': filter,
      'colorMode': colorMode,
      'imageParams': forSQL ? jsonEncode(imageParams.toMap()) : imageParams.toMap()
    };
  }

  ImageKey getKey(){
    final String parentFolder = p.basename(File(imageParams.path).parent.path);
    return ImageKey(type: re, parent: parentFolder, name: imageParams.fileName);
  }
}

enum RenderEngine{
  unknown,
  txt2img,
  img2img,
  txt2imgGrid,
  img2imgGrid,
  extra,
  comfUI,
}