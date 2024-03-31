import 'dart:convert';

import 'package:cimagen/utils/SQLite.dart';
import 'package:exif/exif.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../Utils.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:png_chunks_extract/png_chunks_extract.dart' as pngExtract;

import 'NavigationService.dart';

class ImageManager extends ChangeNotifier{

  List<String> _favoritePaths = [];

  List<String> get favoritePaths => _favoritePaths;

  String _lastJob = '';
  String get lastJob => _lastJob;
  int get jobCount => _jc;
  int _jc = 0;

  void updateJobCount(int c){
    _jc = c;
    notifyListeners();
  }

  void init(BuildContext context){
    var outdirTxt2img = context.read<ConfigManager>().config['outdir_txt2img_samples'];
    var outdirImg2img = context.read<ConfigManager>().config['outdir_img2img_samples'];
    if(outdirTxt2img != null) watchDir(RenderEngine.txt2img, outdirTxt2img as String);
    if(outdirImg2img != null) watchDir(RenderEngine.img2img, outdirImg2img as String);

    context.read<SQLite>().getFavoritePaths().then((v) => _favoritePaths = v);
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

    parseImage(re, imagePath).then((value) async {
      if(value != null) {
        NavigationService.navigatorKey.currentContext?.read<SQLite>().updateImages(re, value);
      }
    });
  }

  void watchDir(RenderEngine re, String path){
    final tempFolder = File(path);
    if (kDebugMode) print('watch $path');
    tempFolder.watch(events: FileSystemEvent.all, recursive: true).listen((event) {
      if (event is FileSystemModifyEvent && !event.isDirectory) {
        updateIfNado(re, event.path);

        //print(lookupMimeType(event.path ?? "", headerBytes: [0xFF, 0xD8]));
      }
    });
  }

  Future<void> toogleFavorite(String path) async {
    NavigationService.navigatorKey.currentContext?.read<SQLite>().updateFavorite(path, !_favoritePaths.contains(path)).then((value) {
      if(_favoritePaths.contains(path)){
        _favoritePaths.remove(path);
      } else {
        _favoritePaths.add(path);
      }
      print(_favoritePaths.contains(path));
      notifyListeners();
    });
  }
}

