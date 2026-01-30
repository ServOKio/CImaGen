import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:external_path/external_path.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'package:path/path.dart' as p;
import 'package:fast_csv/fast_csv_ex.dart' as fast_csv_ex;
import 'package:fast_csv/csv_converter.dart';

import '../Utils.dart';
import '../pages/sub/PromptAnalyzer.dart';
import '../main.dart';

class DataManager with ChangeNotifier {
  String? error;
  bool get hasError => error != null;

  HashMap<String, dynamic> temp = HashMap();

  void updateError(String? message){
    error = message;
    notifyListeners();
  }

  bool loaded = false;
  int _count = 0;

  //Getter
  int get count => _count;

  String? latestE621Tags;
  Map<String, TagInfo> _e621Tags = {};
  Map<String, TagInfo> get e621Tags => _e621Tags;
  Map<String, List<String>> _contentRatingTags = {};
  Map<String, List<String>> get contentRatingTags => _contentRatingTags;

  String? latestE621Posts;

  String userAgent = '';

  Future<void> init() async {
    await loadE621Tags();
    await loadE621Posts();
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    userAgent = "CImaGen/${packageInfo.version} (platform; ${Platform.isAndroid ? 'android' : Platform.isWindows ? 'windows' : Platform.isIOS ? 'IOS' : Platform.isLinux ? 'linux' : Platform.isFuchsia ? 'fuchsia' : Platform.isMacOS ? 'MacOs' : 'Unknown'})";
    loaded = true;
    notifyListeners();
  }

