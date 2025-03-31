import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:cimagen/main.dart';
import 'package:cimagen/modules/webUI/AbMain.dart';
import 'package:cimagen/modules/webUI/OnLocal.dart';
import 'package:cimagen/modules/webUI/OnWeb.dart';
import 'package:cimagen/utils/BufferUtils.dart';
import 'package:cimagen/utils/DataModel.dart';
import 'package:cimagen/utils/SQLite.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:objectbox/objectbox.dart';
import 'package:xml/xml.dart';

import '../Utils.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:png_chunks_extract/png_chunks_extract.dart' as png_extract;
import 'package:http/http.dart' as http;

import '../modules/ConfigManager.dart';
import '../modules/ICCProfiles.dart';
import '../modules/webUI/OnNetworkLocation.dart';
import '../modules/webUI/OnRemote.dart';
import 'NavigationService.dart';

class ImageManager extends ChangeNotifier {

  List<String> _favoritePaths = [];

  List<String> get favoritePaths => _favoritePaths;

  String _lastJob = '';
  String get lastJob => _lastJob;
  int get jobCount => _jc;
  int _jc = 0;

  // Local
  bool _useLastAsTest = false;
  bool get useLastAsTest => _useLastAsTest;
  bool toogleUseLastAsTest(){
    _useLastAsTest = !_useLastAsTest;
    return _useLastAsTest;
  }

  void updateLastJob(String job){
    _lastJob = job;
    notifyListeners();
  }

  void updateJobCount(int c){
    _jc = c;
    notifyListeners();
  }

  // Getters
  late AbMain _getter;
  AbMain get getter => _getter;

  void init(BuildContext context){
    switchGetterAuto();
    context.read<SQLite>().getFavoritePaths().then((v) => _favoritePaths = v);
  }

  void switchGetterAuto(){
    if(prefs.getBool('use_remote_version') ?? false){
      changeGetter(1, exit: false);
    } else {
      changeGetter(0, exit: false);
    }
  }

  /// Changing [AbMain]
  ///
  /// * 1 - [OnRemote]
  /// * 2 - [OnNetworkLocation]
  /// * 3 - [OnWeb]
  /// * default - [OnLocal]
  Future<void> changeGetter(int type, {bool exit = true}) async {
    print('Change getter to $type:$exit');
    switch (type) {
      case 1:
        if(exit) _getter.exit();
        _getter = OnRemote()..init();
      case 2:
        if(exit) _getter.exit();
        _getter = OnWeb()..init();
      default:
        if(exit) _getter.exit();
        _getter = OnLocal()..init();
    }
  }

  Future<void> updateIfNado(RenderEngine re, String imagePath) async {
    imagePath = p.normalize(imagePath); // windows suck
    // Check file type
    final String e = p.extension(imagePath);
    if(!['png', 'jpg', 'webp', 'jpeg'].contains(e.replaceFirst('.', ''))) return;
    final String b = p.basename(imagePath);
    for(String d in ['mask', 'before']){
      if(b.contains(d)) {
        if (kDebugMode) print('skip $b');
        return;
      }
    }

    NavigationService.navigatorKey.currentContext!.read<SQLite>().shouldUpdate(imagePath).then((doI) async {
      if(doI){
        ImageMeta? value = await parseImage(re, imagePath);
        updateLastJob(imagePath);
        if(value != null) {
          objectbox.updateImages(imageMeta: value, fromWatch: true);
          if(_useLastAsTest){
            Future.delayed(const Duration(milliseconds: 1000), () {
              DataModel? d = NavigationService.navigatorKey.currentContext?.read<DataModel>();
              if(d != null){
                d.comparisonBlock.moveTestToMain();
                d.comparisonBlock.changeSelected(1, value);
                d.comparisonBlock.addImage(value);
              }
            });
          }
        }
      }
    });
  }

  Future<void> toogleFavorite(String path, {String? host}) async {
    NavigationService.navigatorKey.currentContext?.read<SQLite>().updateFavorite(path, !_favoritePaths.contains(path), host: host).then((value) {
      if(_favoritePaths.contains(path)){
        _favoritePaths.remove(path);
      } else {
        _favoritePaths.add(path);
      }
      if (kDebugMode) print(_favoritePaths.contains(path));
      notifyListeners();
    });
  }
}

class JobImageFile{
  final String fullPath;
  String? fullNetworkPath;
  String? networkThumbhail;
  DateTime? dateModified;

  JobImageFile({
    required this.fullPath,
    this.fullNetworkPath,
    this.networkThumbhail,
    this.dateModified
  });
}

class ParseJob {
  Function? _onDone;
  Function? _onProcess;

  int _jobID = -1;
  int get jobID => _jobID;
  bool _forceStop = false;

  List<dynamic> _cache = [];
  List<ImageMeta> _done = [];
  int _doneTotal = 0;

  RenderEngine? filterByRe;

  late StreamController<List<ImageMeta>> _controller;
  StreamController<List<ImageMeta>> get controller => _controller;

  List<ImageMeta> get finished => _done;

  bool get isDone => _doneTotal >= _cache.length;

  void forceStop(){
    _forceStop = true;
  }

  var rng = Random();

  ParseJob({RenderEngine? re}){
    filterByRe = re;
    _controller = StreamController<List<ImageMeta>>();
  }

  String? host;

  Future<int> putAndGetJobID(List<dynamic> rawImages, {String? host}) async {
    this.host = host;

    if (kDebugMode) {
      print('IM:putAndGetJobID: get ${rawImages.length}');
    }
    _cache.addAll(rawImages);

    _jobID = getRandomInt(1000, 100000);
    return _jobID;
  }

  void run({Null Function()? onDone, Null Function(int total, int current, Uint8List? thumbnail)? onProcess}) {
    if (kDebugMode) {
      print('Run job $_jobID');
    }
    if(onDone != null) _onDone = onDone;
    if(onProcess != null) _onProcess = onProcess;
    _parse(host);
  }

  // path НОРМАЛИЗОВАНО
  Future<void> _parse(String? host) async {
    if(_cache.isEmpty){
      if (kDebugMode) {
        print('putAndGetJobID: _cache.isEmpty');
      }
      return _isDone();
    }
    for(dynamic raw in _cache){
      if(_forceStop) {
        _doneTotal++;
        _isDone();
        continue;
      }
      bool yes = true;
      String path = normalizePath(raw.runtimeType == String ? raw : raw.runtimeType == JobImageFile ? (raw as JobImageFile).fullPath : raw);
      // Check file type
      final String e = p.extension(path);
      if(!['png', 'jpg', 'webp', 'jpeg'].contains(e.replaceFirst('.', ''))) {
        print('putAndGetJobID: invalid ex: ${e.replaceFirst('.', '')} ($e)');
        yes = false;
        _doneTotal++;
        _isDone();
        continue;
      }
      final String b = p.basename(path);
      for(String d in ['mask', 'before']){
        if(b.contains(d)) {
          yes = false;
        }
      }
      if(yes){
        if(host == null){
          try{
            ImageMeta? value = await parseImage(RenderEngine.unknown, path);
            if(value != null){
              _done.add(value);
              _controller.add(finished);
              if(filterByRe != null){
                if(value.re == filterByRe){
                  objectbox.updateImages(imageMeta: value, fromWatch: false).then((value){
                    _doneTotal++;
                    _isDone();
                  });
                } else {
                  _doneTotal++;
                  _isDone();
                }
              } else {
                objectbox.updateImages(imageMeta: value, fromWatch: false).then((value){
                _doneTotal++;
                _isDone();
              });
              }
            } else {
              _doneTotal++;
              _isDone();
            }
          } catch(e){
            if (kDebugMode) {
              print(e);
            }
            _doneTotal++;
            _isDone();
          }
        } else {
          // Если изображение в сети
          JobImageFile jf = raw as JobImageFile;
          ImageMeta im = ImageMeta(
              host: host,
              re: RenderEngine.unknown,
              fileTypeExtension: e.replaceFirst('.', ''),
              fullPath: path,
              fullNetworkPath: jf.fullNetworkPath,
              networkThumbnail: jf.networkThumbhail,
              dateModified: jf.dateModified
          );

          int attempts = 0;
          bool okay = false;
          String? err;
          while(attempts < 3 && okay != true){
            try {
              await im.parseNetworkImage(makeCachedImage: true);
              _done.add(im);
              if(!_controller.isClosed) _controller.add(finished);
              okay = true;
              objectbox.updateImages(imageMeta: im, fromWatch: false).then((value){
                _doneTotal++;
                _isDone();
              });
            } catch (e, t){
              err = e.toString();
              if (kDebugMode) {
                print(t);
              }
              attempts++;
              await Future.delayed(const Duration(seconds: 3));
            }
          }
          if(okay != true && attempts >= 3){
            _doneTotal++;
            _isDone();
            // Save broken image
            bool s = false;
            if(im.tempFilePath != null){
              s = true;
              String imagesErrorDir = NavigationService.navigatorKey.currentContext!.read<ConfigManager>().imagesErrorDir;
              File(im.tempFilePath!).copy(p.join(imagesErrorDir, im.fileName));
            }
            int notID = notificationManager!.show(
                thumbnail: const Icon(Icons.error, color: Colors.redAccent),
                title: 'Error in image processing${kDebugMode ? ', look at console' : ''}',
                description: 'We were unable to process the image, 3 attempts were made\n$path${s ? ', save to error folder':''}\nError: $err\nJob ID: $jobID'
            );
            audioController!.player.play(AssetSource('audio/error.wav'));
            Future.delayed(const Duration(milliseconds: 10000), () => notificationManager!.close(notID));
          }
        }
      } else {
        _doneTotal++;
        _isDone();
      }
    }
  }

