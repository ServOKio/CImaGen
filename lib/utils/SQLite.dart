import 'dart:async';
import 'dart:convert';

import 'package:cimagen/pages/Comparison.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io' show File, Platform;

import '../Utils.dart';

class SQLite{
  late Database database;

  List<ImageMeta> toBatchOne = [];
  List<ImageMeta> toBatchTwo = [];
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
                send.forEach((element) {
                  batch.insert('images', element.toMap(forSQL: true));
                });
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
          return db.execute(
            'CREATE TABLE IF NOT EXISTS images('
                'keyup VARCHAR(256) PRIMARY KEY,'
                'type TINYINT,'
                'parent VARCHAR(128),'
                'name TEXT,'
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
      use ? toBatchTwo.add(imageMeta) : toBatchOne.add(imageMeta);
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

  imageParamsFromJson(String data) {
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

class ImageMeta {
  final RenderEngine re;
  final String? mine;
  final String fileTypeExtension;
  final DateTime dateModified;
  final int fileSize;
  final Size size;
  final int bitDepth;
  final int colorType;
  final int compression;
  final int filter;
  final int colorMode;
  final ImageParams imageParams;

  const ImageMeta({
    required this.re,
    required this.mine,
    required this.fileTypeExtension,
    required this.fileSize,
    required this.dateModified,
    required this.size,
    required this.bitDepth,
    required this.colorType,
    required this.compression,
    required this.filter,
    required this.colorMode,
    required this.imageParams
  });

  Map<String, dynamic> toMap({required bool forSQL}) {
    final String parentFolder = path.basename(File(imageParams.path).parent.path);
    return {
      'keyup': genHash(re, parentFolder, imageParams.fileName),
      'type': re.index,
      'parent': parentFolder,
      'name': imageParams.fileName,
      'seed': imageParams.generationParams?.seed,
      'dateModified': dateModified.toIso8601String(),

      'mine': mine,
      'fileTypeExtension': fileTypeExtension,
      'fileSize': fileSize,
      'size': size.toString(),
      'bitDepth': bitDepth,
      'colorType': colorType,
      'compression': compression,
      'filter': filter,
      'colorMode': colorMode,
      'imageParams': forSQL ? jsonEncode(imageParams.toMap()) : imageParams.toMap()
    };
  }
}

enum RenderEngine{
  unknown,
  txt2img,
  img2img,
  txt2imgGrid,
  img2imgGrid,
  extra,
  comfUI,
}