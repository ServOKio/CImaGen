import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:cimagen/components/Animations.dart';
import 'package:cimagen/components/NotesSection.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:csv/csv.dart';
import 'package:external_path/external_path.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sqflite/utils/utils.dart' as sqLite show firstIntValue;
import '../constants.dart';
import '../main.dart';
import '../pages/sub/E621Search.dart';
import '../utils/DBExceptions.dart';
import 'ConfigManager.dart';
import 'webUI/AbMain.dart';
import '../objectbox.g.dart';
import '../utils/DataModel.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Directory, File, Platform;

import '../Utils.dart';
import 'Objectbox.dart';

class SQLite{
  late Database database;
  late Database constDatabase;

  bool use = false;

  bool BLYATPIZDETS = !kDebugMode;
  int debug_index = 0;

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
    dbPath = File(p.join(dD.path, 'CImaGen', 'databases', 'images_database${!BLYATPIZDETS ? '_debug${debug_index == 0 ? '' : '_$debug_index'}' : ''}.db'));
    if (kDebugMode) {
      print('DB: using ${dbPath.path}');
    }

    database = await openDatabase(
      dbPath.path,
      version: dbVersion,
      onOpen: (db) async {
        if(isDesktop){
          await db.execute('PRAGMA journal_mode = WAL;');
          await db.execute('PRAGMA synchronous = NORMAL;');
          await db.execute('PRAGMA cache_size = -20000;');
        }
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
        await db.execute('CREATE INDEX IF NOT EXISTS idx_images_day_host_re_date ON images(dayKey, host, dbRe, dateModified)');


        await db.execute('''
      CREATE TABLE IF NOT EXISTS generation_params (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        
        image_keyup TEXT NOT NULL UNIQUE,

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

        await db.execute('CREATE INDEX IF NOT EXISTS idx_gp_image_keyup ON generation_params(image_keyup)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_gen_seed ON generation_params(seed)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_gp_id ON generation_params(id)');

        try{
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
        } on DatabaseException catch(e){
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
        }

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

        await db.execute('''
          CREATE TABLE IF NOT EXISTS e621posts (
            id INTEGER PRIMARY KEY,
            uploader_id INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            md5 TEXT NOT NULL,
            source TEXT,
            rating TEXT NOT NULL,
            image_width INTEGER NOT NULL,
            image_height INTEGER NOT NULL,
            tag_string TEXT NOT NULL,
            locked_tags TEXT,
            fav_count INTEGER NOT NULL,
            file_ext TEXT NOT NULL,
            parent_id INTEGER,
            change_seq INTEGER NOT NULL,
            approver_id INTEGER,
            file_size INTEGER NOT NULL,
            comment_count INTEGER NOT NULL,
            description TEXT,
            duration TEXT,
            updated_at TEXT,
            is_deleted INTEGER NOT NULL DEFAULT 0,
            is_pending INTEGER NOT NULL DEFAULT 0,
            is_flagged INTEGER NOT NULL DEFAULT 0,
            score INTEGER NOT NULL,
            up_score INTEGER NOT NULL,
            down_score INTEGER NOT NULL,
            is_rating_locked INTEGER NOT NULL DEFAULT 0,
            is_status_locked INTEGER NOT NULL DEFAULT 0,
            is_note_locked INTEGER NOT NULL DEFAULT 0
          )
        ''');

        await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_md5 ON e621posts(md5);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_created_at ON e621posts(created_at);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_score ON e621posts(score);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_fav_count ON e621posts(fav_count);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_uploader_id ON e621posts(uploader_id);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_parent_id ON e621posts(parent_id);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_rating ON e621posts(rating);');

        try{
          await db.execute("""
          CREATE VIRTUAL TABLE IF NOT EXISTS post_tags_fts USING fts4(
            tag_string,
            content='e621posts',
            tokenize="unicode61 tokenchars '_()-/.:'''"
          );
        """);
        } on DatabaseException catch(e){
          await db.execute("""
          CREATE VIRTUAL TABLE IF NOT EXISTS post_tags_fts USING fts5(
            tag_string,
            content='e621posts',
            content_rowid='id',
            tokenize="unicode61 tokenchars '_()-'"
          );
        """);
        }

        await db.execute('''
          CREATE TRIGGER IF NOT EXISTS e621posts_ai AFTER INSERT ON e621posts BEGIN
            INSERT INTO post_tags_fts(rowid, tag_string) VALUES (new.id, new.tag_string);
          END;
        ''');

        await db.execute('''
          CREATE TRIGGER IF NOT EXISTS e621posts_au AFTER UPDATE OF tag_string ON e621posts BEGIN
            INSERT INTO post_tags_fts(post_tags_fts, rowid, tag_string) VALUES('delete', old.id, old.tag_string);
            INSERT INTO post_tags_fts(rowid, tag_string) VALUES (new.id, new.tag_string);
          END;
        ''');

        await db.execute('''
          CREATE TRIGGER IF NOT EXISTS e621posts_ad AFTER DELETE ON e621posts BEGIN
            INSERT INTO post_tags_fts(post_tags_fts, rowid, tag_string) VALUES('delete', old.id, old.tag_string);
          END;
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


    dbPath = File(p.join(dD.path, 'CImaGen', 'databases', 'const_database${!BLYATPIZDETS ? '_debug${debug_index == 0 ? '' : '_$debug_index'}' : ''}.db'));
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

        db.execute('''
          CREATE TABLE IF NOT EXISTS notes (
            id      INTEGER PRIMARY KEY AUTOINCREMENT,
            title   TEXT NOT NULL DEFAULT 'New note',
            content TEXT NOT NULL DEFAULT '',
            color   TEXT NOT NULL DEFAULT '#FF3F51B5',
            icon    TEXT NOT NULL DEFAULT 'note_alt_outlined'
          )
        ''');

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
      notificationManager!.update(notID, (o){
        o.setDescription('Process: ${progress.percent.toStringAsFixed(2)}%, stage: ${progress.stage}');
        o.setContent(Container(
            margin: const EdgeInsets.only(top: 7),
            width: 100,
            child: LinearProgressIndicator(value: progress.percent / 100)
        ));
      });
    }, onDone: () async {
      await sqlQueue.dispose();
      notificationManager!.update(notID, (o){
        o.setDescription(null);
        o.setTitle('Migration complete & flushed');
      });
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
    debugPrint('sql:getImagesByDay $day $host $re');
    final dt = DateFormat('yyyy-MM-dd').parse(day);
    final dayKey = dt.year * 10000 + dt.month * 100 + dt.day;

    final where = StringBuffer('i.dayKey = ?');
    final args = <dynamic>[dayKey];

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
      int dayKey, {
        String? host,
        RenderEngine? re,
      }) async {
    final y = dayKey ~/ 10000;
    final m = (dayKey ~/ 100) % 100;
    final d = dayKey % 100;

    final where = StringBuffer('dayKey = ?');
    final args = <dynamic>[dayKey];

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

    final countResult = await database.rawQuery(
      'SELECT COUNT(*) as c FROM images WHERE ${where.toString()}',
      args,
    );

    final total = sqLite.firstIntValue(countResult) ?? 0;

    if (total == 0) {
      return Folder(
        index: 0,
        name: '$y-${_2(m)}-${_2(d)}',
        getter: '$y-${_2(m)}-${_2(d)}',
        type: FolderType.byDay,
        total: 0,
        files: const [],
      );
    }

    final indexes = <int>{
      0,
      (total * 0.33).floor(),
      (total * 0.66).floor(),
      total - 1,
    }.toList()
      ..sort();

    final files = <FolderFile>[];

    for (final i in indexes) {
      final rows = await database.query(
        'images',
        where: where.toString(),
        whereArgs: args,
        orderBy: 'dateModified',
        limit: 1,
        offset: i,
      );

      if (rows.isNotEmpty) {
        final im = _mapImage(rows.first);
        files.add(
          FolderFile(
            fullPath: im.fullPath!,
            isLocal: im.isLocal,
            thumbnail: im.thumbnail,
          ),
        );
      }
    }

    return Folder(
      index: 0,
      name: '$y-${_2(m)}-${_2(d)}',
      getter: '$y-${_2(m)}-${_2(d)}',
      type: FolderType.byDay,
      total: total,
      files: List.unmodifiable(files),
    );
  }


  Future<ImageMeta?> updateIfNado(String path, {String? host}) async {
    path = normalizePath(path);

    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    if (!const {'png', 'jpg', 'jpeg', 'webp'}.contains(ext)) return null;

    final name = p.basename(path).toLowerCase();
    if (name.contains('mask') || name.contains('before')) {
      if (kDebugMode) print('skip $name');
      return null;
    }

    final pathHash = genPathHash(path);

    final exists = sqLite.firstIntValue(
      await database.rawQuery(
        '''
      SELECT 1
      FROM images
      WHERE pathHash = ? AND ${host == null ? 'host IS NULL' : 'host = ?'}
      LIMIT 1
      ''',
        host == null ? [pathHash] : [pathHash, host],
      ),
    ) != null;

    if (exists) {
      // Optional: update timestamp / size if needed later
      return null;
    }

    final ImageMeta? im = await parseImage(RenderEngine.unknown, path);
    if (im == null) return null;

    updateImages(imageMeta: im).then((value){
      final ctx = kBaseNavigatorKey.currentContext!;
      if (ctx.read<ImageManager>().useLastAsTest) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          final d = ctx.read<DataModel>();
          d.comparisonBlock.moveTestToMain();
          d.comparisonBlock.changeSelected(2, im);
          d.comparisonBlock.addImage(im);
        });
      }
    });
    return im;
  }

  Future<List<String>> getFolderHashes(String folder, {String? host}) async {
    final parentKey = p.basename(folder);

    final rows = await database.query(
      'images',
      columns: ['pathHash'],
      where: 'parent = ? AND ${host == null ? 'host IS NULL' : 'host = ?'}',
      whereArgs: host == null ? [parentKey] : [parentKey, host],
    );

    return rows.map((row) => row['pathHash'] as String).toList(growable: false);
  }

  Future<List<Folder>> getFoldersPaged({
    String? host,
    RenderEngine? re,
    required int offset,
    required int limit,
  }) async {
    debugPrint('sql:getFoldersPaged $host $re $offset $limit');
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

  bool searchInProgress = false;

  Future<List<ImageMeta>> search(String query, String? host) async {
    if (searchInProgress) return [];
    searchInProgress = true;

    try {
      final cleanQuery = query.replaceAll(',', ' ').trim();
      final terms = cleanQuery
          .split(RegExp(r'\s+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      List<String> positiveTags = [];
      List<String> negativeTags = [];
      Map<String, String> filters = {};

      for (var term in terms) {
        if (term.startsWith('-')) {
          final tag = term.substring(1).trim();
          if (tag.isNotEmpty) negativeTags.add(tag);
        } else if (term.contains(':')) {
          final parts = term.split(':');
          final key = parts[0].toLowerCase().trim();
          final value = parts.sublist(1).join(':').trim();
          if (key.isNotEmpty) filters[key] = value;
        } else {
          final tag = term.trim();
          if (tag.isNotEmpty) positiveTags.add(tag);
        }
      }

      final ftsPositive = positiveTags.join(' ');
      final ftsNegative = negativeTags.map((t) => 'NOT $t').join(' ');

      String ftsQuery;
      if (positiveTags.isNotEmpty && negativeTags.isNotEmpty) {
        ftsQuery = '$ftsPositive $ftsNegative';
      } else if (positiveTags.isNotEmpty) {
        ftsQuery = ftsPositive;
      } else if (negativeTags.isNotEmpty) {
        ftsQuery = negativeTags.map((t) => 'NOT $t').join(' ');
      } else {
        ftsQuery = '';
      }

      final useFts = ftsQuery.isNotEmpty;

      final whereParts = <String>[];
      final queryArgs = <Object?>[];

      if (useFts) {
        whereParts.add('images_fts MATCH ?');
        queryArgs.add(ftsQuery);
      }

      if (filters.isNotEmpty) {
        for (final entry in filters.entries) {
          final key = entry.key;
          final value = entry.value;

          switch (key) {
            case 'seed':
            case 'steps':
            case 'rating':
              final intVal = int.tryParse(value);
              if (intVal != null) {
                whereParts.add('gp.$key = ?');
                queryArgs.add(intVal);
              }
              break;

            case 'cfgscale':
            case 'hiresupscale':
            case 'denoisingsstrength':
              final doubleVal = double.tryParse(value);
              if (doubleVal != null) {
                whereParts.add('gp.$key = ?');
                queryArgs.add(doubleVal);
              }
              break;

            case 'file':
              whereParts.add("i.fileName LIKE ?");
              queryArgs.add('%.${value.toLowerCase()}');
              break;

            default:
              whereParts.add("i.$key LIKE ?");
              queryArgs.add('%$value%');
          }
        }
      }

      if (host == null) {
        whereParts.add('i.host IS NULL');
      } else if (host.isNotEmpty) {
        whereParts.add('i.host = ?');
        queryArgs.add(host);
      }

      final whereClause = whereParts.isNotEmpty
          ? 'WHERE ${whereParts.join(' AND ')}'
          : '';

      final fromClause = useFts
          ? '''
      FROM images_fts
      JOIN images i ON images_fts.keyup = i.keyup
      LEFT JOIN generation_params gp ON gp.image_keyup = i.keyup
    '''
          : '''
      FROM images i
      LEFT JOIN generation_params gp ON gp.image_keyup = i.keyup
    ''';

      final sql = '''
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
      $fromClause
      $whereClause
      ORDER BY i.dateModified DESC
      LIMIT 1000
    ''';

      final rows = await database.rawQuery(sql, queryArgs);

      return rows.map((row) {
        final im = _mapImage(row);
        if (row['gp_id'] != null) {
          im.generationParams = GenerationParamsSql.fromSqlMap(_extractGpMap(row));
        }
        im.cacheFilePath = _cachePath(im);
        return im;
      }).toList(growable: false);
    } finally {
      searchInProgress = false;
    }
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

  Future<void> rebuildContentRating(String? host) async {
    final db = database;

    const int batchSize = 1000;
    int lastId = 0;
    int processed = 0;

    final notificationId = notificationManager!.show(
      thumbnail: const Icon(Icons.build, size: 64, color: Colors.blue),
      title: 'Preparing content rating rebuild...',
      description: 'Starting...',
    );

    final warningId = notificationManager!.show(
      thumbnail: const Icon(Icons.warning, color: Colors.orange, size: 64),
      title: 'Do not touch the database file!',
      description: 'External access may corrupt the process.',
    );

    try {
      final totalResult = await db.rawQuery('''
      SELECT COUNT(gp.id) as cnt
      FROM generation_params gp
      ${host != null ? 'JOIN images i ON i.keyup = gp.image_keyup WHERE i.host = ?' : ''}
    ''', host != null ? [host] : []);

      final int total = sqLite.firstIntValue(totalResult) ?? 0;

      if (total == 0) {
        notificationManager!.update(notificationId, (o) => o.setTitle('Nothing to rebuild'));
        return;
      }

      while (true) {
        final rows = await db.rawQuery('''
        SELECT gp.id, gp.positive
        FROM generation_params gp
        ${host != null ? 'JOIN images i ON i.keyup = gp.image_keyup' : ''}
        WHERE gp.id > ?
        ${host != null ? 'AND i.host = ?' : ''}
        ORDER BY gp.id
        LIMIT $batchSize
      ''', host != null ? [lastId, host] : [lastId]);

        if (rows.isEmpty) break;

        await db.transaction((txn) async {
          final batch = txn.batch();

          for (final row in rows) {
            final int id = row['id'] as int;
            final String? positive = row['positive'] as String?;

            final int ratingIndex =
                kBaseNavigatorKey.currentContext!
                    .read<DataModel>()
                    .contentRatingModule
                    .getContentRating(positive ?? '')
                    .index;

            batch.update(
              'generation_params',
              {'rating': ratingIndex},
              where: 'id = ?',
              whereArgs: [id],
            );

            lastId = id;
          }

          await batch.commit(noResult: true);
        });

        processed += rows.length;

        final progress = processed / total;

        notificationManager!.update(notificationId, (o) {
          o.setDescription('Processed: $processed / $total (${(progress * 100).toStringAsFixed(1)}%)');
          o.setContent(Container(
            margin: const EdgeInsets.only(top: 10),
            child: CImaGenLinearProgressIndicator(value: progress),
          ));
        });
        await Future.delayed(const Duration(milliseconds: 10));
      }

      notificationManager!.update(notificationId, (o) {
        o.setTitle('Content rating rebuild completed');
        o.setDescription('Processed $processed records');
      });
      notificationManager!.close(warningId);
    } catch (e) {
      notificationManager!.update(notificationId, (o) {
        o.setTitle('Error during rebuild');
        o.setDescription(e.toString());
      });
      rethrow;
    }
  }


  // UTILS
  ImageMeta _mapImage(Map<String, dynamic> m) => ImageMeta.fromSqlMap(m);

  String _cachePath(ImageMeta im) {
    if(!im.isLocal && im.fullNetworkPath == null && im.fullPath != null){
      return im.fullPath!;
    }
    final cacheDir = kBaseNavigatorKey.currentContext!.read<ConfigManager>().imagesCacheDir;

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
  Future<Note> createNote({
    String title = 'New note',
    Color? color,
    IconData? icon,
  }) async {
    color ??= _getRandomColor();
    icon ??= _getRandomIcon();

    final String colorHex = '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';

    final id = await constDatabase.insert(
      'notes',
      {
        'title': title,
        'content': '',
        'color': colorHex,
        'icon': iconToString(icon),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return Note(
      id: id,
      title: title,
      content: '',
      color: color,
      icon: icon,
    );
  }

// Helper functions
  Color _getRandomColor() {
    final colors = [
      Colors.indigoAccent,
      Colors.redAccent,
      Colors.greenAccent,
      Colors.yellowAccent.shade700,
      Colors.purpleAccent,
      Colors.tealAccent,
      Colors.orangeAccent,
      Colors.cyanAccent,
    ];
    return colors[Random().nextInt(colors.length)];
  }

  IconData _getRandomIcon() {
    final icons = [
      Icons.note_alt_outlined,
      Icons.lightbulb_outline,
      Icons.star_outline,
      Icons.check_circle_outline,
      Icons.favorite_border,
      Icons.palette_outlined,
      Icons.music_note_outlined,
      Icons.book_outlined,
    ];
    return icons[Random().nextInt(icons.length)];
  }

  String iconToString(IconData icon) {
    return icon.toString().split('.').last;
  }

  IconData stringToIcon(String iconName) {
    final iconMap = {
      'note_alt_outlined': Icons.note_alt_outlined,
      'lightbulb_outline': Icons.lightbulb_outline,
      'star_outline': Icons.star_outline,
      'check_circle_outline': Icons.check_circle_outline,
      'favorite_border': Icons.favorite_border,
      'palette_outlined': Icons.palette_outlined,
      'music_note_outlined': Icons.music_note_outlined,
      'book_outlined': Icons.book_outlined,
      'ac_unit': Icons.ac_unit,
      'photo_rounded': Icons.photo_rounded,
    };

    return iconMap[iconName] ?? Icons.note_alt_outlined;
  }

  Future<List<Note>> getNotes() async {
    final List<Map<String, dynamic>> maps = await constDatabase.query('notes');

    return List.generate(maps.length, (i) {
      final map = maps[i];
      return Note(
        id: map['id'] as int,
        title: map['title'] as String? ?? 'New note',
        content: map['content'] as String? ?? '',
        color: _hexToColor(map['color'] as String? ?? '#FF3F51B5'),
        icon: stringToIcon(map['icon'] as String? ?? 'note_alt_outlined'),
      );
    });
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
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

  Future<void> updateNoteColor(int id, Color newColor) async {
    final String colorHex = '#${newColor.value.toRadixString(16).padLeft(8, '0').substring(2)}';

    await constDatabase.update(
      'notes',
      {'color': colorHex},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateNoteIcon(int id, IconData newIcon) async {
    final String iconName = iconToString(newIcon);

    await constDatabase.update(
      'notes',
      {'icon': iconName},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // System
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

  // e621
  Future<void> updatePosts(File csvFile) async {
    print('File exists: ${csvFile.existsSync()}');
    print('File size: ${await csvFile.length()} bytes');

    if (await csvFile.length() == 0) {
      print('File is empty → nothing to process');
      return;
    }

    await _dropIndexes(database);

    const int batchSize = 5000;
    const int commitEvery = 20;
    List<List<dynamic>> pendingRows = [];
    int rowCount = 0;

    try {
      final bytes = await csvFile.readAsBytes();
      int startOffset = 0;
      if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
        print('Detected UTF-8 BOM → skipping it');
        startOffset = 3;
      }

      final inputStream = csvFile.openRead(startOffset);
      final rowStream = inputStream
          .transform(utf8.decoder)
          .transform(const CsvToListConverter(
            shouldParseNumbers: false,
            eol: '\n',
          )).handleError((error, stack) {
            print('Stream error: $error');
          });

      await for (var row in rowStream) {
        rowCount++;
        if (rowCount <= 3) {
          print('First few rows: $row');
        }

        pendingRows.add(row);

        if (pendingRows.length >= batchSize * commitEvery) {
          await _processLargeChunk(pendingRows);
          pendingRows = [];
          print('Processed large chunk (total rows: $rowCount)');
        }
      }
      await database.execute("INSERT INTO post_tags_fts(post_tags_fts) VALUES('rebuild');");
      print('Stream completed. Total rows read: $rowCount');

      if (pendingRows.isNotEmpty) {
        await _processLargeChunk(pendingRows);
        print('Processed final chunk');
      }

      await _createIndexes(database);

      print('Import finished successfully');
    } catch (e, st) {
      print('Fatal error during streaming: $e');
      print(st);
      rethrow;
    }
  }

  Future<void> _processLargeChunk(List<List<dynamic>> rows) async {
    const int batchSize = 5000;
    await database.transaction((txn) async {
      Batch batch = txn.batch();
      int subBatchCount = 0;

      for (var rawData in rows) {
        if (rawData.length < 29) continue;

        final data = rawData.map((e) => e?.toString() ?? '').toList();

        try {
          final int id = int.parse(data[0]);
          final int uploaderID = int.parse(data[1]);
          final String createdAt = data[2];
          final String md5 = data[3];
          final String source = data[4];
          final String rating = data[5];
          final int width = int.parse(data[6]);
          final int height = int.parse(data[7]);
          final String tagString = data[8];
          final String lockedTags = data[9];
          final int favCount = int.parse(data[10]);
          final String fileExt = data[11];
          final int? parentID = data[12].isEmpty ? null : int.parse(data[12]);
          final int changeSeq = int.parse(data[13]);
          final int? approverID = data[14].isEmpty ? null : int.parse(data[14]);
          final int fileSize = int.parse(data[15]);
          final int commentCount = int.parse(data[16]);
          final String? description = data[17].isEmpty ? null : data[17];
          final String duration = data[18];
          final String updatedAt = data[19];
          final int isDeleted = data[20] == 't' ? 1 : 0;
          final int isPending = data[21] == 't' ? 1 : 0;
          final int isFlagged = data[22] == 't' ? 1 : 0;
          final int score = int.parse(data[23]);
          final int upScore = int.parse(data[24]);
          final int downScore = int.parse(data[25]);
          final int isRatingLocked = data[26] == 't' ? 1 : 0;
          final int isStatusLocked = data[27] == 't' ? 1 : 0;
          final int isNoteLocked = data[28] == 't' ? 1 : 0;

          batch.insert(
            'e621posts',
            {
              'id': id,
              'uploader_id': uploaderID,
              'created_at': createdAt,
              'md5': md5,
              'source': source.isEmpty ? null : source,
              'rating': rating,
              'image_width': width,
              'image_height': height,
              'tag_string': tagString,
              'locked_tags': lockedTags.isEmpty ? null : lockedTags,
              'fav_count': favCount,
              'file_ext': fileExt,
              'parent_id': parentID,
              'change_seq': changeSeq,
              'approver_id': approverID,
              'file_size': fileSize,
              'comment_count': commentCount,
              'description': description,
              'duration': duration.isEmpty ? null : duration,
              'updated_at': updatedAt.isEmpty ? null : updatedAt,
              'is_deleted': isDeleted,
              'is_pending': isPending,
              'is_flagged': isFlagged,
              'score': score,
              'up_score': upScore,
              'down_score': downScore,
              'is_rating_locked': isRatingLocked,
              'is_status_locked': isStatusLocked,
              'is_note_locked': isNoteLocked,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );

          subBatchCount++;
          if (subBatchCount % batchSize == 0) {
            await batch.commit(noResult: true);
            batch = txn.batch();
          }
        } catch (e) {
          continue;
        }
      }

      if (subBatchCount % batchSize != 0) {
        await batch.commit(noResult: true);
      }
    });
  }

  Future<void> _dropIndexes(Database database) async {
    await database.execute('DROP INDEX IF EXISTS idx_md5;');
    await database.execute('DROP INDEX IF EXISTS idx_created_at;');
    await database.execute('DROP INDEX IF EXISTS idx_score;');
    await database.execute('DROP INDEX IF EXISTS idx_fav_count;');
    await database.execute('DROP INDEX IF EXISTS idx_uploader_id;');
    await database.execute('DROP INDEX IF EXISTS idx_parent_id;');
    await database.execute('DROP INDEX IF EXISTS idx_rating;');
  }

  Future<void> _createIndexes(Database database) async {
    await database.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_md5 ON e621posts(md5);');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_created_at ON e621posts(created_at);');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_score ON e621posts(score);');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_fav_count ON e621posts(fav_count);');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_uploader_id ON e621posts(uploader_id);');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_parent_id ON e621posts(parent_id);');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_rating ON e621posts(rating);');
  }

  Future<List<Map<String, dynamic>>> getCooccurringTags(String targetTag, Database db) async {
    String matchQuery = '"$targetTag"';

    final cursor = await db.rawQueryCursor(
      '''
      SELECT e621posts.tag_string 
      FROM e621posts 
      INNER JOIN post_tags_fts ON e621posts.id = post_tags_fts.rowid 
      WHERE post_tags_fts.tag_string MATCH ?
    ''',
      [matchQuery],
    );

    Map<String, int> counts = {};

    while (await cursor.moveNext()) {
      final row = cursor.current;
      final String tagString = row['tag_string'] as String;
      final List<String> tags = tagString.split(' ');
      for (final tag in tags) {
        if (tag != targetTag && tag.isNotEmpty) {
          counts.update(tag, (value) => value + 1, ifAbsent: () => 1);
        }
      }
    }

    await cursor.close();

    final List<Map<String, dynamic>> result = counts.entries
        .map((e) => {'tag': e.key, 'count': e.value})
        .toList();

    result.sort((a, b) => (a['count'] as int).compareTo(b['count'] as int));

    return result;
  }

  Future<Map<String, dynamic>> searchPosts(String query, int page, int limit) async {
    List<String> terms = query.trim().split(RegExp(r'\s+'));

    List<String> positiveTags = [];
    List<String> negativeTags = [];
    List<String> whereClauses = [];
    List<dynamic> params = [];
    String orderBy = 'created_at DESC';

    for (String term in terms) {
      if (term.isEmpty) continue;

      if (term.contains(':')) {
        // Metatag
        var parts = term.split(':');
        String meta = parts[0].toLowerCase();
        String value = parts.sublist(1).join(':');

        switch (meta) {
          case 'rating':
            String r = value.toLowerCase()[0]; // s, q, e
            whereClauses.add('rating = ?');
            params.add(r);
            break;
          case 'score':
          case 'favcount':
          case 'id':
            String column = meta == 'favcount' ? 'fav_count' : meta;
            _parseNumericMetatag(column, value, whereClauses, params);
            break;
          case 'type':
            whereClauses.add('file_ext = ?');
            params.add(value.toLowerCase());
            break;
          case 'md5':
            whereClauses.add('md5 = ?');
            params.add(value);
            break;
          case 'order':
            orderBy = _parseOrder(value);
            break;
        // Add more metatags as needed, e.g., width, height, source:*example*
          default:
          // Unknown metatag, ignore or handle as tag
            _handleTag(term, positiveTags, negativeTags);
        }
      } else {
        // Regular tag
        _handleTag(term, positiveTags, negativeTags);
      }
    }

    // Build SQL
    String baseSelect = 'SELECT * FROM e621posts';
    bool useFts = positiveTags.isNotEmpty || negativeTags.isNotEmpty;

    if (useFts) {
      baseSelect += ' INNER JOIN post_tags_fts ON e621posts.id = post_tags_fts.rowid';
    }

    String where = '';
    List<dynamic> matchParams = [];

    if (positiveTags.isNotEmpty) {
      where += 'post_tags_fts.tag_string MATCH ?';
      matchParams.add(positiveTags.map((t) => '"$t"').join(' AND '));
    }

    if (negativeTags.isNotEmpty) {
      if (where.isNotEmpty) where += ' AND ';
      where += 'NOT (post_tags_fts.tag_string MATCH ?)';
      matchParams.add(negativeTags.map((t) => '"$t"').join(' OR '));
    }

    if (whereClauses.isNotEmpty) {
      if (where.isNotEmpty) where += ' AND ';
      where += whereClauses.join(' AND ');
    }

    List<dynamic> allParams = [...matchParams, ...params];

    if (where.isNotEmpty) {
      baseSelect += ' WHERE $where';
    }

    baseSelect += ' ORDER BY $orderBy LIMIT ? OFFSET ?';
    allParams.add(limit);
    allParams.add((page - 1) * limit);

    print(baseSelect);
    print(allParams);

    var rawPosts = await database.rawQuery(baseSelect, allParams);
    var posts = rawPosts.map((map) => E621Post.fromMap(map)).toList();

    bool hasMore = posts.length == limit;

    return {
      'posts': posts,
      'hasMore': hasMore,
    };
  }

  void _handleTag(String term, List<String> positiveTags, List<String> negativeTags) {
    if (term.startsWith('-')) {
      negativeTags.add(term.substring(1));
    } else if (term.startsWith('~')) {
      // OR not supported in basic version
      positiveTags.add(term.substring(1));
    } else {
      positiveTags.add(term);
    }
  }

  void _parseNumericMetatag(String column, String value, List<String> clauses, List<dynamic> params) {
    if (value.contains(',')) {
      List<int> nums = value.split(',').map((s) => int.parse(s.trim())).toList();
      clauses.add('$column IN (${List.filled(nums.length, '?').join(', ')})');
      params.addAll(nums);
    } else if (value.contains('..')) {
      var range = value.split('..');
      String start = range[0].trim();
      String end = range[1].trim();
      if (start.isEmpty) {
        clauses.add('$column <= ?');
        params.add(int.parse(end));
      } else if (end.isEmpty) {
        clauses.add('$column >= ?');
        params.add(int.parse(start));
      } else {
        clauses.add('$column BETWEEN ? AND ?');
        params.add(int.parse(start));
        params.add(int.parse(end));
      }
    } else if (value.startsWith('>=')) {
      clauses.add('$column >= ?');
      params.add(int.parse(value.substring(2)));
    } else if (value.startsWith('>')) {
      clauses.add('$column > ?');
      params.add(int.parse(value.substring(1)));
    } else if (value.startsWith('<=')) {
      clauses.add('$column <= ?');
      params.add(int.parse(value.substring(2)));
    } else if (value.startsWith('<')) {
      clauses.add('$column < ?');
      params.add(int.parse(value.substring(1)));
    } else {
      clauses.add('$column = ?');
      params.add(int.parse(value));
    }
  }

  String _parseOrder(String value) {
    bool asc = value.endsWith('_asc');
    String field = asc ? value.substring(0, value.length - 4) : value;
    String dir = asc ? 'ASC' : 'DESC';

    switch (field) {
      case 'score':
        return 'score $dir';
      case 'favcount':
        return 'fav_count $dir';
      case 'id':
        return 'id $dir';
    // Add more: random (but needs special handling, e.g., 'RANDOM()')
      case 'random':
        return 'RANDOM()';
      default:
        return 'id DESC';
    }
  }

  Future<void> checkDBErrors() async {
    final duplicates = await database.rawQuery('''
    SELECT image_keyup
    FROM generation_params
    GROUP BY image_keyup
    HAVING COUNT(*) > 1
  ''');

    if (duplicates.isNotEmpty) {
      throw DuplicateGenerationParamsException(
        duplicates.map((e) => e['image_keyup'] as String).toList(),
      );
    }

    final orphans = await database.rawQuery('''
    SELECT gp.image_keyup
    FROM generation_params gp
    LEFT JOIN images i ON i.keyup = gp.image_keyup
    WHERE i.keyup IS NULL
  ''');

    // DELETE FROM generation_params
    // WHERE rowid IN (
    //     SELECT gp.rowid
    //     FROM generation_params gp
    //     LEFT JOIN images i ON i.keyup = gp.image_keyup
    //     WHERE i.keyup IS NULL
    // );

    if (orphans.isNotEmpty) {
      throw OrphanGenerationParamsException(
        orphans.map((e) => e['image_keyup'] as String).toList(),
      );
    }
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

  Future<List<ImageMeta>> getTopByImageSize(
      int year, {
        String? host,
        int limit = 50,
      }) async {
    final args = <Object>[
      '$year-01-01',
      '${year + 1}-01-01',
    ];

    final whereHost = host != null ? 'AND i.host = ?' : '';
    if (host != null) {
      args.add(host);
    }

    args.add(limit);

    // STEP 1 — get top keyups by parsed size
    final keyRows = await database.rawQuery(
      '''
    WITH ranked AS (
      SELECT
        i.keyup,
        i.size,
        ROW_NUMBER() OVER (
          PARTITION BY i.size
          ORDER BY i.dateModified DESC
        ) AS rn
      FROM images i
      WHERE i.size IS NOT NULL
        AND i.size LIKE '%x%'
        AND i.dateModified >= ?
        AND i.dateModified < ?
        $whereHost
    )
    SELECT keyup
    FROM ranked
    WHERE rn = 1
    ORDER BY
      CAST(SUBSTR(size, 1, INSTR(size, 'x') - 1) AS INTEGER)
      *
      CAST(SUBSTR(size, INSTR(size, 'x') + 1) AS INTEGER)
    DESC
    LIMIT ?
    ''',
      args,
    );

    if (keyRows.isEmpty) return [];

    final keyups = keyRows.map((e) => e['keyup']).toList();
    final placeholders = List.filled(keyups.length, '?').join(',');

    // STEP 2 — hydrate full rows
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
    ORDER BY (
      CAST(SUBSTR(i.size, 1, INSTR(i.size, 'x') - 1) AS INTEGER)
      +
      CAST(SUBSTR(i.size, INSTR(i.size, 'x') + 1) AS INTEGER)
    ) DESC
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
