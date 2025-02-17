import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cimagen/Utils.dart';
import 'package:cimagen/main.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../modules/ConfigManager.dart';
import '../modules/webUI/AbMain.dart';
import '../objectbox.g.dart';
import 'DataModel.dart';
import 'NavigationService.dart'; // flutter pub run build_runner build

class ObjectboxDB {
  late final Store _store;
  Store get store => _store;
  late final Admin _admin;

  late Timer timer;
  List<Job> toBatchOne = [];
  List<Job> toBatchTwo = [];
  bool use = false;
  bool inProgress = false;

  late final Box<ImageMeta> _imageMetaBox;
  Box<ImageMeta> get imageMetaBox => _imageMetaBox;
  late final Box<GenerationParams> _generationParamsBox;
  Box<GenerationParams> get generationParamsBox => _generationParamsBox;

  static Future<ObjectboxDB> create() async {
    Directory dD = await getApplicationDocumentsDirectory();
    Directory dbPath = Directory(p.join(dD.path, 'CImaGen', 'databases'));
    if (!await dbPath.exists()) {
      await dbPath.create(recursive: true);
    }

    final store = await openStore(
      directory: dbPath.absolute.path,
      maxDBSizeInKB: prefs.containsKey('max_db_size') ? prefs.getInt('max_db_size')! * 1048576 : 524288000 // 500gb
    );
    return ObjectboxDB._create(store);
  }


