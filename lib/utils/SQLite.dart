import 'dart:async';
import 'dart:convert';

import 'package:cimagen/utils/ImageManager.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io' show File, Platform;

import '../Utils.dart';

class SQLite{
  late Database database;

  List<Job> toBatchOne = [];
  List<Job> toBatchTwo = [];
  bool use = false;
  bool inProgress = false;

  late Timer timer;

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
                Batch batch = db.batch();
                print('Sending ${send.length}...');
                for (var e in send) {
                  if(e.type == JobType.insert){
                    batch.insert(e.to, e.obj);
                  }
                }
                await batch.commit(continueOnError: true, noResult: true);
                print('Done');
                !use ? toBatchTwo.clear() : toBatchOne.clear();
                inProgress = false;
              }
            } on Exception {
              print('error');
            }
          });
        },
        onCreate: (db, version) {
          db.execute(
            'CREATE TABLE IF NOT EXISTS images('
                'keyup VARCHAR(256) PRIMARY KEY,'
                'type TINYINT,'
                'parent VARCHAR(128),'
                'name TEXT,'
                'pathHash VARCHAR(256),'
                'seed INTEGER,'
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
                'imageParams TEXT'
            ')',
          );

          db.execute(
            'CREATE TABLE IF NOT EXISTS generation_params('
              'keyup VARCHAR(256) PRIMARY KEY,'
              'type TINYINT,'
              'parent VARCHAR(128),'
              'name TEXT,'
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
              'hiresUpscale DOUBLE,'
              'tiHashes TEXT,'
              'version VARCHAR(16),'
              'full TEXT'
            ')',
          );
        },
        version: 1,
    );
  }

  Future<void> updateImages(RenderEngine type, ImageMeta imageMeta) async {
    final String parentFolder = path.basename(File(imageMeta.imageParams.path).parent.path);
    final List<Map<String, dynamic>> maps = await database.query(
      'images',
      where: 'keyup = ?',
      whereArgs: [genHash(type, parentFolder, imageMeta.imageParams.fileName)],
    );
    //print([type.index, parentFolder, imageMeta.imageParams.fileName]);
    print(genHash(type, parentFolder, imageMeta.imageParams.fileName));
    if (maps.isNotEmpty) {
      //print(maps.length);
    } else {
      //Insert
      if(use){
        toBatchTwo.add(Job(to: 'images', type: JobType.insert, obj: imageMeta.toMap(forSQL: true)));
        if(imageMeta.imageParams.generationParams != null) {
          toBatchTwo.add(
            Job(
                to: 'generation_params',
                type: JobType.insert,
                obj: imageMeta.imageParams.generationParams!.toMap(
                    forDB: true,
                    key: imageMeta.getKey(),
                    amply: {
                      'pathHash': genPathHash(imageMeta.imageParams.path)
                    }
                )
            )
          );
        }
      } else {
        toBatchOne.add(Job(to: 'images', type: JobType.insert, obj: imageMeta.toMap(forSQL: true)));
        if(imageMeta.imageParams.generationParams != null) {
          toBatchOne.add(
              Job(
                  to: 'generation_params',
                  type: JobType.insert,
                  obj: imageMeta.imageParams.generationParams!.toMap(
                      forDB: true,
                      key: imageMeta.getKey(),
                      amply: {
                        'pathHash': genPathHash(imageMeta.imageParams.path)
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

  Future<List<TimelineProject>> getPossibleTimelineProjects() async {
    final List<Map<String, dynamic>> maps = await database.query(
      'images',
      columns: ['seed', 'COUNT(seed) as order_count'],
      groupBy: 'seed',
      having: 'COUNT(seed) > 1',
      orderBy: 'order_count desc',
    );
    return maps.map((e) => TimelineProject(seed: e['seed'] as int, count: e['order_count'] as int)).toList();
    // SELECT seed, COUNT(seed) as order_count FROM images GROUP BY seed HAVING COUNT(seed) > 1 ORDER BY order_count desc
    // SELECT seed FROM images GROUP BY seed HAVING COUNT(seed) > 1 ORDER BY COUNT(seed) desc
  }

  Future<List<ImageMeta>> getImagesBySeed(int seed) async {
    final List<Map<String, dynamic>> maps = await database.query(
      'images',
      orderBy: 'datemodified ASC',
      where: 'seed = ?',
      whereArgs: [seed]
    );
    return List.generate(maps.length, (i) {
      List<int> s = (maps[i]['size'] as String).split('x').map((e) => int.parse(e)).toList();
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
          dateModified: DateTime.parse(maps[i]['dateModified'] as String),
          size: Size(width: s[0], height: s[1]),
          bitDepth: maps[i]['bitDepth'] as int,
          colorType: maps[i]['colorType'] as int,
          compression: maps[i]['compression'] as int,
          filter: maps[i]['filter'] as int,
          colorMode: maps[i]['colorMode'] as int,
          imageParams: imageParamsFromJson(maps[i]['imageParams'] as String)
      );
    });
    // SELECT seed, COUNT(seed) as order_count FROM images GROUP BY seed HAVING COUNT(seed) > 1 ORDER BY order_count desc
    // SELECT seed FROM images GROUP BY seed HAVING COUNT(seed) > 1 ORDER BY COUNT(seed) desc
  }

  Future<List<GenerationParams>> getGPByPath({required String path}) async {
    print(genPathHash(path));
    final List<Map<String, dynamic>> maps = await database.query(
        'generation_params',
        where: 'pathHash = ?',
        whereArgs: [genPathHash(path)]
    );

    print(maps.length);
    return List.generate(maps.length, (i) {
      var d = maps[i];
      return GenerationParams(
        positive: d['positive'] as String,
        negative: d['negative'] as String,
        steps: d['steps'] as int,
        sampler: d['sampler'] as String,
        cfgScale: d['cfgScale'] as double,
        seed: d['seed'] as int,
        size: Size(width: d['sizeW'] as int, height: d['sizeH'] as int),
        modelHash: d['modelHash'] as String,
        model: d['model'] as String,
        denoisingStrength: d['denoisingStrength'] != null ? d['denoisingStrength'] as double : null,
        rng: d['rng'] != null ? d['rng'] as String : null,
        hiresSampler: d['hiresSampler'] != null ? d['hiresSampler'] as String : null,
        hiresUpscale: d['hiresUpscale'] != null ? d['hiresUpscale'] as double : null,
        version: d['version'] as String,
        full: d['full']
      );
    });
    // SELECT seed, COUNT(seed) as order_count FROM images GROUP BY seed HAVING COUNT(seed) > 1 ORDER BY order_count desc
    // SELECT seed FROM images GROUP BY seed HAVING COUNT(seed) > 1 ORDER BY COUNT(seed) desc
  }

  Future<void> addLikeOrRemove(ImageMeta imageMeta, bool add) async {
    final String parentFolder = path.basename(File(imageMeta.imageParams.path).parent.path);
    final List<Map<String, dynamic>> maps = await database.query(
      'images',
      where: 'keyup = ?',
      whereArgs: [genHash(imageMeta.re, parentFolder, imageMeta.imageParams.fileName)],
    );
    if (maps.isNotEmpty) {

    }
  }
}

ImageParams imageParamsFromJson(String data) {
  final decoded = json.decode(data);
  GenerationParams? gp;
  var d = decoded['generationParams'];
  if(d != null){
    List<int> s = (d['size'] as String).split('x').map((e) => int.parse(e)).toList();
    gp = GenerationParams(
      positive: d['positive'] as String,
      negative: d['negative'] as String,
      steps: d['steps'] as int,
      sampler: d['sampler'] as String,
      cfgScale: d['cfgScale'] as double,
      seed: d['seed'] as int,
      size: Size(width: s[0], height: s[1]),
      modelHash: d['modelHash'] as String,
      model: d['model'] as String,
      denoisingStrength: d['denoisingStrength'] != null ? d['denoisingStrength'] as double : null,
      rng: d['rng'] != null ? d['rng'] as String : null,
      hiresSampler: d['hiresSampler'] != null ? d['hiresSampler'] as String : null,
      hiresUpscale: d['hiresUpscale'] != null ? d['hiresUpscale'] as double : null,
      version: d['version'] as String,
    );
  }

  return ImageParams(
      path: decoded['path'] as String,
      fileName: decoded['fileName'] as String,
      hasExif: decoded['hasExif'] != null ? decoded['hasExif'] as bool : false,
      generationParams: gp
  );
}

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