  void _isDone(){
    if(_onProcess != null) _onProcess!(_cache.length, _doneTotal, _done.isNotEmpty ? _done.last.thumbnail : null);
    if(isDone){
      if (kDebugMode) {
        print('done with $_jobID');
      }
      _controller.close();
      if(_onDone != null) _onDone!();
    }
  }
}

DateFormat format = DateFormat("yyyy-MM-dd");

final listEqual = const ListEquality().equals;
Future<ImageMeta?> parseImage(RenderEngine re, String imagePath, {Uint8List? fileBytes, bool makeCachedImage = false, String? host}) async {
  bool debug = false;

  GenerationParams? gp;

  // Read
  fileBytes ??= await compute(readAsBytesSync, imagePath);
  final File f = File(imagePath);

  final String mine = lookupMimeType(imagePath, headerBytes: fileBytes) ?? 'unknown';
  String e = mine.split('/').last;
  var fileStat = await f.stat();
  DateTime? creationDate;

  if(e == 'png') {

    String? error;

    List<Map<String, dynamic>> chunks = [];
    try{
      chunks = png_extract.extractChunks(fileBytes!);
    } catch(e){
      if(debug) print(e);
      error = e.toString();
    }

    Map<String, dynamic> pngEx = {};
    Map<String, dynamic> specific = {};

    var bdata;

    if(error == null){
      // http://www.libpng.org/pub/png/spec/1.2/PNG-Chunks.html
      // [IHDR, tEXt, IDAT, IEND], [13, 1009, 25524, 0]                           - Vanilla png
      // [IHDR, oFFs, tEXt, tEXt, tEXt, iTXt, eXIf, IDAT, IDAT, IDAT... , IEND]   - Topaz Photo AI 1.5.3
      // [IHDR, iCCP, pHYs, IDAT, IDAT, IDAT, IDAT, IDAT, IDAT, IDAT, eXIf, IEND] - Crita
      // [IHDR, pHYs, iTXt, IDAT, IDAT, IDAT, IDAT, eXIf, IEND]                   - Photoshop

      List<String> chunksNames = chunks.map((e) => e['name'] as String).toList();

      if(debug) print('Chunk names: ${chunksNames.join(', ')}');

      // IHDR
      final IHDRtrunk = chunks.where((e) => e["name"] == 'IHDR').toList(growable: false)[0]['data'];

      var iCCP;
      if(chunksNames.contains('iCCP')) iCCP = chunks.where((e) => e["name"] == 'iCCP').toList(growable: false)[0]['data'];
      var pHYs;
      if(chunksNames.contains('pHYs')) pHYs = chunks.where((e) => e["name"] == 'pHYs').toList(growable: false)[0]['data'];
      var iTXt;
      if(chunksNames.contains('iTXt')) iTXt = chunks.where((e) => e["name"] == 'iTXt').toList(growable: false)[0]['data'];

      //debug

      // chunks.where((e) => e["name"] == 'tEXt').toList(growable: false).forEach((element) {
      //   if(element.isNotEmpty){
      //     print(element);
      //     List<int> fix = element['data'].map((e) => e == 0 ? 32 : e).toList(growable: false).cast<int>();
      //     String text = utf8.decode(Uint8List.fromList(fix));
      //     print(text);
      //   }
      // });

      // ================================

      Uint8List IHDRu8List = Uint8List.fromList(IHDRtrunk);
      bdata = ByteData.view(Uint8List.fromList(IHDRtrunk).buffer);
      // [
      //  0, 0, 0, 128, Width               4 bytes
      //  0, 0, 0, 128, Height              4 bytes
      //  8,            Bit depth           1 byte
      //  2,            Color type          1 byte
      //  0,            Compression method  1 byte - always 0
      //  0,            Filter method       1 byte
      //  0             Interlace method    1 byte
      // ]

      specific.addAll({
        'bitDepth': IHDRu8List[8],
        'colorType': IHDRu8List[9],
        'compression': IHDRu8List[10],
        'filter': IHDRu8List[11],
        'colorMode': IHDRu8List[12], // 13 bytes - ok
      });

      // TODO: PNG:SignificantBits
      if(iCCP != null){
        var we = BufferReader(data: iCCP);
        specific['iccProfileName'] = we.getNullTerminatedByteString(); // ITUR_2100_PQ_FULL for example
        int cm = we.getUint8();
        specific['iccCompressionMethod'] = cm;
        if(cm == 0){
          List<int> t = we.get(null);
          var inflated = zlib.decode(t);
          specific.addAll(extract(inflated));
        } else {
          if(debug) print('Invalid compression method value $cm');
        }

        // http://www.libpng.org/pub/png/spec/1.2/PNG-Chunks.html#C.iCCP
        // Profile name:       1-79 bytes (character string)
        // Null separator:     1 byte

        // Compression method: 1 byte
        // Compressed profile: n bytes - wtf is this shit ?
      }

      if(pHYs != null){
        // http://www.libpng.org/pub/png/book/chapter11.html#png.ch11.div.8
        var we = BufferReader(data: pHYs);
        specific['pixelsPerUnitX'] = we.getInt32();
        specific['pixelsPerUnitY'] = we.getInt32();
        specific['pixelUnits'] = we.get(1)[0]; // 1, the units are meters; if it is 0, the units are unspecified
      }

      if(iTXt != null) {
        // http://www.libpng.org/pub/png/spec/1.2/PNG-Chunks.html

        // Keyword:             1-79 bytes (character string)
        // Null separator:      1 byte
        // Compression flag:    1 byte
        // Compression method:  1 byte
        // Language tag:        0 or more bytes (character string)
        // Null separator:      1 byte
        // Translated keyword:  0 or more bytes
        // Null separator:      1 byte
        // Text:                0 or more bytes

        var we = BufferReader(data: iTXt);
        String main = we.getNullTerminatedByteString();
        int compressionFlag = we.getUint8();
        int compressionMethod = we.getUint8();
        String languageTag = we.getNullTerminatedByteString();
        String translatedKeyword = we.getNullTerminatedByteString();
        String? text;
        try{
          text = utf8.decode(Uint8List.fromList(we.get(null)));
        } on FormatException catch(e){ // TODO

        }
        if(debug) print('m:$main cf:$compressionFlag cm:$compressionMethod l:$languageTag t:$translatedKeyword t:$text');
        if(text != null){
          if(main == 'XML:com.adobe.xmp'){
            try{
              final document = XmlDocument.parse(text);
              Map<String, dynamic> t = {};
              document.findAllElements('rdf:Description').first.attributes.forEach((p0) {
                t['${p0.name.prefix != null ? '${p0.name.prefix}:' : ''}${p0.name.local}'] = p0.value;
              });
              if(t['xmp:CreatorTool'] != null){
                specific['xmpCreatorTool'] = t['xmp:CreatorTool'];
                if(t['xmp:CreatorTool']!.startsWith('Adobe Photoshop')) pngEx['softwareType'] = Software.photoshop;
              }
              if(t['xmp:CreateDate'] != null) specific['xmpCreateDate'] = t['xmp:CreateDate'];
              if(t['xmp:ModifyDate'] != null) specific['xmpModifyDate'] = t['xmp:ModifyDate'];
              if(t['xmp:MetadataDate'] != null) specific['xmpMetadataDate'] = t['xmp:MetadataDate'];
              if(t['dc:format'] != null) specific['xmpDcFormat'] = t['dc:format'];
              if(t['photoshop:ColorMode'] != null) specific['xmpPhotoshopColorMode'] = int.parse(t['photoshop:ColorMode']); // https://helpx.adobe.com/photoshop/using/color-modes.html
            } catch (e) {
              // No specified type, handles all
              if(debug) print('Something really unknown: $e');
            }
          } else if(main == 'parameters'){
            // hello 1.5
            re = RenderEngine.txt2img;
            gp = parseSDParameters(text);
          }
        }
        // String text = utf8.decode(Uint8List.fromList(iTXt));
        // print(text);
      }

      // tEXt
      final tEXtTrunk = chunks.where((e) => e["name"] == 'tEXt').toList(growable: false);
      if(tEXtTrunk.isNotEmpty){
        for (var element in tEXtTrunk) {
          List<int> fix = element['data'].map((e) => e == 0 ? 32 : e).toList(growable: false).cast<int>();
          String text = '';
          // Ебануться, латынь 0-0
          try{
            text = utf8.decode(Uint8List.fromList(fix));
          } on FormatException catch (e) {
            text = latin1.decode(Uint8List.fromList(fix));
          }
          int idx = text.indexOf(" ");
          List parts = [text.substring(0,idx).trim(), text.substring(idx+1).trim()];
          pngEx[parts[0].toLowerCase()] = parts[1];
        }

        // SD
        if(pngEx['parameters'] != null){
          if(pngEx['generation_data'] != null && await isJson(pngEx['generation_data'])){
            pngEx['softwareType'] = Software.tensorArt;
          }
          if(await isJson(pngEx['parameters'])){
            var data = jsonDecode(pngEx['parameters']);
            if(data.runtimeType == String){ // BLYATTTTTT
              re = RenderEngine.txt2img;
              gp = parseSDParameters(data);
            } else {
              if(data['sui_image_params'] != null){
                pngEx['softwareType'] = Software.swarmUI;
                gp = parseSwarmUIParameters(pngEx['parameters']);
                // Data check
                if(data['sui_extra_data'] != null) creationDate = format.parse(data['sui_extra_data']['date']);
              }
            }
          } else {
            re = RenderEngine.txt2img;
            gp = parseSDParameters(pngEx['parameters']);
          }
        } else if(pngEx['workflow'] != null){
          if(await isJson(pngEx['workflow'] as String)){
            re = RenderEngine.comfUI;
            List<dynamic> nodesList = parseComfUIParameters(pngEx['prompt']);
            if(nodesList.isNotEmpty) specific['comfUINodes'] = nodesList;
          }
        } else if(pngEx['prompt'] != null){
          if(await isJson(pngEx['prompt'] as String)){
            var data = jsonDecode(pngEx['prompt'] as String);
            if(pngEx['generation_data'] == null){
              if(data['request_type'] == null){
                re = RenderEngine.comfUI;
                List<dynamic> nodesList = parseComfUIParameters(pngEx['prompt']);
                if(nodesList.isNotEmpty) specific['comfUINodes'] = nodesList;
              } else {
                // Какая-то хуйня
                re = RenderEngine.txt2img;
                gp = GenerationParams(
                    positive: data['prompt'] as String,
                    negative: data['uc'] as String,
                    steps: data['steps'] as int,
                    sampler: data['sampler'] as String,
                    cfgScale: double.parse(data['cfg_rescale'].toString()),
                    seed: data['seed'],
                    size: data['width'] != null ? ImageSize(width: data['width'], height: data['height']) : null,
                    rawData: jsonEncode(data),
                    params: data
                );
              }
            } else {
              pngEx['softwareType'] = Software.tensorArt;
              if(await isJson(pngEx['generation_data'])){
                var data = jsonDecode(pngEx['generation_data']);
                String modelType = data['baseModel']['type'] as String;
                re = data['inpaint'] != null ? RenderEngine.inpaint : RenderEngine.txt2img;
                gp = GenerationParams(
                  positive: von<String>(data['prompt']),
                  negative: von<String>(data['negativePrompt']),
                  steps: data['steps'] as int,
                  sampler: data['ksamplerName'] != null ? '${data['ksamplerName']}_${data['schedule']}' : data['samplerName'] as String,
                  cfgScale: double.parse(data['cfgScale'].toString()),
                  seed: int.parse(data['seed'] as String),
                  size: data['width'] != null ? ImageSize(width: data['width'], height: data['height']) : null,
                  checkpointType: modelType == 'BASE_MODEL' ? CheckpointType.model : CheckpointType.unknown,
                  checkpoint: data['baseModel']['modelFileName'] as String,
                  checkpointHash: data['baseModel']['hash'] as String,
                  version: data['workEngine'] != null ? data['workEngine'] as String : null,
                  rawData: jsonEncode(data),
                  params: data,

                  denoisingStrength: von<double>(data['denoisingStrength']),
                  hiresUpscaler: von<String>(data['hrUpscaler']),
                  hiresUpscale: data['hrResizeX'] != null && data['width'] != null ? data['hrResizeX'] / data['width'] : null
                );
              }
            }
          }
        }

        if(gp != null){
          if(gp.params?['mask_blur'] != null){
            re = RenderEngine.inpaint;
          } else if(pngEx['postprocessing'] != null){
            re = RenderEngine.extra;
          } else if(gp.params?['denoising_strength'] != null && gp.params?['hires_upscale'] == null){
            re = RenderEngine.img2img;
          }
        } else {
          if(pngEx['postprocessing'] != null){
            re = RenderEngine.extra;
          }
        }


        // Find render Engine
        //Topaz
        if(pngEx['software'] != null){
          if(pngEx['software'].startsWith('Topaz Photo AI')){
            pngEx['softwareType'] = Software.topazPhotoAI;
          } else if(pngEx['software'] == 'NovelAI'){
            pngEx['softwareType'] = Software.novelAI;
            if(pngEx['comment'] != null && await isJson(pngEx['comment'])){
              final data = jsonDecode(pngEx['comment']);
              if(data['req_type'] != 'lineart'){
                // {
                //   "prompt": "protogen",
                //   "steps": 28,
                //   "height": 1024,
                //   "width": 1024,
                //   "scale": 6.2,
                //   "uncond_scale": 1,
                //   "cfg_rescale": 0,
                //   "seed": 1354345381,
                //   "n_samples": 1,
                //   "hide_debug_overlay": false,
                //   "noise_schedule": "native",
                //   "legacy_v3_extend": false,
                //   "reference_information_extracted_multiple": [],
                //   "reference_strength_multiple": [],
                //   "sampler": "k_euler_ancestral",
                //   "controlnet_strength": 1,
                //   "controlnet_model": null,
                //   "dynamic_thresholding": false,
                //   "dynamic_thresholding_percentile": 0.999,
                //   "dynamic_thresholding_mimic_scale": 10,
                //   "sm": false,
                //   "sm_dyn": false,
                //   "skip_cfg_below_sigma": 0,
                //   "lora_unet_weights": null,
                //   "lora_clip_weights": null,
                //   "uc": "high contrast",
                //   "request_type": "PromptGenerateRequest",
                //   "signed_hash": "wOTyzWt95rON2w43sVLPfXYBJuBf3EeD3AYdxDtYfDXKYKvcBqi9huWsBPy/DMgrVRZZY304fSkiMR70235MBg=="
                // }
                gp = GenerationParams(
                    positive: data['prompt'] != null ? data['prompt'] as String : pngEx['description'],
                    negative: data['uc'] != null ? data['uc'] as String : null,
                    steps: data['steps'] as int,
                    sampler: data['sampler'] as String,
                    cfgScale: data['cfg_rescale'] != null ? data['cfg_rescale'] as double : null,
                    seed: data['seed'] as int,
                    size: data['width'] != null ? ImageSize(width: data['width'], height: data['height']) : null,
                    checkpointType: pngEx['source'] != null ? pngEx['source'].startsWith('Stable Diffusion') ? CheckpointType.model : CheckpointType.unknown : CheckpointType.unknown,
                    checkpoint: pngEx['source'],
                    checkpointHash: null,
                    version: null,
                    rawData: jsonEncode(data),
                    params: data
                );
              }
            }
          } else if(pngEx['software'] == 'Adobe ImageReady') {
            pngEx['softwareType'] = Software.adobeImageReady;
          } else if(pngEx['software'] == 'Celsys Studio Tool') {
            pngEx['softwareType'] = Software.celsysStudioTool;
          } else if(pngEx['software'] == 'PhotoScape') {
            pngEx['softwareType'] = Software.photoScape;
          } else if(pngEx['software'].startsWith('Adobe Photoshop')) {
            pngEx['softwareType'] = Software.photoshop;
          } else {
            print(imagePath);
            print('new Software');
            print(pngEx);
          }
        }

        // Character card inside
        if(pngEx['chara'] != null){
        }

        if(debug) print(pngEx);
      }

      //Remove shit
      if(gp != null) pngEx.remove('parameters');
      pngEx.remove('postprocessing');
      if(pngEx['softwareType'] != null ) pngEx['softwareType'] = pngEx['softwareType'].index;

      if(debug){
        print('final');
        print(specific);
      }
    }

    ImageMeta i = ImageMeta(
      host: host,
      error: error,
      fullPath: imagePath,
      re: re == RenderEngine.unknown ? gp?.denoisingStrength != null ? gp?.hiresUpscale == null ? RenderEngine.img2img : RenderEngine.txt2img : re : re,
      mine: mine,
      fileTypeExtension: e,
      fileSize: fileStat.size,
      dateModified: creationDate ?? fileStat.modified,
      size: error == null ? ImageSize(width: bdata.getInt32(0), height: bdata.getInt32(4)) : const ImageSize(width: 500, height: 500),
      specific: specific,
      other: pngEx
    );
    i.generationParams = gp;
    await i.makeImage(fileBytes: fileBytes, makeCacheImage: makeCachedImage);
    return i;
    // print(text);
  } else if(['jpg', 'jpeg'].contains(e)){
    // Welcome to hell
    Map<String, dynamic> specific = {};

    // icc
    int SEGMENT_IDENTIFIER = 0xFF;
    int SEGMENT_SOS = 0xDA;
    int MARKER_EOI = 0xD9;

    var reader = BufferReader(data: fileBytes!);
    int magicNumber = 0;
    String? error;
    try{
      magicNumber = reader.getUInt16();
    } catch(e){
      error = e.toString();
    }

    if(error == null){
      if (magicNumber != 0xFFD8) {
        print("JPEG data is expected to begin with 0xFFD8 (ÿØ) not 0x${magicNumber.toRadixString(16)}");
      } else {
        HashMap<int, List<int>> segmentDataMap = HashMap<int, List<int>>();

        List<int> getOrCreateSegmentList(int segmentType) {
          List<int> segmentList;
          if (segmentDataMap.containsKey(segmentType)) {
            segmentList = segmentDataMap[segmentType]!;
          } else {
            segmentList = [];
            segmentDataMap[segmentType] = segmentList;
          }
          return segmentList;
        }

        void addSegment(int segmentType, dynamic segmentBytes){
          getOrCreateSegmentList(segmentType).addAll(segmentBytes);
        }

        bool hasError = false;

        do {
          // Find the segment marker. Markers are zero or more 0xFF bytes, followed
          // by a 0xFF and then a byte not equal to 0x00 or 0xFF.

          int segmentIdentifier = reader.getInt8();
          int segmentType = reader.getInt8();

          // Read until we have a 0xFF byte followed by a byte that is not 0xFF or 0x00
          while (segmentIdentifier != SEGMENT_IDENTIFIER || segmentType == SEGMENT_IDENTIFIER || segmentType == 0) {
            segmentIdentifier = segmentType;
            segmentType = reader.getInt8();
          }

          if (segmentType == SEGMENT_SOS) {
            // The 'Start-Of-Scan' segment's length doesn't include the image data, instead would
            // have to search for the two bytes: 0xFF 0xD9 (EOI).
            // It comes last so simply return at this point
            //return segmentData;
            break;
          }

          if (segmentType == MARKER_EOI) {
            // the 'End-Of-Image' segment -- this should never be found in this fashion
            //return segmentData;
            break;
          }

          // next 2-bytes are <segment-size>: [high-byte] [low-byte]
          int segmentLength = reader.getUInt16();

          // segment length includes size bytes, so subtract two
          segmentLength -= 2;

          if (segmentLength < 0) {
            if(debug) print("JPEG segment size would be less than zero");
            hasError = true;
            break;
          }

          List<int> segmentBytes = reader.get(segmentLength);
          assert(segmentLength == segmentBytes.length);
          addSegment(segmentType, segmentBytes);

        } while (true);

        if(!hasError && segmentDataMap.containsKey(0xE2)){
          List<int> segmentBytes = segmentDataMap[0xE2]!;

          String JPEG_SEGMENT_PREAMBLE = "ICC_PROFILE";
          int preambleLength = JPEG_SEGMENT_PREAMBLE.length;

          List<int> newB = segmentBytes.sublist(14);
          specific.addAll(extract(newB));
        }
      }
    }

    img.Image? originalImage;
    try{
      originalImage = img.decodeJpg(fileBytes);
    } catch(e){
      if(debug) print('Sosi $e');
      error = e.toString();
    }

    Map<String, dynamic> jpgEx = {};

    if(error == null && originalImage!.exif.exifIfd.hasUserComment){
      String fi = utf8.decode(Uint8List.fromList(originalImage.exif.exifIfd[0x9286]!.toData().toList().where((e) => e != 0).toList(growable: false).cast()));
      try{
        for (var e in ['ASCII', 'UNICODE', 'JIS', '']) {
          if(fi.substring(0, 8).contains(e)){
            fi = fi.substring(e.length, fi.length);
            break;
          }
        }
        jpgEx['EXIF UserComment'] = fi;
      } on RangeError catch (e) {
        print('RangeError');
        print(imagePath);
        print(e);
      }

      if(jpgEx['EXIF UserComment'] != null && (jpgEx['EXIF UserComment'] as String).trim().isNotEmpty){
        gp = parseSDParameters(jpgEx['EXIF UserComment']);

        if(gp != null){
          if(gp.params?['mask_blur'] != null){
            re = RenderEngine.inpaint;
          } else if(gp.params?['denoising_strength'] != null && gp.params?['hires_upscale'] == null){
            re = RenderEngine.img2img;
          }
        }
      }

      //clean
      jpgEx.remove('EXIF UserComment');
    }

    if(error == null  && originalImage!.exif.imageIfd.hasSoftware){
      String fi = originalImage.exif.imageIfd.software ?? '';
      if(fi.startsWith('ArtBot - Create') && gp != null) {
        jpgEx['softwareType'] = Software.artBot;
        if(re == RenderEngine.unknown) re = RenderEngine.txt2img;
      }
    }

    if(error == null ) {
      specific.addAll({
        'bitsPerChannel': originalImage!.bitsPerChannel,
        'rowStride': originalImage.rowStride,
        'numChannels': originalImage.numChannels,
        'isLdrFormat': originalImage.isLdrFormat,
        'isHdrFormat': originalImage.isHdrFormat,
        'hasPalette': originalImage.hasPalette,
        'supportsPalette': originalImage.supportsPalette,
        'hasAnimation': originalImage.hasAnimation
      });
    }

    if(jpgEx['softwareType'] != null) jpgEx['softwareType'] = jpgEx['softwareType'].index;

    ImageMeta i = ImageMeta(
        host: host,
        error: error,
        fullPath: imagePath,
        re: re == RenderEngine.unknown ? gp?.denoisingStrength != null ? gp?.hiresUpscale == null ? RenderEngine.img2img : RenderEngine.txt2img : re : re,
        mine: mine,
        fileTypeExtension: e,
        fileSize: fileStat.size,
        dateModified: fileStat.changed,
        size: error == null ? ImageSize(width: originalImage!.width, height: originalImage.height) : const ImageSize(width: 500, height: 500),
        specific: specific,
        other: jpgEx
    )..generationParams = gp;
    if(error == null ) await i.makeImage(fileBytes: fileBytes, makeCacheImage: makeCachedImage);
    return i;
  } else if(['webp'].contains(e)) {
    Map<String, dynamic> specific = {};
    Map<String, dynamic> webpEx = {};

    final originalImage = await compute(img.decodeWebP, fileBytes!);
    if(originalImage!.exif.exifIfd.hasUserComment){
      String fi = utf8.decode(Uint8List.fromList(originalImage.exif.exifIfd[0x9286]!.toData().toList().where((e) => e != 0).toList(growable: false).cast()));
      try{
        for (var e in ['ASCII', 'UNICODE', 'JIS', '']) {
          if(fi.substring(0, 8).contains(e)){
            fi = fi.substring(e.length, fi.length);
            break;
          }
        }
        webpEx['EXIF UserComment'] = fi;
      } on RangeError catch (e) {
        print('RangeError');
        print(imagePath);
        print(e);
      }

      if(webpEx['EXIF UserComment'] != null && (webpEx['EXIF UserComment'] as String).trim().isNotEmpty){
        gp = parseSDParameters(webpEx['EXIF UserComment']);

        if(gp != null){
          if(gp.params?['mask_blur'] != null){
            re = RenderEngine.inpaint;
          } else if(gp.params?['denoising_strength'] != null && gp.params?['hires_upscale'] == null){
            re = RenderEngine.img2img;
          }
        }
      }

      //clean
      webpEx.remove('EXIF UserComment');
    }
    if(originalImage.hasAnimation) specific['hasAnimation'] = true;

    // // Fuuuuuck... it's u again...
    // var reader = BufferReader(data: fileBytes);
    // reader.setOffset(12);
    // while (true) {
    //   List<int> header = [];
    //   try{
    //     header = reader.getRange(reader.offset, 8);
    //   } on RangeError catch(e){
    //     throw Exception('Stop using webp it\'s such a pain. We are not ready to read it yet');
    //   }
    //   if (header.isEmpty) {
    //     print("No EXIF information found");
    //     break;
    //   } else if (header.length < 8) {
    //     print("Invalid RIFF encoding");
    //     break;
    //   }
    //
    //   final tag = String.fromCharCodes(header.sublist(0, 4));
    //   final length = Int8List.fromList(header.sublist(4, 8)).buffer.asByteData().getInt32(0, Endian.little);
    //   print('$tag $length');
    //
    //   // According to exiftool's RIFF documentation, WebP uses "EXIF" as tag
    //   // name while other RIFF-based files tend to use "Exif".
    //   if (tag == "EXIF") {
    //     // Look for Exif\x00\x00, and skip it if present. The WebP implementation
    //     // in Exiv2 also handles a \xFF\x01\xFF\xE1\x00\x00 prefix, but with no
    //     // explanation or test file present, so we ignore that for now.
    //     List<int> exifHeader = reader.getRange(reader.offset, 6);
    //     if (!listEqual(exifHeader, Uint8List.fromList('Exif\x00\x00'.codeUnits))) {
    //       reader.setOffset(reader.offset - exifHeader.length);
    //     }
    //     final offset = reader.offset;
    //     final endian = reader.endianOfByte(reader.getByte(reader.offset));
    //     //ReadParams(endian: endian, offset: offset);
    //     print('exif fosdofosidfiuasdbfiarws');
    //     break;
    //   }
    //
    //   // Skip forward to the next box.
    //   reader.setOffset(reader.offset + length + header.length);
    // }


    specific.addAll({
      'bitsPerChannel': originalImage.bitsPerChannel,
      'rowStride': originalImage.rowStride,
      'numChannels': originalImage.numChannels,
      'isLdrFormat': originalImage.isLdrFormat,
      'isHdrFormat': originalImage.isHdrFormat,
      'hasPalette': originalImage.hasPalette,
      'supportsPalette': originalImage.supportsPalette,
      'hasAnimation': originalImage.hasAnimation
    });

    ImageMeta i = ImageMeta(
        host: host,
        fullPath: imagePath,
        re: re,
        mine: mine,
        fileTypeExtension: e,
        fileSize: fileStat.size,
        dateModified: fileStat.modified,
        size: ImageSize(width: originalImage.width, height: originalImage.height),
        specific: specific,
        other: webpEx
    )..generationParams = gp;
    await i.makeImage(fileBytes: fileBytes, makeCacheImage: makeCachedImage);
    return i;
  } else if('gif' == e) {
    final originalImage = img.decodeGif(fileBytes!);
    Map<String, dynamic> specific = {};
    Map<String, dynamic> gifEx = {};

    if(originalImage!.hasAnimation) specific['hasAnimation'] = true;

    ImageMeta i = ImageMeta(
        host: host,
        fullPath: imagePath,
        re: re,
        mine: mine,
        fileTypeExtension: e,
        fileSize: fileStat.size,
        dateModified: fileStat.modified,
        size: ImageSize(width: originalImage.width, height: originalImage.height),
        specific: specific,
        other: gifEx
    )..generationParams = gp;
    await i.makeImage(fileBytes: fileBytes, makeCacheImage: makeCachedImage);
    return i;
  } else if('vnd.adobe.photoshop' == e) {
    Map<String, dynamic> specific = {};
    Map<String, dynamic> psdEx = {};

    final originalImage = img.decodePsd(fileBytes!);

    psdEx['softwareType'] = Software.photoshop.index;

    ImageMeta i = ImageMeta(
        host: host,
        fullPath: imagePath,
        re: re,
        mine: mine,
        fileTypeExtension: e,
        fileSize: fileStat.size,
        dateModified: fileStat.modified,
        size: ImageSize(width: originalImage!.width, height: originalImage.height),
        specific: specific,
        other: psdEx
    )..generationParams = gp;
    await i.makeImage(fileBytes: fileBytes, makeCacheImage: makeCachedImage);
    return i;
  } else {
    if (kDebugMode) {
      print('parseImage - not supported format: $e');
    }
    return null;
  }
}

