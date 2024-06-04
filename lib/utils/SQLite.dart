import 'dart:async';
import 'dart:convert';

import 'package:cimagen/components/NotesSection.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'NavigationService.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Directory, File, Platform;
import 'package:cimagen/utils/SaveManager.dart';

import '../Utils.dart';

class SQLite with ChangeNotifier{
  late Database database;
  late Database constDatabase;

  List<Job> toBatchOne = [];
  List<Job> toBatchTwo = [];
  bool use = false;
  bool inProgress = false;

  late Timer timer;

  Future<void> init() async {
    int dbVersion = 2;
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    Directory dD = await getApplicationDocumentsDirectory();
    Directory dbPath = Directory(path.join(dD.path, 'CImaGen', 'databases'));
    if (!await dbPath.exists()) {
      await dbPath.create(recursive: true);
    }
    dbPath = Directory(path.join(dD.path, 'CImaGen', 'databases', 'images_database.db'));

    database = await openDatabase(
      dbPath.path,
      onOpen: (db) async {
        await db.execute(
          'CREATE TABLE IF NOT EXISTS images('
            'keyup VARCHAR(256) PRIMARY KEY,'
            'isLocal BOOL,'
            'host VARCHAR(256),'
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
            'specific TEXT,'
            'imageParams TEXT,'
            'other TEXT,'
            'thumbnail TEXT'
          ')',
        );

        await db.execute(
          'CREATE TABLE IF NOT EXISTS generation_params('
            'keyup VARCHAR(256) PRIMARY KEY,'
            'isLocal BOOL,'
            'host VARCHAR(256),'
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
            'checkpointType INTEGER,'
            'checkpoint VARCHAR(256),'
            'checkpointHash VARCHAR(128),'
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

              await batch.commit(noResult: false, continueOnError: false);
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
      onCreate: (db, version) async {
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // switch (newVersion) {
        //   case 2:
        //   default:
        // }
      },
      version: dbVersion,
    );

    dbPath = Directory(path.join(dD.path, 'CImaGen', 'databases', 'const_database.db'));
    constDatabase = await openDatabase(
      dbPath.path,
      onOpen: (db){
        db.execute(
          'CREATE TABLE IF NOT EXISTS favorites('
            'pathHash VARCHAR(256) PRIMARY KEY,'
            'host VARCHAR(256),'
            'fullPath TEXT NOT NULL,'
            'fileName TEXT NOT NULL,'
            'parent TEXT NOT NULL'
          ')'
        );

        db.execute(
          'CREATE TABLE IF NOT EXISTS notes('
            'id INTEGER PRIMARY KEY AUTOINCREMENT,'
            'title VARCHAR(256),'
            'content TEXT,'
            'color VARCHAR(16),'
            'icon VARCHAR(128)'
          ')'
        );

        // Saved
        db.execute(
          'CREATE TABLE IF NOT EXISTS saved_categories('
            'id INTEGER PRIMARY KEY AUTOINCREMENT,'
            'title VARCHAR(256),'
            'description TEXT,'
            'color VARCHAR(16),'
            'icon VARCHAR(128),'
            'thumbnail TEXT'
          ')'
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        switch (newVersion) {
          case 2:
            await db.execute('ALTER TABLE favorites ADD host VARCHAR(256)');
            break;
          default:
        }
      },
      version: dbVersion,
    );
  }

  Future<bool> shouldUpdate(String path, {String? host}) async {
    List<Object> args = [genPathHash(path)];
    if(host != null) args.add(host);
    final List<Map<String, dynamic>> maps = await database.query(
      'images',
      where: 'pathHash = ? AND ${host == null ? 'host IS NULL' : 'host = ?'}',
      whereArgs: args,
    );
    return maps.isEmpty;
  }

  //TODO: ЧИНИМ
  Future<void> updateImages({required RenderEngine renderEngine, required ImageMeta imageMeta, bool fromWatch = false}) async {
    final String parentName = path.basename(File(imageMeta.fullPath).parent.path);
    final List<Map<String, dynamic>> maps = await database.query(
      'images',
      where: 'keyup = ?',
      whereArgs: [genHash(renderEngine, parentName, imageMeta.fileName, host: imageMeta.host)],
    );
    //print(genHash(type, parentName, imageMeta.imageParams.fileName));
    if (maps.isNotEmpty) {
    } else {
      //Insert
      if(use){
        toBatchTwo.add(Job(to: 'images', type: JobType.insert, obj: await imageMeta.toMap()));
        if(imageMeta.generationParams != null) {
          Map<String, dynamic> m = imageMeta.generationParams!.toMap(
              forDB: true,
              key: imageMeta.getKey(),
              amply: {
                'pathHash': genPathHash(imageMeta.fullPath)
              }
          );
          toBatchTwo.add(
            Job(
                to: 'generation_params',
                type: JobType.insert,
                obj: m
            )
          );
        }
      } else {
        toBatchOne.add(Job(to: 'images', type: JobType.insert, obj: await imageMeta.toMap()));
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
    }
  }

  Future<void> rawRun(List<String> que) async {
    Batch batch = database.batch();
    for(String q in que){
      batch.rawQuery(q);
    }
    await batch.apply();
  }

  Future<void> rawRunConst(List<String> que) async {
    Batch batch = constDatabase.batch();
    for(String q in que){
      batch.rawQuery(q);
    }
    await batch.apply();
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

  Future<List<ImageMeta>> getImagesBySeed(int seed) async {
    final List<Map<String, dynamic>> maps = await database.rawQuery('SELECT * from images join generation_params on images.keyup=generation_params.keyup where generation_params.seed = ? ORDER by datemodified ASC', [seed]);
    return List.generate(maps.length, (i) {
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
          specific: jsonDecode(d['specific'] as String) as Map<String, dynamic>,
          thumbnail: d['thumbnail'] as String,
          generationParams: GenerationParams(
              positive: d['positive'] as String,
              negative: d['negative'] as String,
              steps: d['steps'] as int,
              sampler: d['sampler'] as String,
              cfgScale: d['cfgScale'] as double,
              seed: d['seed'] as int,
              size: ImageSize(width: d['sizeW'] as int, height: d['sizeH'] as int),
              checkpointType: CheckpointType.values[d['checkpointType'] as int],
              checkpoint: d['checkpoint'] as String,
              checkpointHash: d['checkpointHash'] as String,
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
  }

  Future<List<ImageMeta>> findByTags(List<String> tags) async {
    String g = 'SELECT * from images join generation_params on images.keyup=generation_params.keyup where ${tags.map((e) => 'generation_params.positive LIKE ?').join(" AND ")} ORDER by datemodified DESC LIMIT 100';
    final List<Map<String, dynamic>> maps = await database.rawQuery(g, tags.map((e) => '%$e%').toList(growable: false));
    return List.generate(maps.length, (i) {
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
          specific: jsonDecode(d['specific'] as String) as Map<String, dynamic>,
          thumbnail: d['thumbnail'] == null ? null : d['thumbnail'] as String,
          generationParams: GenerationParams(
              positive: d['positive'] as String,
              negative: d['negative'] as String,
              steps: d['steps'] as int,
              sampler: d['sampler'] as String,
              cfgScale: d['cfgScale'] as double,
              seed: d['seed'] as int,
              size: ImageSize(width: d['sizeW'] as int, height: d['sizeH'] as int),
              checkpointType: CheckpointType.values[d['checkpointType'] as int],
              checkpoint: d['checkpoint'] as String,
              checkpointHash: d['checkpointHash'] as String,
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

  Future<List<ImageMeta>> getImagesByParent(dynamic type, String parent, {String? host}) async {
    if (kDebugMode) {
      print('$type ${type.runtimeType} $parent ${host ?? 'null'}');
    }
    List<dynamic> args = [];
    if(type.runtimeType == RenderEngine) args.add(type.index);
    args.add(parent);
    if(host != null) args.add(host);
    final List<Map<String, dynamic>> maps = await database.rawQuery('SELECT * FROM images JOIN generation_params on images.keyup=generation_params.keyup WHERE images.type ${type.runtimeType == RenderEngine ? '= ?' : 'IN(${type.map((value) => value.index).toList().join(',')})'} AND images.parent = ? ${host != null ? 'AND images.host = ? ' : ''}ORDER by datemodified ASC', args);
    List<ImageMeta> fi = List.generate(maps.length, (i) {
      var d = maps[i];
      List<int> size = (d['size'] as String).split('x').map((e) => int.parse(e)).toList();
      return ImageMeta(
        re: RenderEngine.values[d['type'] as int],
        host: d['host'] != null ? d['host'] as String : null,
        mine: d['mine'] as String,
        fileTypeExtension: d['fileTypeExtension'] as String,
        fileSize: d['fileSize'] as int,
        fullPath: d['fullPath'] as String,
        dateModified: DateTime.parse(d['dateModified'] as String),
        size: ImageSize(width: size[0], height: size[1]),
        specific: jsonDecode(d['specific'] as String),
        thumbnail: d['thumbnail'] == null ? null : d['thumbnail'] as String,
        generationParams: GenerationParams(
            positive: d['positive'] as String,
            negative: d['negative'] as String,
            steps: d['steps'] as int,
            sampler: d['sampler'] as String,
            cfgScale: d['cfgScale'] as double,
            seed: d['seed'] as int,
            size: ImageSize(width: d['sizeW'] as int, height: d['sizeH'] as int),
            checkpointType: CheckpointType.values[d['checkpointType'] as int],
            checkpoint: d['checkpoint'] as String,
            checkpointHash: d['checkpointHash'] as String,
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
    if (kDebugMode) {
      print(fi.length);
    }
    return fi;
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
        checkpointType: CheckpointType.values[d['checkpointType'] as int],
        checkpoint: d['checkpoint'] as String,
        checkpointHash: d['checkpointHash'] as String,
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
    final List<Map<String, dynamic>> maps = await constDatabase.query(
        'favorites'
    );
    return maps.map((e) => e['fullPath'] as String).toList();
  }

  Future<void> updateFavorite(String pa, bool isFavorite, {String? host}) async {
    pa = path.normalize(pa);
    String ph = genPathHash(pa);

    if (isFavorite) {
      var values = {
        'pathHash': ph,
        'fullPath': pa,
        'parent': path.basename(File(pa).parent.path),
        'fileName': path.basename(pa)
      };
      if(host != null) values[host] = host;
      constDatabase.insert(
        'favorites',
        values,
        conflictAlgorithm: ConflictAlgorithm.replace
      );
    } else {
      constDatabase.delete(
        'favorites',
        where: 'pathHash = ? AND host = ?',
        whereArgs: [ph]
      );
    }
  }

  // Notes
  Future<Note> createNote() async {
    Color color = getRandomColor();
    String title = 'New note';
    List<IconData> ic = [
      Icons.note_alt_outlined,
      Icons.ac_unit,
      Icons.photo_rounded,
      Icons.stadium_rounded,
      Icons.linear_scale_rounded
    ];
    int id = await constDatabase.insert(
        'notes',
        {
          'title': title,
          'color': '#FF${color.value.toRadixString(16).substring(2, 8)}'
        },
        conflictAlgorithm: ConflictAlgorithm.abort
    );
    return Note(id: id, title: title, content: '', color: color, icon: ic[0]);
  }

  Future<List<Note>> getNotes() async {
    final List<Map<String, dynamic>> maps = await constDatabase.query('notes');
    return List.generate(maps.length, (i) {
      var d = maps[i];
      return Note(id: d['id'] as int, title: d['title'] as String, content: d['content'] == null ? '' : d['content'] as String, color: fromHex(d['color'] as String), icon: Icons.sticky_note_2_sharp);
    });
  }

  Future<void> updateNoteTitle(int noteID, String title) async {
    constDatabase.update('notes', {
      'title': title.trim()
    },
        where: 'id = ?',
        whereArgs: [noteID]
    );
  }

  Future<void> updateNoteContent(int noteID, String content) async {
    await constDatabase.update('notes', {
        'content': content
      },
      where: 'id = ?',
      whereArgs: [noteID]
    );
  }

  Future<void> deleteNote(int noteID) async {
    await constDatabase.delete('notes',
        where: 'id = ?',
        whereArgs: [noteID]
    );
  }

  // Categories
  Future<Category> createCategory({required String title, String? description}) async {
    Color color = getRandomColor();
    int id = await constDatabase.insert(
        'saved_categories',
        {
          'title': title.trim(),
          'description': description,
          'color': '#FF${color.value.toRadixString(16).substring(2, 8)}'
        },
        conflictAlgorithm: ConflictAlgorithm.replace
    );

    return Category(
        id: id,
        title: title.trim(),
        description: description,
        color: color,
        icon: Icons.category
    );
  }

  Future<List<Category>> getCategories() async {
    final List<Map<String, dynamic>> maps = await constDatabase.query('saved_categories');
    return List.generate(maps.length, (i) {
      var d = maps[i];
      return Category(
        id: d['id'] as int,
        title: d['title'] as String,
        description: d['description'] == null ? '' : d['description'] as String,
        color: fromHex(d['color'] as String),
        icon: Icons.category,
        thumbnail: d['thumbnail']
      );
    });
  }

  // System
  Future<Map<String, int>> getTablesInfo() async {
      final List<Map<String, dynamic>> maps = await database.rawQuery(
          'SELECT'
              '(SELECT COUNT(keyup) FROM images) as totalImages,'
              '(SELECT COUNT(keyup) FROM generation_params) as totalImagesWithMetadata,'
              '(SELECT COUNT(keyup) FROM images WHERE type = 1) as txt2imgCount,'
              '(SELECT SUM(filesize) FROM images WHERe type = 1) as txt2imgSumSize,'
              '(SELECT COUNT(keyup) FROM images WHERE type = 2) as img2imgCount,'
              '(SELECT SUM(filesize) FROM images WHERE type = 2) as img2imgSumSize,'
              '(SELECT COUNT(keyup) FROM images WHERE type = 3) as inpaintCount,'
              '(SELECT SUM(filesize) FROM images WHERE type = 3) as inpaintSumSize,'
              '(SELECT COUNT(keyup) FROM images WHERE type = 7) as comfuiCount,'
              '(SELECT SUM(filesize) FROM images WHERE type = 7) as comfuiSumSize'
      );

      Map<String, int> finalMe = {};
      maps.first.forEach((key, value) {
        finalMe[key] = value == null ? 0 : value as int;
      });
      return finalMe;
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