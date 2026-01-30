import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

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
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:win32/win32.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;
import 'package:psd_sdk/psd_sdk.dart' as psd;
import 'package:http/http.dart' as http;

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

String getRandomStringFromList(List<String> list){
  final random = Random();
  return list[random.nextInt(list.length)];
}

int getRandomInt(int min, int max) {
  return min + _rnd.nextInt(max - min);
}

int getRandomID() {
  return getRandomInt(1000, 100000);
}

// FS
Future<Uint8List> readAsBytesSync(String path) async {
  return File(path).readAsBytesSync();
}

// TODO Rewrite this stupid shit

String? readStealthInfo(Uint8List data) {
  final image = img.decodeImage(data);
  if (image == null) return null;

  final width = image.width;
  final height = image.height;
  final hasAlpha = image.numChannels == 4;

  String? mode; // 'alpha' or 'rgb'
  bool compressed = false;

  final bufferA = StringBuffer();
  final bufferRGB = StringBuffer();

  int indexA = 0;
  int indexRGB = 0;

  bool sigConfirmed = false;
  bool confirmingSignature = true;
  bool readingParamLen = false;
  bool readingParam = false;
  bool readEnd = false;

  int paramLen = 0;
  String binaryData = '';

  const sigAlpha = 'stealth_pnginfo';
  const sigAlphaComp = 'stealth_pngcomp';
  const sigRgb = 'stealth_rgbinfo';
  const sigRgbComp = 'stealth_rgbcomp';

  for (int x = 0; x < width && !readEnd; x++) {
    for (int y = 0; y < height && !readEnd; y++) {
      final pixel = image.getPixel(x, y);

      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();
      final a = hasAlpha ? pixel.a.toInt() : null;

      if (hasAlpha) {
        bufferA.write((a! & 1).toString());
        indexA++;
      }

      bufferRGB
        ..write((r & 1))
        ..write((g & 1))
        ..write((b & 1));
      indexRGB += 3;

      // ── SIGNATURE DETECTION
      if (confirmingSignature) {
        if (indexA == sigAlpha.length * 8) {
          final decoded = _decodeBits(bufferA.toString());
          if (decoded == sigAlpha || decoded == sigAlphaComp) {
            confirmingSignature = false;
            sigConfirmed = true;
            readingParamLen = true;
            mode = 'alpha';
            compressed = decoded == sigAlphaComp;
            bufferA.clear();
            indexA = 0;
            continue;
          }
        }

        if (indexRGB == sigRgb.length * 8) {
          final decoded = _decodeBits(bufferRGB.toString());
          if (decoded == sigRgb || decoded == sigRgbComp) {
            confirmingSignature = false;
            sigConfirmed = true;
            readingParamLen = true;
            mode = 'rgb';
            compressed = decoded == sigRgbComp;
            bufferRGB.clear();
            indexRGB = 0;
            continue;
          }
        }
      }

      // ── READ PARAM LENGTH
      else if (readingParamLen) {
        if (mode == 'alpha' && indexA == 32) {
          paramLen = int.parse(bufferA.toString(), radix: 2);
          bufferA.clear();
          indexA = 0;
          readingParamLen = false;
          readingParam = true;
        } else if (mode == 'rgb' && indexRGB == 33) {
          final lastBit = bufferRGB.toString().substring(bufferRGB.length - 1);
          final bits = bufferRGB.toString().substring(0, bufferRGB.length - 1);
          paramLen = int.parse(bits, radix: 2);
          bufferRGB
            ..clear()
            ..write(lastBit);
          indexRGB = 1;
          readingParamLen = false;
          readingParam = true;
        }
      }

      // ── READ PARAM DATA
      else if (readingParam) {
        if (mode == 'alpha' && indexA == paramLen) {
          binaryData = bufferA.toString();
          readEnd = true;
        } else if (mode == 'rgb' && indexRGB >= paramLen) {
          binaryData = bufferRGB.toString().substring(0, paramLen);
          readEnd = true;
        }
      }
    }
  }

  if (!sigConfirmed || binaryData.isEmpty) return null;

  try {
    final bytes = _binaryToBytes(binaryData);
    if (compressed) {
      return utf8.decode(gzip.decode(bytes));
    } else {
      return utf8.decode(bytes, allowMalformed: true);
    }
  } catch (_) {
    return null;
  }
}

