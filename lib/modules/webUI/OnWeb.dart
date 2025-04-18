import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cimagen/main.dart';
import 'package:cimagen/modules/webUI/AbMain.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:snowflake_dart/snowflake_dart.dart';

import '../../Utils.dart';
import '../../utils/NavigationService.dart';
import '../../utils/SQLite.dart';
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

  String _remoteAddress = '';
  String _userAgent = 'CImaGen/Undefined.version';

  List<String> _tabs = [];
  @override
  List<String> get tabs => _tabs;

  void findError(){
    int notID = notificationManager!.show(
        thumbnail: const Icon(Icons.error, color: Colors.redAccent),
        title: 'Initialization problem',
        description: '${error!.startsWith('TimeoutException') ? 'The host did not return the information within 10 seconds' : 'Unknown error'}\nError: $error',
        content: ElevatedButton(
            onPressed: () => init(),
            child: const Text("Try again", style: TextStyle(fontSize: 12))
        )
    );
    audioController!.player.play(AssetSource('audio/error.wav'));
  }

  Map<int, ParseJob> _jobs = {};
  Map<int, ParseJob> get getJobs => _jobs;
  int getJobCountActive() {
    _jobs.removeWhere((key, value) => value.controller.isClosed);
    return _jobs.length;
  }

  @override
  Future<void> init() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    _userAgent = "CImaGen/${packageInfo.version} (platform; ${Platform.isAndroid ? 'android' : Platform.isWindows ? 'windows' : Platform.isIOS ? 'IOS' : Platform.isLinux ? 'linux' : Platform.isFuchsia ? 'fuchsia' : Platform.isMacOS ? 'MacOs' : 'Unknown'})";

    // 1. Check download folder
    Directory? dP = await getDownloadsDirectory();
    if(dP == null){
      int notID = notificationManager!.show(
          thumbnail: const Icon(Icons.warning, color: Colors.redAccent),
          title: 'Downloads folder not found',
          description: 'The system cannot find the path specified'
      );
      audioController!.player.play(AssetSource('audio/error.wav'));
      return;
    }

    snowflake = Snowflake(epoch: 1420070400000, nodeId: 0); //Discord

    // 2. Watch new json bathes
    watchDir(dP.absolute.path);
    _tabs = ['All'];

    loaded = true;
    notifyListeners();

    int notID = notificationManager!.show(
        thumbnail: const Icon(Icons.web, color: Colors.blue),
        title: 'Welcome to web',
        description: 'Now when we find a new file with a name starting with "images_batch", we will immediately start analyzing it\nWe are watching: ${dP.absolute.path}'
    );
    audioController!.player.play(AssetSource('audio/info.wav'));
    Future.delayed(const Duration(milliseconds: 10000), () => notificationManager!.close(notID));
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

  List<String> looked = [];
  void watchDir(String path){
    final tempFolder = File(path);
    if (kDebugMode) print('watch $path');
    Stream<FileSystemEvent> te = tempFolder.watch(events: FileSystemEvent.all, recursive: false);
    watchList.add(te.listen((event) {
      print(event);
      if (event is FileSystemCreateEvent && !event.isDirectory){
        String name = p.basename(event.path);
        if(name.startsWith('images_batch') && name.endsWith('.json')) {
          if(!looked.contains(name)){
            looked.add(name);
            Future.delayed(const Duration(seconds: 5), (){
              File jsFile = File(event.path);
              jsFile.readAsString().then((value) async {
                if (await isJson(value)) {
                  List<String> urls = List<String>.from(jsonDecode(value));
                  indexUrls(urls);
                  looked.remove(name);
                }
              });
            });
          }
        }
      }
    }));
  }

  @override
  Future<List<Folder>> getFolders(int index) async {
    return objectbox.getFolders(host: _host);
  }

  @override
  Future<List<Folder>> getAllFolders(int index) async {
    List<Folder> list = [];
    return list;
  }

  @override
  Future<List<ImageMeta>> getFolderFiles(int section, int index) async {
    List<Folder> f = await getFolders(section);
    String day = f[index].name;
    return objectbox.getImagesByDay(day, host: host);
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

  Future<StreamController<List<ImageMeta>>> indexUrls(List<String> urls) async {
    // 1. Check if this is discord
    urls = urls.where((url) => ['cdn.discordapp.com', 'media.discordapp.net'].contains(Uri.parse(url).host)).toList();

    // 2. Put images and parse
    ParseJob job = ParseJob();
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
    }).toList(), host: 'web');

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
          if (notID != -1) notificationManager!.close(notID);
        },
        onProcess: (total, current, thumbnail) {
          if (notID == -1) return;
          print('on process');
          notificationManager!.update(notID, 'description', 'We are processing $total/$current images, please wait');
          if (thumbnail != null) {
            notificationManager!.update(notID, 'thumbnail', Image.memory(
              thumbnail,
              filterQuality: FilterQuality.low,
              gaplessPlayback: true,
            ));
          }
        }
    );
    _jobs[jobID] = job;

    // Return job id
    return job.controller;
  }

  @override
  bool indexAll(int index) {
    // int notID = notificationManager!.show(
    //     thumbnail: const Icon(Icons.access_time_filled_outlined, color: Colors.lightBlueAccent, size: 64),
    //     title: 'Starting indexing',
    //     description: 'Give us a few minutes, you will receive the folder data...'
    // );
    // getAllFolders(index).then((fo) async {
    //   if(isIndexingAll) return false;
    //   isIndexingAll = true;
    //   notificationManager!.update(notID, 'title', 'Indexing ${tabs[index]}');
    //   notificationManager!.update(notID, 'description', 'We are processing ${fo.length} folders,\nmeantime, you can have some tea');
    //   notificationManager!.update(notID, 'content', Container(
    //     margin: const EdgeInsets.only(top: 7),
    //     width: 100,
    //     child: const LinearProgressIndicator(),
    //   ));
    //   notificationManager!.update(notID, 'thumbnail', Shimmer.fromColors(
    //     baseColor: Colors.lightBlueAccent,
    //     highlightColor: Colors.blueAccent.withOpacity(0.3),
    //     child: const Icon(Icons.image_search_outlined, color: Colors.white, size: 64),
    //   ));
    //   int d = 0;
    //   for(var f in fo){
    //     // То что уже есть, чтобы не трогать
    //     List<String> ima = await getFolderHashes(normalizePath(f.getter), host: host);
    //     StreamController co = await indexFolder(f, hashes: ima);
    //     print('jobs co $getJobCountActive()');
    //     bool cont = await _isDone(co);
    //     d++;
    //     notificationManager!.update(notID, 'content', Container(
    //         margin: const EdgeInsets.only(top: 7),
    //         width: 100,
    //         child: LinearProgressIndicator(value: (d * 100 / fo.length) / 100)
    //     ));
    //   }
    //   if(notID != -1) notificationManager!.close(notID);
    //   isIndexingAll = false;
    // });
    return true;
  }

  Future<bool> _isDone(StreamController co) async{
    while(getJobCountActive() > 10){
      await Future.delayed(const Duration(seconds: 2));
    }
    return true;
  }

  Future<List<String>> getFolderHashes(String folder, {String? host}) async {
    return NavigationService.navigatorKey.currentContext!.read<SQLite>().getFolderHashes(folder, host: _host);
  }

  @override
  Future<StreamController<List<ImageMeta>>> indexFolder(Folder folder, {List<String>? hashes, RenderEngine? re}) async {
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
              notificationManager!.update(notID, 'description', 'We are processing $total/$current images, please wait');
              if(thumbnail != null) {
                notificationManager!.update(notID, 'thumbnail', Image.memory(
                  thumbnail,
                  filterQuality: FilterQuality.low,
                  gaplessPlayback: true,
                ));
              }
            }
        );
        _jobs[jobID] = job;

        // Return job id
        return job.controller;
      } else {
        late final StreamController<List<ImageMeta>> controller;
        controller = StreamController<List<ImageMeta>>(
          onListen: () async {
            await controller.close();
          },
        );
        return controller;
      }
    } else if(software == Software.swarmUI) {
      String session_id = NavigationService.navigatorKey.currentContext!.read<DataManager>().temp.containsKey('swarm_client_info') ? (NavigationService.navigatorKey.currentContext?.read<DataManager>().temp['swarm_client_info'] as SwarmClientInfo).sessionID! : 'null';
      Uri base = Uri(
          scheme: parse.scheme,
          host: parse.host,
          port: parse.port,
          path: '/API/ListImages'
      );
      var res = await http.Client().post(base, headers: {
        "User-Agent": _userAgent,
        "Accept": "*/*",
        "Accept-Language": "en,en-US;q=0.5",
        "Content-Type": "application/json"
      }, body: jsonEncode(<String, String>{
        'session_id': session_id,
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
              notificationManager!.update(notID, 'description', 'We are processing $total/$current images, please wait');
              if(thumbnail != null) {
                notificationManager!.update(notID, 'thumbnail', Image.memory(
                  thumbnail,
                  filterQuality: FilterQuality.low,
                  gaplessPlayback: true,
                ));
              }
            }
        );
        _jobs[jobID] = job;

        // Return job id
        return job.controller;
      } else {
        late final StreamController<List<ImageMeta>> controller;
        controller = StreamController<List<ImageMeta>>(
          onListen: () async {
            await controller.close();
          },
        );
        return controller;
      }
    } else {
      late final StreamController<List<ImageMeta>> controller;
      controller = StreamController<List<ImageMeta>>(
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
}