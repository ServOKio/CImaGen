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
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../Utils.dart';
import '../../utils/NavigationService.dart';
import '../../utils/SQLite.dart';
import '../swarmUI/swarmModule.dart';

class OnRemote extends ChangeNotifier implements AbMain{
  @override
  bool loaded = false;
  String? error;
  @override
  bool get hasError => error != null;

  Software? software;

  List<String> inProcess = [];
  bool isIndexingAll = false;

  String _host = '-';
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

  String _sd_root = '';

  Map<String, String> _webuiPaths = {};
  @override
  Map<String, String> get webuiPaths => _webuiPaths;

  Map<int, ParseJob> _jobs = {};
  int getJobCountActive() {
    _jobs.removeWhere((key, value) => value.controller.isClosed);
    return _jobs.length;
  }

  @override
  Future<void> init() async {
    bool _has_connection = false;
    bool _has_200_code = false;
    bool _has_infinite_image_browsing_extension = false;

    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    _userAgent = "CImaGen/${packageInfo.version} (platform; ${Platform.isAndroid ? 'android' : Platform.isWindows ? 'windows' : Platform.isIOS ? 'IOS' : Platform.isLinux ? 'linux' : Platform.isFuchsia ? 'fuchsia' : Platform.isMacOS ? 'MacOs' : 'Unknown'})";
    // 1. We need to know the system we are working with.
    if(!prefs!.containsKey('remote_webui_address')){
      int notID = notificationManager!.show(
          thumbnail: const Icon(Icons.error, color: Colors.redAccent),
          title: 'Initialization problem',
          description: 'The remote address of the panel is not specified. Specify it in the settings in the remote connection section\bDev: remote_webui_address key',
          content: ElevatedButton(
              onPressed: () => init(),
              child: const Text("Try again", style: TextStyle(fontSize: 12))
          )
      );
      audioController!.player.play(AssetSource('audio/error.wav'));
      return;
    }
    _remoteAddress = prefs!.getString('remote_webui_address')!;
    Uri parse = Uri.parse(_remoteAddress);

    // Checking if Stable Diffusion
    Uri base = Uri(
        scheme: parse.scheme,
        host: parse.host,
        port: parse.port,
        path: '/internal/sysinfo',
        queryParameters: {'attachment': 'false'}
    );
    http.Client().get(base).then((res) async {
      _has_connection = true;
      if(res.statusCode == 200){
        //print(res.body);
        _has_200_code = true;
        var data = await json.decode(res.body);
        var exNames = data['Extensions'].map((ex) => ex['name'] as String).toList();
        _has_infinite_image_browsing_extension = exNames.contains('sd-webui-infinite-image-browsing');
        if(!_has_infinite_image_browsing_extension){
          int notID = notificationManager!.show(
              thumbnail: const Icon(Icons.warning, color: Colors.redAccent),
              title: 'One of the Dependencies is missing',
              description: 'sd-webui-infinite-image-browsing addon not found',
              content: ElevatedButton(
                  onPressed: () => init(),
                  child: const Text("Try again", style: TextStyle(fontSize: 12))
              )
          );
          audioController!.player.play(AssetSource('audio/error.wav'));
          return;
        }

        _host = Uri(
            host: parse.host,
            port: parse.port
        ).toString();
        Uri base = Uri(
          scheme: parse.scheme,
          host: parse.host,
          port: parse.port,
          path: '/infinite_image_browsing/global_setting',
        );
        http.Client().get(base, headers: {
          "User-Agent": _userAgent,
          "Accept": "*/*",
          "Accept-Language": "en,en-US;q=0.5",
          "Content-Type": "application/json"
        }).timeout(const Duration(seconds: 10)).then((res) async {
          if(res.statusCode == 200){
            var data = await json.decode(res.body);
            _sd_root = data['sd_cwd'];

            //reForge has difference
            _webuiPaths.addAll({
              'outdir_extras-images': normalizePath(p.join(_sd_root, (data['global_setting']['outdir_extras_samples'] ?? 'outputs/extras-images'))),
              'outdir_img2img-grids': normalizePath(p.join(_sd_root, (data['global_setting']['outdir_img2img_grids'] ?? 'outputs/img2img-grids'))),
              'outdir_img2img-images': normalizePath(p.join(_sd_root, (data['global_setting']['outdir_img2img_samples'] ?? 'outputs/img2img-images'))),
              'outdir_txt2img-grids': normalizePath(p.join(_sd_root, (data['global_setting']['outdir_txt2img_grids'] ?? 'outputs/txt2img-grids'))),
              'outdir_txt2img-images': normalizePath(p.join(_sd_root, (data['global_setting']['outdir_txt2img_samples'] ?? 'outputs/txt2img-images'))),
              'outdir_save': normalizePath(p.join(_sd_root, (data['global_setting']['outdir_save']))),
              'outdir_init': normalizePath(p.join(_sd_root, (data['global_setting']['outdir_init_images'])))
            });
            software = Software.stableDiffusionWebUI;
            _tabs = ['txt2img', 'img2img'];
            loaded = true;
          } else {
            if (kDebugMode) {
              print('idi naxyi ${res.statusCode}');
            }
            error = 'The host returned an invalid response: ${res.statusCode}';
          }
          notifyListeners();
          if(!loaded) findError();
        }).catchError((e, t) {
          error = e.toString();
          notifyListeners();

          int notID = notificationManager!.show(
              thumbnail: const Icon(Icons.error, color: Colors.redAccent, size: 32),
              title: 'Error on OnRemote.dart',
              description: e.toString(),
              content: ElevatedButton(
                  onPressed: () => init(),
                  child: const Text("Try again", style: TextStyle(fontSize: 12))
              )
          );
          audioController!.player.play(AssetSource('audio/error.wav'));
          findError();
        });
      } else {
        // Not sd, swarm ?
        // 1. Need session token
        String session_id = NavigationService.navigatorKey.currentContext!.read<DataManager>().temp.containsKey('swarm_client_info') ? (NavigationService.navigatorKey.currentContext?.read<DataManager>().temp['swarm_client_info'] as SwarmClientInfo).sessionID! : 'null';

        Uri base = Uri(
            scheme: parse.scheme,
            host: parse.host,
            port: parse.port,
            path: '/API/${session_id != 'null' ? 'GetCurrentStatus' : 'GetNewSession'}'
        );
        http.Client().post(base, headers: {
          "User-Agent": _userAgent,
          "Accept": "*/*",
          "Accept-Language": "en,en-US;q=0.5",
          "Content-Type": "application/json"
        }, body: jsonEncode(<String, String>{
          'session_id': session_id
        })).then((res) async {
          if(res.statusCode == 200){
            //print(res.body);
            _has_200_code = true;
            _host = Uri(
                host: parse.host,
                port: parse.port
            ).toString();
            var data = await json.decode(res.body);
            if(session_id == 'null'){
              NavigationService.navigatorKey.currentContext?.read<DataManager>().temp['swarm_client_info'] = SwarmClientInfo(
                  sessionID: data['session_id'],
                  userID: data['user_id'],
                  outputAppendUser: data['output_append_user'],
                  version: data['version'],
                  serverID: data['server_id'],
                  countRunning: data['count_running'],
                  permissions: List<String>.from(data['permissions'])
              );
            }
            software = Software.swarmUI;
            _tabs = ['All'];
            loaded = true;
            SwarmClientInfo info = (NavigationService.navigatorKey.currentContext?.read<DataManager>().temp['swarm_client_info'] as SwarmClientInfo);
            int notID = notificationManager!.show(
                thumbnail: const Icon(Icons.account_tree_outlined, color: Colors.blue),
                title: 'Welcome to SwarmUI, ${info.userID}',
                description: 'Server: ${info.serverID}\nSession ID: ${info.sessionID}'
            );
            audioController!.player.play(AssetSource('audio/info.wav'));
            Future.delayed(const Duration(milliseconds: 10000), () {
              notificationManager!.close(notID);
            });
          } else {
            // TODO
            // Not swarm, comfui ?
            int notID = notificationManager!.show(
                thumbnail: const Icon(Icons.error, color: Colors.redAccent, size: 32),
                title: 'Initialization problem',
                description: 'Error: Code is not 200: ${res.statusCode}\n${res.body}',
                content: ElevatedButton(
                    onPressed: () => init(),
                    child: const Text("Try again", style: TextStyle(fontSize: 12))
                )
            );
            audioController!.player.play(AssetSource('audio/error.wav'));
          }
          notifyListeners();
          if(!loaded) findError();
        }).catchError((e){
          int notID = notificationManager!.show(
              thumbnail: const Icon(Icons.error, color: Colors.redAccent, size: 32),
              title: 'Initialization problem',
              description: 'Error: $e',
              content: ElevatedButton(
                  onPressed: () => init(),
                  child: const Text("Try again", style: TextStyle(fontSize: 12))
              )
          );
          audioController!.player.play(AssetSource('audio/error.wav'));
        });
      }
    }).catchError((e){
      int notID = notificationManager!.show(
          thumbnail: const Icon(Icons.error, color: Colors.redAccent, size: 32),
          title: 'Initialization problem',
          description: 'Error: $e',
          content: ElevatedButton(
              onPressed: () => init(),
              child: const Text("Try again", style: TextStyle(fontSize: 12))
          )
      );
      audioController!.player.play(AssetSource('audio/error.wav'));
    });
  }