  // https://e621.net/db_export/
  Future<void> loadE621Tags() async {
    Directory? dD;
    if(Platform.isAndroid){
      dD = Directory(await ExternalPath.getExternalStoragePublicDirectory(ExternalPath.DIRECTORY_DOCUMENTS));
    } else if(Platform.isWindows){
      dD = await getApplicationDocumentsDirectory();
    }
    if(dD == null){
      int notID = 0;
      notID = notificationManager!.show(
          thumbnail: const Icon(Icons.question_mark, color: Colors.orangeAccent, size: 32),
          title: 'Documents folder not found',
          description: 'It seems to be some kind of system error. Check the settings section and folder paths',
          content: Padding(padding: EdgeInsets.only(top: 7), child: ElevatedButton(
              style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                  shape: WidgetStateProperty.all<RoundedRectangleBorder>(const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))))
              ),
              onPressed: (){
                notificationManager!.close(notID);
                loadE621Tags();
              },
              child: const Text("Try again", style: TextStyle(fontSize: 12))
          ))
      );
      audioController!.player.play(AssetSource('audio/wrong.wav'));
      return;
    }
    dynamic csvPath = Directory(p.join(dD.path, 'CImaGen', 'csv'));
    if (!csvPath.existsSync()) {
      await csvPath.create(recursive: true);
    }
    // 1. Find e621 latest files
    // 2025-01-27
    List<FileSystemEntity> files = await dirContents(csvPath);
    csvPath = File(p.join(dD.path, 'CImaGen', 'csv', 'tags.csv'));
    RegExp fileRegex = RegExp(r"tags-([0-9]{4}-[0-9]{2}-[0-9]{2})\.csv$");
    DateFormat format = DateFormat("yyyy-MM-dd");
    files = files.where((file) => fileRegex.hasMatch(p.basename(file.path))).toList(growable: false);
    DateTime? latest;
    for(FileSystemEntity f in files){
      DateTime d = format.parse(fileRegex.firstMatch(p.basename(f.path))![1]!);
      if(latest == null){
        latest = d;
        csvPath = File(f.path);
      } else if(d.isAfter(latest)){
        latest = d;
        csvPath = File(f.path);
      }
    }

    if (csvPath.existsSync()) {
      latestE621Tags = csvPath.path;
      File(csvPath.path).readAsString().then((value) async {
        final data = await compute(fast_csv_ex.parse, value);
        data.skip(1).forEach((e) {
          _e621Tags[e[1]] = TagInfo(id: int.parse(e[0]), name: e[1], category: int.parse(e[2]), count: int.parse(e[3]));
        });
      });
    } else {
      int notID = 0;
      notID = notificationManager!.show(
        thumbnail: const Icon(Icons.question_mark, color: Colors.orangeAccent, size: 32),
        title: 'Tags not found',
        description: 'Put the tags-YYYY-mm-dd.csv file in folder:\n   "${csvPath.parent.path}"\nYou can download tags, for example, from https://e621.net/db_export/',
        content: Padding(padding: EdgeInsets.only(top: 7), child: ElevatedButton(
            style: ButtonStyle(
                foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                shape: WidgetStateProperty.all<RoundedRectangleBorder>(const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))))
            ),
            onPressed: (){
              notificationManager!.close(notID);
              init();
            },
            child: const Text("Try again", style: TextStyle(fontSize: 12))
        ))
      );
      audioController!.player.play(AssetSource('audio/wrong.wav'));
    }
  }


  Future<void> loadContentRatingTags() async {
    Directory? dD;
    if(Platform.isAndroid){
      dD = Directory(await ExternalPath.getExternalStoragePublicDirectory(ExternalPath.DIRECTORY_DOCUMENTS));
    } else if(Platform.isWindows){
      dD = await getApplicationDocumentsDirectory();
    }
    if(dD == null){
      int notID = 0;
      notID = notificationManager!.show(
          thumbnail: const Icon(Icons.question_mark, color: Colors.orangeAccent, size: 32),
          title: 'Documents folder not found',
          description: 'It seems to be some kind of system error. Check the settings section and folder paths',
          content: Padding(padding: EdgeInsets.only(top: 7), child: ElevatedButton(
              style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                  shape: WidgetStateProperty.all<RoundedRectangleBorder>(const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))))
              ),
              onPressed: (){
                notificationManager!.close(notID);
                loadContentRatingTags();
              },
              child: const Text("Try again", style: TextStyle(fontSize: 12))
          ))
      );
      audioController!.player.play(AssetSource('audio/wrong.wav'));
      return;
    }
    dynamic jsonPath = Directory(p.join(dD.path, 'CImaGen', 'json'));
    if (!jsonPath.existsSync()) {
      await jsonPath.create(recursive: true);
    }

    File crtFile = File(p.join(dD.path, 'CImaGen', 'csv', 'content-rating.json'));
    if (crtFile.existsSync()) {
      crtFile.readAsString().then((v) async {
        var data = await json.decode(v);
        _contentRatingTags = {
          "G": List<String>.from(data['G']),
          "PG": List<String>.from(data['PG']),
          "PG_13": List<String>.from(data['PG_13']),
          "R": List<String>.from(data['R']),
          "NC_17": List<String>.from(data['NC_17']),
          "X": List<String>.from(data['X']),
          "XXX": List<String>.from(data['XXX'])
        };
      });
    } else {
      int notID = 0;
      notID = notificationManager!.show(
          thumbnail: const Icon(Icons.question_mark, color: Colors.orangeAccent, size: 32),
          title: 'Content rating tags not found',
          description: 'Put the content-rating.json file in folder:\n   "${crtFile.parent.path}"\nYou can ask someone for this file or create it yourself',
          content: Padding(padding: EdgeInsets.only(top: 7), child: ElevatedButton(
              style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                  shape: WidgetStateProperty.all<RoundedRectangleBorder>(const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))))
              ),
              onPressed: (){
                notificationManager!.close(notID);
                loadContentRatingTags();
              },
              child: const Text("Try again", style: TextStyle(fontSize: 12))
          ))
      );
      audioController!.player.play(AssetSource('audio/wrong.wav'));
    }
  }

  Future<void> loadE621Posts() async {
    Directory? dD;
    if(Platform.isAndroid){
      dD = Directory(await ExternalPath.getExternalStoragePublicDirectory(ExternalPath.DIRECTORY_DOCUMENTS));
    } else if(Platform.isWindows){
      dD = await getApplicationDocumentsDirectory();
    }
    if(dD == null){
      int notID = 0;
      notID = notificationManager!.show(
          thumbnail: const Icon(Icons.question_mark, color: Colors.orangeAccent, size: 32),
          title: 'Documents folder not found',
          description: 'It seems to be some kind of system error. Check the settings section and folder paths',
          content: Padding(padding: EdgeInsets.only(top: 7), child: ElevatedButton(
              style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                  shape: WidgetStateProperty.all<RoundedRectangleBorder>(const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))))
              ),
              onPressed: (){
                notificationManager!.close(notID);
                loadE621Tags();
              },
              child: const Text("Try again", style: TextStyle(fontSize: 12))
          ))
      );
      audioController!.player.play(AssetSource('audio/wrong.wav'));
      return;
    }
    dynamic csvPath = Directory(p.join(dD.path, 'CImaGen', 'csv'));
    if (!csvPath.existsSync()) {
      await csvPath.create(recursive: true);
    }
    // 1. Find e621 latest files
    // 2025-01-27
    List<FileSystemEntity> files = await dirContents(csvPath);
    csvPath = File(p.join(dD.path, 'CImaGen', 'csv', 'tags.csv'));
    RegExp fileRegex = RegExp(r"posts-([0-9]{4}-[0-9]{2}-[0-9]{2})\.csv$");
    DateFormat format = DateFormat("yyyy-MM-dd");
    files = files.where((file) => fileRegex.hasMatch(p.basename(file.path))).toList(growable: false);
    DateTime? latest;
    for(FileSystemEntity f in files){
      DateTime d = format.parse(fileRegex.firstMatch(p.basename(f.path))![1]!);
      if(latest == null){
        latest = d;
        csvPath = File(f.path);
      } else if(d.isAfter(latest)){
        latest = d;
        csvPath = File(f.path);
      }
    }

    if (csvPath.existsSync()) {
      latestE621Posts = csvPath.path;
    } else {
      int notID = 0;
      notID = notificationManager!.show(
          thumbnail: const Icon(Icons.question_mark, color: Colors.orangeAccent, size: 32),
          title: 'Posts not found',
          description: 'Put the posts-YYYY-mm-dd.csv file in folder:\n   "${csvPath.parent.path}"\nYou can download tags, for example, from https://e621.net/db_export/',
          content: Padding(padding: EdgeInsets.only(top: 7), child: ElevatedButton(
              style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                  shape: WidgetStateProperty.all<RoundedRectangleBorder>(const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))))
              ),
              onPressed: (){
                notificationManager!.close(notID);
                init();
              },
              child: const Text("Try again", style: TextStyle(fontSize: 12))
          ))
      );
      audioController!.player.play(AssetSource('audio/wrong.wav'));
    }
  }

  Future<E621Post?> getE621Post(int postID) async {
    // Find csv
    E621Post? p;
    if(latestE621Posts != null) {
      bool done = false;
      final File file = File(latestE621Posts!);

      Stream<List> inputStream = file.openRead();
      final parser = _MyParser((data) async {
        print('Complete');
        print(data);
        if(data != null){
          p = E621Post(
            id: int.parse(data[0]),
            uploaderID: int.parse(data[1]),
            createdAt: data[2],
            md5: data[3],
            source: data[4],
            rating: data[5],
            width: int.parse(data[6]), height: int.parse(data[7]),
            tags: data[8].split(' '), lockedTags: data[9].split(' '),
            favCount: int.parse(data[10]),
            fileExt: data[11],
            parentID: data[12] == '' ? null : int.parse(data[12]),
            changeSeq: int.parse(data[13]),
            approverID: data[14] == '' ? null : int.parse(data[14]),
            fileSize: int.parse(data[15]),
            commentCount: int.parse(data[16]),
            description: data[17] == '' ? null : data[17],
            duration: data[18],
            updatedAt: data[19],
            isDeleted: data[20] == 't',
            isPending: data[21] == 't',
            isFlagged: data[22] == 't',
            score: int.parse(data[23]),
            upScore: int.parse(data[24]),
            downScore: int.parse(data[25]),
            isRatingLocked: data[26] == 't',
            isStatusLocked: data[27] == 't',
            isNoteLocked: data[28] == 't',
          );
          done = true;
        }
      }, postID: postID);
      inputStream.transform(utf8.decoder).transform(CsvConverter(parser: parser)).listen(null);
      Future<void> isDone() async{
        while(!done){
          await Future.delayed(const Duration(seconds: 1));
        }
      }
      await isDone();
    }

    return p;
  }

  void increment() {
    _count++;
  }
}

