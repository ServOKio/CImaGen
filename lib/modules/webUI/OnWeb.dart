import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cimagen/main.dart';
import 'package:cimagen/modules/AudioController.dart';
import 'package:cimagen/modules/webUI/AbMain.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:snowflake_dart/snowflake_dart.dart';

import '../../Utils.dart';
import '../../constants.dart';
import '../DataManager.dart';
import '../swarmUI/swarmModule.dart';

class OnWeb extends ChangeNotifier implements AbMain{
  @override
  bool loaded = false;
  String? error;
  @override
  bool get hasError => error != null;

  Software? software;

  List<String> inProcess = [];
  bool isIndexingAll = false;

  // Other
  List<StreamSubscription<FileSystemEvent>> watchList = [];
  late Snowflake snowflake;

  String _host = 'web';
  @override
  String? get host => _host;

  final String _remoteAddress = '';

  List<String> _tabs = [];
  @override
  List<String> get tabs => _tabs;
  List<RenderEngine> _internalTabs = [];

  void findError(){
    notificationManager!.show(
      thumbnail: const Icon(Icons.error, color: Colors.redAccent),
      title: 'Initialization problem',
      description: '${error!.startsWith('TimeoutException') ? 'The host did not return the information within 10 seconds' : 'Unknown error'}\nError: $error',
      content: ElevatedButton(
        onPressed: () => init(),
        child: const Text("Try again", style: TextStyle(fontSize: 12))
      ),
      sound: NtSound.error
    );
  }

  final Map<int, ParseJob> _jobs = {};
  @override
  Map<int, ParseJob> get getJobs => _jobs;
  int getJobCountActive() {
    _jobs.removeWhere((key, value) => value.controller.isClosed);
    return _jobs.length;
  }

  @override
  Future<void> init() async {
    _tabs.clear();
    _internalTabs.clear();

    // 1. Check download folder
    Directory? dP = await getDownloadsDirectory();
    if(dP == null){
      notificationManager!.show(
        thumbnail: const Icon(Icons.warning, color: Colors.redAccent),
        title: 'Downloads folder not found',
        description: 'The system cannot find the path specified',
        sound: NtSound.error
      );
      return;
    }

    snowflake = Snowflake(epoch: 1420070400000, nodeId: 0); //Discord

    // 2. Watch new json bathes
    watchDir(dP.absolute.path);
    _tabs = ['txt2img', 'img2img', 'comfUI'];
    _internalTabs = [RenderEngine.txt2img, RenderEngine.img2img, RenderEngine.comfUI];
    _host = 'furry-diffusion';

    loaded = true;
    notifyListeners();

    notificationManager!.show(
      thumbnail: const Icon(Icons.web, color: Colors.blue),
      title: 'Welcome to web',
      description: 'Now when we find a new file with a name starting with "images_batch", we will immediately start analyzing it\nWe are watching: ${dP.absolute.path}',
      autoCloseDuration: const Duration(milliseconds: 10000),
      sound: NtSound.info
    );
  }

  @override
  void exit() {
    for (var e in watchList) {
      e.cancel();
    }
    for(int id in _jobs.keys){
      _jobs[id]!.forceStop();
    }
  }

  final int _maxConcurrentJobs = 4;

  int _runningJobs = 0;
  final Queue<_IndexJob> _jobQueue = Queue();

  void _tryRunNextJob() {
    if (_runningJobs >= _maxConcurrentJobs) return;
    if (_jobQueue.isEmpty) return;

    final job = _jobQueue.removeFirst();
    _runningJobs++;

    indexUrls(job.urls).whenComplete(() {
      _runningJobs--;
      _tryRunNextJob(); // run next queued job
    });
  }