/// Converts "010101..." → String
String _decodeBits(String bits) {
  final bytes = _binaryToBytes(bits);
  return utf8.decode(bytes, allowMalformed: true);
}

/// Converts "010101..." → Uint8List
Uint8List _binaryToBytes(String bits) {
  final byteCount = bits.length ~/ 8;
  final out = Uint8List(byteCount);
  for (int i = 0; i < byteCount; i++) {
    out[i] = int.parse(bits.substring(i * 8, i * 8 + 8), radix: 2);
  }
  return out;
}

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

extension GenerationParamsSql on GenerationParams {

  Map<String, dynamic> toSqlMap({required String imageKeyup}) {
    return {
      'image_keyup': imageKeyup,
      'positive': positive,
      'negative': negative,
      'steps': steps,
      'sampler': sampler,
      'cfgScale': cfgScale,
      'seed': seed,
      'sizeW': size?.width,
      'sizeH': size?.height,
      'checkpointType': dbCheckpointType,
      'checkpoint': checkpoint,
      'checkpointHash': checkpointHash,
      'vae': vae,
      'vaeHash': vaeHash,
      'denoisingStrength': denoisingStrength,
      'rng': rng,
      'hiresSampler': hiresSampler,
      'hiresUpscaler': hiresUpscaler,
      'hiresUpscale': hiresUpscale,
      'tiHashes': dbTiHashes,
      'params': dbParams,
      'rawData': rawData,
      'rating': dbRating,
    };
  }

