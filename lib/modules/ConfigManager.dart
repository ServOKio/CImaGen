import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'package:path/path.dart' as p;

import '../Utils.dart';
import '../main.dart';

class ConfigManager with ChangeNotifier {
  int _count = 0;

  //Getter
  int get count => _count;

  String _tempDir = './temp';
  String get tempDir => _tempDir;

  String _imagesCacheDir = './temp/images';
  String get imagesCacheDir => _imagesCacheDir;

  String _imagesErrorDir = './temp/error';
  String get imagesErrorDir => _imagesErrorDir;

  bool _isNull = false;
  bool get isNull => _isNull;

  Timer? cacheTimer;

  Future<void> init() async {
    updateCacheLocation();
    if(Platform.isWindows){
      _isNull = (getUserName() == 'aandr' && getComputerName().toLowerCase() == 'workhorse') || (getUserName() == 'TurboBox' && getComputerName() == 'TurboBox');
    }
  }

  Future<String> updateCacheLocation() async {
    // Global cache
    if(cacheTimer != null) cacheTimer!.cancel();
    String? customCacheDir = prefs.getString('custom_cache_dir');
    Directory tDir;
    if(customCacheDir != null){
      tDir = Directory(customCacheDir);
    } else {
      Directory appTempDir = await getTemporaryDirectory();
      tDir = Directory(p.join(appTempDir.path, 'CImaGen', 'UCanDeleteMe'));
    }

    if(!tDir.existsSync()){
      tDir.createSync(recursive: true);
    }
    _tempDir = tDir.path;
    cacheTimer = Timer.periodic(const Duration(minutes: 10), (timer) => checkCasheDir());
    checkCasheDir();

    // Images cache
    customCacheDir = prefs.getString('custom_images_cache_dir');
    if(customCacheDir != null){
      tDir = Directory(customCacheDir);
    } else {
      Directory appTempDir = await getTemporaryDirectory();
      tDir = Directory(p.join(appTempDir.path, 'CImaGen', 'ImagesBackup'));
    }
    if(!tDir.existsSync()){
      tDir.createSync(recursive: true);
    }
    _imagesCacheDir = tDir.path;

    // For test images
    customCacheDir = prefs.getString('custom_images_cache_dir');
    tDir = Directory(p.join(tDir.parent.path, 'CantRead'));
    if(!tDir.existsSync()){
      tDir.createSync(recursive: true);
    }
    _imagesErrorDir = tDir.path;

    return _tempDir;
  }

  void checkCasheDir(){
    getDirSizeIsolated(Directory(_tempDir)).then((size){
      if(size >= ((prefs.getDouble('max_cache_size') ?? 5) * 1073741824)){
        if (kDebugMode) {
          print(_tempDir);
        }
        int notID = notificationManager!.show(
            thumbnail: CircularProgressIndicator(),
            title: 'Too much junk in cache (${readableFileSize(size)})',
            description: 'Please wait while we clean everything up'
        );
        Future.delayed(const Duration(seconds: 3), (){
          List<FileSystemEntity> files = Directory(_tempDir).listSync();
          for(FileSystemEntity ent in files){
            try {
              ent.deleteSync(recursive: true);
            } on Exception catch(e){
              if (kDebugMode) {
                print(e);
              }
            }
          }
          notificationManager!.update(notID, 'thumbnail', const Icon(Icons.restore_from_trash, color: Colors.greenAccent));
          notificationManager!.update(notID, 'title', 'Well...done!');
          notificationManager!.update(notID, 'description', 'Everything is clear!');
          Future.delayed(const Duration(milliseconds: 10000), () => notificationManager!.close(notID));
        });
      }
    });
  }

  void increment() {
    _count++;
  }
}