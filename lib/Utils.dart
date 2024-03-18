import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cimagen/utils/ImageManager.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';

class ConfigManager with ChangeNotifier {
  //init
  Map<String, dynamic> _json = <String, dynamic>{};
  int _count = 0;

  //Getter
  int get count => _count;
  Map<String, dynamic> get config => _json;

  Future<void> init() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String sdWebuiFolder = (prefs.getString('sd_webui_folter') ?? '');
    if(sdWebuiFolder != ''){
      final String response = File('$sdWebuiFolder/config.json').readAsStringSync();
      final data = await json.decode(response);
      _json = data;
    }
  }

  void increment() {
    _count++;
  }
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

// FS
Future<Uint8List> readAsBytesSync(String path) async {
  return File(path).readAsBytesSync();
}

GenerationParams? parseSDParameters(String rawData){
  Map<String, Object> gp = <String, Object>{};

  // Positive
  RegExp posReg = RegExp(r'\b ([\s\S]*?)(?=\nNegative prompt\b)');
  String? posMatch = posReg.firstMatch(rawData)?.group(1)?.trim();
  // Negative
  RegExp negReg = RegExp(r'\bNegative prompt: ([\s\S]*?)(?=\nSteps: \b)');
  String? negMatch = negReg.firstMatch(rawData)?.group(1)?.trim();
  // Generation params
  RegExp regExp = RegExp(r'(Steps[\s\S].*)');
  String? genMatch = regExp.firstMatch(rawData)?.group(1)?.trim();

  if(posMatch != null && negMatch != null && genMatch != null){
    Iterable<RegExpMatch> matches = RegExp(r'\s*(\w[\w \-/]+):\s*("(?:\\.|[^\\"])+"|[^,]*)(?:,|$)').allMatches(genMatch);
    for (final m in matches) {
      try{
        gp.putIfAbsent(m[1]!.toLowerCase().replaceAll(RegExp(r' '), '_'), () => m[2] ?? 'null');
      } on RangeError catch(e){
        print(e.message);
        print(e.stackTrace);
        print(genMatch);
      }
    }

    print(gp);

    return GenerationParams(
      positive: posMatch,
      negative: negMatch,
      steps: int.parse(gp['steps'] as String),
      sampler: gp['sampler'] as String,
      cfgScale: double.parse(gp['cfg_scale'] as String),
      seed: int.parse(gp['seed'] as String),
      size: sizeFromString(gp['size'] as String),
      modelHash: gp['model_hash'] as String,
      model: gp['model'] as String,
      denoisingStrength: gp['denoising_strength'] != null ? double.parse(gp['denoising_strength'] as String) : null,
      rng: gp['rng'] != null ? gp['rng'] as String : null,
      hiresSampler: gp['hires_sampler'] != null ? gp['hires_sampler'] as String : null,
      hiresUpscaler: gp['hires_upscaler'] != null ? gp['hires_upscaler'] as String : null,
      hiresUpscale: gp['hires_upscale'] != null ? double.parse(gp['hires_upscale'] as String) : null,
      version: gp['version'] as String,
      rawData: rawData
    );
  } else {
    return null;
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
class GenerationParams {
  final String positive;
  final String negative;
  final int steps;
  final String sampler;
  final double cfgScale;
  final int seed;
  final ImageSize size;
  final String modelHash;
  final String model;
  final double? denoisingStrength;
  final String? rng;
  final String? hiresSampler;
  final String? hiresUpscaler;
  final double? hiresUpscale;
  final Map<String, String>? tiHashes;
  final String version;
  final String? rawData;

  const GenerationParams({
    required this.positive,
    required this.negative,
    required this.steps,
    required this.sampler,
    required this.cfgScale,
    required this.seed,
    required this.size,
    required this.modelHash,
    required this.model,
    this.denoisingStrength,
    this.rng,
    this.hiresSampler,
    this.hiresUpscaler,
    this.hiresUpscale,
    this.tiHashes,
    required this.version,
    this.rawData,
  });

  Map<String, dynamic> toMap({bool forDB = false, ImageKey? key, Map<String, dynamic>? amply}) {
    Map<String, dynamic> f = {
      'positive': positive,
      'negative': negative,
      'steps': steps,
      'sampler': sampler,
      'cfgScale': cfgScale,

      'seed': seed,
      'modelHash': modelHash,
      'model': model,
      'version': version,
    };

    if (!forDB){
      f['size'] = size.toString();
    } else {
      //forDB
      f['sizeW'] = size.width;
      f['sizeH'] = size.height;
      if(rawData != null) f['rawData'] = rawData;
      if(key != null){
        f['keyup'] = key.keyup;
        f['type'] = key.type.index;
        f['parent'] = key.parent;
        f['fileName'] = key.fileName;
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
  return ['png', 'jpg', 'webp', 'jpeg'].contains(e.replaceFirst('.', ''));
}

String readableFileSize(int size, {bool base1024 = true}) {
  final base = base1024 ? 1024 : 1000;
  if (size <= 0) return "0";
  final units = ["B", "kB", "MB", "GB", "TB"];
  int digitGroups = (log(size) / log(base)).round();
  return "${NumberFormat("#,##0.#").format(size / pow(base, digitGroups))}${units[digitGroups]}";
}

bool isRaw(dynamic image) => image.runtimeType != ImageMeta;