  static GenerationParams fromSqlMap(Map<String, dynamic> map) {
    final gp = GenerationParams(
      id: map['id'] ?? 0,
      positive: map['positive'],
      negative: map['negative'],
      steps: map['steps'],
      sampler: map['sampler'],
      cfgScale: map['cfgScale'],
      seed: map['seed'],
      checkpoint: map['checkpoint'],
      checkpointHash: map['checkpointHash'],
      vae: map['vae'],
      vaeHash: map['vaeHash'],
      denoisingStrength: map['denoisingStrength'],
      rng: map['rng'],
      hiresSampler: map['hiresSampler'],
      hiresUpscaler: map['hiresUpscaler'],
      hiresUpscale: map['hiresUpscale'],
      version: map['version'],
      rawData: map['rawData'],
    );

    gp.dbCheckpointType = map['checkpointType'] ?? 0;
    gp.dbRating = map['rating'] ?? 0;

    if (map['sizeW'] != null && map['sizeH'] != null) {
      gp.size = ImageSize(
        width: map['sizeW'],
        height: map['sizeH'],
      );
    }

    gp.dbTiHashes = map['tiHashes'] ?? '{}';
    gp.dbParams = map['params'] ?? '{}';

    return gp;
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
    file.close();
    return null;
  } else {
    var jsonData = jsonStart + await file.read(metadataLen - 2);
    file.close();
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

bool isRPCard(dynamic d){
  bool y = false;
  if(d['spec'] != null){
    // yes, character
    if(['2.0', '3.0'].contains(d['spec_version'])){
      y = true;
    }
  } else {
    // spec v1 ?
    if(d['name'] != null && d['first_mes']){
      y = true;
    } else {
      // kobold ?
      if(d['savedsettings'] != null){
        y = true;
      }
    }
  }
  return y;
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

Future<int> getDirSizeIsolated(Directory dir) {
  return compute(_dirSizeWorker, dir.path);
}

Future<int> _dirSizeWorker(String path) async {
  int total = 0;
  final dir = Directory(path);

  await for (final entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is File) {
      try {
        total += (await entity.stat()).size;
      } catch (_) {}
    }
  }

  return total;
}


Future<int> getDirSize(Directory dir) async {
  int totalSize = 0;

  await for (final entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is File) {
      try {
        final stat = await entity.stat();
        totalSize += stat.size;
      } catch (_) {
        // ignore unreadable files
      }
    }
  }

  return totalSize;
}


String numanizeKey(String key){
  List<String> s = key.split('_');
  s[0] = '${s[0][0].toUpperCase()}${s[0].substring(1).toLowerCase()}';
  return s.join(' ');
}

List<double> rgb2cmyk(int r, int g, int b) {
  double computedC = 0;
  double computedM = 0;
  double computedY = 0;

  if (r < 0 || g < 0 || b < 0 || r > 255 || g > 255 || b > 255) {
    throw Exception('RGB values must be in the range 0 to 255.');
  }

  if (r == 0 && g == 0 && b == 0) {
    return [0, 0, 0, 1];
  }

  computedC = 1 - (r / 255);
  computedM = 1 - (g / 255);
  computedY = 1 - (b / 255);

  var minCMY = math.min(computedC, math.min(computedM, computedY));
  return [
    ((computedC - minCMY) / (1 - minCMY) * 100).roundToDouble(),
    ((computedM - minCMY) / (1 - minCMY) * 100).roundToDouble(),
    ((computedY - minCMY) / (1 - minCMY) * 100).roundToDouble(),
    (minCMY * 100)
  ];
}

List<int> cmykToRgb(double c, double m, double y, double k) {
  if(c == 0 && m == 0 && y == 0 && k == 1) return [0, 0, 0];
  int r = (255 * (1 - c / 100.0) * (1 - k / 100.0)).round();
  int g = ((255 * (1 - m / 100.0) * (1 - k / 100.0))).round();
  int b = ((255 * (1 - y / 100.0) * (1 - k / 100.0))).round();

  return [r, g, b];
}

int getPsValue(double p, List<num> list) {
  if (p == 0) return list[0].toInt();
  var kIndex = (list.length * (p / 100)).ceil() - 1;
  return list[kIndex].toInt();
}

int percentile(double pro, List<num> list) {

  List<num> newList = List<num>.from(list);
  newList.sort((a, b) {
    a = a.isNaN ? -0x8000000000000000 : a;
    b = b.isNaN ? -0x8000000000000000 : b;

    if (a > b) return 1;
    if (a < b) return -1;

    return 0;
  });

  return getPsValue(pro, newList);
}

img.Image psdToImageData(Uint8List fileBytes){
  psd.File psdFile = psd.File.fromByteData(fileBytes);
  psd.Document document = psd.Document.fromFile(psdFile);
  final sec = document.parseImageDataSection(psdFile)!.getInterleavedImage();

  final image = img.Image(width: document.width!, height: document.height!);

  if(document.channelCount == 3){
    for (var i = 0; i < document.height!; ++i) {
      for (var j = 0; j < document.width!; ++j) {
        final r = sec![(i * document.width! + j) * 4 + 0];
        final g = sec[(i * document.width! + j) * 4 + 1];
        final b = sec[(i * document.width! + j) * 4 + 2];

        image.getPixel(j, i).setRgb(r, g, b);
      }
    }
  } else {
    for (var i = 0; i < document.height!; ++i) {
      for (var j = 0; j < document.width!; ++j) {
        final r = sec![(i * document.width! + j) * 4 + 0];
        final g = sec[(i * document.width! + j) * 4 + 1];
        final b = sec[(i * document.width! + j) * 4 + 2];
        final a = sec[(i * document.width! + j) * 4 + 3];
        image.getPixel(j, i).setRgba(r, g, b, a);
      }
    }
  }
  return image;
}

Future<Uint8List> stripExif(Uint8List originalBytes) async {
  var image = img.decodeImage(originalBytes);
  image = img.bakeOrientation(image!);
  final bytesWithExif = img.encodeJpg(image);

  const int APP1 = 0xFFE1; // segment of EXIF data

  final strippedImage = <int>[];

  int i = 0;
  int end;
  while (i < bytesWithExif.length) {
    // segment length is encoded on bytes 2 and 3 of the segment
    int segmentLength = (bytesWithExif[i + 2] << 8) + bytesWithExif[i + 3];

    if (bytesWithExif[i] == 0xFF && bytesWithExif[i + 1] == APP1) {
      // Skip APP1 segment
      i += 2 + segmentLength;
    } else {
      // Add segment to new image
      end = min(i + 2 + segmentLength, bytesWithExif.length);
      strippedImage.addAll(bytesWithExif.sublist(i, end));
      i += 2 + segmentLength;
    }
  }

  return Uint8List.fromList(strippedImage);
}

double percentFromNum(double percent, double num) {
  return (percent / 100) * num;
}

Uint8List fixPng(Uint8List fileContent) {
  final pngSignature = <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A
  ];