class _MyParser extends CsvParser {
  int postID;
  String cachedPID = '';
  bool hasRes = false;
  final Future<void> Function(List<String>?)? onComplete;

  _MyParser(this.onComplete, {required this.postID});

  @override
  void beginEvent(CsvParserEvent event) {
    if (event == CsvParserEvent.startEvent) {
      cachedPID = postID.toString();
      // _count = 0;
      // _totalCount = 0;
      // _transactionCount = 0;
      // _rows.clear();
    }
  }

  @override
  R? endEvent<R>(CsvParserEvent event, R? result, bool ok) {
    // void saveRows(bool isLast) {
    //   final rows = _rows.toList();
    //   _rows.clear();
    //   Timer.run(() async {
    //     // Asynchronous saving to the database.
    //     await _saveToDatabase(rows, isLast);
    //   });
    // }

    if (ok) {
      switch (event) {
        case CsvParserEvent.rowEvent:
          final row = result as List<String>;
          if(row[0] == cachedPID){
            if (onComplete != null) {
              hasRes = true;
              Timer.run(() => onComplete!(row));
            }
          }
          // Free memory
          result = const <String>[] as R;
          break;
        case CsvParserEvent.startEvent:
          if (!hasRes && onComplete != null) {
            Timer.run(() => onComplete!(null));
          }
          // Completely freeing memory from the entire list
          result = const <List<String>>[] as R;
        default:
      }
    }

    return result;
  }
}

