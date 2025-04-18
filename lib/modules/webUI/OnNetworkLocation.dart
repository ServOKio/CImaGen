import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cimagen/main.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';

import '../../Utils.dart';
import '../../utils/NavigationService.dart';
import '../../utils/SQLite.dart';
import 'AbMain.dart';

class OnNetworkLocation extends ChangeNotifier implements AbMain {
  @override
  bool loaded = false;
  @override
  String? error;
  @override
  bool get hasError => error != null;

  List<String> inProcess = [];
  bool isIndexingAll = false;

  String _host = '-';
  @override
  String? get host => _host;

  String _remoteAddress = '';

  // Config
  Map<String, dynamic> _config = <String, dynamic>{};
  Map<String, dynamic> get config => _config;

  // WebUI
  String _webui_root = '';
  String _webui_outputs_folder = '';

  Map<String, String> _webuiPaths = {};
  @override
  Map<String, String> get webuiPaths => _webuiPaths;

  // Other
  List<StreamSubscription<FileSystemEvent>> watchList = [];
  Map<int, ParseJob> _jobs = {};
  Map<int, ParseJob> get getJobs => _jobs;

  List<RenderEngine> useAddon = [];
  List<RenderEngine> inSMB = [];

  List<String> _tabs = [];
  @override
  List<String> get tabs => _tabs;

  @override
  Future<void> init() async {
    // 'root', 'output', 'remote'
    String useMethod = prefs.getString('remote_version_method') ?? 'remote';
    if(useMethod == 'root'){
      String sdWebuiFolder = prefs.getString('remote_webui_folder') ?? '';
      if(sdWebuiFolder.isNotEmpty){
        _webui_root = sdWebuiFolder;
        final String response = File('$sdWebuiFolder/config.json').readAsStringSync();
        _config = await json.decode(response);
        // paths
        String i2igOut = p.join(_webui_root, _config['outdir_img2img_grids']);
        String i2iOut = p.join(_webui_root, _config['outdir_img2img_samples']);
        String t2igOut = p.join(_webui_root, _config['outdir_txt2img_grids']);
        String t2iOut = p.join(_webui_root, _config['outdir_txt2img_samples']);
        String eiOut = p.join(_webui_root, _config['outdir_extras_samples']);

        bool hasOutputsFolder = prefs.containsKey('remote_webui_outputs_folder');
        String outBase = hasOutputsFolder ? normalizePath(p.join(prefs.getString('remote_webui_outputs_folder')!.split('outputs')[0], 'outputs')) : '';
        String t = '';

        // img2img grid
        bool i2igE = Directory(i2igOut).existsSync();
        if(!i2igE){
          t = p.join(outBase, i2igOut.split('outputs').last.replaceFirst(RegExp(r'[\\/]'), ''));
          if(Directory(t).existsSync()){
            i2igOut = t;
            i2igE = true;
            inSMB.add(RenderEngine.img2imgGrid);
          } else {
            useAddon.add(RenderEngine.img2imgGrid);
          }
        }

        // img2img
        bool i2iE = Directory(i2iOut).existsSync();
        if(!i2iE){
          t = p.join(outBase, i2iOut.split('outputs').last.replaceFirst(RegExp(r'[\\/]'), ''));
          if(Directory(t).existsSync()){
            i2iOut = t;
            i2iE = true;
            inSMB.add(RenderEngine.img2img);
          } else {
            useAddon.add(RenderEngine.img2img);
          }
        }

        // txt2img grid
        bool t2igE = Directory(t2igOut).existsSync();
        if(!t2igE) {
          t = p.join(outBase, t2igOut.split('outputs').last.replaceFirst(RegExp(r"[\\/]"), ''));
          if(Directory(t).existsSync()){
            t2igOut = t;
            t2igE = true;
            inSMB.add(RenderEngine.txt2imgGrid);
          } else {
            useAddon.add(RenderEngine.txt2imgGrid);
          }
        }

        // txt2img
        bool t2iE = Directory(t2iOut).existsSync();
        if(!t2iE){
          t = p.join(outBase, t2iOut.split('outputs').last.replaceFirst(RegExp(r'[\\/]'), ''));
          if(Directory(t).existsSync()){
            t2iOut = t;
            t2iE = true;
            inSMB.add(RenderEngine.txt2img);
          } else {
            useAddon.add(RenderEngine.txt2img);
          }
        }

        // extra
        bool eE = Directory(eiOut).existsSync();
        if(!eE){
          t = p.join(outBase, eiOut.split('outputs').last.replaceFirst(RegExp(r'\\|/'), ''));
          if(Directory(t).existsSync()){
            eiOut = t;
            eE = true;
            inSMB.add(RenderEngine.extra);
          } else {
            useAddon.add(RenderEngine.extra);
          }
        }

        _webuiPaths.addAll({
          // img2img
          'outdir_img2img-grids': i2igE ? i2igOut : _config['outdir_img2img_grids'],
          'outdir_img2img-images': i2iE ? i2iOut : _config['outdir_img2img_samples'],
          //txt2img
          'outdir_txt2img-grids': t2igE ? t2igOut : _config['outdir_txt2img_grids'],
          'outdir_txt2img-images': t2iE ? t2iOut : _config['outdir_txt2img_samples'],
          //extra
          'outdir_extras_samples': eE ? eiOut : _config['outdir_extras_samples'],
        });

        _tabs = ['txt2img', 'img2img'];
        loaded = true;

        if(useAddon.isNotEmpty){
          if(hasOutputsFolder) {
            int notID = notificationManager!.show(
                thumbnail: const Icon(Icons.network_ping, color: Colors.blueAccent, size: 32),
                title: 'Some access points have been changed',
                description: '${useAddon.map((e) => renderEngineToString(e)).join(', ')} will be processed over the internet, not locally'
            );
            audioController!.player.play(AssetSource('audio/wrong.wav'));
          } else {
            int notID = notificationManager!.show(
                thumbnail: const Icon(Icons.network_ping, color: Colors.redAccent, size: 32),
                title: 'Some access points require remote access',
                description: '${useAddon.map((e) => renderEngineToString(e)).join(', ')} should be processed over the internet, not locally, but "outputs folder" is not configured'
            );
            audioController!.player.play(AssetSource('audio/error.wav'));
          }
        }

        if(_webuiPaths['outdir_txt2img-images'] != null) watchDir(RenderEngine.txt2img, _webuiPaths['outdir_txt2img-images']!);
        if(_webuiPaths['outdir_img2img-images'] != null) watchDir(RenderEngine.img2img, _webuiPaths['outdir_img2img-images']!);
      } else {
        print('emply');
      }
    } else {
      print('use $useMethod');
    }
  }