  if (fileContent.length < 8) {
    throw Exception('Not a PNG file');
  }

  for (int i = 0; i < 8; i++) {
    if (fileContent[i] != pngSignature[i]) {
      throw Exception('Not a PNG file');
    }
  }

  int offset = 8;
  Uint8List? ihdr;
  final idatData = <int>[];
  final otherChunks = <int>[];

  while (offset + 8 <= fileContent.length) {
    final length = ByteData.sublistView(fileContent, offset, offset + 4)
        .getUint32(0, Endian.big);

    final type = ascii.decode(
        fileContent.sublist(offset + 4, offset + 8));

    final dataStart = offset + 8;
    final dataEnd = dataStart + length;

    if (dataEnd + 4 > fileContent.length) break;

    final data = fileContent.sublist(dataStart, dataEnd);

    if (type == 'IHDR') {
      ihdr = Uint8List.fromList(data);
    } else if (type == 'IDAT') {
      idatData.addAll(data);
    } else if (type != 'IEND') {
      otherChunks.addAll(_makeChunk(type, data));
    }

    offset = dataEnd + 4;
  }

  if (ihdr == null) {
    throw Exception('Missing IHDR');
  }

  final bd = ByteData.sublistView(ihdr);
  final width = bd.getUint32(0, Endian.big);
  final height = bd.getUint32(4, Endian.big);
  final bitDepth = ihdr[8];
  final colorType = ihdr[9];
  final interlace = ihdr[12];

  if (interlace != 0) {
    throw Exception('Interlaced PNG not supported');
  }
  if (!(colorType == 2 || colorType == 6)) {
    throw Exception('Unsupported color type');
  }
  if (!(bitDepth == 8 || bitDepth == 10)) {
    throw Exception('Unsupported bit depth');
  }

  final channels = colorType == 6 ? 4 : 3;
  final bytesPerChannel = bitDepth > 8 ? 2 : 1;
  final bytesPerPixel = channels * bytesPerChannel;
  final rowSize = 1 + width * bytesPerPixel;
  final expectedSize = rowSize * height;

  // --- PARTIAL ZLIB DECOMPRESSION ---
  final inflated = <int>[];
  try {
    final decoder = ZLibDecoder();
    inflated.addAll(decoder.convert(idatData));
  } catch (_) {
    // tolerate truncated stream
  }

  final validRows = inflated.length ~/ rowSize;
  final recovered = Uint8List(expectedSize);

  // copy valid rows
  final copyLength = validRows * rowSize;
  for (int i = 0; i < copyLength; i++) {
    recovered[i] = inflated[i];
  }

  // fix filter bytes
  for (int y = 0; y < validRows; y++) {
    final idx = y * rowSize;
    if (recovered[idx] > 4) {
      recovered[idx] = 0;
    }
  }

  // pad missing rows
  for (int y = validRows; y < height; y++) {
    recovered[y * rowSize] = 0;
  }

  final compressed = ZLibEncoder().convert(recovered);

  final output = <int>[];
  output.addAll(pngSignature);
  output.addAll(_makeChunk('IHDR', ihdr));
  output.addAll(otherChunks);
  output.addAll(_makeChunk('IDAT', Uint8List.fromList(compressed)));
  output.addAll(_makeChunk('IEND', Uint8List(0)));