  @override
  Future<List<Folder>> getFolders(int index) async {
    return NavigationService.navigatorKey.currentContext!.read<SQLite>().getFolders(host: _host);
  }

  @override
  Future<List<Folder>> getAllFolders(int index) async {
    // http://gg:7860/infinite_image_browsing/files?folder_path=Z:%2Fstable-diffusion-webui%2Foutputs%2Ftxt2img-images
    List<Folder> list = [];
    Uri parse = Uri.parse(_remoteAddress);

    if(software == Software.stableDiffusionWebUI) {
      Uri base = Uri(
          scheme: parse.scheme,
          host: parse.host,
          port: parse.port,
          path: '/infinite_image_browsing/files',
          queryParameters: {
            'folder_path': [
              _webuiPaths['outdir_txt2img-images'],
              _webuiPaths['outdir_img2img-images']
            ][index]!
          }
      );
      var res = await http.Client().get(base).timeout(const Duration(seconds: 10));
      if(res.statusCode == 200){
        List<dynamic> files = await json.decode(res.body)['files'];
        for (var i = 0; i < files.length; i++) {
          var f = files[i];
          //Read Folder
          // base = Uri(
          //     scheme: parse.scheme,
          //     host: parse.host,
          //     port: parse.port,
          //     path: '/infinite_image_browsing/files',
          //     queryParameters: {'folder_path': f['fullpath']}
          // );
          // res = await http.Client().get(base).timeout(const Duration(seconds: 5));
          // var folderFilesRaw = await json.decode(res.body)['files'].where((e) => ['.png', 'jpg', '.jpeg', '.gif', '.webp'].contains(p.extension(e['name']))).toList();
          List<FolderFile> folderFiles = [];
          // for (var i2 = 0; i2 < folderFilesRaw.length; i2++) {
          //   var file = folderFilesRaw[i2];
          //   Uri thumb = Uri(
          //       scheme: parse.scheme,
          //       host: parse.host,
          //       port: parse.port,
          //       path: '/infinite_image_browsing/image-thumbnail',
          //       queryParameters: {
          //         'path': file['fullpath'],
          //         'size': '512x512',
          //         't': file['date']
          //       }
          //   );
          //   folderFiles.add(FolderFile(fullPath: file['fullpath'], isLocal: false, thumbnail: thumb.toString()));
          // }
          list.add(Folder(index: i, getter: f['fullpath'], type: FolderType.path, name: f['name'], files: folderFiles));
          i++;
        }
      } else {
        print('idi naxyi ${res.statusCode}');
      }
    } else if(software == Software.swarmUI) {
      int notID = notificationManager!.show(
          thumbnail: const Icon(Icons.inbox_outlined, color: Colors.blue),
          title: 'Getting all folders',
          description: 'Preparations are underway...'
      );
      audioController!.player.play(AssetSource('audio/info.wav'));

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
        'depth': '10',
        'path': '',
        'sortBy': 'Name',
        'sortReverse': 'true'
      }));
      if(res.statusCode == 200){
        List<String> files = List<String>.from(await json.decode(res.body)['folders']);
        int co = files.length;

        notificationManager!.update(notID, 'title', 'Not bad...');
        notificationManager!.update(notID, 'description', 'We have received $co folders, and they are being read...');
        notificationManager!.update(notID, 'content', Container(
          margin: const EdgeInsets.only(top: 7),
          width: 100,
          child: const LinearProgressIndicator(),
        ));
        notificationManager!.update(notID, 'thumbnail', Shimmer.fromColors(
          direction: ShimmerDirection.ttb,
          baseColor: Colors.lightBlueAccent,
          highlightColor: Colors.blueAccent.withOpacity(0.3),
          child: const Icon(Icons.inbox, color: Colors.white, size: 64),
        ));

        for (var i = 0; i < co; i++) {
          String folderPath = files[i];
          //Read Folder
          base = Uri(
              scheme: parse.scheme,
              host: parse.host,
              port: parse.port,
              path: '/API/ListImages'
          );
          try{
            res = await http.Client().post(base, headers: {
              "User-Agent": _userAgent,
              "Accept": "*/*",
              "Accept-Language": "en,en-US;q=0.5",
              "Content-Type": "application/json"
            }, body: jsonEncode(<String, String>{
              'session_id': session_id,
              'depth': '1',
              'path': folderPath,
              'sortBy': 'Name',
              'sortReverse': 'true'
            })).timeout(const Duration(seconds: 5));
            var folderFilesRaw = await json.decode(res.body)['files'].where((e) => ['.png', 'jpg', '.jpeg', '.gif', '.webp'].contains(p.extension(e['src'].split('/').last))).toList();
            List<FolderFile> folderFiles = [];
            for (var i2 = 0; i2 < folderFilesRaw.length; i2++) {
              var file = folderFilesRaw[i2];
              Uri thumb = Uri(
                  scheme: parse.scheme,
                  host: parse.host,
                  port: parse.port,
                  path: '/View/local/$folderPath/${file['src']}',
                  queryParameters: {
                    'preview': 'true'
                  }
              );
              Uri full = Uri(
                  scheme: parse.scheme,
                  host: parse.host,
                  port: parse.port,
                  path: '/View/local/$folderPath/${file['src']}'
              );
              folderFiles.add(FolderFile(fullPath: full.toString(), isLocal: false, thumbnail: thumb.toString()));
            }
            list.add(Folder(index: i, getter: folderPath, type: FolderType.path, name: folderPath, files: folderFiles));
          } on Exception catch(e){
            int notID = notificationManager!.show(
                thumbnail: const Icon(Icons.error_outline, color: Colors.yellow),
                title: 'Can\'t parse $folderPath',
                description: 'Error: $e'
            );
            audioController!.player.play(AssetSource('audio/error.wav'));
            Future.delayed(const Duration(milliseconds: 10000), () {
              notificationManager!.close(notID);
            });
          }
          notificationManager!.update(notID, 'content', Container(
              margin: const EdgeInsets.only(top: 7),
              width: 100,
              child: LinearProgressIndicator(value: (i * 100 / co) / 100)
          ));
          await Future.delayed(const Duration(milliseconds: 500), (){});
        }
      } else {
        print('idi naxyi ${res.statusCode}');
      }
      Future.delayed(const Duration(seconds: 5), () => notificationManager!.close(notID));
    }
    return list;
  }

  @override
  Future<List<ImageMeta>> getFolderFiles(int section, int index) async {
    // SELECT DISTINCT DATE(dateModified) AS dates, count(keyup) as total FROM images ORDER BY dates; // fasted
    // SELECT DATE(dateModified) AS dates, count(keyup) as total FROM images GROUP BY DATE(dateModified) ORDER BY dates;
    List<Folder> f = await getFolders(section);
    String day = f[index].name;
    if(software == Software.swarmUI) {
      return NavigationService.navigatorKey.currentContext!.read<SQLite>().getImagesByDay(day, host: _host);
    } else {
      return NavigationService.navigatorKey.currentContext!.read<SQLite>().getImagesByDay(day);
    }
  }

  @override
  String getFullUrlImage(ImageMeta im) {
    Uri parse = Uri.parse(_remoteAddress);
    if(software == Software.stableDiffusionWebUI) {
      Uri full = Uri(
          scheme: 'http',
          host: parse.host,
          port: parse.port,
          path: '/infinite_image_browsing/file',
          queryParameters: {
            'path': im.fullPath,
            't': dateFormatter.format(im.dateModified!)
          }
      );
      return full.toString();
    } else if(software == Software.swarmUI){
      Uri full = Uri(
          scheme: parse.scheme,
          host: parse.host,
          port: parse.port,
          path: '/View/local/${im.fullPath}'
      );
      return full.toString();
    }
    return '';
  }

  @override
  String getThumbnailUrlImage(ImageMeta im){
    Uri parse = Uri.parse(_remoteAddress);
    if(software == Software.stableDiffusionWebUI) {
      Uri thumb = Uri(
          scheme: 'http',
          host: parse.host,
          port: parse.port,
          path: '/infinite_image_browsing/image-thumbnail',
          queryParameters: {
            'path': im.fullPath,
            'size': '512x512',
            't': dateFormatter.format(im.dateModified!)
          }
      );
      return thumb.toString();
    } else if(software == Software.swarmUI){
      Uri thumb = Uri(
          scheme: parse.scheme,
          host: parse.host,
          port: parse.port,
          path: '/View/local/${im.fullPath}',
          queryParameters: {
            'preview': 'true'
          }
      );
      return thumb.toString();
    }
    return '';
  }

  Map<RenderEngine, String> ke = {
    RenderEngine.txt2img: 'outdir_txt2img-images',
    RenderEngine.txt2imgGrid: 'outdir_txt2img_grids',
    RenderEngine.img2img: 'outdir_img2img-images',
    RenderEngine.img2imgGrid: 'outdir_img2img_grids',
    RenderEngine.extra: 'outdir_extras_samples'
  };

  @override
  void exit() {
    // TODO: implement exit
  }

  @override
  bool indexAll(int index) {
    int notID = notificationManager!.show(
        thumbnail: const Icon(Icons.access_time_filled_outlined, color: Colors.lightBlueAccent, size: 64),
        title: 'Starting indexing',
        description: 'Give us a few minutes, you will receive the folder data...'
    );
    getAllFolders(index).then((fo) async {
      if(isIndexingAll) return false;
      isIndexingAll = true;
      notificationManager!.update(notID, 'title', 'Indexing ${tabs[index]}');
      notificationManager!.update(notID, 'description', 'We are processing ${fo.length} folders,\nmeantime, you can have some tea');
      notificationManager!.update(notID, 'content', Container(
        margin: const EdgeInsets.only(top: 7),
        width: 100,
        child: const LinearProgressIndicator(),
      ));
      notificationManager!.update(notID, 'thumbnail', Shimmer.fromColors(
        baseColor: Colors.lightBlueAccent,
        highlightColor: Colors.blueAccent.withOpacity(0.3),
        child: const Icon(Icons.image_search_outlined, color: Colors.white, size: 64),
      ));
      int d = 0;
      for(var f in fo){
        // То что уже есть, чтобы не трогать
        List<String> ima = await getFolderHashes(normalizePath(f.getter), host: host);
        StreamController co = await indexFolder(f, hashes: ima);
        print('jobs co $getJobCountActive()');
        bool cont = await _isDone(co);
        d++;
        notificationManager!.update(notID, 'content', Container(
            margin: const EdgeInsets.only(top: 7),
            width: 100,
            child: LinearProgressIndicator(value: (d * 100 / fo.length) / 100)
        ));
      }
      if(notID != -1) notificationManager!.close(notID);
      isIndexingAll = false;
    });
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
  Future<StreamController<List<ImageMeta>>> indexFolder(Folder folder, {List<String>? hashes}) async {
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

        ParseJob job = ParseJob();
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
                  base64Decode(thumbnail),
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
                  base64Decode(thumbnail),
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
}