  void enqueueIndexUrls(List<String> urls) {
    if (_jobQueue.isNotEmpty) {
      List<IconData> ic = [
        Icons.filter_1_rounded,
        Icons.filter_2_rounded,
        Icons.filter_3_rounded,
        Icons.filter_4_rounded,
        Icons.filter_5_rounded,
        Icons.filter_6_rounded,
        Icons.filter_7_rounded,
        Icons.filter_8_rounded,
        Icons.filter_9_rounded,
      ];
      notificationManager!.show(
        thumbnail: Icon(_jobQueue.length > 9 ? Icons.filter_9_plus_rounded : ic[_jobQueue.length-1], color: Colors.amberAccent),
        title: 'Queue growing: ${_jobQueue.length}',
        description: 'It seems the system can\'t process files quickly enough',
        autoCloseDuration: const Duration(milliseconds: 10000),
        sound: NtSound.wrong
      );
    }
    _jobQueue.add(_IndexJob(urls));
    _tryRunNextJob();
  }

  List<String> looked = [];

  void watchDir(String path) {
    final tempFolder = Directory(path);
    if (kDebugMode) print('watch $path');

    final stream = tempFolder.watch(
      events: FileSystemEvent.create,
      recursive: false,
    );

    watchList.add(stream.listen((event) {
      if (event is! FileSystemCreateEvent || event.isDirectory) return;

      final name = p.basename(event.path);
      if (!name.startsWith('images_batch') || !name.endsWith('.json')) return;
      if (looked.contains(name)) return;

      looked.add(name);

      Future.delayed(const Duration(seconds: 5), () async {
        try {
          final file = File(event.path);
          if (!await file.exists()) return;

          final value = await file.readAsString();
          if (!await isJson(value)) return;

          final urls = List<String>.from(jsonDecode(value));

          enqueueIndexUrls(urls);
        } finally {
          looked.remove(name);
        }
      });
    }));
  }


  @override
  Future<List<Folder>> getFolders(int index) async {
    return sqLite.getFolders(host: _host);
  }

  @override
  Future<List<Folder>> getAllFolders(int index) async {
    List<Folder> list = [];
    return list;
  }

  @override
  Future<List<ImageMeta>> getFolderFiles(int section, String day) async {
    return sqLite.getImagesByDay(day, host: host, re: _internalTabs[section]);
  }

  @override
  String getFullUrlImage(ImageMeta im) {
    return im.fullNetworkPath ?? '';
  }

  @override
  String getThumbnailUrlImage(ImageMeta im){
    return im.networkThumbnail ?? '';
  }

  RegExp ex = RegExp(r'(attachments/[0-9]+/([0-9]+)/)');

  Future<void> indexUrls(List<String> urls) async {
    final completer = Completer<void>();
    // 1. Check if this is discord
    urls = urls.where((url) => ['cdn.discordapp.com', 'media.discordapp.net'].contains(Uri.parse(url).host)).toList();

    // 2. Put images and parse
    ParseJob job = ParseJob(skipCached: false); // TODO
    int jobID = await job.putAndGetJobID(urls.map((uri) {
      Uri parsed = Uri.parse(cleanUpUrl(uri));
      Uri thumb = Uri(
        scheme: parsed.scheme,
        host: 'media.discordapp.net',
        port: parsed.port,
        path: parsed.path,
        queryParameters: parsed.queryParameters
      );
      Uri full = Uri(
        scheme: parsed.scheme,
        host: 'cdn.discordapp.com',
        port: parsed.port,
        path: parsed.path,
        queryParameters: parsed.queryParameters
      );
      RegExpMatch match = ex.allMatches(uri).first;
      String fullPath = '${match[1]}${p.basename(parsed.path)}';
      return JobImageFile(
        fullPath: fullPath,
        fullNetworkPath: full.toString(),
        networkThumbhail: thumb.toString(),
        dateModified: DateTime.fromMillisecondsSinceEpoch(snowflake.getTimeFromId(int.parse(match[2]!)))
      );
    }).toList(), host: _host);

    int notID = -1;
    if (urls.isNotEmpty) {
      notID = notificationManager!.show(
          title: 'Indexing ${urls.length} images',
          description: 'Please wait',
          content: Container(
            margin: const EdgeInsets.only(top: 7),
            width: 100,
            child: const LinearProgressIndicator(),
          )
      );
    }

    job.run(
        onDone: () {
          _jobs.remove(jobID);
          completer.complete();
          if (notID != -1) notificationManager!.close(notID);
        },
        onProcess: (total, current, thumbnail) {
          if (notID == -1) return;
          notificationManager!.update(notID, (o){
            o.setDescription('We are processing $total/$current images, please wait');
            if (thumbnail != null) {
              o.setThumbnail(Image.memory(
                thumbnail,
                filterQuality: FilterQuality.low,
                gaplessPlayback: true,
              ));
            }
          });
        }
    );
    _jobs[jobID] = job;

    // Return job id
    return completer.future;
  }