  @override
  Future<List<ImageMeta>> getFolderFiles(int section, int index) async {
    List<Folder> f = await getFolders(section);
    String day = f[index].name;
    return NavigationService.navigatorKey.currentContext!.read<SQLite>().getImagesByDay(day, host: host);
  }

  Map<RenderEngine, String> ke = {
    RenderEngine.txt2img: 'outdir_txt2img-images',
    RenderEngine.txt2imgGrid: 'outdir_txt2img_grids',
    RenderEngine.img2img: 'outdir_img2img-images',
    RenderEngine.img2imgGrid: 'outdir_img2img_grids',
    RenderEngine.extra: 'outdir_extras_samples'
  };

  @override
  Future<List<Folder>> getAllFolders(int index) async {
    return getFolders(index);
  }

  @override
  Future<List<Folder>> getFolders(int index, {String? host}) async {
    if(useAddon.contains(index)) return getNetworkFolders(index);
    List<Folder> f = [];
    int ind = 0;
    Directory di = Directory([
      _webuiPaths['outdir_txt2img-images'],
      _webuiPaths['outdir_img2img-images']
    ][index]!);
    List<FileSystemEntity> fe = await dirContents(di);

    for(FileSystemEntity ent in fe){
      f.add(Folder(
        index: ind,
        getter: ent.path,
        type: FolderType.path,
        name: p.basename(ent.path),
        files: (await dirContents(Directory(ent.path))).where((element) => ['.png', '.jpeg', '.jpg', '.gif', '.webp'].contains(p.extension(element.path))).map((ent) => FolderFile(
            fullPath: normalizePath(ent.path),
            isLocal: true
        )).toList()
      ));
      ind++;
    }
    return f;
  }

