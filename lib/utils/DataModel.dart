import 'dart:io';

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

  DataModel() {
    comparisonBlock.changeNotify(notify);
  }

}

class ComparisonBlock {
  dynamic firstSelected;
  Image? firstCache;
  ImageSize? firstImageSize;

  dynamic secondSelected;
  Image? secondCache;
  ImageSize? secondImageSize;

  late Function notify;

  void changeNotify(Function f){
    notify = f;
  }

  List<ImageMeta> _images = [];

  List<ImageMeta> get getImages => _images;

  void addAllImages(List<ImageMeta> images){
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

  bool get bothSelected => firstSelected != null && secondSelected != null;
  bool get bothHasGenerationParams => bothSelected && (firstSelected.runtimeType == ImageMeta && secondSelected.runtimeType == ImageMeta) && (firstSelected as ImageMeta).generationParams != null && (secondSelected as ImageMeta).generationParams != null;
  bool get oneSelected => firstSelected != null || secondSelected != null;


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

  void updateFuckingCache(int type){
    // Допустим куколд прислал изображение, его читаем сразу
    dynamic s = type == 0 ? firstSelected : secondSelected;
    String path = s.runtimeType == ImageMeta ? (s as ImageMeta).fullPath : s;
    Io.File(path).readAsBytes().then((b) {
        Il.Image? de = Il.decodeImage(b);
        if(de != null) {
          if(type == 0){
            firstImageSize = ImageSize(width: de.width, height: de.height);
            firstCache = Image.file(File(path));
          } else {
            secondImageSize = ImageSize(width: de.width, height: de.height);
            secondCache = Image.file(File(path));
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
              secondCache = Image.memory(Il.encodePng(image));
              secondImageSize =  ImageSize(width: de.width, height: de.height);
            } else {
              firstCache = Image.memory(Il.encodePng(image));
              firstImageSize =  ImageSize(width: de.width, height: de.height);
            }

            if(type == 0){
              firstCache = Image.file(File(path));
            } else {
              secondCache = Image.file(File(path));
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
              bool what = secondImageSize!.totalPixels() < firstImageSize!.totalPixels();
              s = what ? secondSelected : firstSelected;
              path = s.runtimeType == ImageMeta ? (s as ImageMeta).fullPath : s;
              Io.File(path).readAsBytes().then((b) {
                de = Il.decodeImage(b);
                if(de != null) {
                  Il.Image d = Il.copyResize(de!, width: [firstImageSize, secondImageSize][what ? 0 : 1]?.width);
                  if(what){
                    secondCache = Image.memory(Il.encodePng(d));
                    secondImageSize = firstImageSize;
                  } else {
                    firstCache = Image.memory(Il.encodePng(d));
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