Future<ImageMeta?> parseImage(RenderEngine re, String imagePath) async {
  final String e = p.extension(imagePath);
  GenerationParams? gp;

  // Read
  final fileBytes = await compute(readAsBytesSync, imagePath);
  final File f = File(imagePath);

  final String mine = lookupMimeType(imagePath, headerBytes: [0xFF, 0xD8]) ?? 'unknown';
  final fte = e.replaceFirst('.', '');
  var fileStat = await f.stat();

  if(e == '.png') {
    final List<Map<String, dynamic>> chunks = pngExtract.extractChunks(fileBytes);
    // http://www.libpng.org/pub/png/spec/1.2/PNG-Chunks.html
    // [IHDR, tEXt, IDAT, IEND], [13, 1009, 25524, 0]                         - Vanilla png
    // [IHDR, oFFs, tEXt, tEXt, tEXt, iTXt, eXIf, IDAT, IDAT, IDAT... , IEND] - Topaz Photo AI 1.5.3

    // IHDR
    final IHDRtrunk = chunks.where((e) => e["name"] == 'IHDR').toList(growable: false)[0]['data'];

    //debug

    // print(chunks.map((e) => e['name']).toList());
    // chunks.where((e) => e["name"] == 'tEXt').toList(growable: false).forEach((element) {
    //   if(element.isNotEmpty){
    //     print(element);
    //     List<int> fix = element['data'].map((e) => e == 0 ? 32 : e).toList(growable: false).cast<int>();
    //     String text = utf8.decode(Uint8List.fromList(fix));
    //     print(text);
    //   }
    // });

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

    Map<String, dynamic> pngEx = {};

    // tEXt
    final tEXtTrunk = chunks.where((e) => e["name"] == 'tEXt').toList(growable: false);
    if(tEXtTrunk.isNotEmpty){
      tEXtTrunk.forEach((element){
        List<int> fix = element['data'].map((e) => e == 0 ? 32 : e).toList(growable: false).cast<int>();
        String text = utf8.decode(Uint8List.fromList(fix));
        int idx = text.indexOf(" ");
        List parts = [text.substring(0,idx).trim(), text.substring(idx+1).trim()];
        pngEx[parts[0]] = parts[1];
      });

      // SD
      if(pngEx['parameters'] != null) gp = parseSDParameters(pngEx['parameters']);

      //Topaz
      if(pngEx['Software'] != null){
        if(pngEx['Software'].startsWith('Topaz Photo AI')){
          re = RenderEngine.topazPhotoAI;
        }
      }

      print(pngEx);
    }


    //Remove shit
    pngEx.remove('parameters');

    return ImageMeta(
        fullPath: p.normalize(imagePath),
        re: re == RenderEngine.unknown ? gp?.denoisingStrength != null ? gp?.hiresUpscale == null ? RenderEngine.img2img : RenderEngine.txt2img : re : re,
        mine: mine,
        fileTypeExtension: fte,
        fileSize: fileStat.size,
        dateModified: fileStat.modified,
        size: ImageSize(width: bdata.getInt32(0), height: bdata.getInt32(4)),
        specific: {
          'bitDepth': IHDRu8List[8],
          'colorType': IHDRu8List[9],
          'compression': IHDRu8List[10],
          'filter': IHDRu8List[11],
          'colorMode': IHDRu8List[12], // 13 bytes - ok
        },
        generationParams: gp,
        other: pngEx
    );
    // print(text);
  } else if(['.jpg', '.jpeg'].contains(e)){
    final data = await readExifFromBytes(fileBytes);
    final originalImage = img.decodeImage(fileBytes);

    Map<String, dynamic> jpgEx = {};
    if (data.isEmpty) {
      print("No EXIF information found");
      return null;
    } else {

      if (data.containsKey('JPEGThumbnail')) {
        print('File has JPEG thumbnail');
        data.remove('JPEGThumbnail');
      }
      if (data.containsKey('TIFFThumbnail')) {
        print('File has TIFF thumbnail');
        data.remove('TIFFThumbnail');
      }

      for (final entry in data.entries) {
        switch (entry.value.tagType) {
          case 'Long':
            const int maxValue = -1 >>> 1;
            jpgEx[entry.key] =  BigInt.parse(entry.value.printable) > BigInt.from(maxValue) ? entry.value.printable : int.parse(entry.value.printable);
          default:
            // print('${entry.value.tagType} ${entry.value.runtimeType} ${entry.value is String}');
            // if(entry.value.runtimeType == IfdTag) print(entry.value.values);
            var hasPrintable = false;
            try {
              (entry.value as dynamic).printable;
              hasPrintable = true;
            } on NoSuchMethodError {}

            if(entry.key == 'EXIF UserComment'){
              //fuck
              String fi = utf8.decode(Uint8List.fromList(entry.value.values.toList().where((e) => e != 0).toList(growable: false).cast()));
              for (var e in ['ASCII', 'UNICODE', 'JIS', '']) {
                if(fi.substring(0, 8).contains(e)){
                  fi = fi.substring(e.length, fi.length);
                  break;
                }
              }
              jpgEx[entry.key] = fi;
            } else {
              jpgEx[entry.key] = hasPrintable ? entry.value.printable : entry.value;
            }
        }
      }

      if(jpgEx['EXIF UserComment'] != null){
        gp = parseSDParameters(jpgEx['EXIF UserComment']);
      }

      //clean
      jpgEx.remove('EXIF UserComment');

      return ImageMeta(
          fullPath: p.normalize(imagePath),
          re: re == RenderEngine.unknown ? gp?.denoisingStrength != null ? gp?.hiresUpscale == null ? RenderEngine.img2img : RenderEngine.txt2img : re : re,
          mine: mine,
          fileTypeExtension: fte,
          fileSize: fileStat.size,
          dateModified: fileStat.modified,
          size: ImageSize(width: originalImage!.width, height: originalImage.height),
          specific: {
            'bitsPerChannel': originalImage.bitsPerChannel,
            'rowStride': originalImage.rowStride,
            'numChannels': originalImage.numChannels,
            'isLdrFormat': originalImage.isLdrFormat,
            'isHdrFormat': originalImage.isHdrFormat,
            'hasPalette': originalImage.hasPalette,
            'supportsPalette': originalImage.supportsPalette,
            'hasAnimation': originalImage.hasAnimation
          },
          generationParams: gp,
          other: jpgEx
      );
    }
  } else {
    return null;
  }
}

class ImageKey{
  String keyup = '';
  final RenderEngine type;
  final String parent;
  final String fileName;

  ImageKey({
    required this.type,
    required this.parent,
    required this.fileName
  }){
    keyup = genHash(type, parent, fileName);
  }
}

