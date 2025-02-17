import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cimagen/utils/DataModel.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:cimagen/utils/NavigationService.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:objectbox/objectbox.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:win32/win32.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:path/path.dart' as p;

String getUserName() {
  const usernameLength = 256;
  final pcbBuffer = calloc<DWORD>()..value = usernameLength + 1;
  final lpBuffer = wsalloc(usernameLength + 1);

  try {
    final result = GetUserName(lpBuffer, pcbBuffer);
    if (result != 0) {
      return lpBuffer.toDartString();
    } else {
      throw WindowsException(HRESULT_FROM_WIN32(GetLastError()));
    }
  } finally {
    free(pcbBuffer);
    free(lpBuffer);
  }
}

String getComputerName() {
  final nameLength = calloc<DWORD>();
  String name;

  GetComputerNameEx(COMPUTER_NAME_FORMAT.ComputerNameDnsFullyQualified, nullptr, nameLength);

  final namePtr = wsalloc(nameLength.value);

  try {
    final result = GetComputerNameEx(
        COMPUTER_NAME_FORMAT.ComputerNameDnsFullyQualified,
        namePtr,
        nameLength);

    if (result != 0) {
      name = namePtr.toDartString();
    } else {
      throw WindowsException(HRESULT_FROM_WIN32(GetLastError()));
    }
  } finally {
    free(namePtr);
    free(nameLength);
  }
  return name;
}

Color getColor(int index){
  List<Color> c = [
    const Color(0xffea4b49),
    const Color(0xfff88749),
    const Color(0xfff8be46),
    const Color(0xff89c54d),
    const Color(0xff48bff9),
    const Color(0xff5b93fd),
    const Color(0xff9c6efb)
  ];
  return c[index % c.length];
}

