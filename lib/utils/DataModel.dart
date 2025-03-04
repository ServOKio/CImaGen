import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:cimagen/Utils.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:external_path/external_path.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io' as Io;

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../components/PromptAnalyzer.dart';

import 'package:path/path.dart' as p;

import '../main.dart';

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
  dynamic firstSelected;
  Uint8List? firstCache; // НЕ ТРОГАТЬ УЕБУ
  ImageSize? firstImageSize;

  dynamic secondSelected;
  Uint8List? secondCache; // НЕ ТРОГАТЬ УЕБУ
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


  void changeSelected(int type, dynamic data){
    if(type == 0){
      firstSelected = data;
      updateFuckingCache(0);
    } else if(type == 1){
      secondSelected = data;
      updateFuckingCache(1);
    }
    // notify();
  }

  Future<void> updateFuckingCache(int type) async {
    // Допустим куколд прислал изображение, его читаем сразу
    dynamic s = type == 0 ? firstSelected : secondSelected;
    String path = '';
    if(s.runtimeType == ImageMeta){
      ImageMeta im = s as ImageMeta;
      if(im.isLocal){
        path = im.fullPath!;
      } else {
        if(im.tempFilePath != null){
          path = im.tempFilePath!;
        } else {
          await im.parseNetworkImage();
          path = im.tempFilePath!;
        }
      }
    } else {
      path = s;
    }
    final Uint8List bytes = await compute(readAsBytesSync, path);
    img.Image? de = await compute(img.decodeImage, bytes);
    if(de != null) {
      // ok
      if(type == 0){
        firstImageSize = ImageSize(width: de.width, height: de.height);
        firstCache = bytes;
      } else {
        secondImageSize = ImageSize(width: de.width, height: de.height);
        secondCache = bytes;
      }
      //Ура, прочитали, теперь сверяем и потом скейлим
      //Блять, надо узнать что скейлить
      if([firstSelected, secondSelected][type == 0 ? 1 : 0] == null){
        //Если пустое и мы нихера не знаем о втором

        //Создаём новое
        final image = img.Image(width: de.width, height: de.height);
        //Рисуем херню
        int limit = 20;
        for (img.Pixel pixel in image) {
          if(pixel.x%(limit*2) > limit){
            if(pixel.y%(limit*2) < limit){
              pixel.setRgb(255, 255, 255);
            } else {
              pixel.setRgb(137, 137, 137);
            }
          } else {
            if(pixel.y%(limit*2) > limit){
              pixel.setRgb(255, 255, 255);
            } else {
              pixel.setRgb(137, 137, 137);
            }
          }
        }

        if(type == 0){
          secondCache = img.encodePng(image);
          secondImageSize =  ImageSize(width: de.width, height: de.height);
        } else {
          firstCache = img.encodePng(image);
          firstImageSize =  ImageSize(width: de.width, height: de.height);
        }
        notify();
      } else {
        // Если размеры есть, но нужно узнать кого наебать
        // А похуй, пусть сверяет с сеткой
        // 😭 не хочууууууу
        // Просто нужно понять что надо изменит и всё, а так всё равно придётся
        if(firstImageSize.toString() == secondImageSize.toString()){
          //Срать
          notify();
        } else {
          //flutter: comparison_as_main
          //[ERROR:flutter/runtime/dart_vm_initializer.cc(41)] Unhandled Exception: Null check operator used on a null value
          bool what = secondImageSize!.totalPixels() < firstImageSize!.totalPixels();
          s = what ? secondSelected : firstSelected;
          if(s.runtimeType == ImageMeta){
            ImageMeta im = s as ImageMeta;
            if(im.isLocal){
              path = im.fullPath!;
            } else if(im.tempFilePath != null){
              path = im.tempFilePath!;
            }
          } else {
            path = s;
          }
          Io.File(path).readAsBytes().then((b) {
            de = img.decodeImage(b);
            if(de != null) {
              img.Image d = img.copyResize(de!, width: [firstImageSize, secondImageSize][what ? 0 : 1]?.width);
              if(what){
                secondCache = img.encodePng(d);
                secondImageSize = firstImageSize;
              } else {
                firstCache = img.encodePng(d);
                firstImageSize = secondImageSize;
              }
            }
            notify();
          });
        }
      }
    }
  }
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
          ))
      );
      audioController!.player.play(AssetSource('audio/wrong.wav'));
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
      int notID = notificationManager!.show(
          thumbnail: const Icon(Icons.question_mark, color: Colors.orangeAccent, size: 32),
          title: 'Content rating tags not found',
          description: 'Put the content-rating.json file in the "$jsonPath" folder'
      );
      audioController!.player.play(AssetSource('audio/wrong.wav'));
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
}

List<Combination> combinations = [
  Combination(
      level: 2,
      exactly: ['trap'],
      requires: ['1girl', 'girl'],
      containsOne: ['penis']
  ),
  Combination(
      level: 1,
      requires: ['nude', 'naked'],
      containsOne: ['big_breasts']
  ),
];

class Combination{
  // 0 - нахуя ?
  // 1 - стандартно, бабки будут не довольны (gay, male, solo, masturbation)
  // 2 - ну бля, давай не будем (трапы там)
  // 3 - специфичные вкусы сука можно бан получить (xxx rating)
  int level;
  List<String>? containsOne;
  List<String>? containsAll;
  List<String>? requires;
  List<String>? exactly;

  Combination({
    required this.level,
    this.containsOne,
    this.containsAll,
    this.requires,
    this.exactly
  });

  bool test(String string){
    return false;
  }
}