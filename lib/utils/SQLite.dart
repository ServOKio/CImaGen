import 'dart:async';
import 'dart:convert';

import 'package:cimagen/utils/ImageManager.dart';
import 'NavigationService.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:provider/provider.dart';
import 'dart:io' show File, Platform;

import '../Utils.dart';

class SQLite with ChangeNotifier{
  late Database database;

  List<Job> toBatchOne = [];
  List<Job> toBatchTwo = [];
  bool use = false;
  bool inProgress = false;

  late Timer timer;

  String _lastJob = '';
  String get lastJob => _lastJob;

  Future<void> init() async {
    if (Platform.isWindows || Platform.isLinux) sqfliteFfiInit();

    databaseFactory = databaseFactoryFfi;

    database = await openDatabase(
        path.join(await getDatabasesPath(), 'images_database.db'),
        onOpen: (db){
          if (kDebugMode) print(db.path);

          timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
            try{
              var send = use ? toBatchTwo : toBatchOne;
              if(send.isNotEmpty){
                use = !use;
                inProgress = true;
                NavigationService.navigatorKey.currentContext?.read<ImageManager>().updateJobCount(send.length);
                Batch batch = db.batch();
                if (kDebugMode) print('Sending ${send.length}...');
                for (var e in send) {
                  if(e.type == JobType.insert){
                    batch.insert(e.to, e.obj);
                  }
                }

                await batch.commit(noResult: true, continueOnError: true);
                if (kDebugMode) print('Done');
                !use ? toBatchTwo.clear() : toBatchOne.clear();
                inProgress = false;
              }
            } on Exception catch(e) {
              if (kDebugMode){
                print('error');
                print(e);
              }
            }
          });
        },
        onCreate: (db, version) {
          db.execute(
            'CREATE TABLE IF NOT EXISTS images('
                'keyup VARCHAR(256) PRIMARY KEY,'
                'type TINYINT,'
                'parent VARCHAR(128),'
                'fileName VARCHAR(256),'
                'pathHash VARCHAR(256),'
                'fullPath TEXT,'
                'dateModified DATETIME,'

                'mine VARCHAR(64),'
                'fileTypeExtension VARCHAR(8),'
                'fileSize INTEGER,'
                'size VARCHAR(64),'
                'bitDepth TINYINT,'
                'colorType TINYINT,'
                'compression TINYINT,'
                'filter TINYINT,'
                'colorMode TINYINT,'
                'imageParams TEXT,'
                'thumbnail TEXT'
            ')',
          );

          db.execute(
            'CREATE TABLE IF NOT EXISTS generation_params('
              'keyup VARCHAR(256) PRIMARY KEY,'
              'type TINYINT,'
              'parent VARCHAR(128),'
              'fileName TEXT,'
              'pathHash VARCHAR(256),'

              'positive TEXT,'
              'negative TEXT,'
              'steps INTEGER,'
              'sampler VARCHAR(128),'
              'cfgScale DOUBLE,'
              'seed INTEGER,'
              'sizeW INTEGER,'
              'sizeH INTEGER,'
              'modelHash VARCHAR(128),'
              'model VARCHAR(256),'
              'denoisingStrength DOUBLE,'
              'rng VARCHAR(16),'
              'hiresSampler VARCHAR(128),'
              'hiresUpscaler VARCHAR(128),'
              'hiresUpscale DOUBLE,'
              'tiHashes TEXT,'
              'version VARCHAR(16),'
              'rawData TEXT'
            ')',
          );

          db.execute(
            'CREATE TABLE IF NOT EXISTS favorites('
                'pathHash VARCHAR(256) PRIMARY KEY,'
                'fullPath TEXT NOT NULL,'
                'fileName TEXT NOT NULL,'
                'parent TEXT NOT NULL'
              ')'
          );
        },
        version: 1,
    );
  }

  //TODO: ЧИНИМ
  Future<void> updateImages(RenderEngine type, ImageMeta imageMeta) async {
    final String parentName = path.basename(File(imageMeta.fullPath).parent.path);
    final List<Map<String, dynamic>> maps = await database.query(
      'images',
      where: 'keyup = ?',
      whereArgs: [genHash(type, parentName, imageMeta.fileName)],
    );
    //print(genHash(type, parentName, imageMeta.imageParams.fileName));
    if (maps.isNotEmpty) {
      //print(maps.length);
    } else {
      //Insert
      _lastJob = imageMeta.fullPath;
      notifyListeners();
      if(use){
        toBatchTwo.add(Job(to: 'images', type: JobType.insert, obj: await imageMeta.toMap(forSQL: true)));
        if(imageMeta.generationParams != null) {
          toBatchTwo.add(
            Job(
                to: 'generation_params',
                type: JobType.insert,
                obj: imageMeta.generationParams!.toMap(
                    forDB: true,
                    key: imageMeta.getKey(),
                    amply: {
                      'pathHash': genPathHash(imageMeta.fullPath)
                    }
                )
            )
          );
        }
      } else {
        toBatchOne.add(Job(to: 'images', type: JobType.insert, obj: await imageMeta.toMap(forSQL: true)));
        if(imageMeta.generationParams != null) {
          toBatchOne.add(
              Job(
                  to: 'generation_params',
                  type: JobType.insert,
                  obj: imageMeta.generationParams!.toMap(
                      forDB: true,
                      key: imageMeta.getKey(),
                      amply: {
                        'pathHash': genPathHash(imageMeta.fullPath)
                      }
                  )
              )
          );
        }
      }
      // batch.insert(
      //   'images',
      //   imageMeta.toMap(forSQL: true),
      //   conflictAlgorithm: ConflictAlgorithm.ignore
      // );
    }
  }

  Future<void> clearMeta() async {
    Batch batch = database.batch();
    batch.delete('images');
    batch.delete('generation_params');
    await batch.apply();
  }

  Future<List<TimelineProject>> getPossibleTimelineProjects() async {
    final List<Map<String, dynamic>> maps = await database.query(
      'generation_params',
      columns: ['seed', 'COUNT(seed) as order_count'],
      groupBy: 'seed',
      having: 'COUNT(seed) > 1',
      orderBy: 'order_count desc',
    );
    return maps.map((e) => TimelineProject(seed: e['seed'] as int, count: e['order_count'] as int)).toList();
    // SELECT seed, COUNT(seed) as order_count FROM images GROUP BY seed HAVING COUNT(seed) > 1 ORDER BY order_count desc
    // SELECT seed FROM images GROUP BY seed HAVING COUNT(seed) > 1 ORDER BY COUNT(seed) desc
  }

  // TODO: СЛОМАНО
  Future<List<ImageMeta>> getImagesBySeed(int seed) async {
    final List<Map<String, dynamic>> maps = await database.query(
      'generation_params',
      orderBy: 'datemodified ASC', //Pizda
      where: 'seed = ?',
      whereArgs: [seed]
    );
    return List.generate(maps.length, (i) {
      if(maps[i]['colorType'] == null){
        print('--- ERROR ---');
        print(maps[i]);
        print('--- ERROR ---');
      }
      return ImageMeta(
          re: RenderEngine.values[maps[i]['type'] as int],
          mine: maps[i]['mine'] as String,
          fileTypeExtension: maps[i]['fileTypeExtension'] as String,
          fileSize: maps[i]['fileSize'] as int,
          fullPath: maps[i]['fullPath'] as String,
          dateModified: DateTime.parse(maps[i]['dateModified'] as String),
          size: ImageSize(width: maps[i]['sizeW'] as int, height: maps[i]['sizeH'] as int),
          bitDepth: maps[i]['bitDepth'] as int,
          colorType: maps[i]['colorType'] as int,
          compression: maps[i]['compression'] as int,
          filter: maps[i]['filter'] as int,
          colorMode: maps[i]['colorMode'] as int,
          thumbnail: maps[i]['thumbnail'] as String,
      );
    });
    // SELECT seed, COUNT(seed) as order_count FROM images GROUP BY seed HAVING COUNT(seed) > 1 ORDER BY order_count desc
    // SELECT seed FROM images GROUP BY seed HAVING COUNT(seed) > 1 ORDER BY COUNT(seed) desc
  }

  // TODO: СЛОМАНО
  Future<List<ImageMeta>> getImagesByParent(RenderEngine type, String parent) async {
    final List<Map<String, dynamic>> maps = await database.rawQuery('SELECT * from images join generation_params on images.keyup=generation_params.keyup where images.type = ? AND images.parent = ? ORDER by datemodified ASC', [type.index, parent]);
    // final List<Map<String, dynamic>> maps = await database.rawQuery(
    //     'images',
    //     orderBy: 'datemodified ASC',//ok
    //     columns: ['*', 'generation_params.full as fullParams'],//ok
    //     where: 'type = ? AND parent = ?', //ok
    //     whereArgs: [type.index, parent] //ok
    // );
    return List.generate(maps.length, (i) {
      if(maps[i]['colorType'] == null){
        print('--- ERROR ---');
        print(maps[i]);
        print('--- ERROR ---');
      }
      var d = maps[i];
      List<int> size = (d['size'] as String).split('x').map((e) => int.parse(e)).toList();
      return ImageMeta(
        re: RenderEngine.values[d['type'] as int],
        mine: d['mine'] as String,
        fileTypeExtension: d['fileTypeExtension'] as String,
        fileSize: d['fileSize'] as int,
        fullPath: d['fullPath'] as String,
        dateModified: DateTime.parse(d['dateModified'] as String),
        size: ImageSize(width: size[0], height: size[1]),
        bitDepth: d['bitDepth'] as int,
        colorType: d['colorType'] as int,
        compression: d['compression'] as int,
        filter: d['filter'] as int,
        colorMode: d['colorMode'] as int,
        thumbnail: d['thumbnail'] as String,
        generationParams: GenerationParams(
            positive: d['positive'] as String,
            negative: d['negative'] as String,
            steps: d['steps'] as int,
            sampler: d['sampler'] as String,
            cfgScale: d['cfgScale'] as double,
            seed: d['seed'] as int,
            size: ImageSize(width: d['sizeW'] as int, height: d['sizeH'] as int),
            modelHash: d['modelHash'] as String,
            model: d['model'] as String,
            denoisingStrength: d['denoisingStrength'] != null ? d['denoisingStrength'] as double : null,
            rng: d['rng'] != null ? d['rng'] as String : null,
            hiresSampler: d['hiresSampler'] != null ? d['hiresSampler'] as String : null,
            hiresUpscaler: d['hiresUpscaler'] != null ? d['hiresUpscaler'] as String : null,
            hiresUpscale: d['hiresUpscale'] != null ? d['hiresUpscale'] as double : null,
            version: d['version'] as String,
            rawData: d['rawData']
        )
      );
    });
    // SELECT seed, COUNT(seed) as order_count FROM images GROUP BY seed HAVING COUNT(seed) > 1 ORDER BY order_count desc
    // SELECT seed FROM images GROUP BY seed HAVING COUNT(seed) > 1 ORDER BY COUNT(seed) desc
  }

  Future<List<GenerationParams>> getGPByPath({required String path}) async {
    final List<Map<String, dynamic>> maps = await database.query(
        'generation_params',
        where: 'pathHash = ?',
        whereArgs: [genPathHash(path)]
    );

    return List.generate(maps.length, (i) {
      var d = maps[i];
      return GenerationParams(
        positive: d['positive'] as String,
        negative: d['negative'] as String,
        steps: d['steps'] as int,
        sampler: d['sampler'] as String,
        cfgScale: d['cfgScale'] as double,
        seed: d['seed'] as int,
        size: ImageSize(width: d['sizeW'] as int, height: d['sizeH'] as int),
        modelHash: d['modelHash'] as String,
        model: d['model'] as String,
        denoisingStrength: d['denoisingStrength'] != null ? d['denoisingStrength'] as double : null,
        rng: d['rng'] != null ? d['rng'] as String : null,
        hiresSampler: d['hiresSampler'] != null ? d['hiresSampler'] as String : null,
        hiresUpscaler: d['hiresUpscaler'] != null ? d['hiresUpscaler'] as String : null,
        hiresUpscale: d['hiresUpscale'] != null ? d['hiresUpscale'] as double : null,
        version: d['version'] as String,
        rawData: d['rawData']
      );
    });
    // SELECT seed, COUNT(seed) as order_count FROM images GROUP BY seed HAVING COUNT(seed) > 1 ORDER BY order_count desc
    // SELECT seed FROM images GROUP BY seed HAVING COUNT(seed) > 1 ORDER BY COUNT(seed) desc
  }

  Future<List<String>> getFavoritePaths() async {
    final List<Map<String, dynamic>> maps = await database.query(
        'favorites'
    );
    return maps.map((e) => e['fullPath'] as String).toList();
  }

  Future<void> updateFavorite(String pa, bool isFavorite) async {
    pa = path.normalize(pa);
    String ph = genPathHash(pa);

    if (isFavorite) {
      var values = {
        'pathHash': ph,
        'fullPath': pa,
        'parent': path.basename(File(pa).parent.path),
        'fileName': path.basename(pa)
      };
      database.insert(
        'favorites',
        values,
        conflictAlgorithm: ConflictAlgorithm.replace
      );
    } else {
      database.delete(
        'favorites',
        where: 'pathHash = ?',
        whereArgs: [ph]
      );
    }
  }
}