enum ColorType{
  greyscale,           // 0 - Each pixel consists of a single grey sample, which represents overall luminance (on a scale from black to white).
  unknown1,            // 1 - null
  truecolor,           // 2 - Each pixel consists of a triplet of samples: red, green, blue.
  indexedColor, 	     // 3 - Each pixel consists of an index into a palette (and into an associated table of alpha values, if present).
  greyscaleWithAlpha,  //	4 - Each pixel consists of two samples: a grey sample and an alpha sample.
  unknown5,            // 5 - null
  truecolorWithAlpha 	 // 6 - Each pixel consists of four samples: red, green, blue and alpha.
}

String getColorType(int type){
  return <int, String>{
    0: 'Greyscale',
    1: 'Unknown',
    2: 'Truecolor',
    3: 'Indexed-color',
    4: 'Greyscale with alpha',
    5: 'Unknown',
    6: 'Truecolor with alpha'
  }[type] ?? 'Unknown';
}

String numChannelsToString(int type){
  return <int, String>{
    3: 'RGB',
    4: 'RGBA',
  }[type] ?? 'Unknown';
}

int numChannelsToColorType(int numChannels){
  return <int, int>{
    2: 0,
    3: 2,
  }[numChannels] ?? -1;
}

enum InterlaceMethod {
  nullMethod,
  adam7,
}

String getInterlaceMethod(int type){
  return <int, String>{
    0: 'Null method',
    1: 'Adam7',
  }[type] ?? 'Unknown';
}

enum FilterTypes{
  none,
  sub,
  up,
  average,
  paeth
}

// https://w3c.github.io/PNG-spec/#9-table91
String getFilterType(int type){
  return <int, String>{
    0: 'None',
    1: 'Sub',
    2: 'Up',
    3: 'Average',
    4: 'Paeth'
  }[type] ?? 'Unknown';
}

String getCompression(int type){
  return <int, String>{
    0 : 'Deflate'
  }[type] ?? 'Unknown';
}

class ImageMeta {
  String keyup = '';
  final RenderEngine re;
  final String? mine;
  final String fileTypeExtension;
  final DateTime dateModified;
  final int fileSize;
  String fileName = '';
  final ImageSize size;
  String pathHash = '';
  final String fullPath;
  GenerationParams? generationParams;
  String? thumbnail;
  Map<String, dynamic>? other = {};
  Map<String, dynamic>? specific = {};

  ImageMeta({
    required this.re,
    required this.mine,
    required this.fileTypeExtension,
    required this.fileSize,
    required this.dateModified,
    required this.size,
    this.specific,
    required this.fullPath,
    this.generationParams,
    this.thumbnail,
    this.other,
  }){
    final String parentFolder = p.basename(File(fullPath).parent.path);
    fileName = p.basename(fullPath);
    pathHash = genPathHash(fullPath);
    keyup = genHash(re, parentFolder, fileName);
  }

  Future<Map<String, dynamic>> toMap() async {
    final String parentFolder = p.basename(File(fullPath).parent.path);
    img.Image? image = await img.decodeImageFile(fullPath);
    return {
      'keyup': keyup,
      'type': re.index,
      'parent': parentFolder,
      'fileName': fileName,
      'pathHash': pathHash,
      'fullPath': fullPath,

      'dateModified': dateModified.toIso8601String(),

      'mine': mine,
      'fileTypeExtension': fileTypeExtension,
      'fileSize': fileSize,
      'size': size.toString(),
      'specific': jsonEncode(specific),
      // 'generationParams': generationParams != null ? forSQL ? jsonEncode(generationParams?.toMap()) : generationParams?.toMap() : null, // Нахуй не нужно оно мне в базе
      'thumbnail': image != null ? base64Encode(img.encodeJpg(img.copyResize(image, width: 250), quality: 50)) : null,
      'other': jsonEncode(other)
    };
  }

  ImageKey getKey(){
    final String parentFolder = p.basename(File(fullPath).parent.path);
    return ImageKey(type: re, parent: parentFolder, fileName: fileName);
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
  topazPhotoAI
}

class ImageSize {
  final int width;
  final int height;

  const ImageSize({
    required this.width,
    required this.height
  });

  @override
  String toString(){
    return '${width}x$height';
  }

  int totalPixels(){
    return width*height;
  }

  double aspectRatio(){
    return width / height;
  }

  String withMultiply(double hiresUpscale) {
    return '${(width * hiresUpscale).round()}x${(height * hiresUpscale).round()}';
  }
}