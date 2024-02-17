import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConfigManager with ChangeNotifier {
  //init
  Map<String, dynamic> _json = <String, dynamic>{};
  int _count = 0;

  //Getter
  int get count => _count;
  Map<String, dynamic> get config => _json;

  Future<void> init() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String sd_webui_folter = (prefs.getString('sd_webui_folter') ?? '');
    if(sd_webui_folter != ''){
      final String response = File(sd_webui_folter+'/config.json').readAsStringSync();
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

GenerationParams? parseSDParameters(String text){
  Map<String, Object> gp = <String, Object>{};

  int? seed = 0;
  String sampler = 'none';

  // Positive
  RegExp posReg = RegExp(r'\b ([\s\S]*?)(?=\nNegative prompt\b)');
  String? posMatch = posReg.firstMatch(text)?.group(1)?.trim();
  // Negative
  RegExp negReg = RegExp(r'\bNegative prompt: ([\s\S]*?)(?=\nSteps: \b)');
  String? negMatch = negReg.firstMatch(text)?.group(1)?.trim();
  // Generation params
  RegExp regExp = RegExp(r'(Steps[\s\S].*)');
  String? genMatch = regExp.firstMatch(text)?.group(1)?.trim();

  if(posMatch != null && negMatch != null && genMatch != null){
    Iterable<RegExpMatch> matches = RegExp(r'\s*(\w[\w \-\/]+):\s*("(?:\\.|[^\\"])+"|[^,]*)(?:,|$)').allMatches(genMatch);
    for (final m in matches) {
      try{
        gp.putIfAbsent(m[1]!.toLowerCase().replaceAll(RegExp(r' '), '_'), () => m[2] ?? 'null');
      } on RangeError catch(e){
        print(e.message);
        print(e.stackTrace);
        print(genMatch);
      }
    }

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
      hiresUpscale: gp['hires_upscale'] != null ? double.parse(gp['hires_upscale'] as String) : null,
      version: gp['version'] as String,
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
  final Size size;
  final String modelHash;
  final String model;
  final double? denoisingStrength;
  final String? rng;
  final String? hiresSampler;
  final double? hiresUpscale;
  final Map<String, String>? tiHashes;
  final String version;

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
    this.hiresUpscale,
    this.tiHashes,
    required this.version
  });

  Map<String, dynamic> toMap() {
    Map<String, dynamic> f = {
      'positive': positive,
      'negative': negative,
      'steps': steps,
      'sampler': sampler,
      'cfgScale': cfgScale,

      'seed': seed,
      'size': size.toString(),
      'modelHash': modelHash,
      'model': model,
      'version': version,
    };

    if (denoisingStrength != null) f['denoisingStrength'] = denoisingStrength;
    if (rng != null) f['rng'] = rng;
    if (hiresSampler != null) f['hiresSampler'] = hiresSampler;
    if (hiresUpscale != null) f['hiresUpscale'] = hiresUpscale;
    if (tiHashes != null) f['tiHashes'] = tiHashes;

    return f;
  }

  String toJsonString(){
    return jsonEncode(toMap());
  }
}

Size sizeFromString(String s){
  final List<String> ar = s.split('x');
  return Size(width: int.parse(ar[0]), height: int.parse(ar[1]));
}

class Size {
  final int width;
  final int height;

  const Size({
    required this.width,
    required this.height
  });

  String toString(){
    return '${width}x$height';
  }

  int totalPixels(){
    return width*height;
  }

  double aspectRatio(){
    return width / height;
  }
}