  ObjectboxDB._create(this._store) {
    if (kDebugMode) {
      if (Admin.isAvailable()) {
        _admin = Admin(_store);
      } else {
        print('OB: web panel not awailable');
      }
    }

    _imageMetaBox = Box<ImageMeta>(_store);
    _generationParamsBox = Box<GenerationParams>(_store);

    timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try{
        List<Job> send = use ? toBatchTwo : toBatchOne;
        if(send.isNotEmpty){
          use = !use;
          inProgress = true;
          if (kDebugMode) print('OB: Sending ${send.length}...');
          List<Job> imList = send.where((job) => job.to == 'images').toList();
          if(imList.isNotEmpty) {
            List<int> res = await objectbox.imageMetaBox.putManyAsync(imList.map((job) => job.obj as ImageMeta).toList());
            if (kDebugMode) {
              print(res);
            }
          }
          List<Job> gpList = send.where((job) => job.to == 'generation_params').toList();
          if(gpList.isNotEmpty){
            List<int> res = await objectbox.generationParamsBox.putManyAsync(gpList.map((job) => job.obj as GenerationParams).toList());
            if (kDebugMode) {
              print(res);
            }
          }

          if (kDebugMode) print('OB: Done');
          !use ? toBatchTwo.clear() : toBatchOne.clear();
          inProgress = false;
        }
      } on Exception catch(e) {
        if (kDebugMode){
          print('OB: toBatch error');
          print(e);
        }
      }
    });
  }

  // DB
  HashMap<String, List<Folder>> foldersCache = HashMap();
  Future<List<Folder>> getFolders({String? host, RenderEngine? re}) async{
    if (kDebugMode) {
      print('OB: getFolders $host');
    }
    List<dynamic> args = [];
    if(host != null) args.add(host);
    String k = (host ?? 'null')+(re != null ? re.toString() : 'all');
    if(foldersCache.containsKey(k)) return foldersCache[k]!;

    Condition<ImageMeta> c = (host != null ? ImageMeta_.host.equals(host) : ImageMeta_.host.isNull());

    Query<ImageMeta> query = imageMetaBox.query(
            re != null ? c.and(ImageMeta_.dbRe.equals(re.index)) : c
    ).order(ImageMeta_.dateModified).build();
    List<ImageMeta> list = query.find();

    query.close();
    Map<String, List<ImageMeta>> folders = groupBy(list, (im) => DateFormat('yyyy-MM-dd').format(im.dateModified!));
    List<Folder> fi = [];
    for(String day in folders.keys){
      fi.add(Folder(
          index: fi.length,
          name: day,
          getter: day,
          type: FolderType.byDay,
          files: folders[day]!.map((im) => FolderFile(
            fullPath: im.fullPath!,
            isLocal: im.isLocal,
            thumbnail: im.thumbnail
          )).toList(growable: false)
      ));
    }
    if (kDebugMode) {
      print('getFolders ${fi.length}');
    }
    foldersCache[k] = fi;
    return fi;
  }

  Future<List<String>> getFolderHashes(String folder, {String? host}) async {
    Query<ImageMeta> query = imageMetaBox.query(
        host != null ? ImageMeta_.host.equals(host) : ImageMeta_.host.isNull()
    ).build();
    List<String> list = query.property(ImageMeta_.pathHash).find();
    query.close();
    return list;
  }

  Future<List<ImageMeta>> getImagesByDay(String day, {String? host, RenderEngine? re}) async {
    String cacheDir = NavigationService.navigatorKey.currentContext!.read<ConfigManager>().imagesCacheDir;
    if (kDebugMode) {
      print('OB: getImagesByDay: $day ${re ?? 'null'} ${host ?? 'null'}');
    }
    DateTime dayDate = DateFormat("yyyy-MM-dd").parse(day);
    Condition<ImageMeta> c = (host != null ? ImageMeta_.host.equals(host) : ImageMeta_.host.isNull()).and(ImageMeta_.dateModified.betweenDate(dayDate, dayDate.add(Duration(hours: 23, minutes: 59, seconds: 59))));
    Query<ImageMeta> query = imageMetaBox.query(
      re != null ? c.and(ImageMeta_.dbRe.equals(re.index)) : c
    ).build();
    List<ImageMeta> fi = query.find();
    fi = fi.map((im) => im..cacheFilePath = p.join(cacheDir, '${im.host}_${im.keyup}.${im.specific?['hasAnimation'] == true ? 'png' : 'jpg'}')).toList(growable: false);
    query.close();
    return fi;
  }

  Future<List<ImageMeta>> getImagesBySeed(int seed, {String? host}) async {
    String cacheDir = NavigationService.navigatorKey.currentContext!.read<ConfigManager>().imagesCacheDir;
    if (kDebugMode) {
      print('OB: getImagesBySeed: $seed ${host ?? 'null'}');
    }
    QueryBuilder<ImageMeta> builder = imageMetaBox.query((host != null ? ImageMeta_.host.equals(host) : ImageMeta_.host.isNull()));
    builder.link(ImageMeta_.dbGenerationParams, GenerationParams_.seed.equals(seed));
    Query<ImageMeta> query = builder.build();
    List<ImageMeta> fi = query.find();
    fi = fi.map((im) => im..cacheFilePath = p.join(cacheDir, '${im.host}_${im.keyup}.${im.specific?['hasAnimation'] == true ? 'png' : 'jpg'}')).toList(growable: false);
    query.close();
    return fi;
  }

  Future<void> updateIfNado(String path, {String? host}) async{
    path = normalizePath(path); // windows suck
    // Check file type
    final String e = p.extension(path);
    if(!['png', 'jpg', 'webp', 'jpeg'].contains(e.replaceFirst('.', '').toLowerCase())) return;
    final String b = p.basename(path);
    for(String d in ['mask', 'before']){
      if(b.contains(d)) {
        if (kDebugMode) print('skip $b');
        return;
      }
    }
    String pathHash = genPathHash(path);

    List<ImageMeta> list = imageMetaBox.query(
        (host != null ? ImageMeta_.host.equals(host) : ImageMeta_.host.isNull())
            .and(ImageMeta_.pathHash.equals(pathHash))
    ).build().find();
    if (list.isNotEmpty) {
      //toBatchTwo.add(Job(to: 'images', type: JobType.update, obj: await imageMeta.toMap()));
    } else {
      ImageMeta? im = await parseImage(RenderEngine.unknown, path);
      if(im != null){
        objectbox.updateImages(imageMeta: im, fromWatch: true);
        if(NavigationService.navigatorKey.currentContext!.read<ImageManager>().useLastAsTest){
          Future.delayed(const Duration(milliseconds: 1000), () {
            DataModel? d = NavigationService.navigatorKey.currentContext?.read<DataModel>();
            if(d != null){
              d.comparisonBlock.moveTestToMain();
              d.comparisonBlock.changeSelected(1, im);
              d.comparisonBlock.addImage(im);
            }
          });
        }
      }
    }
  }

  Future<void> updateImages({required ImageMeta imageMeta, bool fromWatch = false}) async {
    List<ImageMeta> list = imageMetaBox.query(
        (imageMeta.host != null ? ImageMeta_.host.equals(imageMeta.host!) : ImageMeta_.host.isNull())
            .and(ImageMeta_.keyup.equals(imageMeta.keyup))
    ).build().find();
    if (list.isNotEmpty) {
      //toBatchTwo.add(Job(to: 'images', type: JobType.update, obj: await imageMeta.toMap()));
    } else {
      //Insert
      if(use){
        toBatchTwo.add(Job(to: 'images', type: JobType.insert, obj: imageMeta));
      } else {
        toBatchOne.add(Job(to: 'images', type: JobType.insert, obj: imageMeta));
      }
      if(foldersCache.containsKey(imageMeta.host ?? 'null')) {
        foldersCache.remove(imageMeta.host ?? 'null');
      }
    }
  }

  Future<void> deleteAllFromHost(String? host) async {
    List<int> list = imageMetaBox.query(host != null ? ImageMeta_.host.equals(host) : ImageMeta_.host.isNull()).build().property(ImageMeta_.id).find();
    if (list.isNotEmpty) {
      imageMetaBox.removeMany(list);
    }
  }

  Future<void> fixDB(DBErrorsForFix type) async {
    if(type == DBErrorsForFix.image_size_missmatch){
      // 1. Find.
      // Get keyups from dir
      int notID = notificationManager!.show(
          thumbnail: const Icon(Icons.broken_image_outlined, color: Colors.lightBlueAccent, size: 64),
          title: 'Finding images...',
          description: 'Give us a few seconds...'
      );
      String cacheFolder = NavigationService.navigatorKey.currentContext!.read<ConfigManager>().imagesCacheDir;
      Stream<FileSystemEntity> stream = Directory(cacheFolder).list();
      Map<String, String> sizes = {};
      List<FileSystemEntity> files = [];
      stream.listen((ent) {
        files.add(ent);
      }, onDone: () async {
        print('Loaded files: ${files.length}');
        // 2. Get files WxH
        int i = 0;
        for(FileSystemEntity ent in files){
          try{
            final Uint8List bytes = await compute(readAsBytesSync, ent.path);
            img.Image? data = await compute(img.decodeImage, bytes);
            if(data != null){
              String basename = p.basename(ent.path);
              List<String> pa = p.basename(ent.path).replaceRange(basename.length - p.extension(basename).length, basename.length, '').split('_');
              String host = pa[0];
              String keyup = pa[1];
              sizes[keyup] = '${data.width}x${data.height}';
              if (kDebugMode) {
                print('ok $i / ${files.length - i}');
              }
              notificationManager!.update(notID, 'description', 'ok $i / ${files.length - i}');
            } else if (kDebugMode) {
              print('Can\'t parse ${ent.path}');
            }
          } catch (e) {
            int d2 = notificationManager!.show(
                thumbnail: const Icon(Icons.error, color: Colors.redAccent),
                title: 'Error in for',
                description: 'Error: $e\nFile: ${ent.path}'
            );
            audioController!.player.play(AssetSource('audio/error.wav'));
          }
          i++;
        }
        Directory dD = await getApplicationDocumentsDirectory();
        Directory dbPath = Directory(p.join(dD.path, 'CImaGen', 'databases'));
        if (!await dbPath.exists()) {
          await dbPath.create(recursive: true);
        }
        // 3. Save to json
        File file = File(p.join(dbPath.absolute.path, 'broken_sizes_images.json'));
        await file.writeAsString(jsonEncode(sizes));
        notificationManager!.update(notID, 'description', 'Loaded, check ${file.path}');
        Future.delayed(const Duration(milliseconds: 10000), () => notificationManager!.close(notID));
      });
    }
  }
}

class Job{
  final String to;
  final JobType type;
  final dynamic obj;

  const Job({
    required this.to,
    required this.type,
    required this.obj
  });
}

enum JobType{
  insert,
  update,
  delete
}

enum DBErrorsForFix{
  image_size_missmatch
}