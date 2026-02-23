import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:cimagen/Utils.dart';
import 'package:cimagen/modules/AudioController.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:external_path/external_path.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../pages/sub/PromptAnalyzer.dart';

import 'package:path/path.dart' as p;

import '../main.dart';
import 'ColorUtils.dart';

class DataModel with ChangeNotifier {
  late Function jumpToTab;

  void notify(){
    notifyListeners();
  }

  ComparisonBlock comparisonBlock = ComparisonBlock();
  TimelineBlock timelineBlock = TimelineBlock();
  ContentRatingModule contentRatingModule = ContentRatingModule();

  DataModel() {
    comparisonBlock.changeNotify(notify);
    timelineBlock.changeNotify(notify);
    contentRatingModule.loadCRTags();
  }
}

class ComparisonBlock {
  ImageMeta? firstSelected;
  Uint8List? firstCache; // НЕ ТРОГАТЬ УЕБУ - потому-что с него читается изображение
  img.Image? firstDecoded; // НЕ ТРОГАТЬ УЕБУ
  Map<String, Uint8List> firstProcessed = {};
  ImageSize? firstImageSize;

  ImageMeta? secondSelected;
  Uint8List? secondCache; // НЕ ТРОГАТЬ УЕБУ
  img.Image? secondDecoded; // НЕ ТРОГАТЬ УЕБУ - потому-что с него читается изображение
  Map<String, Uint8List> secondProcessed = {};
  ImageSize? secondImageSize;

  late Function notify;

  void changeNotify(Function f){
    notify = f;
  }

  List<ImageMeta> _images = [];

  List<ImageMeta> get getImages => _images;

  void addAllImages(List<ImageMeta> images){
    _images.clear();
    _images.addAll(images);
    notify();
  }

  //TODO: blyat filter if has
  void addImage(ImageMeta image){
    _images.add(image);
    notify();
  }

  void clear(){
    _images.clear();
    notify();
  }

  void moveTestToMain(){
    firstSelected = secondSelected;
    firstCache = secondCache;
    firstImageSize = secondImageSize;
  }

  bool get bothSelected => firstSelected != null && secondSelected != null;
  bool get bothHasGenerationParams => bothSelected && (firstSelected.runtimeType == ImageMeta && secondSelected.runtimeType == ImageMeta) && (firstSelected as ImageMeta).generationParams != null && (secondSelected as ImageMeta).generationParams != null;
  bool get oneSelected => firstSelected != null || secondSelected != null;
  GenerationParams? getGPOrHull(int type){
    switch(type) {
      case 0:
        return firstSelected.runtimeType == ImageMeta && (firstSelected as ImageMeta).generationParams != null ? (firstSelected as ImageMeta).generationParams : null;
      case 1:
        return secondSelected.runtimeType == ImageMeta && (secondSelected as ImageMeta).generationParams != null ? (secondSelected as ImageMeta).generationParams : null;
      default:
        return null;
    }
  }

  void changeSelected(int type, ImageMeta? im) {
    if (im == null) return;

    if (type == 1) {
      firstSelected = im;
      firstProcessed.clear();
    } else if (type == 2) {
      secondSelected = im;
      secondProcessed.clear();
    }

    unawaited(_updateImageCache(type));
  }

  Future<void> _updateImageCache(int type) async {
    final selected = type == 1 ? firstSelected : secondSelected;
    if (selected == null) return;

    if (selected.fullImage == null) {
      await selected.decodeToFull();
    }
    final bytes = selected.fullImage!;
    if (bytes.isEmpty) return;

    final decoded = img.decodeImage(bytes);
    if (decoded == null) return;

    if (type == 1) {
      firstCache = bytes;
      firstDecoded = decoded;
      firstImageSize = ImageSize(width: decoded.width, height: decoded.height);
    } else {
      secondCache = bytes;
      secondDecoded = decoded;
      secondImageSize = ImageSize(width: decoded.width, height: decoded.height);
    }

    final other = type == 1 ? secondSelected : firstSelected;
    if (other == null) {
      await _generateCheckerboardPlaceholder(type, decoded);
    }

    await _normalizeSizesIfNeeded();

    await _processBothImagesIfPossible();
    notify();
  }