const _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
Random _rnd = Random();
String getRandomString(int length) => String.fromCharCodes(Iterable.generate(length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

int getRandomInt(int min, int max) {
  return min + _rnd.nextInt(max - min);
}

// FS
Future<Uint8List> readAsBytesSync(String path) async {
  return File(path).readAsBytesSync();
}

// TODO Rewrite this stupid shit
GenerationParams? parseSDParameters(String rawData, {bool onlyParams = false}){
  try{
    RegExp ex = RegExp(r'\s*(\w[\w \-/]+):\s*("(?:\\.|[^\\"])+"|[^,]*)(?:,|$)');

    Map<String, Object> gp = <String, Object>{};

    // Generation params
    List<String> lines = rawData.trim().split('\n');
    if(lines.length == 1 && lines[0].contains('Steps: ')){
      lines = rawData.trim().split(' Steps:');
      lines.last = 'Steps:${lines.last}';
    }

    bool doneWithPrompt = false;
    bool doneWithNegative = false;
    bool doneWithGenerationParams = false;
    bool doneWithPositiveTemplate = false;
    bool doneWithNegativeTemplate = false;

    String positivePromt = '';
    String negativePromt = '';

    String generationParams = '';

    String positiveTemplate = '';
    String negativeTemplate = '';

    if(!onlyParams){
      for(String line in lines){
        line = line.trim();
        if(line.startsWith('Negative prompt:')){
          doneWithPrompt = true;
          line = line.length != 16 ? line.substring(16+1, line.length).trim() : '';
        }
        if(line.startsWith('Steps:')){
          doneWithPrompt = true;
          doneWithNegative = true;
          line = line.trim();
        }
        if(doneWithPrompt){
          if(line.startsWith('Template:')){
            doneWithNegative = true;
            doneWithGenerationParams = true;
            line = line.length != 9 ? line.substring(9+1, line.length).trim() : '';
          }
          if(!doneWithNegative){
            negativePromt += (negativePromt == "" ? '' : "\n") + line;
          } else {
            if(line.startsWith('Template:')){
              doneWithGenerationParams = true;
              line = line.length != 9 ? line.substring(9+1, line.length).trim() : '';
            }
            if(!doneWithGenerationParams){
              generationParams += (generationParams == "" ? '' : "\n") + line;
            } else {
              if(line.startsWith('Negative Template:')){
                doneWithPositiveTemplate = true;
                line = line.length != 18 ? line.substring(18+1, line.length).trim() : '';
              }
              if(!doneWithPositiveTemplate){
                positiveTemplate += (positiveTemplate == "" ? '' : "\n") + line;
              } else {
                negativeTemplate += (negativeTemplate == "" ? '' : "\n") + line;
              }
            }
          }
        } else {
          positivePromt += (positivePromt == "" ? '' : "\n") + line;
        }
      }
    }

    // print('positivePromt');
    // print(positivePromt);
    // print('negativePromt');
    // print(negativePromt);
    // print('generationParams');
    // print(generationParams);
    // print('positiveTemplate');
    // print(positiveTemplate);
    // print('negativeTemplate');
    // print(negativeTemplate);

    Iterable<RegExpMatch> matches = ex.allMatches(generationParams);

    for (final m in matches) {
      try{
        gp[m[1]!.toLowerCase().replaceAll(RegExp(r' '), '_')] = m[2] ?? 'null';
      } on RangeError catch(e){
        print(e.message);
        print(e.stackTrace);
      }
    }

    bool isRefiner = gp['refiner'] != null;
    bool isUNET = gp['unet'] != null;

    Object? model = gp[isRefiner ? 'refiner' : isUNET ? 'unet' : 'model'];

    //  cinematic, highly detailed

    //  Negative prompt: drawing, painting, crayon, sketch

    //  Steps: 20,
    //  Sampler: DPM++ 2M,
    //  Schedule type: Karras,
    //  CFG scale: 5,
    //  Seed: 802142021,
    //  Size: 1216x832
    //  Model: datassRevFINALPony_final,
    //  FP8 weight: Enable,
    //  Cache FP16 weight for LoRA: True,
    //  Denoising strength: 0.5,
    //  Clip skip: 2,
    //  Style Selector Enabled: True,
    //  Style Selector Randomize: False,
    //  Style Selector Style: Photographic,
    //  Hires prompt: "solo,anthro,(furry:1.2),male focus,felid,black panther,muscular,mature,back muscular,daddy,bathrobe,partially clothed,\ndetailed background,bathroom,\nzPDXL3,photo,realistic,",
    //  Hires negative prompt: "human,(5 toes:1.5),necklace,text,logo,signature,bad hands,bad anatomy,abnormal,",
    //  Hires upscale: 1.5,
    //  Hires upscaler: 4x_foolhardy_Remacri,
    //  Version: v1.10.1
    if(gp.keys.isEmpty) return null;
    GenerationParams gpF;
    try{
      gpF = GenerationParams(
          positive: positivePromt,
          negative: negativePromt,
          steps: int.parse(gp['steps'] as String),
          sampler: gp['sampler'] as String,
          cfgScale: double.parse(gp['cfg_scale'] as String),
          seed: int.parse(gp['seed'] as String),
          size: sizeFromString(gp['size'] as String),
          checkpointType: isRefiner ? CheckpointType.refiner : isUNET ? CheckpointType.unet : gp['model'] != null ? CheckpointType.model : CheckpointType.unknown,
          checkpoint: model != null ? model as String : null,
          checkpointHash: gp['model_hash'] != null ? gp['model_hash'] as String : null,
          vae: gp['vae'] != null ? gp['vae'] as String : null,
          vaeHash: gp['vae_hash'] != null ? gp['vae_hash'] as String : null,
          denoisingStrength: gp['denoising_strength'] != null ? double.parse(gp['denoising_strength'] as String) : null,
          rng: gp['rng'] != null ? gp['rng'] as String : null,
          hiresSampler: gp['hires_sampler'] != null ? gp['hires_sampler'] as String : null,
          hiresUpscaler: gp['hires_upscaler'] != null ? gp['hires_upscaler'] as String : null,
          hiresUpscale: gp['hires_upscale'] != null ? double.parse(gp['hires_upscale'] as String) : null,
          version: gp['version']  != null ? gp['version'] as String : null,
          params: gp,
          rawData: rawData
      );
    } on Exception catch(e){
      print(jsonEncode(gp));
      throw Exception(e);
    }

    return gpF;
  } catch(e, s){
    print(e);
    print(s);
    print(rawData);
    return null;
  }
}

List<dynamic> parseComfUIParameters(String rawData){
  var myData;
  try{
    myData = jsonDecode(rawData);
  } on FormatException catch(e){
    try{
      myData = jsonDecode(rawData.replaceAll('[NaN]', '[]').replaceAll(': NaN', ': []'));
    } on FormatException catch(e){
      print(e);
    }
  }
  if(myData['nodes'] != null){
    // Vanilla ComfUI
    // TODO: Страшная штука, курить много
    return [];
  } else {
    List<dynamic> fi = [];
    List<dynamic> best = [];
    for (String key in myData.keys){
      dynamic d = myData[key];
      String classType = d['class_type'];

      if(['SaveImage'].contains(classType)){
        fi.add(List.from(getImageLine(d, myData).reversed));
      }
    }
    // Find best
    // 1. With max correct nodes
    List<dynamic> test = fi.where((el) => ['SDXL Quick Empty Latent (WLSH)', 'EmptyLatentImage', 'LoadImage', 'VHS_LoadVideo'].contains(el[0]['type']) && el[el.length-1]['type'] == 'SaveImage').toList(growable: false);
    test.sort((a, b) => a.length > b.length ? 0 : 1);
    if(test.isNotEmpty){
      best = test[0];
    } else {
      if (kDebugMode) {
        print('parseComfUIParameters: pizda');
        print(jsonEncode(fi));
      }
    }
    return best;
  }
}

GenerationParams? parseSwarmUIParameters(String rawData, {bool onlyParams = false}){
  try{
    var data = jsonDecode(rawData)['sui_image_params'];

//   {
//       "sui_image_params": {
      //   "prompt": "solo,score_9, score_8_up, score_7_up, light, realistic lighting, by marloncores, FULL-LENGTH PORTRAIT,",
      //   "negativeprompt": "NSFW",
      //   "model": "Indigo_Furry_Mix_XL_-_realistic_beta",
      //   "images": 51,
      //   "seed": 2138144307,
      //   "steps": 50,
      //   "cfgscale": 7,
      //   "aspectratio": "16:9",
      //   "width": 1344,
      //   "height": 1344,
      //   "sampler": "dpmpp_3m_sde_gpu",
      //   "scheduler": "karras",
      //   "initimagecreativity": 0.6,
      //   "maskblur": 4,
      //   "altresolutionheightmultiplier": 1,
      //   "webhooks": "Manual At End",
      //   "internalbackendtype": "comfyui_selfstart",
      //   "wildcardseed": -1,
      //   "colordepth": "16bit",
      //   "automaticvae": true,
      //   "loras": [
        //   "Lora/epi_noiseoffset2",
        //   "Lora/more_details"
      //   ],
      //   "loraweights": [
        //   "1",
        //   "1"
      //   ],
      //   "swarm_version": "0.9.2.3",
      //   "date": "2024-10-03",
      //   "generation_time": "42.31 (prep) and 7.74 (gen) seconds",
      // }
  // }

    Map<String, Object> gp = (data as Map).map((key, value) => MapEntry<String, Object>(key, value));

    GenerationParams gpF = GenerationParams(
        positive: data['prompt'],
        negative: data['negativeprompt'],
        steps: data['steps'],
        sampler: data['sampler'] != null ? data['sampler'] as String : null,
        cfgScale: data['cfgscale'],
        seed: data['seed'],
        size: ImageSize(
          width: data['width'],
          height: data['height']
        ),
        checkpointType: CheckpointType.model,
        checkpoint: data['model'],
        version: data['swarm_version'],
        params: gp,
        rawData: rawData
    );
    return gpF;
  } catch(e, s){
    print(e);
    print(s);
    print(rawData);
    return null;
  }
}

List<dynamic> getImageLine(dynamic el, dynamic data){
  List<dynamic> history = [];
  if(el['class_type'] == 'SaveImage'){
    history.add({
      'type': 'SaveImage',
      'path': el['inputs']['filename_prefix']
    });
    if(el['inputs']['images'] != null){
      findNext(data[el['inputs']['images'][0]], data, history);
    } else {
      suddenEnd(history, el);
    }
  }
  return history;
}

void findNext(dynamic el, dynamic data, List<dynamic> history){
  var inp = el['inputs'];
  switch (el['class_type']) {
    case 'UltimateSDUpscale':
      nextOrEnd(el, data, history, nextKey: 'image', nodeName: 'UltimateSDUpscale');
      break;
    case 'ImageUpscaleWithModel':
      nextOrEnd(el, data, history, nextKey: 'image', nodeName: 'ImageUpscaleWithModel');
      break;
    case 'VAEDecodeTiled':
      nextOrEnd(el, data, history, nextKey: 'samples', nodeName: 'VAEDecodeTiled');
      break;
    case 'KSampler':
      nextOrEnd(el, data, history, nextKey: 'latent_image', nodeName: 'KSampler');
      break;
    case 'KSamplerAdvanced':
      nextOrEnd(el, data, history, nextKey: 'latent_image', nodeName: 'KSamplerAdvanced');
      break;
    case 'KSampler_A1111':
      nextOrEnd(el, data, history, nextKey: 'latent_image', nodeName: 'KSampler_A1111');
      break;
    case 'VAEEncodeTiled':
      nextOrEnd(el, data, history, nextKey: 'pixels', nodeName: 'VAEEncodeTiled');
      break;
    case 'VAEDecode':
      nextOrEnd(el, data, history, nextKey: 'samples', nodeName: 'VAEDecode');
      break;
    case 'VAEEncode':
      nextOrEnd(el, data, history, nextKey: 'pixels', nodeName: 'VAEEncode');
      break;
    case 'SamplerCustomAdvanced':
      nextOrEnd(el, data, history, nextKey: 'latent_image', nodeName: 'SamplerCustomAdvanced');
      break;
    case 'NNLatentUpscale':
      nextOrEnd(el, data, history, nextKey: 'latent', nodeName: 'NNLatentUpscale');
      break;
    case 'SamplerCustom':
      nextOrEnd(el, data, history, nextKey: 'latent_image', nodeName: 'SamplerCustom');
      break;
    case 'ImageScale':
      nextOrEnd(el, data, history, nextKey: 'image', nodeName: 'ImageScale');
      break;
    //starters
    case 'EmptyLatentImage':
      history.add(fillMap(data, inp, '', 'EmptyLatentImage'));
      break;
    case 'SDXL Quick Empty Latent (WLSH)':
      history.add(fillMap(data, inp, '', 'SDXL Quick Empty Latent (WLSH)'));
      break;
    case 'LoadImage':
      history.add(fillMap(data, inp, '', 'LoadImage'));
      break;
    case 'VHS_LoadVideo':
      history.add(fillMap(data, inp, '', 'VHS_LoadVideo'));
      break;
    // other
    case 'FaceDetailer':
      history.add(fillMap(data, inp, '', 'FaceDetailer'));
      findNext(data[inp['image'][0]], data, history);
      break;
    default:
      history.add({
        'type': 'next_not_found',
        'classType': el['class_type'],
        'data': inp
      });
  }
}

void nextOrEnd(dynamic el, dynamic data, List<dynamic> history, {required String nextKey, required String nodeName}){
  var inp = el['inputs'];
  if(inp[nextKey] != null){
    history.add(fillMap(data, inp, nextKey, nodeName));
    findNext(data[inp[nextKey][0]], data, history);
  } else {
    suddenEnd(history, el);
  }
}

void suddenEnd(dynamic history, dynamic el){
  history.add({
    'type': 'sudden_end',
    'classType': el['class_type'],
    'data': el['inputs']
  });
}

Map<String, dynamic> fillMap(data, input, key, action){
  var temp = {'type': action};
  for(String _key in input.keys){
    if(_key == key) continue;
    temp[normalizeKey(_key)] = vilkaIliJopa(data, input[_key]);
  }
  return temp;
}

String normalizeKey(String key){
  List<String> kw = key.split('');
  kw.asMap().forEach((i, e) {
    kw[i] = i-1 == -1 ? e : kw[i-1] == '_' ? e.toUpperCase(): e;
  });
  return kw.where((e) => e != '_').join('');
}

dynamic vilkaIliJopa(dynamic data, dynamic check){ // dynamic vilka Ili Jopa - ;D
  if(check == null) return null;
  if((check.runtimeType == List<dynamic>) && check.length == 2 && check[0].runtimeType == String){
    return findEnd(data[check[0]], data);
  } else {
    return check;
  }
}

dynamic findEnd(dynamic node, dynamic data){
  var inp = node['inputs'];
  switch (node['class_type']) {
    case 'CLIPTextEncode':
      return inp['text'];
    case 'Text Multiline':
      return inp['text'];
    case 'CLIPTextEncodeSDXL':
      return inp['text_g'].runtimeType == String ? inp['text_g'] : findEnd(data[inp['text_g'][0]], data);
    case 'CLIPTextEncodeSDXLRefiner':
      return inp['text'].runtimeType == String ? inp['text'] : findEnd(data[inp['text'][0]], data);
    case 'BNK_CLIPTextEncodeAdvanced':
      return inp['text'];
    case 'Simple String Combine (WLSH)':
      // https://comfy.icu/node/Simple-String-Combine-WLSH
      String addition = vilkaIliJopa(data, inp['addition']);
      String main = vilkaIliJopa(data, inp['input_string']);
      String separator = inp['separator'] == 'comma' ? ',' : inp['separator'] == 'space' ? ' ' : inp['separator'] == 'newline' ? '\n' : '';
      return inp['placement'] == 'before' ? '$main$separator$addition' : '$addition$separator$main';
    case 'CheckpointLoaderSimple':
      return inp['ckpt_name'];
    case 'VAELoader':
      return inp['vae_name'];
    case 'UpscaleModelLoader':
      return inp['model_name'];
    case 'LoraTagLoader':
      List<String> fi = [inp['text']];
      loraStack(fi, data[inp['model'][0]], data);
      return List.from(fi.reversed);
    case 'LoraLoader':
      List<String> fi = [inp['lora_name']];
      loraStack(fi, data[inp['model'][0]], data);
      return List.from(fi.reversed);
    case 'SAMLoader':
      return {
        'modelName': inp['model_name'],
        'deviceMode': inp['device_mode']
      };
    default:
      return node['class_type'];
  }
}

void loraStack(List<String> fi, dynamic node, dynamic data){
  var inp = node['inputs'];
  switch (node['class_type']) {
    case 'LoraLoader':
      fi.add('${inp['lora_name']}:${inp['strength_model']}');
      loraStack(fi, data[inp['model'][0]], data);
      break;
    case 'CheckpointLoaderSimple':
      fi.add(inp['ckpt_name']);
      break;
    case 'ECHOCheckpointLoaderSimple':
      fi.add(inp['ckpt_name']);
      break;
    default:
      fi.add('IDK: ${node['class_type']}');
  }
}

// Steps: 35,
// Sampler: Euler a,
// CFG scale: 7,
// Seed: 3658053067,
// Size: 512x512,
// Model hash: 1ac4dcb22c,
// Model: EasyFluffV10.1,
// Denoising strength: 0.42,
// RNG: NV,
// RP Active: True,
// RP Divide mode: Mask,
// RP Matrix submode: Rows,
// RP Mask submode: Mask,
// RP Prompt submode: Prompt,
// RP Calc Mode: Attention,
// RP Ratios: "1,3;2;1,1",
// RP Base Ratios: 0.2,
// RP Use Base: False,
// RP Use Common: True,
// RP Use Ncommon: False,
// RP Options: ["[", "\"", "[", "\""],
// RP LoRA Neg Te Ratios: 0,
// RP LoRA Neg U Ratios: 0,
// RP threshold: 0.4,
// RP LoRA Stop Step: 0,
// RP LoRA Hires Stop Step: 0,
// RP Flip: False,
// Hires sampler: DPM++ 3M SDE,
// Hires upscale: 1.5,
// Hires upscaler: Latent,
// TI hashes: "deformityv6: 8455ec9b3d31, easynegative: c74b4e810b03",
// Version: 1.7.0
@Entity()
class GenerationParams {
  int id;
  final String? positive;
  final String? negative;
  final int? steps;
  final String? sampler;
  final double? cfgScale;
  final int? seed;

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

  @Transient()
  CheckpointType? checkpointType;
  int get dbCheckpointType {
    _ensureCheckpointTypeEnumValues();
    return checkpointType != null ? checkpointType!.index : 0;
  }
  set dbCheckpointType(int value) {
    _ensureCheckpointTypeEnumValues();
    checkpointType = value >= 0 && value < CheckpointType.values.length ? CheckpointType.values[value] : CheckpointType.unknown;
  }

  void _ensureCheckpointTypeEnumValues() {
    assert(CheckpointType.unknown.index == 0);
    assert(CheckpointType.model.index == 1);
    assert(CheckpointType.refiner.index == 2);
    assert(CheckpointType.inpaint.index == 3);
    assert(CheckpointType.unet.index == 4);
  }

  final String? checkpoint;
  final String? checkpointHash;
  final String? vae;
  final String? vaeHash;
  final double? denoisingStrength;
  final String? rng;
  final String? hiresSampler;
  final String? hiresUpscaler;
  final double? hiresUpscale;

  @Transient()
  Map<String, String>? tiHashes;
  String get dbTiHashes {
    return tiHashes != null ? jsonEncode(tiHashes) : '{}';
  }
  set dbTiHashes(String value) {
    try{
      tiHashes = json.decode(value);
    } catch (e) {
      tiHashes = null;
    }
  }

  final String? version;
  final String? rawData;

  @Transient()
  ContentRating rating = ContentRating.G;
  int get dbRating {
    _ensureRatingEnumValues();
    return rating.index;
  }
  set dbRating(int value) {
    _ensureRatingEnumValues();
    rating = value >= 0 && value < ContentRating.values.length ? ContentRating.values[value] : ContentRating.Unknown;
  }
  void _ensureRatingEnumValues() {
    assert(ContentRating.Unknown.index == 0);
    assert(ContentRating.G.index == 1);
    assert(ContentRating.PG.index == 2);
    assert(ContentRating.PG_13.index == 3);
    assert(ContentRating.R.index == 4);
    assert(ContentRating.NC_17.index == 5);
    assert(ContentRating.X.index == 6);
    assert(ContentRating.XXX.index == 7);
  }

  @Transient()
  Map<String, dynamic>? params;
  String get dbParams {
    return params != null ? jsonEncode(params) : '{}';
  }
  set dbParams(String value) {
    try{
      params = json.decode(value);
    } catch (e) {
      params = null;
    }
  }

  GenerationParams({
    this.id = 0,
    this.positive,
    this.negative,
    this.steps,
    this.sampler,
    this.cfgScale,
    this.seed,
    this.size,
    this.checkpointType,
    this.checkpoint,
    this.checkpointHash,
    this.vae,
    this.vaeHash,
    this.denoisingStrength,
    this.rng,
    this.hiresSampler,
    this.hiresUpscaler,
    this.hiresUpscale,
    this.tiHashes,
    this.version,
    this.rawData,
    this.params
  }){
    if(positive != null) rating = NavigationService.navigatorKey.currentContext!.read<DataModel>().contentRatingModule.getContentRating(positive!);
    // if(rawData != null){
    //   GenerationParams? p = parseSDParameters(rawData!, onlyParams: true);
    //   if(p != null){
    //     params = p.params;
    //   }
    // }
  }

  Map<String, dynamic> toMap({bool forDB = false, ImageKey? key, Map<String, dynamic>? amply}) {
    Map<String, dynamic> f = {
      'positive': positive,
      'negative': negative,
      'steps': steps,
      'sampler': sampler,
      'cfgScale': cfgScale,

      'seed': seed,
      'checkpointType': checkpointType?.index ?? null,
      'checkpoint': checkpoint,
      'checkpointHash': checkpointHash,
      'vae': vae,
      'vaeHash': vaeHash,
      'version': version,
    };

    if (!forDB){
      f['size'] = size.toString();
    } else {
      //forDB
      f['sizeW'] = size?.width;
      f['sizeH'] = size?.height;
      if(rawData != null) f['rawData'] = rawData;
      if(params != null) f['params'] = jsonEncode(params);
      if(key != null){
        f['keyup'] = key.keyup;
        f['type'] = key.type.index;
        f['parent'] = key.parent;
        f['fileName'] = key.fileName;
        f['isLocal'] = key.host == null ? 1 : 0;
        f['host'] = key.host;
      } else {
        throw Exception('Пошёл нахуй');
      }
    }

    if (denoisingStrength != null) f['denoisingStrength'] = denoisingStrength;
    if (rng != null) f['rng'] = rng;
    if (hiresSampler != null) f['hiresSampler'] = hiresSampler;
    if (hiresUpscaler != null) f['hiresUpscaler'] = hiresUpscaler;
    if (hiresUpscale != null) f['hiresUpscale'] = hiresUpscale;
    if (tiHashes != null) f['tiHashes'] = tiHashes;

    if(amply != null){
      for(String key in amply.keys) {
        f[key] = amply[key];
      }
    }

    return f;
  }

  String toJsonString(){
    return jsonEncode(toMap());
  }
}

ImageSize sizeFromString(String s){
  final List<String> ar = s.split('x');
  return ImageSize(width: int.parse(ar[0]), height: int.parse(ar[1]));
}

String genPathHash(String path){
  List<int> bytes = utf8.encode(path);
  String hash = sha256.convert(bytes).toString();
  return hash;
}

bool isImage(dynamic file){
  final String e = p.extension(file.path);
  return ['png', 'jpg', 'webp', 'jpeg', 'psd'].contains(e.replaceFirst('.', '').toLowerCase());
}

T? von<T>(x) => x is T ? x : null;

List<String> _image_types = [
  'jpg',
  'jpeg',
  'jfif',
  'pjpeg',
  'pjp',
  'png',
  'svg',
  'gif',
  'apng',
  'webp',
  'avif'
];

bool isImageUrl(String url){
  Uri uri = Uri.parse(url);
  String extension = p.extension(uri.path).toLowerCase();
  if (extension.isNotEmpty) {
    extension = extension.split('.').last;
    if (_image_types.contains(extension)) {
      return true;
    }
  }
  
  if(uri.queryParameters.containsKey('format') && ['png', 'webp', 'jpeg', 'jpg', 'gif'].contains(uri.queryParameters['format'])) return true;
  return false;
}

String cleanUpUrl(String url){
  Uri parse = Uri.parse(url);
  Map<String, String> params = {};
  parse.queryParameters.forEach((key, value) => params[key] = value);
  // Discord
  if(['media.discordapp.net', 'cdn.discordapp.com'].contains(parse.host)){
    params.removeWhere((key, value) => ['format', 'quality', 'width', 'height'].contains(key));
  }
  // Twitter aka X
  if(['pbs.twimg.com'].contains(parse.host)){
    if(params.containsKey('format')){
      params['format'] = 'png';
      params['name'] = '4096x4096';
    }
  }
  params.removeWhere((key, value) => [
    'ysclid', // yandex metric
  ].contains(key));
  Uri newUri = Uri(
    host: parse.host,
    port: parse.port,
    scheme: parse.scheme,
    path: parse.path,
    queryParameters: params
  );
  return newUri.toString();
}

String readableFileSize(int size, {int round = 2, bool base1024 = true}) {
  const List<String> affixes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];

  num divider = base1024 ? 1024 : 1000;

  num runningDivider = divider;
  num runningPreviousDivider = 0;
  int affix = 0;

  while (size >= runningDivider && affix < affixes.length - 1) {
    runningPreviousDivider = runningDivider;
    runningDivider *= divider;
    affix++;
  }

  String result = (runningPreviousDivider == 0 ? size : size / runningPreviousDivider).toStringAsFixed(round);

  if (result.endsWith("0" * round)) result = result.substring(0, result.length - round - 1);

  return "$result ${affixes[affix]}";
}

bool isRaw(dynamic image) => image.runtimeType != ImageMeta;


String aspectRatioFromSize(ImageSize size) => aspectRatio(size.width, size.height);
String aspectRatio(int width, int height){
  int r = _gcd(width, height);
  return '${(width/r).round()}:${(height/r).round()}';
}

int _gcd(int a, int b) {
  return b == 0 ? a : _gcd(b, a%b);
}

dynamic readMetadataFromSafetensors(String path) async {
  RandomAccessFile file = await File(path).open(mode: FileMode.read);
  var main = await file.read(8);
  int metadataLen = bytesToInteger(main);
  var jsonStart = await file.read(2);
  if(!(metadataLen > 2 && ['{"', "{'"].contains(utf8.decode(jsonStart)))){
    return null;
  } else {
    var jsonData = jsonStart + await file.read(metadataLen - 2);
    return utf8.decode(jsonData);
  }
}

int bytesToInteger(List<int> bytes) {
  int value = 0;
  for (var i = 0, length = bytes.length; i < length; i++) {
    value += bytes[i] * pow(256, i).toInt();
  }
  return value;
}

Future<void> showInExplorer(String file) async {
  if(Platform.isWindows){
    Process.run('explorer.exe ', [ '/select,', file]);
  } else {
    final Uri launchUri = Uri(
      scheme: 'file',
      path: file,
    );
    if (await canLaunchUrl(launchUri)) {
      launchUrl(launchUri);
    }
  }
}

Future<bool> isJson(String text) async {
  try{
    await json.decode(text);
    return true;
  } catch (e) {
    return false;
  }
}

Color getRandomColor(){
  return Color((math.Random().nextDouble() * 0xFFFFFF).toInt()).withOpacity(1.0);
}

Color fromHex(String hexString) {
  final buffer = StringBuffer();
  if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
  buffer.write(hexString.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}

List<int> _daysInMonth365 = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

bool isValidDate(int year, int month, int day) {
  if (year < 1 || year > 9999 || month < 0 || month > 11) return false;

  int daysInMonth = _daysInMonth365[month];
  if (month == 1) {
    bool isLeapYear = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
    if (isLeapYear) daysInMonth++;
  }
  return day >= 1 && day <= daysInMonth;
}

bool isValidTime(int hours, int minutes, int seconds) {
  return hours >= 0 && hours < 24
      && minutes >= 0 && minutes < 60
      && seconds >= 0 && seconds < 60;
}

bool isHDR(String profileName){
  return ['ITUR_2100_PQ_FULL'].contains(profileName);
}

bool get isOnDesktopAndWeb {
  if (kIsWeb) {
    return true;
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.macOS:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return true;
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return false;
  }
}

Future<String> getDeviceInfo() async {
  String f = '';

  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  if(Platform.isWindows){
    WindowsDeviceInfo info = await deviceInfo.windowsInfo;
    f += 'Build Lab: ${info.buildLab}\n';
    f += 'Build Lab Ex: ${info.buildLabEx}\n';
    f += 'Build Number: ${info.buildNumber}\n';
    f += 'Computer Name: ${info.computerName}\n';
    f += 'CSD Version: ${info.csdVersion}\n';
    f += 'Device ID: ${info.deviceId}\n';
    f += 'Display Version: ${info.displayVersion}\n';
    f += 'Edition ID: ${info.editionId}\n';
    f += 'Registered Owner: ${info.registeredOwner}\n';
    f += 'Release ID: ${info.releaseId}\n';
    f += 'User Name: ${info.userName}\n';
  } else if(Platform.isAndroid){
    AndroidDeviceInfo info = await deviceInfo.androidInfo;
    f += 'Host: ${info.host}\n';
    f += 'Model: ${info.model}\n';
    if(info.version.baseOS != null) f += 'Version base OS: ${info.version.baseOS}\n';
    f += 'Version codename: ${info.version.codename}\n';
    f += 'Version incremental: ${info.version.incremental}\n';
    if(info.version.previewSdkInt != null) f += 'Version incremental: ${info.version.previewSdkInt}\n';
    f += 'Version release: ${info.version.release}\n';
    f += 'Version sdkInt: ${info.version.sdkInt}\n';
    if(info.version.securityPatch != null) f += 'Version security patch: ${info.version.securityPatch}\n';
    f += 'Type: ${info.type}\n';
    f += 'ID: ${info.id}\n';
    f += 'Device: ${info.device}\n';
    f += 'Board: ${info.board}\n';
    f += 'Bootloader: ${info.bootloader}\n';
    f += 'Display: ${info.display}\n';
    f += 'Fingerprint: ${info.fingerprint}\n';
    f += 'Hardware: ${info.hardware}\n';
    f += 'isLowRamDevice: ${info.isLowRamDevice}\n';
    f += 'isPhysicalDevice: ${info.isPhysicalDevice}\n';
    f += 'Manufacturer: ${info.manufacturer}\n';
    f += 'Product: ${info.product}\n';
    f += 'Serial number: ${false ? info.serialNumber : '***'}\n';
  }
  return f;
}

String normalizePath(String path){
  bool isWindowsPath = path.startsWith('\\\\') || path[1] == ':';
  return p.normalize(isWindowsPath ? path.replaceAll('/', '\\') : path.replaceAll('\\', '/'));
}

Future<List<FileSystemEntity>> dirContents(Directory dir) {
  var files = <FileSystemEntity>[];
  var completer = Completer<List<FileSystemEntity>>();
  var lister = dir.list(recursive: false);
  lister.listen((file) => files.add(file), onDone:() => completer.complete(files));
  return completer.future;
}

Future<int> getDirSize(Directory dir) async {
  var files = await dir.list(recursive: true).toList();
  var dirSize = files.fold(0, (int sum, file) => sum + file.statSync().size);
  return dirSize;
}

String numanizeKey(String key){
  List<String> s = key.split('_');
  s[0] = '${s[0][0].toUpperCase()}${s[0].substring(1).toLowerCase()}';
  return s.join(' ');
}