class TagInfo {
  final int id;
  final String name;
  final int category;
  final int count;

  const TagInfo({
    required this.id,
    required this.name,
    required this.category,
    required this.count
  });

  @override
  String toString(){
    return '$name: cat:$category(${categoryToString(category)}) cou:$count';
  }
}

class E621Post {
  final int id;
  final int uploaderID;
  final String createdAt;
  final String md5;
  final String? source;
  final String rating;
  final int width;
  final int height;
  final List<String> tags;
  final List<String> lockedTags;
  final int favCount;
  final String fileExt;
  final int? parentID;
  final int changeSeq;
  final int? approverID;
  final int fileSize;
  final int commentCount;
  final String? description;
  final dynamic duration;
  final String updatedAt;
  final bool isDeleted;
  final bool isPending;
  final bool isFlagged;
  final int score;
  final int upScore;
  final int downScore;
  final bool isRatingLocked;
  final bool isStatusLocked;
  final bool isNoteLocked;

  const E621Post({
    required this.id,
    required this.uploaderID,
    required this.createdAt,
    required this.md5,
    this.source,
    required this.rating,
    required this.width,
    required this.height,
    required this.tags,
    required this.lockedTags,
    required this.favCount,
    required this.fileExt,
    this.parentID,
    required this.changeSeq,
    this.approverID,
    required this.fileSize,
    required this.commentCount,
    this.description,
    this.duration,
    required this.updatedAt,
    this.isDeleted = false,
    this.isPending = false,
    this.isFlagged = false,
    required this.score,
    required this.upScore,
    required this.downScore,
    this.isRatingLocked = true,
    this.isStatusLocked = false,
    this.isNoteLocked = true
  });
}