  Future<void> _generateCheckerboardPlaceholder(int type, img.Image reference) async {
    const cellSize = 24;
    final width = reference.width;
    final height = reference.height;

    final placeholder = img.Image(width: width, height: height);

    img.fill(placeholder, color: img.ColorRgb8(140, 140, 140));

    // checkerboard
    for (var y = 0; y < height; y += cellSize * 2) {
      for (var x = 0; x < width; x += cellSize * 2) {
        img.fillRect(
          placeholder,
          x1: x,
          y1: y,
          x2: x + cellSize - 1,
          y2: y + cellSize - 1,
          color: img.ColorRgb8(255, 255, 255),
        );

        img.fillRect(
          placeholder,
          x1: x + cellSize,
          y1: y + cellSize,
          x2: x + cellSize * 2 - 1,
          y2: y + cellSize * 2 - 1,
          color: img.ColorRgb8(255, 255, 255),
        );
      }
    }

    final bytes = img.encodePng(placeholder);

    if (type == 1) {
      secondCache = bytes;
      secondImageSize = ImageSize(width: width, height: height);
      // secondDecoded = placeholder;
    } else {
      firstCache = bytes;
      firstImageSize = ImageSize(width: width, height: height);
      // firstDecoded = placeholder;
    }
  }

  Future<void> _normalizeSizesIfNeeded() async {
    if (firstImageSize == null || secondImageSize == null) return;

    if (firstImageSize!.width == secondImageSize!.width &&
        firstImageSize!.height == secondImageSize!.height) {
      return;
    }

    if (firstSelected == null || secondSelected == null) return;

    final s1 = firstImageSize!.totalPixels();
    final s2 = secondImageSize!.totalPixels();

    final bool resizeFirst = s1 < s2;
    final ImageMeta toResize = resizeFirst ? firstSelected! : secondSelected!;
    final ImageSize targetSize = resizeFirst ? secondImageSize! : firstImageSize!;

    if (toResize.fullImage == null) await toResize.decodeToFull();
    final decoded = img.decodeImage(toResize.fullImage!);
    if (decoded == null) return;

    final resized = img.copyResize(
      decoded,
      width: targetSize.width,
      height: targetSize.height,
      interpolation: img.Interpolation.cubic,
    );

    final bytes = img.encodePng(resized);

    if (resizeFirst) {
      firstCache = bytes;
      firstDecoded = resized;
      firstImageSize = targetSize;
    } else {
      secondCache = bytes;
      secondDecoded = resized;
      secondImageSize = targetSize;
    }
  }