  return Uint8List.fromList(output);
}

Uint8List _makeChunk(String type, Uint8List data) {
  final typeBytes = ascii.encode(type);
  final length = ByteData(4)..setUint32(0, data.length, Endian.big);

  final crcInput = <int>[]..addAll(typeBytes)..addAll(data);
  final crc = _crc32(crcInput);
  final crcBytes = ByteData(4)..setUint32(0, crc, Endian.big);

  return Uint8List.fromList([
    ...length.buffer.asUint8List(),
    ...typeBytes,
    ...data,
    ...crcBytes.buffer.asUint8List(),
  ]);
}

int _crc32(List<int> data) {
  const poly = 0xEDB88320;
  int crc = 0xFFFFFFFF;

  for (final b in data) {
    crc ^= b;
    for (int i = 0; i < 8; i++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ poly : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}


// Uint8List fixPng(Uint8List data) {
//   const pngSig = [
//     0x89, 0x50, 0x4E, 0x47,
//     0x0D, 0x0A, 0x1A, 0x0A
//   ];
//
//   if (data.length < 8) {
//     throw ArgumentError('Not a PNG');
//   }
//
//   for (int i = 0; i < 8; i++) {
//     if (data[i] != pngSig[i]) {
//       throw ArgumentError('Not a PNG');
//     }
//   }
//
//   int offset = 8;
//   Uint8List? ihdr;
//   final idatParts = <Uint8List>[];
//   final otherChunks = <Uint8List>[];
//
//   while (offset + 8 <= data.length) {
//     final length = _readU32(data, offset);
//     final type =
//     ascii.decode(data.sublist(offset + 4, offset + 8));
//     final start = offset + 8;
//     final end = start + length;
//
//     if (end + 4 > data.length) break;
//
//     final chunkData = data.sublist(start, end);
//
//     if (type == 'IHDR') {
//       ihdr = chunkData;
//     } else if (type == 'IDAT') {
//       idatParts.add(chunkData);
//     } else if (type != 'IEND') {
//       otherChunks.add(_makeChunk(type, chunkData));
//     }
//
//     offset = end + 4;
//   }
//
//   if (ihdr == null) {
//     throw StateError('Missing IHDR');
//   }
//
//   final width = _readU32(ihdr!, 0);
//   final height = _readU32(ihdr!, 4);
//   final bitDepth = ihdr![8];
//   final colorType = ihdr![9];
//   final interlace = ihdr![12];
//
//   if (interlace != 0) {
//     throw UnsupportedError('Interlaced PNG not supported');
//   }
//   if (bitDepth != 8 && bitDepth != 10) {
//     throw UnsupportedError('Unsupported bit depth');
//   }
//   if (colorType != 2 && colorType != 6) {
//     throw UnsupportedError('Unsupported color type');
//   }
//
//   final channels = colorType == 6 ? 4 : 3;
//   final bytesPerChannel = bitDepth > 8 ? 2 : 1;
//   final rowSize =
//       1 + width * channels * bytesPerChannel;
//   final expectedSize = rowSize * height;
//
//   // --- Partial zlib inflate ---
//   final inflated = _inflatePartial(_concat(idatParts));
//
//   final validRows = inflated.length ~/ rowSize;
//   final recovered = Uint8List(expectedSize);
//
//   recovered.setRange(
//     0,
//     validRows * rowSize,
//     inflated,
//   );
//
//   // Fill missing rows
//   for (int y = validRows; y < height; y++) {
//     recovered[y * rowSize] = 0x00; // filter byte
//   }
//
//   final compressed = Uint8List.fromList(
//     ZLibEncoder().convert(recovered),
//   );
//
//   final out = BytesBuilder();
//   out.add(pngSig);
//   out.add(_makeChunk('IHDR', ihdr!));
//   for (final c in otherChunks) out.add(c);
//   out.add(_makeChunk('IDAT', compressed));
//   out.add(_makeChunk('IEND', Uint8List(0)));
//
//   return out.toBytes();
// }
//
// Uint8List _inflatePartial(Uint8List input) {
//   final output = BytesBuilder();
//
//   final decoder = ZLibDecoder();
//   final sink = decoder.startChunkedConversion(
//     ByteConversionSink.withCallback((bytes) {
//       output.add(bytes);
//     }),
//   );
//
//   try {
//     sink.add(input);
//     sink.close();
//   } catch (_) {
//     // Ignore zlib errors — keep partial output
//   }
//
//   return output.toBytes();
// }
//
//
// int _readU32(Uint8List b, int o) =>
//     (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
//
// Uint8List _u32(int n) => Uint8List.fromList([
//   (n >> 24) & 0xff,
//   (n >> 16) & 0xff,
//   (n >> 8) & 0xff,
//   n & 0xff
// ]);
//
// Uint8List _makeChunk(String type, Uint8List data) {
//   final typeBytes = ascii.encode(type);
//   final crc = _crc32([...typeBytes, ...data]);
//   return Uint8List.fromList([
//     ..._u32(data.length),
//     ...typeBytes,
//     ...data,
//     ..._u32(crc),
//   ]);
// }
//
// Uint8List _concat(List<Uint8List> parts) {
//   final b = BytesBuilder();
//   for (final p in parts) b.add(p);
//   return b.toBytes();
// }
//
// int _crc32(List<int> data) {
//   const poly = 0xEDB88320;
//   int crc = 0xFFFFFFFF;
//
//   for (final b in data) {
//     crc ^= b;
//     for (int i = 0; i < 8; i++) {
//       crc = (crc & 1) != 0 ? (crc >> 1) ^ poly : crc >> 1;
//     }
//   }
//   return crc ^ 0xFFFFFFFF;
// }

Future<void> downloadToDownloadFolder(String fileName, String uri) async {
  dynamic appDownloadDir = await getDownloadsDirectory();
  if(appDownloadDir != null) appDownloadDir = appDownloadDir.path;
  String pa = p.join(appDownloadDir, fileName);
  File f = File(pa);
  if(!f.existsSync()) f.deleteSync();
  String clean = cleanUpUrl(uri);
  http.Response res = await http.get(Uri.parse(clean));
  if(res.statusCode == 200){
    await f.writeAsBytes(res.bodyBytes);
  }
}

Future<void> changeLoraOutputNameMeta(String path, String name) async{
  // int count = 123123;
  // Uint32List list = Uint32List(8)..buffer.asInt32List()[0] = count;
  //
  // Uint32List uint32 = Uint32List.view(list.buffer);
  // print(uint32[0]);

  File file = File(path);
  RandomAccessFile randomAccessFile = await file.open(mode: FileMode.read);
  Uint8List metadataLen = await randomAccessFile.read(8);
  Uint32List uint32 = Uint32List.view(metadataLen.buffer);
  int metaLength = uint32[0];
  Uint8List chunk = await randomAccessFile.read(metaLength);
  randomAccessFile.close();
  String value = utf8.decode(chunk);
  var data = jsonDecode(value);
  if(data['__metadata__'] != null) {
    if (data['__metadata__']['ss_output_name'] != null) {
      data['__metadata__']['ss_output_name'] = name.replaceAll(' ', '_');
    }
    if(data['__metadata__']['modelspec.title'] != null){
      data['__metadata__']['modelspec.title'] = name.replaceAll(' ', '_');
    }
  }
  String finalData = json.encode(data);
  Uint8List newDataLength = Uint8List(8)..buffer.asInt32List()[0] = finalData.length;

  List<int> content = List<int>.from(await file.readAsBytes(), growable: true);
  content.replaceRange(0, 8+metaLength, Uint8List.fromList([
    ...newDataLength,
    ...utf8.encode(finalData)
  ]));
  randomAccessFile.close();
  await file.writeAsBytes(content);
}

double getAspectRatio(img.Image image) {

  int w = image.width;
  int h = image.height;

  double aspectRatio;

  if (w > h) {
    aspectRatio = w / h;
  } else {
    aspectRatio = h / w;
  }

  return aspectRatio;
}