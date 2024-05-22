import 'dart:io';
import 'dart:typed_data';

import 'package:cimagen/Utils.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/material.dart';
import 'dart:io' as Io;

import 'package:image/image.dart' as Il;

class DataModel with ChangeNotifier {
  late Function jumpToTab;

  void notify(){
    notifyListeners();
  }

  ComparisonBlock comparisonBlock = ComparisonBlock();
  TimelineBlock timelineBlock = TimelineBlock();

  DataModel() {
    comparisonBlock.changeNotify(notify);
    timelineBlock.changeNotify(notify);
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

  List<dynamic> _images = [];

  List<dynamic> get getImages => _images;

  void addAllImages(List<dynamic> images){
    _images = images;
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
    if(secondCache == null) return;
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
        path = im.fullPath;
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
    Io.File(path).readAsBytes().then((b) {
        Il.Image? de = Il.decodeImage(b);
        if(de != null) {
          // ok
          if(type == 0){
            firstImageSize = ImageSize(width: de.width, height: de.height);
            firstCache = b;
          } else {
            secondImageSize = ImageSize(width: de.width, height: de.height);
            secondCache = b;
          }
          //Ура, прочитали, теперь сверяем и потом скейлим
          //Блять, надо узнать что скейлить
          if([firstSelected, secondSelected][type == 0 ? 1 : 0] == null){
            //Если пустое и мы нихера не знаем о втором

            //Создаём новое
            final image = Il.Image(width: de.width, height: de.height);
            //Рисуем херню
            for (var pixel in image) {
              pixel..r = pixel.x
                ..g = pixel.y;
            }

            if(type == 0){
              secondCache = Il.encodePng(image);
              secondImageSize =  ImageSize(width: de.width, height: de.height);
            } else {
              firstCache = Il.encodePng(image);
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
                  path = im.fullPath;
                } else if(im.tempFilePath != null){
                  path = im.tempFilePath!;
                }
              } else {
                path = s;
              }
              Io.File(path).readAsBytes().then((b) {
                de = Il.decodeImage(b);
                if(de != null) {
                  Il.Image d = Il.copyResize(de!, width: [firstImageSize, secondImageSize][what ? 0 : 1]?.width);
                  if(what){
                    secondCache = Il.encodePng(d);
                    secondImageSize = firstImageSize;
                  } else {
                    firstCache = Il.encodePng(d);
                    firstImageSize = secondImageSize;
                  }
                }
                notify();
              });
            }
          }
        }
    });
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