  Future<void> _processBothImagesIfPossible() async {
    final futures = <Future>[];

    if (firstDecoded != null) {
      futures.add(_processImage(firstDecoded!, 1));
    }
    if (secondDecoded != null) {
      futures.add(_processImage(secondDecoded!, 2));
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  Future<void> _processImage(img.Image original, int type) async {
    final auto = await compute(_autoStretch, original.clone());

    Uint8List? colorMatched;
    if (type == 2) {
      colorMatched = await compute(_colorTransfer, (
      source: secondDecoded!,
      target: firstDecoded!,
      ));
    }

    if (type == 1) {
      firstProcessed['autocolor'] = img.encodePng(auto);
    } else {
      secondProcessed['autocolor'] = img.encodePng(auto);
      if (colorMatched != null) {
        secondProcessed['colortransfer'] = colorMatched;
      }
    }
  }
}

img.Image _autoStretch(img.Image input) {
  final w = input.width;
  final h = input.height;
  final count = w * h;

  List<int> rVals = List.filled(count, 0);
  List<int> gVals = List.filled(count, 0);
  List<int> bVals = List.filled(count, 0);

  int idx = 0;
  for (final p in input) {
    rVals[idx] = p.r.toInt();
    gVals[idx] = p.g.toInt();
    bVals[idx] = p.b.toInt();
    idx++;
  }

  final rOut = _stretchChannel(rVals);
  final gOut = _stretchChannel(gVals);
  final bOut = _stretchChannel(bVals);

  idx = 0;
  for (final p in input) {
    p
      ..r = rOut[idx].toDouble()
      ..g = gOut[idx].toDouble()
      ..b = bOut[idx].toDouble();
    idx++;
  }

  return input;
}

List<int> _stretchChannel(List<int> values) {
  final sorted = values.toList()..sort();
  final n = sorted.length;
  final lowIdx  = (n * 0.005).round();
  final highIdx = (n * 0.995).round();

  final low  = sorted[lowIdx];
  final high = sorted[highIdx];

  if (high <= low) return values;

  return values.map((v) {
    final stretched = (v - low) * 255.0 / (high - low);
    return stretched.clamp(0.0, 255.0).round();
  }).toList();
}

Uint8List _colorTransfer(({img.Image source, img.Image target}) data) {
  final source = data.source;
  final target = data.target;

  final sourceLab = rgbToLab(source);
  final targetLab = rgbToLab(target);

  final sourceStats = computeMeanStd(sourceLab);
  final targetStats = computeMeanStd(targetLab);

  final sourceMeans = sourceStats.mean;
  final sourceStds  = sourceStats.std;
  final targetMeans = targetStats.mean;
  final targetStds  = targetStats.std;

  final h = sourceLab.length;
  final w = sourceLab[0].length;
  int i = 0;

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      for (var c = 0; c < 3; c++) {
        double v = sourceLab[y][x][c];

        v = (v - sourceMeans[c]) * (targetStds[c] / (sourceStds[c] + 1e-6)) + targetMeans[c];

        v = v.clamp(-200.0, 300.0);

        sourceLab[y][x][c] = v;
      }
      i++;
    }
  }

  final resultImage = labToRgb(sourceLab);
  return img.encodePng(resultImage);
}

class TimelineBlock {
  int _seed = 0;

  late Function notify;

  void changeNotify(Function f){
    notify = f;
  }

  int get getSeed => _seed;

  void setSeed(int seed){
    _seed = seed;
    notify();
  }
}

// Other
class ContentRatingModule {

  List<String> G = [];
  List<String> PG = [];
  List<String> PG_13 = [];
  List<String> R = [];
  List<String> NC_17 = [];
  List<String> X = [];
  List<String> XXX = [];

  final List<ContradictionRule> _contradictionRules = [
    ContradictionRule(
      code: 'solo_vs_duo',
      requireAll: ['solo'],
      forbidIfPresent: ['duo', 'group', 'multiple_people'],
      message: 'solo contradicts multiple people tags',
    ),

    ContradictionRule(
      code: 'female_penis',
      requireAll: ['solo'],
      requireAny: ['girl', '1girl', 'female', 'woman'],
      forbidIfPresent: ['penis'],
      message: 'female solo with penis requires futa',
    ),

    ContradictionRule(
      code: 'minor_sexual',
      requireAny: ['child', 'minor', 'underage'],
      forbidIfPresent: [
        'sex',
        'penis',
        'vagina',
        'nude',
        'sexual',
      ],
      message: 'minor-related tags cannot coexist with sexual content',
    ),

    ContradictionRule(
      code: 'nude_clothed',
      requireAny: ['nude'],
      forbidIfPresent: ['clothed', 'fully_clothed', 'jacket', 'pants'],
      message: 'nude contradicts clothing tags',
    ),

    ContradictionRule(
      code: 'gender_conflict',
      requireAll: ['male'],
      forbidIfPresent: ['female', 'girl', 'woman'],
      message: 'male conflicts with female tags',
    ),
  ];