  @override
  Future<List<Folder>> getNetworkFolders(int index) async {
    // http://gg:7860/infinite_image_browsing/files?folder_path=Z:%2Fstable-diffusion-webui%2Foutputs%2Ftxt2img-images
    List<Folder> list = [];
    Uri parse = Uri.parse(_remoteAddress);
    Uri base = Uri(
        scheme: parse.scheme,
        host: parse.host,
        port: parse.port,
        path: '/infinite_image_browsing/files',
        queryParameters: {'folder_path': [
          _webuiPaths['outdir_txt2img-images'],
          _webuiPaths['outdir_img2img-images']
        ][index]!}
    );
    print(base.toString());
    var res = await http.Client().get(base).timeout(const Duration(seconds: 10));
    if(res.statusCode == 200){
      List<dynamic> files = await json.decode(res.body)['files'];
      for (var i = 0; i < files.length; i++) {
        var f = files[i];
        //Read Folder
        base = Uri(
            scheme: parse.scheme,
            host: parse.host,
            port: parse.port,
            path: '/infinite_image_browsing/files',
            queryParameters: {'folder_path': f['fullpath']}
        );
        res = await http.Client().get(base).timeout(const Duration(seconds: 5));
        var folderFilesRaw = await json.decode(res.body)['files'].where((e) => ['.png', 'jpg', '.jpeg', '.gif', '.webp'].contains(p.extension(e['name']))).toList();
        List<FolderFile> folderFiles = [];
        for (var i2 = 0; i2 < folderFilesRaw.length; i2++) {
          var file = folderFilesRaw[i2];
          Uri thumb = Uri(
              scheme: parse.scheme,
              host: parse.host,
              port: parse.port,
              path: '/infinite_image_browsing/image-thumbnail',
              queryParameters: {
                'path': file['fullpath'],
                'size': '512x512',
                't': file['date']
              }
          );
          folderFiles.add(FolderFile(fullPath: file['fullpath'], isLocal: false, networkThumbnail: thumb.toString()));
        }
        list.add(Folder(
            index: i,
            getter: f['fullpath'],
            type: FolderType.path,
            name: f['name'],
            files: folderFiles
        ));
        i++;
      }
    } else {
      print('idi naxyi ${res.statusCode}');
    }

    return list;
  }

  @override
  String getFullUrlImage(ImageMeta im) => '';
  @override
  String getThumbnailUrlImage(ImageMeta im) => '';

  @override
  void exit() {
    for (var element in watchList) {
      element.cancel();
    }
  }

  void watchDir(RenderEngine re, String path){
    final tempFolder = File(path);
    if (kDebugMode) print('watch $path');
    // flutter: FileSystemCreateEvent('K:/pictures/sd/outputs/txt2img-images\2024-04-13\00058-Euler a-3200625744.tmp', isDirectory=false)
    // flutter: FileSystemModifyEvent('K:/pictures/sd/outputs/txt2img-images\2024-04-13\00058-Euler a-3200625744.tmp', isDirectory=false, contentChanged=true)
    // flutter: FileSystemMoveEvent('K:/pictures/sd/outputs/txt2img-images\2024-04-13\00058-Euler a-3200625744.tmp', isDirectory=false, destination=K:/pictures/sd/outputs/txt2img-images\2024-04-13\00058-Euler a-3200625744.png)
    // flutter: FileSystemModifyEvent('K:/pictures/sd/outputs/txt2img-images\2024-04-13', isDirectory=true, contentChanged=true)
    Stream<FileSystemEvent> te = tempFolder.watch(events: FileSystemEvent.all, recursive: true);
    watchList.add(te.listen((event) {
      if (event is FileSystemMoveEvent && !event.isDirectory && event.destination != null) {
        NavigationService.navigatorKey.currentContext!.read<ImageManager>().updateIfNado(re, event.destination ?? 'jri govno dart');
      }
    }));
  }