Future<ImageMeta?> parseUrlImage(String imagePath) async {
  if(isImageUrl(imagePath)){

    Uri parse = Uri.parse(imagePath);
    final String e = p.extension(parse.path);
    ImageMeta im = ImageMeta(
      host: Uri(
          host: parse.host,
          port: parse.port
      ).toString(),
      re: RenderEngine.unknown,
      fileTypeExtension: e.replaceFirst('.', ''),
      fullNetworkPath: imagePath,
    );

    await im.parseNetworkImage();
    await im.makeImage(makeCacheImage: true);
    return im;
  } else {
    // Checking host
    Uri parse = Uri.parse(imagePath);
    if(['pin.it'].contains(parse.host)){
      final client = HttpClient();
      var request = await client.getUrl(parse);
      request.followRedirects = false;
      var response = await request.close();
      while (response.isRedirect) {
        response.drain();
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location != null) {
          parse = parse.resolve(location);
          request = await client.getUrl(parse);
          request.followRedirects = false;
          response = await request.close();
        }
      }
      RegExp ex = RegExp(r'pin/(.+)/sent');
      if(ex.hasMatch(parse.path)) {
        RegExpMatch match = ex.allMatches(parse.path).first;
        parse = Uri(
            scheme: 'https',
            host: 'widgets.pinterest.com',
            path: '/v3/pidgets/pins/info/',
            queryParameters: {'pin_ids': match[1]}
        );
        http.Response res = await http.Client().get(parse).timeout(const Duration(seconds: 5));
        if(res.statusCode == 200){
          var data = await json.decode(res.body);
          //print(res.body);
          if(data['status'] == 'success' && data['message'] == 'ok'){
            data = data['data'].first;
            if(!data['is_video'] && data['videos'] == null){
              String fU = '';
              bool h = false;
              if(data['story_pin_data'] != null && data['story_pin_data']['pages'].first['image_adjusted']['images']['originals'] != null){
                fU = data['story_pin_data']['pages'].first['image_adjusted']['images']['originals']['url'];
                h = true;
              } else if(data['embed'] != null){
                fU = data['embed']['src'];
                h = true;
              } else if(data['images']['564x'] != null){
                fU = data['images']['564x']['url'];
                h = true;
              } else if(data['images']['237x'] != null){
                fU = data['images']['237x']['url'];
                h = true;
              }

              if(h){
                parse = Uri.parse(fU);
                final String e = p.extension(parse.path);
                ImageMeta im = ImageMeta(
                  host: Uri(
                      host: parse.host,
                      port: parse.port
                  ).toString(),
                  re: RenderEngine.unknown,
                  fileTypeExtension: e.replaceFirst('.', ''),
                  fullNetworkPath: fU,
                );

                await im.parseNetworkImage();
                await im.makeImage(makeCacheImage: true);
                return im;
              }
            }
          }
        }
      }
    } else if(RegExp(r'\.pinterest\.com').hasMatch(parse.host)){
      RegExp ex = RegExp(r'pin/(.+)/');
      if(ex.hasMatch(parse.path)) {
        RegExpMatch match = ex.allMatches(parse.path).first;
        parse = Uri(
            scheme: 'https',
            host: 'widgets.pinterest.com',
            path: '/v3/pidgets/pins/info/',
            queryParameters: {'pin_ids': match[1]}
        );
        http.Response res = await http.Client().get(parse).timeout(const Duration(seconds: 5));
        if(res.statusCode == 200){
          var data = await json.decode(res.body);
          //print(res.body);
          if(data['status'] == 'success' && data['message'] == 'ok'){
            data = data['data'].first;
            if(!data['is_video'] && data['videos'] == null){
              String fU = '';
              bool h = false;
              if(data['story_pin_data'] != null && data['story_pin_data']['pages'].first['image_adjusted']['images']['originals'] != null){
                fU = data['story_pin_data']['pages'].first['image_adjusted']['images']['originals']['url'];
                h = true;
              } else if(data['embed'] != null){
                fU = data['embed']['src'];
                h = true;
              } else if(data['images']['564x'] != null){
                fU = data['images']['564x']['url'];
                h = true;
              } else if(data['images']['237x'] != null){
                fU = data['images']['237x']['url'];
                h = true;
              }

              if(h){
                parse = Uri.parse(fU);
                final String e = p.extension(parse.path);
                ImageMeta im = ImageMeta(
                  host: Uri(
                      host: parse.host,
                      port: parse.port
                  ).toString(),
                  re: RenderEngine.unknown,
                  fileTypeExtension: e.replaceFirst('.', ''),
                  fullNetworkPath: fU,
                );

                await im.parseNetworkImage();
                await im.makeImage(makeCacheImage: true);
                return im;
              }
            }
          }
        }
      }
    } else print('not ok');
    //https://pin.it/5xZcetzTV
    ImageMeta im = ImageMeta(
      error: 'Unknown host: ${parse.host}',
      host: Uri(
          host: parse.host,
          port: parse.port
      ).toString(),
      re: RenderEngine.unknown,
      fileTypeExtension: '',
      fullNetworkPath: imagePath,
    );
    return im;
    return null;
  }

}

