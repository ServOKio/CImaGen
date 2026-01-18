import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:cimagen/components/NotesSection.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:external_path/external_path.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sqflite/utils/utils.dart' as sqLite show firstIntValue;
import '../main.dart';
import '../modules/ConfigManager.dart';
import '../modules/webUI/AbMain.dart';
import '../objectbox.g.dart';
import 'DataModel.dart';
import 'NavigationService.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Directory, File, Platform;
import 'package:cimagen/modules/SaveManager.dart';

import '../Utils.dart';
import 'Objectbox.dart';

class SQLite{
  late Database database;
  late Database constDatabase;

  bool use = false;
  bool inProgress = false;

  late final SqlBatchQueue sqlQueue;

  Future<void> init() async {
    int dbVersion = 5;
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    Directory? dD;
    if(Platform.isAndroid){
      dD = Directory(await ExternalPath.getExternalStoragePublicDirectory(ExternalPath.DIRECTORY_DOCUMENTS));
    } else {
      dD = await getApplicationDocumentsDirectory();
    }
    dynamic dbPath = Directory(p.join(dD.path, 'CImaGen', 'databases'));
    if (!await dbPath.exists()) {
      await dbPath.create(recursive: true);
    }
    dbPath = File(p.join(dD.path, 'CImaGen', 'databases', 'images_database${kDebugMode ? '_debug' : ''}.db'));

    database = await openDatabase(
      dbPath.path,
      version: dbVersion,
      onOpen: (db) async {

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
        specific
      )
    ''');

        if (kDebugMode) print('DB path: ${db.path}');

        initSqlQueue(db);

        final notID = notificationManager!.show(
          thumbnail: const Icon(Icons.data_saver_off, color: Colors.greenAccent),
          title: 'Connected to DB',
          description: 'SQLite ready',
        );

        Future.delayed(const Duration(milliseconds: 10000), () => notificationManager!.close(notID));
      },

      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion == 0) return;

        if (kDebugMode) {
          print('DB upgrade: $oldVersion → $newVersion');
        }
      },
    );


    dbPath = File(p.join(dD.path, 'CImaGen', 'databases', 'const_database${kDebugMode ? '_debug' : ''}.db'));
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
        if(oldVersion == 0) return;
        if (kDebugMode) {
          print('old: $oldVersion, new: $newVersion');
        }
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

  void initSqlQueue(Database db) {
    sqlQueue = SqlBatchQueue(db);
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

  late final StreamSubscription migrationSub;

  Future<int> _getImageIdFast(Database db, String keyup) async {
    final res = await db.rawQuery(
      'SELECT id FROM images WHERE keyup = ? LIMIT 1',
      [keyup],
    );

    if (res.isEmpty) {
      throw StateError('Image not found for keyup=$keyup');
    }

    return res.first['id'] as int;
  }

  Stream<MigrationProgress> migrateObjectBoxToSql({
    required ObjectboxDB objectbox,
    required Database sqlDb,
    required SqlBatchQueue sqlQueue,
    int chunkSize = 1000,
  }) async* {
    final box = objectbox.store.box<ImageMeta>();

    final total = box.count();
    int processed = 0;
    int lastId = 0;

    yield MigrationProgress(
      processed: 0,
      total: total,
      percent: 0,
      stage: 'Starting migration',
    );

    while (true) {
      final qb = box.query(ImageMeta_.id.greaterThan(lastId))
        ..order(ImageMeta_.id);

      final query = qb.build()
        ..limit = chunkSize;

      final images = query.find();
      query.close();

      if (images.isEmpty) break;

      for (final im in images) {
        sqlQueue.add(
          SqlWriteJob.insert(
            'images',
            await im.toSqlMap(),
          ),
        );
        lastId = im.id;
      }

      await sqlQueue.dispose();

      for (final im in images) {
        final gp = im.generationParams;
        if (gp == null) continue;

        final imageId = await _getImageIdFast(sqlDb, im.keyup);

        // sqlQueue.add(
        //   SqlWriteJob.insert(
        //     'generation_params',
        //     gp.toSqlMap(imageId: imageId),
        //   ),
        // );
      }

      await sqlQueue.dispose();

      processed += images.length;

      yield MigrationProgress(
        processed: processed,
        total: total,
        percent: processed / total,
        stage: 'Migrating images',
      );

      await Future.delayed(const Duration(milliseconds: 1));
    }

    yield MigrationProgress(
      processed: processed,
      total: total,
      percent: 1.0,
      stage: 'Migration complete',
    );
  }



  void startMigration() {
    print('Migration started');
    int notID = notificationManager!.show(
        thumbnail: Shimmer.fromColors(
          baseColor: Colors.lightBlueAccent,
          highlightColor: Colors.blueAccent.withOpacity(0.3),
          child: const Icon(Icons.drive_file_move_sharp, color: Colors.white, size: 64),
        ),
        title: 'Starting migration',
        description: 'Just a second...'
    );

    int notIDWarning = notificationManager!.show(
        thumbnail: const Icon(Icons.warning, color: Colors.redAccent, size: 64),
        title: 'Don\'t touch the database file!',
        description: 'Even with other programs, it can disrupt the process and damage file'
    );

    migrationSub = migrateObjectBoxToSql(
      objectbox: objectbox,
      sqlDb: database,
      sqlQueue: sqlQueue,
    ).listen((progress) {
      notificationManager!.update(notID, 'content', Container(
          margin: const EdgeInsets.only(top: 7),
          width: 100,
          child: LinearProgressIndicator(value: progress.percent / 100)
      ));
      notificationManager!.update(notID, 'description', 'Process: ${progress.percent.toStringAsFixed(2)}%, stage: ${progress.stage}');
    }, onDone: () async {
      await sqlQueue.dispose();
      print('Migration complete & flushed');
      notificationManager!.update(notID, 'title', 'Migration complete & flushed');
    });
  }

  Future<void> updateImages({
    required ImageMeta imageMeta,
  }) async {
    sqlQueue.add(
      SqlWriteJob.insert(
        'images',
        await imageMeta.toSqlMap(),
      ),
    );

    final gp = imageMeta.generationParams;
    if (gp != null) {
      sqlQueue.add(
        SqlWriteJob.insert(
          'generation_params',
          gp.toSqlMap(imageKeyup: imageMeta.keyup),
        ),
      );
    }
  }

  // MAIN
  final HashMap<String, List<Folder>> foldersCache = HashMap();
  Future<List<Folder>> getFolders({
    String? host,
    RenderEngine? re,
    int previewLimit = 4,
  }) async {
    final cacheKey = '${host ?? "_"}|${re?.index ?? -1}';
    if (foldersCache.containsKey(cacheKey)) {
      return foldersCache[cacheKey]!;
    }

    final where = StringBuffer('1=1');
    final args = <dynamic>[];

    if (host == null) {
      where.write(' AND host IS NULL');
    } else {
      where.write(' AND host = ?');
      args.add(host);
    }

    if (re != null) {
      where.write(' AND dbRe = ?');
      args.add(re.index);
    }

    final days = await database.rawQuery('''
    SELECT dayKey
    FROM images
    WHERE $where
    GROUP BY dayKey
    ORDER BY dayKey DESC
  ''', args);

    final List<Folder> result = [];
    int folderIndex = 0;

    for (final row in days) {
      final int dayKey = row['dayKey'] as int;

      final y = dayKey ~/ 10000;
      final m = (dayKey ~/ 100) % 100;
      final d = dayKey % 100;
      final name = '$y-${_2(m)}-${_2(d)}';

      final images = await database.query(
        'images',
        columns: [
          'fullPath',
          'host',
          'dbThumbnail',
        ],
        where: '$where AND dayKey = ?',
        whereArgs: [...args, dayKey],
        orderBy: 'dateModified DESC',
        limit: previewLimit,
      );

      final files = images.map((m) {
        return FolderFile(
          fullPath: m['fullPath'] as String,
          isLocal: m['host'] == null,
          thumbnail: m['dbThumbnail'] != null
              ? base64Decode(m['dbThumbnail'] as String)
              : null,
        );
      }).toList(growable: false);

      result.add(
        Folder(
          index: folderIndex++,
          name: name,
          getter: name,
          type: FolderType.byDay,
          files: files,
        ),
      );
    }

    foldersCache[cacheKey] = result;
    return result;
  }
  String _2(int v) => v < 10 ? '0$v' : '$v';


  Future<List<ImageMeta>> getImagesByDay(
      String day, {
        String? host,
        RenderEngine? re,
      }) async {
    final dayDate = DateFormat('yyyy-MM-dd').parse(day);
    final start = dayDate.toIso8601String();
    final end = dayDate
        .add(const Duration(hours: 23, minutes: 59, seconds: 59))
        .toIso8601String();

    final where = StringBuffer('i.dateModified BETWEEN ? AND ?');
    final args = <dynamic>[start, end];

    if (host == null) {
      where.write(' AND i.host IS NULL');
    } else {
      where.write(' AND i.host = ?');
      args.add(host);
    }

    if (re != null) {
      where.write(' AND i.dbRe = ?');
      args.add(re.index);
    }

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
    WHERE ${where.toString()}
    ORDER BY i.dateModified
    ''',
      args,
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

  Map<String, dynamic> _extractGpMap(Map<String, dynamic> row) {
    final gp = <String, dynamic>{};

    for (final e in row.entries) {
      if (e.key.startsWith('gp_')) {
        gp[e.key.substring(3)] = e.value;
      }
    }

    return gp;
  }


  Future<List<ImageMeta>> getImagesBySeed(int seed, {String? host}) async {
    final args = <dynamic>[seed];

    final whereHost = host == null ? 'i.host IS NULL' : 'i.host = ?';
    if (host != null) args.add(host);

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
    WHERE gp.seed = ?
      AND $whereHost
    ORDER BY i.dateModified
    ''',
      args,
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

  Future<List<int>> getAvailableDays({
    String? host,
    RenderEngine? re,
    required int offset,
    required int limit,
  }) async {
    final where = StringBuffer('1=1');
    final args = <dynamic>[];

    if (host == null) {
      where.write(' AND host IS NULL');
    } else {
      where.write(' AND host = ?');
      args.add(host);
    }

    if (re != null) {
      where.write(' AND dbRe = ?');
      args.add(re.index);
    }

    final rows = await database.rawQuery('''
    SELECT DISTINCT dayKey
    FROM images
    WHERE $where
    ORDER BY dayKey DESC
    LIMIT ? OFFSET ?
  ''', [...args, limit, offset]);

    return rows.map((e) => e['dayKey'] as int).toList();
  }

  Future<Folder> getFolderByDay(
      int ymd, {
        String? host,
        RenderEngine? re,
      }) async {
    final y = ymd ~/ 10000;
    final m = (ymd ~/ 100) % 100;
    final d = ymd % 100;

    final start = DateTime(y, m, d).toIso8601String();
    final end = DateTime(y, m, d + 1).toIso8601String();

    final where = StringBuffer('dateModified BETWEEN ? AND ?');
    final args = <dynamic>[start, end];

    if (host == null) {
      where.write(' AND host IS NULL');
    } else {
      where.write(' AND host = ?');
      args.add(host);
    }

    if (re != null) {
      where.write(' AND dbRe = ?');
      args.add(re.index);
    }

    final rows = await database.query(
      'images',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'dateModified',
      limit: 4,
    );

    return Folder(
      index: 0,
      name: '$y-${_2(m)}-${_2(d)}',
      getter: '$y-${_2(m)}-${_2(d)}',
      type: FolderType.byDay,
      files: rows.map((m) {
        final im = _mapImage(m);
        return FolderFile(
          fullPath: im.fullPath!,
          isLocal: im.isLocal,
          thumbnail: im.thumbnail,
        );
      }).toList(growable: false),
    );
  }

  Future<void> updateIfNado(String path, {String? host}) async {
    path = normalizePath(path);

    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    if (!const {'png', 'jpg', 'jpeg', 'webp'}.contains(ext)) return;

    final name = p.basename(path).toLowerCase();
    if (name.contains('mask') || name.contains('before')) {
      if (kDebugMode) print('skip $name');
      return;
    }

    final pathHash = genPathHash(path);

    final exists = sqLite.firstIntValue(
      await database.rawQuery(
        '''
      SELECT 1
      FROM images
      WHERE pathHash = ?
        AND ${host == null ? 'host IS NULL' : 'host = ?'}
      LIMIT 1
      ''',
        host == null ? [pathHash] : [pathHash, host],
      ),
    ) != null;

    if (exists) {
      // Optional: update timestamp / size if needed later
      return;
    }

    final ImageMeta? im = await parseImage(RenderEngine.unknown, path);
    if (im == null) return;

    updateImages(imageMeta: im).then((value){
      final ctx = NavigationService.navigatorKey.currentContext;
      if (ctx != null && ctx.read<ImageManager>().useLastAsTest) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          final d = ctx.read<DataModel>();
          if (d != null) {
            d.comparisonBlock.moveTestToMain();
            d.comparisonBlock.changeSelected(1, im);
            d.comparisonBlock.addImage(im);
          }
        });
      }
    });
  }

  Future<List<String>> getFolderHashes(String folder, {String? host}) async {
    final parentKey = p.basename(folder);

    final rows = await database.query(
      'images',
      columns: ['pathHash'],
      where: 'parent = ? AND ${host == null ? 'host IS NULL' : 'host = ?'}',
      whereArgs: host == null ? [parentKey] : [parentKey, host],
    );

    return rows
        .map((row) => row['pathHash'] as String)
        .toList(growable: false);
  }

  Future<List<Folder>> getFoldersPaged({
    String? host,
    RenderEngine? re,
    required int offset,
    required int limit,
  }) async {
    final days = await getAvailableDays(
      host: host,
      re: re,
      offset: offset,
      limit: limit,
    );

    final List<Folder> result = [];

    for (final day in days) {
      result.add(
        await getFolderByDay(
          day,
          host: host,
          re: re,
        ),
      );
    }

    return result;
  }

  // OTHER

  Future<void> deleteAllFromHost(String? host) async {
    await database.delete(
      'images',
      where: host == null ? 'host IS NULL' : 'host = ?',
      whereArgs: host == null ? null : [host],
    );
  }

  Future<void> cleanUp(String? host) async {
    await database.delete(
      'images',
      where: '(dbRe = 0) AND ${host == null ? 'host IS NULL' : 'host = ?'}',
      whereArgs: host == null ? null : [host],
    );
  }

  Future<void> getBiggestAss() async {
    final rows = await database.query(
      'images',
      orderBy: 'fileSize DESC',
      limit: 1,
    );

    if (rows.isEmpty) return;

    final im = ImageMeta.fromSqlMap(rows.first);
  }

  // UTILS
  ImageMeta _mapImage(Map<String, dynamic> m) => ImageMeta.fromSqlMap(m);

  String _cachePath(ImageMeta im) {
    final cacheDir = NavigationService.navigatorKey.currentContext!.read<ConfigManager>().imagesCacheDir;

    final ext = im.specific?['hasAnimation'] == true ? 'png' : 'jpg';
    return p.join(cacheDir, '${im.host}_${im.keyup}.$ext');
  }


  Future<void> rawRun(List<String> que) async {
    Batch batch = database.batch();
    for(String q in que){
      batch.rawQuery(q);
    }
    await batch.apply();
  }

  Future<List<Map<String, dynamic>>> rawRunResult(String que) async {
    return await database.rawQuery(que);
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

  Future<List<String>> getFavoritePaths() async {
    final List<Map<String, dynamic>> maps = await constDatabase.query(
        'favorites'
    );
    return maps.map((e) => e['fullPath'] as String).toList();
  }

  Future<void> updateFavorite(String pa, bool isFavorite, {String? host}) async {
    pa = p.normalize(pa);
    String ph = genPathHash(pa);

    if (isFavorite) {
      var values = {
        'pathHash': ph,
        'fullPath': pa,
        'parent': p.basename(File(pa).parent.path),
        'fileName': p.basename(pa)
      };
      if(host != null) values['host'] = host;
      constDatabase.insert(
        'favorites',
        values,
        conflictAlgorithm: ConflictAlgorithm.replace
      );
    } else {
      constDatabase.delete(
        'favorites',
        where: 'pathHash = ? AND host ${host == null ? 'IS NULL' : '= ?'}',
        whereArgs: host != null ? [ph, host] : [ph]
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
  Future<Map<String, int>> getTablesInfo({String? host}) async {
    final sql = '''
  SELECT
    COUNT(*) AS totalImages,

    SUM(CASE WHEN type = 1 THEN 1 ELSE 0 END) AS txt2imgCount,
    SUM(CASE WHEN type = 2 THEN 1 ELSE 0 END) AS img2imgCount,
    SUM(CASE WHEN type = 3 THEN 1 ELSE 0 END) AS inpaintCount,
    SUM(CASE WHEN type = 6 THEN 1 ELSE 0 END) AS extraCount,
    SUM(CASE WHEN type = 7 THEN 1 ELSE 0 END) AS comfuiCount,

    SUM(CASE WHEN type = 0 THEN fileSize ELSE 0 END) AS unknownSumSize,
    SUM(CASE WHEN type = 1 THEN fileSize ELSE 0 END) AS txt2imgSumSize,
    SUM(CASE WHEN type = 2 THEN fileSize ELSE 0 END) AS img2imgSumSize,
    SUM(CASE WHEN type = 3 THEN fileSize ELSE 0 END) AS inpaintSumSize,
    SUM(CASE WHEN type = 6 THEN fileSize ELSE 0 END) AS extraSumSize,
    SUM(CASE WHEN type = 7 THEN fileSize ELSE 0 END) AS comfuiSumSize
  FROM images
  WHERE ${host == null ? 'host IS NULL' : 'host = ?'}
  ''';

    final res = await database.rawQuery(
      sql,
      host == null ? null : [host],
    );

    final row = res.first;

    return row.map(
          (k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0),
    );
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

enum SqlJobType {
  insert,
  update,
  raw,
}

class SqlWriteJob {
  final SqlJobType type;

  final String? table;
  final Map<String, dynamic>? values;

  final String? where;
  final List<Object?>? whereArgs;

  final String? sql;
  final List<Object?>? sqlArgs;

  /// INSERT
  SqlWriteJob.insert(this.table, this.values)
      : type = SqlJobType.insert,
        where = null,
        whereArgs = null,
        sql = null,
        sqlArgs = null;

  /// UPDATE
  SqlWriteJob.update(
      this.table,
      this.values, {
        required this.where,
        required this.whereArgs,
      })  : type = SqlJobType.update,
        sql = null,
        sqlArgs = null;

  /// RAW SQL
  SqlWriteJob.raw(
      this.sql, {
        this.sqlArgs,
      })  : type = SqlJobType.raw,
        table = null,
        values = null,
        where = null,
        whereArgs = null;
}


class SqlBatchQueue {
  final Database db;

  final int maxBatchSize;
  final Duration maxDelay;

  final List<SqlWriteJob> _queue = [];
  bool _running = false;
  Timer? _flushTimer;

  SqlBatchQueue(
      this.db, {
        this.maxBatchSize = 200,
        this.maxDelay = const Duration(seconds: 2),
      });

  void add(SqlWriteJob job) {
    _queue.add(job);

    if (!_running) {
      _scheduleFlush();
    }

    if (_queue.length >= maxBatchSize) {
      _triggerFlush();
    }
  }

  void _scheduleFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer(maxDelay, _triggerFlush);
  }

  void _triggerFlush() {
    if (_running) return;
    _flush();
  }

  Future<void> _flush() async {
    if (_queue.isEmpty) return;

    _running = true;
    _flushTimer?.cancel();

    final batch = db.batch();

    final jobs = _queue.take(maxBatchSize).toList();
    _queue.removeRange(0, jobs.length);

    for (final job in jobs) {
      switch (job.type) {
        case SqlJobType.insert:
          batch.insert(
            job.table!,
            job.values!,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          break;

        case SqlJobType.update:
          batch.update(
            job.table!,
            job.values!,
            where: job.where,
            whereArgs: job.whereArgs,
          );
          break;

        case SqlJobType.raw:
          batch.execute(
            job.sql!,
            job.sqlArgs,
          );
          break;
      }
    }

    try {
      await batch.commit(
        noResult: false,
        continueOnError: false,
      );
    } catch (e, st) {
      if (kDebugMode) {
        print('SQL batch error');
        print(e);
        print(st);
      }
    }

    _running = false;

    if (_queue.isNotEmpty) {
      _scheduleFlush();
    }
  }

  Future<void> dispose() async {
    _flushTimer?.cancel();
    await _flush();
  }
}