// ImageParams imageParamsFromJson(String data) {
//   final decoded = json.decode(data);
//   GenerationParams? gp;
//   var d = decoded['generationParams'];
//   if(d != null){
//     List<int> s = (d['size'] as String).split('x').map((e) => int.parse(e)).toList();
//     gp = GenerationParams(
//       positive: d['positive'] as String,
//       negative: d['negative'] as String,
//       steps: d['steps'] as int,
//       sampler: d['sampler'] as String,
//       cfgScale: d['cfgScale'] as double,
//       seed: d['seed'] as int,
//       size: ImageSize(width: s[0], height: s[1]),
//       modelHash: d['modelHash'] as String,
//       model: d['model'] as String,
//       denoisingStrength: d['denoisingStrength'] != null ? d['denoisingStrength'] as double : null,
//       rng: d['rng'] != null ? d['rng'] as String : null,
//       hiresSampler: d['hiresSampler'] != null ? d['hiresSampler'] as String : null,
//       hiresUpscale: d['hiresUpscale'] != null ? d['hiresUpscale'] as double : null,
//       version: d['version'] as String,
//     );
//   }
//
//   return ImageParams(
//       path: decoded['path'] as String,
//       fileName: decoded['fileName'] as String,
//       hasExif: decoded['hasExif'] != null ? decoded['hasExif'] as bool : false,
//       generationParams: gp
//   );
// }

String genHash(RenderEngine re, String parent, String name){
  List<int> bytes = utf8.encode([re.index.toString(), parent, name].join());
  String hash = sha256.convert(bytes).toString();
  return hash;
}

class TimelineProject {
  final int seed;
  final int count;
  List<ImageMeta>? images = [];

  TimelineProject({
    required this.seed,
    required this.count,
    this.images
  });
}

class Job{
  final String to;
  final JobType type;
  final dynamic obj;

  Job({
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