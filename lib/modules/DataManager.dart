import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:cimagen/modules/AudioController.dart';
import 'package:external_path/external_path.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'package:path/path.dart' as p;
import 'package:fast_csv/fast_csv_ex.dart' as fast_csv_ex;
import 'package:http/http.dart' as http;
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
  final Map<String, TagInfo> _e621Tags = {};
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

  Future<void> loadE621Tags() async {
    Directory? docDir;
    if (Platform.isAndroid) {
      docDir = Directory(await ExternalPath.getExternalStoragePublicDirectory(
          ExternalPath.DIRECTORY_DOCUMENTS));
    } else if (Platform.isWindows) {
      docDir = await getApplicationDocumentsDirectory();
    } else {
      docDir = await getApplicationDocumentsDirectory();
    }

    if (!docDir.existsSync()) {
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
        )),
        sound: NtSound.wrong
      );
      return;
    }

    final csvDir = Directory(p.join(docDir.path, 'CImaGen', 'csv'));
    if (!csvDir.existsSync()) {
      await csvDir.create(recursive: true);
    }

    final files = await dirContents(csvDir);
    final fileRegex = RegExp(r'tags-(\d{4}-\d{2}-\d{2})\.csv$');
    final dateFormat = DateFormat('yyyy-MM-dd');

    final tagFiles = files
        .whereType<File>()
        .where((f) => fileRegex.hasMatch(p.basename(f.path)))
        .toList();

    File? latestFile;
    DateTime? latestDate;

    for (final file in tagFiles) {
      final match = fileRegex.firstMatch(p.basename(file.path));
      if (match == null) continue;
      final dateStr = match.group(1)!;
      final date = dateFormat.parse(dateStr);

      if (latestDate == null || date.isAfter(latestDate)) {
        latestDate = date;
        latestFile = file;
      }
    }

    if (latestFile == null || !latestFile.existsSync()) {
      int notID = 0;
      notID = notificationManager!.show(
        thumbnail: const Icon(Icons.question_mark, color: Colors.yellow, size: 32),
        title: 'Tags not found',
        description: 'Put a tags-YYYY-MM-DD.csv file in folder:\n   "${csvDir.path}"\nDownload from: https://e621.net/db_export/',
        content: Padding(
          padding: const EdgeInsets.only(top: 7),
          child: ElevatedButton(
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
              shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(4))),
              ),
            ),
            onPressed: () {
              notificationManager!.close(notID);
              init();
            },
            child: const Text("Try again", style: TextStyle(fontSize: 12)),
          ),
        ),
        sound: NtSound.wrong
      );
      return;
    }

    final now = DateTime.now();
    final fileModified = await latestFile.lastModified();
    final ageDays = now.difference(fileModified).inDays;

    const maxAgeDays = 10;

    String? warningMessage;
    if (ageDays > maxAgeDays) {
      warningMessage =
      'The tags file is quite old ($ageDays days).\n'
          'e621 updates the export roughly daily.\n'
          'Consider downloading a fresh one from https://e621.net/db_export/';
    }

    bool shouldDownload = latestFile == null;

    if (!shouldDownload) {
      final fileModified = await latestFile.lastModified();
      final ageDays = DateTime.now().difference(fileModified).inDays;
      shouldDownload = ageDays > maxAgeDays;
    }

    // Set global path
    latestE621Tags = latestFile.path;

    // Load the file (async)
    try {
      final content = await latestFile.readAsString();
      final data = await compute(fast_csv_ex.parse, content);

      _e621Tags.clear();

      for (final row in data.skip(1)) {
        if (row.length < 4) continue;
        final name = row[1].trim();
        if (name.isEmpty) continue;

        _e621Tags[name] = TagInfo(
          id: int.tryParse(row[0]) ?? 0,
          name: name,
          category: int.tryParse(row[2]) ?? 0,
          count: int.tryParse(row[3]) ?? 0,
        );
      }

      if (warningMessage != null) {
        int notWarn = 0;
        notWarn = notificationManager!.show(
          thumbnail: const Icon(Icons.warning_amber, color: Colors.yellow, size: 32),
          title: 'Outdated tags database',
          description: warningMessage,
          autoCloseDuration: const Duration(seconds: 12),
          content: Padding(padding: EdgeInsets.only(top: 7), child: ElevatedButton(
              style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                  shape: WidgetStateProperty.all<RoundedRectangleBorder>(const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))))
              ),
              onPressed: () async {
                notificationManager!.close(notWarn);
                int progressNotId = notificationManager!.show(
                  thumbnail: const Icon(Icons.downloading, color: Colors.blue, size: 32),
                  title: 'Updating e621 tags',
                  description: 'Downloading latest tags database...\nThis may take a minute.',
                );

                final newPath = await downloadLatestE621Tags(csvDir);

                notificationManager!.close(progressNotId);

                if (newPath != null) {
                  latestFile = File(newPath);
                  latestDate = dateFormat.parse(
                    fileRegex.firstMatch(p.basename(newPath))!.group(1)!,
                  );

                  notificationManager!.show(
                    thumbnail: const Icon(Icons.check_circle, color: Colors.green, size: 32),
                    title: 'Tags updated',
                    description: 'Latest tags loaded from e621.',
                    autoCloseDuration: const Duration(seconds: 6),
                  );
                  loadE621Tags();
                } else {
                  notificationManager!.show(
                    thumbnail: const Icon(Icons.warning_amber, color: Colors.orange, size: 32),
                    title: 'Update failed',
                    description: 'Could not download fresh tags.\nUsing existing file (may be outdated).',
                    autoCloseDuration: const Duration(seconds: 10),
                  );
                }
              },
              child: const Text("Update", style: TextStyle(fontSize: 12))
          ))
        );
      }
    } catch (e) {
      notificationManager!.show(
        thumbnail: const Icon(Icons.error, color: Colors.redAccent, size: 32),
        title: 'Failed to parse tags',
        description: 'The CSV file may be corrupted.\n$e',
        sound: NtSound.wrong
      );
    }
  }

  Future<String?> downloadLatestE621Tags(Directory csvDir) async {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final client = http.Client();

    for (int offset = 0; offset < 3; offset++) {
      final targetDate = DateTime.now().subtract(Duration(days: offset));
      final dateStr = dateFormat.format(targetDate);
      final fileName = 'tags-$dateStr.csv.gz';
      final downloadUrl = 'https://e621.net/db_export/$fileName';

      try {
        final request = http.Request('GET', Uri.parse(downloadUrl));

        request.headers['User-Agent'] = userAgent;

        final response = await client.send(request);

        if (response.statusCode != 200) {
          if (kDebugMode) {
            print('Failed to download $fileName: ${response.statusCode}');
          }
          continue;
        }

        final tempGzPath = p.join(csvDir.path, fileName);
        final gzFile = File(tempGzPath);
        final sink = gzFile.openWrite();
        await response.stream.pipe(sink);
        await sink.flush();
        await sink.close();

        final compressedBytes = await gzFile.readAsBytes();
        final csvBytes = GZipDecoder().decodeBytes(compressedBytes);

        if (csvBytes.isEmpty) {
          if (kDebugMode) {
            print('Decompression resulted in empty data for $fileName');
          }
          gzFile.deleteSync();
          continue;
        }

        final csvFileName = 'tags-$dateStr.csv';
        final csvPath = p.join(csvDir.path, csvFileName);
        final csvFile = File(csvPath);
        await csvFile.writeAsBytes(csvBytes);

        gzFile.deleteSync();

        if (kDebugMode) {
          print('Downloaded and decompressed: $csvPath');
        }
        return csvPath;

      } catch (e) {
        if (kDebugMode) {
          print('Error downloading $fileName: $e');
        }
        continue;
      }
    }

    if (kDebugMode) {
      print('No recent tags file found online');
    }
    return null;
  }

  Future<String?> downloadLatestE621Posts(Directory csvDir) async {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final client = http.Client();

    for (int offset = 0; offset < 3; offset++) {
      final targetDate = DateTime.now().subtract(Duration(days: offset));
      final dateStr = dateFormat.format(targetDate);
      final fileName = 'posts-$dateStr.csv.gz';
      final downloadUrl = 'https://e621.net/db_export/$fileName';

      try {
        final request = http.Request('GET', Uri.parse(downloadUrl));

        request.headers['User-Agent'] = userAgent;

        final response = await client.send(request);

        if (response.statusCode != 200) {
          if (kDebugMode) {
            print('Failed to download $fileName: ${response.statusCode}');
          }
          continue;
        }

        final tempGzPath = p.join(csvDir.path, fileName);
        final gzFile = File(tempGzPath);
        final sink = gzFile.openWrite();
        await response.stream.pipe(sink);
        await sink.flush();
        await sink.close();

        final compressedBytes = await gzFile.readAsBytes();
        final csvBytes = GZipDecoder().decodeBytes(compressedBytes);

        if (csvBytes.isEmpty) {
          if (kDebugMode) {
            print('Decompression resulted in empty data for $fileName');
          }
          gzFile.deleteSync();
          continue;
        }

        final csvFileName = 'posts-$dateStr.csv';
        final csvPath = p.join(csvDir.path, csvFileName);
        final csvFile = File(csvPath);
        await csvFile.writeAsBytes(csvBytes);

        gzFile.deleteSync();

        if (kDebugMode) {
          print('Downloaded and decompressed: $csvPath');
        }
        return csvPath;

      } catch (e) {
        if (kDebugMode) {
          print('Error downloading $fileName: $e');
        }
        continue;
      }
    }

    if (kDebugMode) {
      print('No recent posts file found online');
    }
    return null;
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
        )),
        sound: NtSound.wrong
      );
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
        )),
        sound: NtSound.wrong
      );
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
        )),
        sound: NtSound.wrong
      );
      return;
    }
    dynamic csvDir = Directory(p.join(dD.path, 'CImaGen', 'csv'));
    if (!csvDir.existsSync()) {
      await csvDir.create(recursive: true);
    }

    List<FileSystemEntity> files = await dirContents(csvDir);
    File csvFile = File(p.join(dD.path, 'CImaGen', 'csv', 'posts.csv'));

    final fileRegex = RegExp(r'posts-(\d{4}-\d{2}-\d{2})\.csv$');
    final dateFormat = DateFormat('yyyy-MM-dd');

    final postsFiles = files
        .whereType<File>()
        .where((f) => fileRegex.hasMatch(p.basename(f.path)))
        .toList();

    File? latestFile;
    DateTime? latestDate;

    for (final file in postsFiles) {
      final match = fileRegex.firstMatch(p.basename(file.path));
      if (match == null) continue;
      final dateStr = match.group(1)!;
      final date = dateFormat.parse(dateStr);

      if (latestDate == null || date.isAfter(latestDate)) {
        latestDate = date;
        latestFile = file;
      }
    }

    if (latestFile != null) {
      latestE621Posts = latestFile.path;
    } else {
      int notWarn = 0;
      notWarn = notificationManager!.show(
        thumbnail: const Icon(Icons.question_mark, color: Colors.orangeAccent, size: 32),
        title: 'Posts not found',
        description: 'Put the posts-YYYY-mm-dd.csv file in folder:\n   "${csvFile.parent.path}"\nYou can download tags, for example, from https://e621.net/db_export/',
        content: Padding(padding: EdgeInsets.only(top: 7), child: Row(
          children: [
            ElevatedButton(
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                  shape: WidgetStateProperty.all<RoundedRectangleBorder>(const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))))
                ),
                onPressed: () async {
                  notificationManager!.close(notWarn);
                  int progressNotId = notificationManager!.show(
                    thumbnail: const Icon(Icons.downloading, color: Colors.blue, size: 32),
                    title: 'Updating e621 posts',
                    description: 'Downloading latest posts database...\nThis may take a few minute (or about hour idk)',
                  );

                  final newPath = await downloadLatestE621Posts(csvDir);

                  notificationManager!.close(progressNotId);

                  if (newPath != null) {
                    latestFile = File(newPath);
                    latestDate = dateFormat.parse(
                      fileRegex.firstMatch(p.basename(newPath))!.group(1)!,
                    );

                    await sqLite.updatePosts(latestFile!);
                    notificationManager!.show(
                      thumbnail: const Icon(Icons.check_circle, color: Colors.green, size: 32),
                      title: 'Posts updated',
                      description: 'Latest posts loaded from e621.',
                      autoCloseDuration: const Duration(seconds: 6),
                    );
                    //loadE621Posts();
                  } else {
                    notificationManager!.show(
                      thumbnail: const Icon(Icons.warning_amber, color: Colors.orange, size: 32),
                      title: 'Update failed',
                      description: 'Could not download fresh posts.\nUsing existing file (may be outdated).',
                      autoCloseDuration: const Duration(seconds: 10),
                    );
                  }
                },
                child: const Text("Try download", style: TextStyle(fontSize: 12))
            ),
            Gap(7),
            ElevatedButton(
                style: ButtonStyle(
                    foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                    shape: WidgetStateProperty.all<RoundedRectangleBorder>(const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))))
                ),
                onPressed: (){
                  notificationManager!.close(notWarn);
                  init();
                },
                child: const Text("Try again", style: TextStyle(fontSize: 12))
            )
          ],
        )),
        sound: NtSound.wrong
      );
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

          result = const <String>[] as R;
          break;
        case CsvParserEvent.startEvent:
          if (!hasRes && onComplete != null) {
            Timer.run(() => onComplete!(null));
          }
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