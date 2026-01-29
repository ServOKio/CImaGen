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

<<<<<<< Updated upstream
  late Timer timer;
=======
  bool BLYATPIZDETS = !kDebugMode;

  late final SqlBatchQueue sqlQueue;
>>>>>>> Stashed changes

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

<<<<<<< Updated upstream
            'mine VARCHAR(64),'
            'fileTypeExtension VARCHAR(8),'
            'fileSize INTEGER,'
            'size VARCHAR(64),'
            'specific TEXT,'
            'imageParams TEXT,'
            'other TEXT,'
            'thumbnail TEXT'
          ')',
=======
        await db.execute('''
      CREATE TABLE IF NOT EXISTS images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        keyup TEXT UNIQUE NOT NULL,
        dayKey INTEGER NOT NULL,

        isLocal INTEGER NOT NULL,
        host TEXT,
        hostMD5 TEXT,

        dbRe INTEGER NOT NULL,
        parent TEXT,
        fileName TEXT,

        pathHash TEXT,
        fullPath TEXT,
        fullNetworkPath TEXT,

        dateModified DATETIME,
        fileSize INTEGER,

        mine TEXT,
        fileTypeExtension TEXT,

        size TEXT,
        specific TEXT,
        other TEXT,

        thumbnail TEXT
      )
    ''');

        await db.execute('CREATE INDEX IF NOT EXISTS idx_images_host ON images(host)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_images_re ON images(dbRe)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_images_pathHash ON images(pathHash)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_images_date ON images(dateModified)');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS generation_params (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            
            image_keyup TEXT NOT NULL,
    
            positive TEXT,
            negative TEXT,
    
            steps INTEGER,
            sampler TEXT,
            cfgScale REAL,
            seed INTEGER,
    
            sizeW INTEGER,
            sizeH INTEGER,
    
            checkpointType INTEGER,
            checkpoint TEXT,
            checkpointHash TEXT,
    
            vae TEXT,
            vaeHash TEXT,
    
            denoisingStrength REAL,
            rng TEXT,
    
            hiresSampler TEXT,
            hiresUpscaler TEXT,
            hiresUpscale REAL,
    
            tiHashes TEXT,
            version TEXT,
            params TEXT,
            rawData TEXT,
            rating INTEGER,
            FOREIGN KEY(image_keyup) REFERENCES images(keyup) ON DELETE CASCADE
          )
      ''');

        await db.execute('CREATE INDEX IF NOT EXISTS idx_gen_seed ON generation_params(seed)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_images_day_host_re ON images(dayKey, host, dbRe)');

        await db.execute('''
          CREATE VIRTUAL TABLE IF NOT EXISTS images_fts
          USING fts5(
            keyup,
            positive,
            negative,
            other,
            specific,
            tokenize = 'unicode61'
          )
        ''');

        await db.execute('''
          CREATE TRIGGER IF NOT EXISTS images_after_insert AFTER INSERT ON generation_params
          BEGIN
            INSERT INTO images_fts(keyup, positive, negative, other, specific)
            SELECT i.keyup, new.positive, new.negative, '', ''
            FROM images i
            WHERE i.keyup = new.image_keyup;
          END;
        ''');

        await db.execute('''
          CREATE TRIGGER IF NOT EXISTS images_after_update AFTER UPDATE ON generation_params
            BEGIN
              UPDATE images_fts
              SET positive = new.positive,
                  negative = new.negative
              WHERE keyup = new.image_keyup;
            END;
        ''');

        await db.execute('''
          CREATE TRIGGER IF NOT EXISTS images_after_delete AFTER DELETE ON generation_params
          BEGIN
            DELETE FROM images_fts WHERE keyup = old.image_keyup;
          END;
        ''');

        if (kDebugMode) print('DB path: ${db.path}');

        initSqlQueue(db);

        final notID = notificationManager!.show(
          thumbnail: const Icon(Icons.data_saver_off, color: Colors.greenAccent),
          title: 'Connected to DB',
          description: 'SQLite ready',
>>>>>>> Stashed changes
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

  Future<List<ImageMeta>> getImagesByParent(dynamic type, String parent) async {
    if (kDebugMode) {
      print('$type ${type.runtimeType} $parent');
    }
    final List<Map<String, dynamic>> maps = await database.rawQuery('SELECT * from images join generation_params on images.keyup=generation_params.keyup where images.type ${type.runtimeType == RenderEngine ? '= ?' : 'IN(${type.map((value) => value.index).toList().join(',')})'} AND images.parent = ? ORDER by datemodified ASC', type.runtimeType == RenderEngine ? [type.index, parent] : [parent]);
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
<<<<<<< Updated upstream
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
=======
  Future<Map<String, int>> getTablesInfo({String? host, int? year}) async {
    final sql = '''
  SELECT
    COUNT(*) AS totalImages,

    SUM(CASE WHEN dbRe = 0 THEN 1 ELSE 0 END) AS unknownCount,
    SUM(CASE WHEN dbRe = 1 THEN 1 ELSE 0 END) AS txt2imgCount,
    SUM(CASE WHEN dbRe = 2 THEN 1 ELSE 0 END) AS img2imgCount,
    SUM(CASE WHEN dbRe = 3 THEN 1 ELSE 0 END) AS inpaintCount,
    SUM(CASE WHEN dbRe = 4 THEN 1 ELSE 0 END) AS txt2imgGridCount,
    SUM(CASE WHEN dbRe = 5 THEN 1 ELSE 0 END) AS img2imgGridCount,
    SUM(CASE WHEN dbRe = 6 THEN 1 ELSE 0 END) AS extraCount,
    SUM(CASE WHEN dbRe = 7 THEN 1 ELSE 0 END) AS comfuiCount,

    SUM(CASE WHEN dbRe = 0 THEN fileSize ELSE 0 END) AS unknownSumSize,
    SUM(CASE WHEN dbRe = 1 THEN fileSize ELSE 0 END) AS txt2imgSumSize,
    SUM(CASE WHEN dbRe = 2 THEN fileSize ELSE 0 END) AS img2imgSumSize,
    SUM(CASE WHEN dbRe = 3 THEN fileSize ELSE 0 END) AS inpaintSumSize,
    SUM(CASE WHEN dbRe = 4 THEN fileSize ELSE 0 END) AS txt2imgGridSumSize,
    SUM(CASE WHEN dbRe = 5 THEN fileSize ELSE 0 END) AS img2imgGridSumSize,
    SUM(CASE WHEN dbRe = 6 THEN fileSize ELSE 0 END) AS extraSumSize,
    SUM(CASE WHEN dbRe = 7 THEN fileSize ELSE 0 END) AS comfuiSumSize
  FROM images
  WHERE ${host == null ? 'host IS NULL' : 'host = ?'}${year == null ? '' : ' AND dateModified >= \'$year-01-01\' AND dateModified <  \'$year-01-01\''}
  ''';

    final res = await database.rawQuery(
      sql,
      host == null ? null : [host],
    );

    final row = res.first;

    return row.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0));
  }


  Future<int> getImageIdByKeyup(String keyup) async {
    final res = await database.query(
      'images',
      columns: ['id'],
      where: 'keyup = ?',
      whereArgs: [keyup],
      limit: 1,
    );

    if (res.isEmpty) {
      throw StateError('Image not found for keyup=$keyup');
    }

    return res.first['id'] as int;
  }

  // Year data
  Future<List<List<int>>> yearsComparison(int year, {String? host}) async {
    List<int> currentYearCounts = List.filled(12, 0);
    List<int> previousYearCounts = List.filled(12, 0);

    final rows = await database.rawQuery('''
    SELECT 
      STRFTIME('%Y', dateModified) AS y,
      STRFTIME('%m', dateModified) AS m,
      COUNT(*) AS c
    FROM images
    WHERE STRFTIME('%Y', dateModified) IN (?, ?)
    GROUP BY y, m
  ''', [year.toString(), (year - 1).toString()]);

    for (final row in rows) {
      final y = int.parse(row['y'] as String);
      final m = int.parse(row['m'] as String); // 1..12
      final c = row['c'] as int;

      if (y == year) {
        currentYearCounts[m - 1] = c;
      } else if (y == year - 1) {
        previousYearCounts[m - 1] = c;
      }
    }

    return [currentYearCounts, previousYearCounts];
  }

  Future<int> countCumInNovember(int year, {String? host}) async {
    final startDate = '$year-11-01';
    final endDate = '$year-12-01';

    final rows = await database.rawQuery('''
    SELECT
      SUM( (LENGTH(LOWER(positive)) - LENGTH(REPLACE(LOWER(positive), 'cum', ''))) / 3 ) AS cum_count
    FROM generation_params gp
    JOIN images i ON i.keyup = gp.image_keyup
    WHERE gp.positive IS NOT NULL
      AND i.dateModified >= ?
      AND i.dateModified < ?
  ''', [startDate, endDate]);

    // SQLite returns null if no rows
    final count = rows.first['cum_count'] as num?;
    return count?.toInt() ?? 0;
  }

  Future<List<List<dynamic>>> topArtists({
    required int year,
    String? host,
    int limit = 50,
  }) async {
    final whereHost = host != null ? 'AND i.host = ?' : '';
    final startDate = '$year-01-01';
    final endDate = '${year + 1}-01-01';

    final args = <Object>[
      if (host != null) host,
      startDate,
      endDate,
      limit,
    ];

    final rows = await database.rawQuery('''
    WITH cleaned AS (
      SELECT
        LOWER(
          REPLACE(
            REPLACE(
              REPLACE(
                REPLACE(
                  REPLACE(
                    REPLACE(
                      REPLACE(
                        REPLACE(gp.positive, CHAR(10), ''),
                      CHAR(13), ''),
                    '[', ','),
                  ']', ','),
                '(', ','),
              ')', ','),
            '<', ','),
          '>', ',')
        ) AS text
      FROM generation_params gp
      JOIN images i
        ON i.keyup = gp.image_keyup
      WHERE gp.positive IS NOT NULL
        $whereHost
        AND i.dateModified >= ?
        AND i.dateModified <  ?
    ),
    
    split(tag, rest) AS (
      SELECT
        TRIM(SUBSTR(text, 1, INSTR(text || ',', ',') - 1)),
        SUBSTR(text || ',', INSTR(text || ',', ',') + 1)
      FROM cleaned
    
      UNION ALL
    
      SELECT
        TRIM(SUBSTR(rest, 1, INSTR(rest, ',') - 1)),
        SUBSTR(rest, INSTR(rest, ',') + 1)
      FROM split
      WHERE rest <> ''
    )
    
    SELECT
      artist,
      COUNT(*) AS count
    FROM (
      SELECT
        TRIM(SUBSTR(tag, 4)) AS artist
      FROM split
      WHERE tag LIKE 'by %'
        AND tag NOT GLOB '*[0-9]*'
        AND SUBSTR(tag, 4) NOT LIKE '%by %'
        AND LENGTH(tag) >= 6
    )
    GROUP BY artist
    ORDER BY count DESC
    LIMIT ?
    ''', args);

    return rows
        .map((row) => [
      row['artist'] as String,
      (row['count'] as num).toInt(),
    ])
        .toList(growable: false);
  }

  Future<List<ImageMeta>> getTopByFileSize(
      int year, {
        String? host,
        int limit = 50,
      }) async {
    final args = <Object>[
      '$year-01-01',
      '${year + 1}-01-01',
    ];

    final whereHost = host != null ? 'AND host = ?' : '';
    if (host != null) args.add(host);
    args.add(limit);

    // STEP 1 — fast keyup lookup
    final keyRows = await database.rawQuery(
      '''
  SELECT keyup
  FROM images i
  WHERE i.fileSize IS NOT NULL
    AND i.dateModified >= ?
    AND i.dateModified <  ?
    ${host != null ? 'AND i.host = ?' : ''}
    AND (
      i.specific IS NULL
      OR json_extract(i.specific, '\$.hasAnimation') IS NOT 1
    )
  ORDER BY i.fileSize DESC
  LIMIT ?
  ''',
      args,
    );

    if (keyRows.isEmpty) return [];

    final keyups = keyRows.map((e) => e['keyup']).toList();
    final placeholders = List.filled(keyups.length, '?').join(',');

    // STEP 2 — fetch full rows
    final rows = await database.rawQuery(
      '''
    SELECT
      i.*,
      gp.id AS gp_id,
      gp.positive AS gp_positive,
      gp.negative AS gp_negative,
      gp.steps AS gp_steps,
      gp.sampler AS gp_sampler,
      gp.cfgScale AS gp_cfgScale,
      gp.seed AS gp_seed,
      gp.sizeW AS gp_sizeW,
      gp.sizeH AS gp_sizeH,
      gp.checkpointType AS gp_checkpointType,
      gp.checkpoint AS gp_checkpoint,
      gp.checkpointHash AS gp_checkpointHash,
      gp.vae AS gp_vae,
      gp.vaeHash AS gp_vaeHash,
      gp.denoisingStrength AS gp_denoisingStrength,
      gp.rng AS gp_rng,
      gp.hiresSampler AS gp_hiresSampler,
      gp.hiresUpscaler AS gp_hiresUpscaler,
      gp.hiresUpscale AS gp_hiresUpscale,
      gp.tiHashes AS gp_tiHashes,
      gp.params AS gp_params,
      gp.rawData AS gp_rawData,
      gp.rating AS gp_rating
    FROM images i
    LEFT JOIN generation_params gp
      ON gp.image_keyup = i.keyup
    WHERE i.keyup IN ($placeholders)
    ORDER BY i.fileSize DESC
    ''',
      keyups,
    );

    return rows.map((row) {
      final im = _mapImage(row);

      if (row['gp_id'] != null) {
        im.generationParams =
            GenerationParamsSql.fromSqlMap(_extractGpMap(row));
      }

      im.cacheFilePath = _cachePath(im);
      return im;
    }).toList(growable: false);
  }




  // System
  Future<void> fixDB() async {
    print('start fix');
    List<Map<String, dynamic>> maps = await database.query(
      'images',
      columns: ['fullPath', 'keyup', 'cached_image'],
      where: 'host = ?',
      whereArgs: ['web'],
      limit: 10
    );
    Batch batch = database.batch();
    if (kDebugMode) print('fixDB: Checking ${maps.length} images...');
    for (var record in maps) {
      // batch.update('images', {
      //   'pathHash': genPathHash(normalizePath(record['fullPath']))
      // }, where: 'keyup = ?', whereArgs: [record['keyup']]);
    }
    await batch.commit(noResult: false, continueOnError: false);

    if (kDebugMode) print('fixDB: Done');
  }

  Future<void> testDB() async {
    print('start test');

    if (kDebugMode) {
      print('testDB: Done');
    }
  }
>>>>>>> Stashed changes
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