class ImageKey{
  String keyup = '';
  final RenderEngine type;
  final String parent;
  final String fileName;
  final String? host;

  ImageKey({
    required this.type,
    required this.parent,
    required this.fileName,
    this.host
  }){
    keyup = genHash(type, parent, fileName, host: host);
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

String xmpColorModeToString(int type){
  return <int, String>{
    0: 'Bitmap',
    1: 'Grayscale',
    2: 'Indexed',
    3: 'RGB',
    4: 'CMYK',
    7: 'Multichannel',
    8: 'Duotone',
    9: 'Lab',
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

final DateFormat dateFormatter = DateFormat('yyyy-MM-dd HH:mm:ss.mmm');
RegExp dateRegex = RegExp(r"[0-9]{4}-[0-9]{2}-[0-9]{2}$");

@Entity()
class ImageMeta {
  int id;
  // Main
  @Index()
  String keyup = '';
  //Network
  @Transient()
  bool get isLocal => host == null;
  String? host;
  @Transient()
  String? hostMD5;
  // Other
  @Transient()
  String? error;

  @Transient()
  RenderEngine re;

  int get dbRe {
    _ensureReEnumValues();
    return re.index;
  }
  set dbRe(int value) {
    _ensureReEnumValues();
    re = value >= 0 && value < RenderEngine.values.length ? RenderEngine.values[value] : RenderEngine.unknown;
    if(fullPath != null){
      final String parentFolder = p.basename(File(fullPath!).parent.path);
      keyup = genHash(re, parentFolder, fileName, host: host);
      // print('$fileName $fullPath');
    } else {
      keyup = genHash(re, 'undefined', fileName, host: host);
    }
  }
  void _ensureReEnumValues() {
    assert(RenderEngine.unknown.index == 0);
    assert(RenderEngine.txt2img.index == 1);
    assert(RenderEngine.img2img.index == 2);
    assert(RenderEngine.inpaint.index == 3);
    assert(RenderEngine.txt2imgGrid.index == 4);
    assert(RenderEngine.img2imgGrid.index == 5);
    assert(RenderEngine.extra.index == 6);
    assert(RenderEngine.comfUI.index == 7);
    assert(RenderEngine.characterCard.index == 8);
  }

  String? mine;
  final String fileTypeExtension;
  @Property(type: PropertyType.date)
  @Index(type: IndexType.value)
  DateTime? dateModified;
  int? fileSize;
  String fileName = '';

  @Transient()
  ImageSize? size;
  List<int>? get dbSize {
    return size != null ? [
      size!.width,
      size!.height
    ] : null;
  }
  set dbSize(List<int>? value) {
    size = value != null && value.length == 2 ? ImageSize(width: value[0], height: value[1]) : null;
  }

  String pathHash = '';
  String? fullPath;
  String? fullNetworkPath;
  String? tempFilePath;
  String? cacheFilePath;

  // @Transient()
  // GenerationParams? generationParams;
  final dbGenerationParams = ToOne<GenerationParams>();
  @Transient()
  GenerationParams? get generationParams {
    return dbGenerationParams.target;
  }
  @Transient()
  set generationParams(GenerationParams? value) {
    dbGenerationParams.target = value;
  }

  @Transient()
  Uint8List? thumbnail;
  String? get dbThumbnail {
    return thumbnail != null ? base64Encode(thumbnail!) : null;
  }
  set dbThumbnail(String? value) {
    thumbnail = value != null ? base64Decode(value) : null;
  }

  String? networkThumbnail;

  @Transient()
  Map<String, dynamic>? other = {};
  String get dbOther {
    return other != null ? jsonEncode(other) : '{}';
  }
  set dbOther(String value) {
    try{
      other = json.decode(value);
    } catch (e) {
      other = null;
    }
  }

  @Transient()
  Map<String, dynamic>? specific = {};
  String get dbSpecific {
    return specific != null ? jsonEncode(specific) : '{}';
  }
  set dbSpecific(String value) {
    try{
      specific = json.decode(value);
    } catch (e) {
      specific = null;
    }
  }

  ImageMeta({
    this.error,
    this.host,
    this.re = RenderEngine.unknown,
    this.mine,
    required this.fileTypeExtension,
    this.fileSize,
    this.dateModified,
    this.size,
    this.specific,
    this.fullPath,
    this.fullNetworkPath,
    this.thumbnail,
    this.networkThumbnail,
    this.other,
    this.id = 0
  }){
    if(fullPath != null){
      final String parentFolder = p.basename(File(fullPath!).parent.path);
      fileName = p.basename(fullPath!);
      pathHash = genPathHash(fullPath!);
      keyup = genHash(re, parentFolder, fileName, host: host);
      // print('$fileName $fullPath');
    } else {
      Uri uri = Uri.parse(fullNetworkPath!);
      fileName = p.basename(uri.path);
      pathHash = genPathHash(uri.path);
      keyup = genHash(re, 'undefined', fileName, host: host);
    }
    if(host != null) hostMD5 = md5.convert(utf8.encode(host!)).toString();
    // if(fullNetworkPath == null && host != null && dateModified != null){
    //   Uri parse = Uri.parse(host!);
    //   Uri thumb = Uri(
    //       scheme: 'http',
    //       host: parse.host,
    //       port: parse.port,
    //       path: '/infinite_image_browsing/image-thumbnail',
    //       queryParameters: {
    //         'path': fullPath,
    //         'size': '512x512',
    //         't': dateFormatter.format(dateModified!)
    //       }
    //   );
    //   Uri full = Uri(
    //       scheme: 'http',
    //       host: parse.host,
    //       port: parse.port,
    //       path: '/infinite_image_browsing/file',
    //       queryParameters: {
    //         'path': fullPath,
    //         't': dateFormatter.format(dateModified!)
    //       }
    //   );
    //   fullNetworkPath = full.toString();
    //   networkThumbnail = thumb.toString();
    // }
  }

  Future<Map<String, dynamic>> toMap() async {
    final String parentFolder = p.basename(File(fullPath!).parent.path);
    if(thumbnail == null && isLocal){
      await makeImage();
    }
    return {
      'keyup': keyup,
      'isLocal': isLocal ? 1 : 0,
      'host': host,
      'type': re.index,
      'parent': parentFolder,
      'fileName': fileName,
      'pathHash': pathHash,
      'fullPath': fullPath,

      'dateModified': dateModified?.toIso8601String(),

      'mine': mine,
      'fileTypeExtension': fileTypeExtension,
      'fileSize': fileSize,
      'size': size.toString(),
      'specific': jsonEncode(specific),
      // 'generationParams': generationParams != null ? forSQL ? jsonEncode(generationParams?.toMap()) : generationParams?.toMap() : null, // Нахуй не нужно оно мне в базе
      'thumbnail': thumbnail != null ? base64Encode(thumbnail!) : null,
      'other': jsonEncode(other)
    };
  }

  void updateHost(String host){
    this.host = host;
  }

  ImageKey getKey(){
    final String parentFolder = p.basename(File(fullPath!).parent.path);
    return ImageKey(type: re, parent: parentFolder, fileName: fileName, host: host);
  }

  Future<void> makeImage({Uint8List? fileBytes, bool makeThumbnail = true, bool makeCacheImage = false}) async {
    if((makeThumbnail && thumbnail == null) || makeCacheImage){
      String? uri = isLocal ? fullPath : tempFilePath;
      if(uri == null && fileBytes == null) return;
      img.Image? data;
      if(fileBytes != null){
        data = await compute(img.decodeImage, fileBytes);
      } else {
        switch (mine?.split('/').last) {
          case 'png':
            data = await compute(img.decodePngFile, uri!);
            break;
          case 'jpg':
          case 'jpeg':
            data = await compute(img.decodeJpgFile, uri!);
            break;
          case 'gif':
            data = await compute(img.decodeGifFile, uri!);
            break;
          case 'webp':
            data = await compute(img.decodeWebPFile, uri!);
            break;
        }
      }
      bool hasAnim = specific != null && (specific!['hasAnimation'] ?? false);
      if(makeThumbnail && thumbnail == null) {
        thumbnail = data != null ? hasAnim ?
          await compute(img.encodePng, img.copyResize(data, width: 256)) :
          await compute(_encodeJpg, {'data': img.copyResize(data, width: 256), 'quality': 50}) : null;
      }
      if(makeCacheImage && data != null) {
        String imagesCacheDir = NavigationService.navigatorKey.currentContext!.read<ConfigManager>().imagesCacheDir;
        Uint8List cachedImage = (
          hasAnim ?
            await compute(img.encodePng, data) :
            await compute(_encodeJpg, {'data': data, 'quality': 80})
        );
        await File(p.join(imagesCacheDir, '${host != null ? hostMD5 : 'unknown'}_$keyup.$fileTypeExtension')).writeAsBytes(cachedImage);
      }
    }
  }

  Future<Uint8List> _encodeJpg(map) async => img.encodeJpg(map['data'], quality: map['quality']);

  Future<void> parseNetworkImage({bool makeCachedImage = false}) async {
    if(!isLocal && fullNetworkPath != null){
      // Download to temp
      String appTempDir = NavigationService.navigatorKey.currentContext!.read<ConfigManager>().tempDir;
      String pa = p.join(appTempDir, '$keyup${p.extension(fileName)}'); // max 256 so shit
      File f = File(pa);
      Uint8List? bytes;
      FileStat? stat;
      if(!f.existsSync()){
        String clean = cleanUpUrl(fullNetworkPath!);
        http.Response res = await http.get(Uri.parse(clean));
        if(res.statusCode == 200){
          bytes = res.bodyBytes;
          await f.writeAsBytes(bytes);
          tempFilePath = pa;
          stat = f.statSync();
          fileSize = stat.size;
          dateModified ??= stat.modified;
        } else {
          throw Exception('The answer is not 200: ${res.statusCode}\nUri: $clean');
        }
      } else {
        tempFilePath = pa;
      }

      if(tempFilePath != null){
        ImageMeta? im = await parseImage(RenderEngine.unknown, pa, fileBytes: bytes, makeCachedImage: makeCachedImage, host: host);
        stat ??= f.statSync();
        if(im != null){
          size = im.size;
          generationParams = im.generationParams;
          other = im.other;
          specific = im.specific;
          mine = im.mine;
          re = im.re;
          thumbnail ??= im.thumbnail;
          final String parentFolder = fullPath != null ? p.basename(File(fullPath!).parent.path) : '';
          keyup = genHash(re, parentFolder, fileName, host: host);
          // Try right date
          if(dateRegex.hasMatch(parentFolder)){
            dateModified = format.parse(parentFolder);
          } else {
            dateModified = stat.modified;
          }
          fileSize = stat.size;
        }
      }
    }
  }

  String toText(TextType type){
    bool byImageLib = fileTypeExtension != 'png';
    String fi = '';
    String prefix = [TextType.discord].contains(type) ? '> ': '';
    bool b = [TextType.discord, TextType.md].contains(type);

    String? colorType = byImageLib ? numChannelsToString(specific?['numChannels']) : specific?['colorType'] != null ? getColorType(specific?['colorType']) : null;

    bool isWebuiForge = false;
    String wForgeV = '';
    String wUIV = '';
    String parentVersion = '';

    if(generationParams?.version != null){
      RegExp ex = RegExp(r'(f[0-9]+\.[0-9]+\.[0-9]+)(v[0-9]+\.[0-9]+\.[0-9]+)(.*)');
      if(ex.hasMatch(generationParams!.version ?? '')){
        RegExpMatch match = ex.allMatches(generationParams!.version ?? '').first;
        if(match[1] != null && match[1]!.startsWith('f')){
          isWebuiForge = true;
          List<String> pa = match[3]!.split('-');
          wForgeV = match[1]!;
          wUIV = '${match[2]}${pa[0]}';
          parentVersion = pa.getRange(1, pa.length).join('-');
        }
      }
    }

    String tb(String t){
      return b ? '`$t`' : t;
    }

    fi += '${[TextType.discord, TextType.md].contains(type) ? '### ': ''}Image Info\n';
    if(mine != null) fi += '${prefix}Mine type: ${tb(mine!)}\n';
    fi += '${prefix}File size: ${tb(readableFileSize(fileSize ?? 0))}\n';
    if(size != null) fi += '${prefix}Size: ${tb('${size.toString()} (${aspectRatioFromSize(size!)})')}\n';
    fi += '\n';

    fi += '${[TextType.discord, TextType.md].contains(type) ? '### ': ''}Raw\n';
    fi += '${prefix}Bit depth: ${tb(byImageLib ? (specific?['bitsPerChannel'].toString() ?? 'None') : specific?['bitDepth'].toString() ?? 'None')}\n';
    if(colorType != null) fi += '${prefix}Color type: ${tb(colorType)}\n';
    if(specific?['compression'] != null) fi += '${prefix}Compression: ${tb(getCompression(specific?['compression']))}\n';
    if(specific?['filter'] != null) fi += '${prefix}Filter: ${tb(getFilterType(specific?['filter']))}\n';
    if(specific?['colorMode'] != null) fi += '${prefix}Color mode: ${tb(getInterlaceMethod(specific?['colorMode']))}\n';
    if(specific?['profileName'] != null) fi += '${prefix}Profile name: ${tb(specific?['profileName'])}\n';
    if(specific?['pixelUnits'] != null) fi += '${prefix}Pixel units: ${tb(specific?['pixelUnits'] == 1 ? 'Meters' : 'Not specified')}\n';
    if(specific?['pixelsPerUnitX'] != null) fi += '${prefix}Pixels per unit X/Y: ${tb('${specific?['pixelsPerUnitX']}x${specific?['pixelsPerUnitY']}')}\n';
    fi += '\n';

    if(specific?['hasIccProfile'] != null){
      fi += '${[TextType.discord, TextType.md].contains(type) ? '### ': ''}ICC Profile\n';
      if(specific?['iccProfileName'] != null) fi += '${prefix}Raw Profile Name: ${tb(specific!['iccProfileName'])}\n';
      if(specific?['iccCompressionMethod'] != null) fi += '${prefix}Compression method: ${tb(specific!['iccCompressionMethod'].toString())}\n';
      if(specific?['iccCmmType'] != null) fi += '${prefix}CMM type: ${tb(getFilterType(specific?['iccCmmType']))}\n';
      if(specific?['iccVersion'] != null) fi += '${prefix}Version: ${tb(getProfileVersionDescription(specific?['iccVersion']))}\n';
      if(specific?['iccClass'] != null) fi += '${prefix}Profile Class: ${tb(getProfileClass(specific?['iccClass']))}\n';
      if(specific?['iccColorSpace'] != null) fi += '${prefix}Color space: ${tb(specific?['iccColorSpace'])}\n';
      if(specific?['iccConnectionSpace'] != null) fi += '${prefix}Connection space: ${tb(specific?['iccConnectionSpace'])}\n';
      if(specific?['iccSignature'] != null) fi += '${prefix}Signature: ${tb(specific?['iccSignature'])}\n';
      if(specific?['iccPlatform'] != null) fi += '${prefix}Platform: ${tb(getPlatform(specific?['iccPlatform']))}\n';
      if(specific?['iccDeviceMake'] != null) fi += '${prefix}Device make: ${tb(specific?['iccDeviceMake'])}\n';
      if(specific?['iccRenderingIntent'] != null) fi += '${prefix}Rendering intent: ${tb(getIndexedDescription(specific?['iccRenderingIntent']))}\n';
      fi += '\n';
    }

    if(specific?['xmpCreatorTool'] != null){
      fi += '${[TextType.discord, TextType.md].contains(type) ? '### ': ''}Editor\n';
      fi += '${prefix}Creator tool: ${tb(specific?['xmpCreatorTool'])}\n';
      if(specific?['xmpPhotoshopColorMode'] != null) fi += '${prefix}Photoshop colormode: ${tb(xmpColorModeToString(specific?['xmpPhotoshopColorMode']))}\n';
      if(specific?['xmpCreateDate'] != null) fi += '${prefix}Create date: ${tb(specific?['xmpCreateDate'])}\n';
      if(specific?['xmpModifyDate'] != null) fi += '${prefix}Modify date: ${tb(specific?['xmpModifyDate'])}\n';
      if(specific?['xmpMetadataDate'] != null) fi += '${prefix}Metadata date: ${tb(specific?['xmpMetadataDate'])}\n';
      if(specific?['xmpDcFormat'] != null) fi += '${prefix}DC format: ${specific?['xmpDcFormat']}}\n';
      fi += '\n';
    }

    if(generationParams != null){
      fi += '${[TextType.discord, TextType.md].contains(type) ? '### ': ''}Generation Info\n';
      if(re != RenderEngine.unknown) fi += '${prefix}Render engine: ${tb(renderEngineToString(re))}\n';
      if(other?['softwareType'] != null) fi += '${prefix}Software: ${tb(softwareToString(Software.values[other?['softwareType']]))}\n';
      fi += 'Promt:\n```diff\n';
      if(generationParams?.positive != null) fi += '+ ${(generationParams!.positive ?? '').replaceAll("\n", " ").trim()}\n';
      if(generationParams?.positive != null && generationParams?.negative != null) fi += '\n';
      if(generationParams?.negative != null) fi += '- ${(generationParams!.negative ?? '').replaceAll("\n", " ").trim()}\n';
      fi += '```\n';
      fi += '${prefix}Checkpoint type: ${tb(checkpointTypeToString(generationParams!.checkpointType ?? CheckpointType.unknown))}\n';
      fi += '${prefix}Checkpoint: ${tb('${generationParams!.checkpoint}${generationParams!.checkpointHash != null ? ' (${generationParams!.checkpointHash})' : ''}')}\n';
      if(generationParams?.params?['vae'] != null) fi += '${prefix}VAE: ${generationParams?.params?['vae']+(generationParams?.params?['vae_hash'] != null ? ' (${generationParams?.params?['vae_hash']})' : '')}\n';
      fi += '$prefix**Sampling**\n';
      if(generationParams?.sampler != null) fi += '${prefix}Method: ${tb(generationParams!.sampler!)}\n';
      fi += '${prefix}Steps: ${tb(generationParams!.steps.toString())}\n';
      fi += '${prefix}CFG Scale: ${tb(generationParams!.cfgScale.toString())}\n';
      if(generationParams?.denoisingStrength != null && generationParams?.hiresUpscale == null) fi += '${prefix}Denoising strength: ${tb(generationParams!.denoisingStrength.toString())}\n';
      if(generationParams?.hiresUpscale != null){
        fi += '$prefix**Hi-res**\n';
        if(generationParams?.hiresSampler != null) fi += '${prefix}Sampler: ${tb(generationParams?.hiresSampler ?? 'None')}\n';
        fi += '${prefix}Denoising strength: ${tb(generationParams!.denoisingStrength.toString())}\n';
        fi += '${prefix}Upscaler: ${tb(generationParams!.hiresUpscaler ?? 'None (Lanczos)')}\n';
        fi += '${prefix}Upscale: ${tb('${generationParams!.hiresUpscale}(${generationParams!.size != null ? ' (${generationParams!.size!.withMultiply(generationParams!.hiresUpscale ?? 0)})' : ''}')}\n';
      }
      fi += '${prefix}Seed: ${tb(generationParams!.seed.toString())}\n';
      if(generationParams!.size?.width != null && generationParams!.size?.height != null) fi += '${prefix}Width and height: ${tb('${generationParams!.size!.width}x${generationParams!.size!.height}')}\n';
      if(isWebuiForge){
        fi += '$prefix**Version**\n';
        fi += '${prefix}WebUI Forge: ${tb(wForgeV)}\n';
        fi += '${prefix}Parent version: ${tb(parentVersion)}\n';
        fi += '${prefix}WebUI: ${tb(wUIV)}';
      } else {
        if(generationParams?.version != null) fi += '${prefix}Version: ${tb(generationParams?.version ?? 'Undefined')}';
      }
    }
    return fi;
  }
}

enum TextType{
  raw,
  discord,
  md
}

enum CheckpointType{
  unknown,
  model,
  refiner,
  inpaint,
  unet
}

String checkpointTypeToString(CheckpointType ct){
  return {
    CheckpointType.unknown: 'Unknown',
    CheckpointType.model: 'Model',
    CheckpointType.refiner: 'Refiner',
    CheckpointType.inpaint: 'Inpaint',
    CheckpointType.unet: 'UNet'
  }[ct] ?? 'Unknown*';
}

enum RenderEngine{
  unknown, // a5a5a5 / 262626
  txt2img, // 1 // 003366 / 80bfff
  img2img, // 2
  inpaint, // 3
  txt2imgGrid, // 4
  img2imgGrid, // 5
  extra, // 6 // f3a505 / 734d02
  comfUI, // 7 // 9d81ba / 31283b,
  characterCard // 8 / 71bc78 / 253d27
}

enum Software {
  topazPhotoAI,
  photoshop,
  novelAI,
  artBot, // https://tinybots.net/artbot
  adobeImageReady,
  celsysStudioTool,
  tensorArt, // https://tensor.art/,
  photoScape,
  swarmUI,
  stableDiffusionWebUI,
  comfUI
}

String renderEngineToString(RenderEngine re){
  return {
    RenderEngine.unknown: 'Unknown',
    RenderEngine.txt2img: 'txt2img',
    RenderEngine.img2img: 'img2img',
    RenderEngine.inpaint: 'Inpaint',
    RenderEngine.txt2imgGrid: 'txt2img grid',
    RenderEngine.img2imgGrid: 'img2img grid',
    RenderEngine.extra: 'Extra',
    RenderEngine.comfUI: 'ComfUI'
  }[re] ?? 'Unknown*';
}

String softwareToString(Software re){
  return {
    Software.topazPhotoAI: 'Topaz Photo AI',
    Software.photoshop: 'Photoshop',
    Software.novelAI: 'NovelAI',
    Software.artBot: 'ArtBot',
    Software.adobeImageReady: 'Adobe ImageReady',
    Software.celsysStudioTool: 'Celsys Studio Tool',
    Software.tensorArt: 'TensorArt',
    Software.photoScape: 'PhotoScape',
    Software.swarmUI: 'SwarmUI',
  }[re] ?? 'Unknown*';
}

String humanizeSamplerName(String name, {bool showOriginal = true}){ // https://github.com/comfyanonymous/ComfyUI/blob/cb8d0ebccc93d3df6e00da1a57718a86d3dde300/comfy/samplers.py#L507C19-L509C116
  return name.contains('_') ? '${{
    'euler': 'Euler',
    'euler_a': 'Euler A',
    'euler_ancestral': 'Euler A',
    'k_euler_a': 'Euler A Karras',
    'k_euler_ancestral': 'Euler A Karras',
    'heun': 'Heun',
    'heunpp2': 'Heun++2',
    'dpm_2': 'DPM 2',
    'dpm_2_ancestral': 'DPM 2 A',
    'lms': 'LMS',
    'dpm_fast': 'DPM Fast',
    'dpm_adaptive': 'DPM Adaptive',
    'dpmpp_2s_ancestral': 'DPM++ 2S A',
    'dpmpp_sde': 'DPM++ SDE',
    'dpmpp_sde_gpu' : 'DPM++ SDE GPU',
    'dpmpp_2m': 'DPM++ 2M',
    'dpmpp_2m_sde': 'DPM++ 2M SDE',
    'dpmpp_2m_sde_gpu': 'DPM++ 2M SDE GPU',
    'dpmpp_3m_sde': 'DPM++ 3M SDE',
    'dpmpp_3m_sde_gpu': 'DPM++ 3M SDE GPU',
    'ddpm': 'DDPM',
    'lcm': 'LCM'
  }[name.toLowerCase().replaceAll(' ', '_')] ?? 'Unknown*'} ($name)' : name;
}

String humanizeSchedulerName(String name, {bool showOriginal = true}){
  return '${{
    'simple': 'Simple',
    'normal': 'Normal',
    'karras': 'Karras',
    'exponential': 'Exponential',
    'sgm_uniform': 'SGM Uniform',
    'ddim_uniform': 'DDIM Uniform'
  }[name] ?? 'Unknown*'} ($name)';
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

  @Transient()
  int totalPixels(){
    return width*height;
  }

  @Transient()
  double aspectRatio(){
    return width / height;
  }

  @Transient()
  String withMultiply(double hiresUpscale) {
    return '${(width * hiresUpscale).round()}x${(height * hiresUpscale).round()}';
  }
}

enum ContentRating {
  Unknown,
  G, // General audiences - All ages admitted // #006835
  PG, // Parental guidance suggested - Some material may not be suitable for children. // #f15a24
  PG_13, // Rated PG-13: Parents strongly cautioned - Some material may be inappropriate for children under 13. // #803d99
  R, // Rated R: Restricted - Under 17 requires accompanying parent or adult guardian. // #d8121a
  NC_17, // Rated NC-17: No children under 17 admitted. // #1b3e9b
  X, // A commission of a couple having sex, Any artwork with detailed genitalia (sheathes, vents, penises, breasts, anuses, etc.), A story of a horse who gets captured by a dragoness for her other 'needs', Reference sheets with visible genitalia (erect or flaccid), Artwork with tight enough clothing to the point where they may as well be not wearing anything at all. // #000000
  XXX // Scat, Watersports, Snuff, Castration, Cub, Etc. #000000
}

String genHash(RenderEngine re, String parent, String name, {String? host}){
  //print('new Keyup from $re $parent $name $host');
  //if(re == RenderEngine.unknown) throw Exception('syka');
  List<int> bytes = utf8.encode([host != null ? 'network' : 'local', host ?? 'null', re.index.toString(), parent, name].join());
  String hash = sha256.convert(bytes).toString();
  return hash;
}

String cleanUpSDPrompt(String prompt){
  return prompt
    .trim()
    .replaceFirst(RegExp(r',\s*$'), '')
    .replaceAll('\n', '')
    .replaceAll(RegExp(r'\s{2,}'), ' ')
    .replaceAll(RegExp(r',+'), ',')
    .replaceAllMapped(RegExp(r'(?<!\\)[)\]]\s*(,)\s*\S'), (match) => '${match.group(0)?.replaceAll(' ', '').replaceFirst(match.group(1).toString(), '')}');
}