  @override
  bool indexAll(int index) {
    throw Exception('Haha, not here');
  }

  @override
  Future<StreamController<ImageMeta>> indexFolder(Folder folder, {List<String>? hashes, RenderEngine? re}) async {
    Uri parse = Uri.parse(_remoteAddress);
    if (kDebugMode) {
      print('indexFolder: ${folder.getter} ${hashes?.length}');
    }
    if(software == Software.stableDiffusionWebUI) {
      Uri base = Uri(
          scheme: parse.scheme,
          host: parse.host,
          port: parse.port,
          path: '/infinite_image_browsing/files',
          queryParameters: {'folder_path': folder.getter}
      );
      var res = await http.Client().get(base).timeout(const Duration(seconds: 5));
      if(res.statusCode == 200){
        var folderFilesRaw = await json.decode(res.body)['files'].where((e) => ['.png', 'jpg', '.jpeg', '.gif', '.webp'].contains(p.extension(e['name']))).toList();
        if(hashes != null && hashes.isNotEmpty){
          folderFilesRaw = folderFilesRaw.where((e) => !hashes.contains(genPathHash(normalizePath(e['fullpath'])))).toList(growable: false);
          if (kDebugMode) {
            print('to send: ${folderFilesRaw.length}');
          }
        }

        if(folderFilesRaw.isNotEmpty){
          if(inProcess.contains(folder.getter)){
            folderFilesRaw = [];
          } else {
            inProcess.add(folder.getter);
          }
        }

        ParseJob job = ParseJob(re: re);
        int jobID = await job.putAndGetJobID(folderFilesRaw.map((e){
          Uri thumb = Uri(
              scheme: parse.scheme,
              host: parse.host,
              port: parse.port,
              path: '/infinite_image_browsing/image-thumbnail',
              queryParameters: {
                'path': e['fullpath'],
                'size': '512x512',
                't': e['date']
              }
          );
          Uri full = Uri(
              scheme: parse.scheme,
              host: parse.host,
              port: parse.port,
              path: '/infinite_image_browsing/file',
              queryParameters: {
                'path': e['fullpath'],
                't': e['date']
              }
          );
          return JobImageFile(
              fullPath: e['fullpath'],
              fullNetworkPath: full.toString(),
              networkThumbhail: thumb.toString()
          );
        }), host: _host);

        int notID = -1;
        if(folderFilesRaw.isNotEmpty) {
          notID = notificationManager!.show(
              title: 'Indexing ${folder.getter}',
              description: 'We are processing ${folderFilesRaw.length} images, please wait',
              content: Container(
                margin: const EdgeInsets.only(top: 7),
                width: 100,
                child: const LinearProgressIndicator(),
              )
          );
        }

        job.run(
            onDone: (){
              _jobs.remove(jobID);
              if(notID != -1) notificationManager!.close(notID);
              if(folderFilesRaw.isNotEmpty) inProcess.remove(folder.getter);
            },
            onProcess: (total, current, thumbnail) {
              if(notID == -1) return;
              notificationManager!.update(notID, (o){
                o.setDescription('We are processing $total/$current images, please wait');
                if(thumbnail != null) {
                  o.setThumbnail(Image.memory(
                    thumbnail,
                    filterQuality: FilterQuality.low,
                    gaplessPlayback: true,
                  ));
                }
              });
            }
        );
        _jobs[jobID] = job;

        // Return job id
        return job.controller;
      } else {
        late final StreamController<ImageMeta> controller;
        controller = StreamController<ImageMeta>(
          onListen: () async {
            await controller.close();
          },
        );
        return controller;
      }
    } else if(software == Software.swarmUI) {
      String sessionId = kBaseNavigatorKey.currentContext!.read<DataManager>().temp.containsKey('swarm_client_info') ? (kBaseNavigatorKey.currentContext!.read<DataManager>().temp['swarm_client_info'] as SwarmClientInfo).sessionID! : 'null';
      Uri base = Uri(
          scheme: parse.scheme,
          host: parse.host,
          port: parse.port,
          path: '/API/ListImages'
      );
      var res = await http.Client().post(base, headers: {
        "User-Agent": userAgent,
        "Accept": "*/*",
        "Accept-Language": "en,en-US;q=0.5",
        "Content-Type": "application/json"
      }, body: jsonEncode(<String, String>{
        'session_id': sessionId,
        'depth': '1',
        'path': folder.getter,
        'sortBy': 'Name',
        'sortReverse': 'true'
      })).timeout(const Duration(seconds: 5));
      if(res.statusCode == 200){
        List<String> folderFilesPaths = List<String>.from(await json.decode(res.body)['files'].map((e) => e['src'])).where((e) => ['.png', '.jpg', '.jpeg', '.gif', '.webp'].contains('.${e.split('.').last}')).toList(growable: false);
        if(hashes != null && hashes.isNotEmpty){
          folderFilesPaths = folderFilesPaths.where((e) => !hashes.contains(genPathHash(normalizePath('${folder.getter}/$e')))).toList(growable: false);
          if (kDebugMode) {
            print('to send: ${folderFilesPaths.length}');
          }
        }

        if(folderFilesPaths.isNotEmpty){
          if(inProcess.contains(folder.getter)){
            folderFilesPaths = [];
          } else {
            inProcess.add(folder.getter);
          }
        }

        ParseJob job = ParseJob();
        int jobID = await job.putAndGetJobID(folderFilesPaths.map((e){
          Uri thumb = Uri(
              scheme: parse.scheme,
              host: parse.host,
              port: parse.port,
              path: '/View/local/${folder.getter}/$e',
              queryParameters: {
                'preview': 'true'
              }
          );
          Uri full = Uri(
              scheme: parse.scheme,
              host: parse.host,
              port: parse.port,
              path: '/View/local/${folder.getter}/$e'
          );
          return JobImageFile(
              fullPath: '${folder.getter}/$e',
              fullNetworkPath: full.toString(),
              networkThumbhail: thumb.toString()
          );
        }).toList(), host: _host);

        int notID = -1;
        if(folderFilesPaths.isNotEmpty) {
          notID = notificationManager!.show(
              title: 'Indexing ${folder.getter}',
              description: 'We are processing ${folderFilesPaths.length} images, please wait',
              content: Container(
                margin: const EdgeInsets.only(top: 7),
                width: 100,
                child: const LinearProgressIndicator(),
              )
          );
        }

        job.run(
            onDone: (){
              _jobs.remove(jobID);
              if(notID != -1) notificationManager!.close(notID);
              if(folderFilesPaths.isNotEmpty) inProcess.remove(folder.getter);
            },
            onProcess: (total, current, thumbnail) {
              if(notID == -1) return;
              notificationManager!.update(notID, (o){
                o.setDescription('We are processing $total/$current images, please wait');
                if(thumbnail != null) {
                  o.setThumbnail(Image.memory(
                    thumbnail,
                    filterQuality: FilterQuality.low,
                    gaplessPlayback: true,
                  ));
                }
              });
            }
        );
        _jobs[jobID] = job;

        // Return job id
        return job.controller;
      } else {
        late final StreamController<ImageMeta> controller;
        controller = StreamController<ImageMeta>(
          onListen: () async {
            await controller.close();
          },
        );
        return controller;
      }
    } else {
      late final StreamController<ImageMeta> controller;
      controller = StreamController<ImageMeta>(
        onListen: () async {
          await controller.close();
        },
      );

      // Return job id
      return controller;
    }
  }

  @override
  Map<String, String> get webuiPaths => {};

  Future getFoldersPaged(int tabIndex, {required int offset, required int limit}) {
    return sqLite.getFoldersPaged(re: _internalTabs[tabIndex], host: _host, offset: offset, limit: limit);
  }

  @override
  Future<void> fixLorasMetadata() {
    // TODO: implement fixLorasMetadata
    throw UnimplementedError();
  }
}

class _IndexJob {
  final List<String> urls;
  _IndexJob(this.urls);
}

