import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cimagen/main.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../Utils.dart';
import '../../utils/NavigationService.dart';
import '../../utils/SQLite.dart';
import 'AbMain.dart';

class OnLocal extends ChangeNotifier implements AbMain{
  @override
  bool loaded = false;
  @override
  String? error;
  @override
  bool get hasError => error != null;

  List<String> inProcess = [];

  // Config
  Map<String, dynamic> _config = <String, dynamic>{};
  Map<String, dynamic> get config => _config;

  // WebUI
  String _webui_root = '';
  String _webui_outputs_folder = '';

  @override
  String? get host => null;

  Map<String, String> _webuiPaths = {};
  @override
  Map<String, String> get webuiPaths => _webuiPaths;

  // Other
  List<StreamSubscription<FileSystemEvent>> watchList = [];
  Map<int, ParseJob> _jobs = {};

  @override
  Future<void> init() async {
    String sdWebuiFolder = prefs!.getString('sd_webui_folder') ?? '';
    if(sdWebuiFolder.isNotEmpty){
      _webui_root = sdWebuiFolder;
      final String response = File('$sdWebuiFolder/config.json').readAsStringSync();
      _config = await json.decode(response);
      // paths
      String i2ig = p.join(_webui_root, _config['outdir_img2img_grids']);
      String i2i = p.join(_webui_root, _config['outdir_img2img_samples']);
      String t2ig = p.join(_webui_root, _config['outdir_txt2img_grids']);
      String t2i = p.join(_webui_root, _config['outdir_txt2img_samples']);
      String ei = p.join(_webui_root, _config['outdir_extras_samples']);

      _webuiPaths.addAll({
        'outdir_img2img-grids': Directory(i2ig).existsSync() ? i2ig : _config['outdir_img2img_grids'],
        'outdir_img2img-images': Directory(i2i).existsSync() ? i2i : _config['outdir_img2img_samples'],
        'outdir_txt2img-grids': Directory(t2ig).existsSync() ? t2ig : _config['outdir_txt2img_grids'],
        'outdir_txt2img-images': Directory(t2i).existsSync() ? t2i : _config['outdir_txt2img_samples'],
        'outdir_extras_samples': Directory(ei).existsSync() ? ei : _config['outdir_extras_samples'],
      });
      loaded = true;
      notifyListeners();

      if(_webuiPaths['outdir_txt2img-images'] != null) watchDir(RenderEngine.txt2img, _webuiPaths['outdir_txt2img-images']!);
      if(_webuiPaths['outdir_img2img-images'] != null) watchDir(RenderEngine.img2img, _webuiPaths['outdir_img2img-images']!);
    }
  }

  @override
  Future<List<ImageMeta>> getFolderFiles(RenderEngine re, String sub) {
    return NavigationService.navigatorKey.currentContext!.read<SQLite>().getImagesByParent(re == RenderEngine.img2img ? [RenderEngine.img2img, RenderEngine.inpaint] : re, sub);
  }

  Map<RenderEngine, String> ke = {
    RenderEngine.txt2img: 'outdir_txt2img-images',
    RenderEngine.txt2imgGrid: 'outdir_txt2img_grids',
    RenderEngine.img2img: 'outdir_img2img-images',
    RenderEngine.img2imgGrid: 'outdir_img2img_grids',
    RenderEngine.extra: 'outdir_extras_samples'
  };

  @override
  Future<List<Folder>> getFolders(RenderEngine renderEngine) async {
    List<Folder> f = [];
    int ind = 0;
    Directory di = Directory(_webuiPaths[ke[renderEngine]]!);
    List<FileSystemEntity> fe = await dirContents(di);

    for(FileSystemEntity ent in fe){
      f.add(Folder(
        index: ind,
        path: ent.path,
        name: p.basename(ent.path),
        files: (await dirContents(Directory(ent.path))).where((element) => ['.png', '.jpeg', '.jpg', '.gif', '.webp'].contains(p.extension(element.path))).map((ent) => FolderFile(
            fullPath: p.normalize(ent.path),
            isLocal: true
        )).toList()
      ));
      ind++;
    }
    return f;
  }

  @override
  void exit() {
    for (var e in watchList) {
      e.cancel();
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
  Future<Stream<List<ImageMeta>>> indexFolder(RenderEngine renderEngine, String sub, {List<String>? hashes}) async {
    print('indexFolder: ${renderEngine.name} $sub ${hashes?.length ?? 'null'}');
    // Read all files sizes and get hash
    //print(p.join(_webuiPaths[ke[renderEngine]]!, sub));
    Directory di = Directory(p.join(_webuiPaths[ke[renderEngine]]!, sub));
    List<FileSystemEntity> fe = await dirContents(di); // Filter this shit
    //print('total: ${fe.length}');

    if(hashes != null && hashes.isNotEmpty){
      // print(hashes.first);
      // for(FileSystemEntity te in fe){
      //   print(te.path);
      //   print(normalizePath(p.normalize(te.path)));
      //   print(genPathHash(normalizePath(p.normalize(te.path))));
      // }
      fe = fe.where((e) => !hashes.contains(genPathHash(normalizePath(e.path)))).toList(growable: false);
      if (kDebugMode) {
        print('onLocal:indexFolder: to send: ${fe.length}');
      }
    }

    if(fe.isNotEmpty){
      if(inProcess.contains(sub)){
        fe = [];
      } else {
        inProcess.add(sub);
      }
    }

    ParseJob job = ParseJob();
    int jobID = await job.putAndGetJobID(renderEngine, fe.map((e) => e.path).toList(growable: false));

    int notID = -1;
    if(fe.isNotEmpty) {
      notID = notificationManager!.show(
        title: 'Indexing $sub',
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
        if(notID != -1) notificationManager!.close(notID);
        if(fe.isNotEmpty) inProcess.remove(sub);
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
    return job.controller.stream;
  }
}

Future<List<FileSystemEntity>> dirContents(Directory dir) {
  var files = <FileSystemEntity>[];
  var completer = Completer<List<FileSystemEntity>>();
  var lister = dir.list(recursive: false);
  lister.listen((file) => files.add(file), onDone:() => completer.complete(files));
  return completer.future;
}