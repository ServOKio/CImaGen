import 'dart:collection';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:external_path/external_path.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'package:path/path.dart' as p;
import 'package:fast_csv/fast_csv_ex.dart' as fast_csv_ex;

import '../Utils.dart';
import '../components/PromptAnalyzer.dart';
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

  Map<String, TagInfo> _e621Tags = {};
  Map<String, TagInfo> get e621Tags => _e621Tags;

  Future<void> init() async {
    await loadE621Tags();
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

  void increment() {
    _count++;
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