  Future<void> loadCRTags() async {
    Directory? dD;
    if(Platform.isAndroid){
      dD = Directory(await ExternalPath.getExternalStoragePublicDirectory(ExternalPath.DIRECTORY_DOCUMENTS));
    } else if(Platform.isWindows){
      dD = await getApplicationDocumentsDirectory();
    }
    if(dD == null){
      int notID = 0;
      notID = notificationManager!.show(
        thumbnail: const Icon(Icons.question_mark, color: Colors.orangeAccent, size: 32),
        title: 'Documents folder not found',
        description: 'It seems to be some kind of system error. Check the settings section and folder paths',
        content: Padding(padding: EdgeInsets.only(top: 7), child: ElevatedButton(
            style: ButtonStyle(
                foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                shape: WidgetStateProperty.all<RoundedRectangleBorder>(const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))))
            ),
            onPressed: (){
              notificationManager!.close(notID);
              loadCRTags();
            },
            child: const Text("Try again", style: TextStyle(fontSize: 12))
        )),
        sound: NtSound.wrong
      );
      return;
    }
    dynamic jsonPath = Directory(p.join(dD.path, 'CImaGen', 'json'));
    if (!jsonPath.existsSync()) {
      await jsonPath.create(recursive: true);
    }
    jsonPath = File(p.join(dD.path, 'CImaGen', 'json', 'content-rating.json'));
    if (jsonPath.existsSync()) {
      File(jsonPath.path).readAsString().then((rawData){
        final data = jsonDecode(rawData);
        G.addAll(List<String>.from(data['G']));
        PG.addAll(List<String>.from(data['PG']));
        PG_13.addAll(List<String>.from(data['PG_13']));
        R.addAll(List<String>.from(data['R']));
        NC_17.addAll(List<String>.from(data['NC_17']));
        X.addAll(List<String>.from(data['X']));
        XXX.addAll(List<String>.from(data['XXX']));
      });
    } else {
      notificationManager!.show(
        thumbnail: const Icon(Icons.question_mark, color: Colors.orangeAccent, size: 32),
        title: 'Content rating tags not found',
        description: 'Put the content-rating.json file in the "$jsonPath" folder',
        sound: NtSound.wrong
      );
    }
  }

  // TODO ;d
  ContentRating getContentRating(String text){
    // First - normalize
    text = cleanUpSDPrompt(text);
    //Second - split
    List<String> tags = getRawTags(text);

    bool done = false;
    ContentRating r = ContentRating.G;

    for(String tag in XXX){
      if(tags.contains(tag)){
        r = ContentRating.XXX;
        done = true;
      }
    }

    if(!done){
      for(String tag in X){
        if(tags.contains(tag)){
          r = ContentRating.X;
          done = true;
        }
      }
    }

    if(!done){
      for(String tag in NC_17){
        if(tags.contains(tag)){
          r = ContentRating.NC_17;
          done = true;
        }
      }
    }

    return r;
  }

  List<TagProblem> findContradictions(List<String> tags) {
    final tagSet = tags.toSet();
    final problems = <TagProblem>[];

    for (final rule in _contradictionRules) {
      if (rule.requireAll.isNotEmpty &&
          !rule.requireAll.every(tagSet.contains)) {
        continue;
      }

      if (rule.requireAny.isNotEmpty &&
          !rule.requireAny.any(tagSet.contains)) {
        continue;
      }

      final triggered = rule.forbidIfPresent
          .where(tagSet.contains)
          .toList();

      if (triggered.isNotEmpty) {
        problems.add(
          TagProblem(
            code: rule.code,
            message: rule.message,
            involvedTags: [
              ...rule.requireAll,
              ...rule.requireAny,
              ...triggered,
            ],
          ),
        );
      }
    }

    return problems;
  }
}

class TagProblem {
  final String code;
  final String message;
  final List<String> involvedTags;

  TagProblem({
    required this.code,
    required this.message,
    required this.involvedTags,
  });

  @override
  String toString() => '$code: $message (${involvedTags.join(", ")})';
}

class ContradictionRule {
  final String code;
  final List<String> requireAll;
  final List<String> forbidIfPresent;
  final List<String> requireAny;
  final String message;

  ContradictionRule({
    required this.code,
    this.requireAll = const [],
    this.requireAny = const [],
    this.forbidIfPresent = const [],
    required this.message,
  });

  factory ContradictionRule.fromJson(Map<String, dynamic> json) {
    return ContradictionRule(
      code: json['code'],
      requireAll: List<String>.from(json['requireAll'] ?? []),
      requireAny: List<String>.from(json['requireAny'] ?? []),
      forbidIfPresent: List<String>.from(json['forbidIfPresent'] ?? []),
      message: json['message'],
    );
  }
}