  @override
  bool indexAll(int index) {
    int notID = notificationManager!.show(
        thumbnail: const Icon(Icons.access_time_filled_outlined, color: Colors.lightBlueAccent, size: 64),
        title: 'Starting indexing',
        description: 'Give us a few seconds...'
    );
    getFolders(index).then((fo) async {
      if(isIndexingAll) return false;
      isIndexingAll = true;
      notificationManager!.update(notID, 'title', 'Indexing ${_tabs[index]}');
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
        List<ImageMeta> ima = await getFolderFiles(index, d);
        StreamController co = await indexFolder(f, hashes: ima.map((e) => e.pathHash).toList(growable: false));
        await _isDone(co);
        d++;
        notificationManager!.update(notID, 'content', Container(
            margin: const EdgeInsets.only(top: 7),
            width: 100,
            child: LinearProgressIndicator(value: (d * 100 / fo.length) / 100)
        ));
      }
      if(notID != -1) notificationManager!.close(notID);
      isIndexingAll = false;
    }).catchError((err) {
      notificationManager!.update(notID, 'title', 'Error');
      notificationManager!.update(notID, 'description', 'Error: $err');
      notificationManager!.update(notID, 'content', const Icon(Icons.error, color: Colors.redAccent, size: 64));
      return true;
    });
    return true;
  }

  Future<bool> _isDone(StreamController co) async{
    while(!co.isClosed && _jobs.length >= 5){
      await Future.delayed(const Duration(seconds: 2));
    }
    return true;
  }

  @override
  Future<StreamController<List<ImageMeta>>> indexFolder(Folder folder, {List<String>? hashes, RenderEngine? re}) async {
    // Read all files sizes and get hash
    Directory di = Directory(folder.getter);
    List<FileSystemEntity> fe = await dirContents(di);

    if(hashes != null && hashes.isNotEmpty){
      fe = fe.where((e) => !hashes.contains(genPathHash(normalizePath(e.path)))).toList(growable: false);
      if (kDebugMode) {
        print('to send: ${fe.length}');
      }
    }

    if(fe.isNotEmpty){
      if(inProcess.contains(folder.getter)){
        fe = [];
      } else {
        inProcess.add(folder.getter);
      }
    }

    ParseJob job = ParseJob(re: re);
    int jobID = await job.putAndGetJobID(fe.map((e) => e.path).toList(growable: false));

    int notID = -1;
    if(fe.isNotEmpty) {
      notID = notificationManager!.show(
          title: 'Indexing ${folder.getter}',
          description: 'We are processing ${fe.length} images, please wait',
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
          if(fe.isNotEmpty) inProcess.remove(folder.getter);
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
  }

  @override
  Future<Stream<List<ImageMeta>>> indexNetworkFolder(RenderEngine renderEngine, String sub, {List<String>? hashes}) async {
    Uri parse = Uri.parse(_remoteAddress);
    Uri base = Uri(
        scheme: parse.scheme,
        host: parse.host,
        port: parse.port,
        path: '/infinite_image_browsing/files',
        queryParameters: {'folder_path': p.join(_webuiPaths[ke[renderEngine]]!, sub)}
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
        if(inProcess.contains(sub)){
          folderFilesRaw = [];
        } else {
          inProcess.add(sub);
        }
      }

      ParseJob job = ParseJob();
      int jobID = await job.putAndGetJobID(folderFilesRaw, host: _host);

      int notID = -1;
      if(folderFilesRaw.isNotEmpty) {
        notID = notificationManager!.show(
            title: 'Indexing $sub',
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
            if(folderFilesRaw.isNotEmpty) inProcess.remove(sub);
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
      return job.controller.stream;
    } else {
      late final StreamController<List<ImageMeta>> controller;
      controller = StreamController<List<ImageMeta>>(
        onListen: () async {
          await controller.close();
        },
      );
      return controller.stream;
    }
  }
}

Future<List<FileSystemEntity>> dirContents(Directory dir) {
  var files = <FileSystemEntity>[];
  var completer = Completer<List<FileSystemEntity>>();
  var lister = dir.list(recursive: false);
  lister.listen((file) => files.add(file), onDone:() => completer.complete(files));
  return completer.future;
}