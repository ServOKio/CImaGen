import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cimagen/main.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:shimmer/shimmer.dart';

import '../../Utils.dart';
import 'AbMain.dart';

class OnLocal extends ChangeNotifier implements AbMain{
  @override
  bool loaded = false;
  @override
  String? error;
  @override
  bool get hasError => error != null;

  Software? software;

  List<String> inProcess = [];
  bool isIndexingAll = false;

  // Config
  Map<String, dynamic> _config = <String, dynamic>{};
  Map<String, dynamic> get config => _config;

  // WebUI
  String _webui_root = '';

  @override
  String? get host => null;
  String hostHash = '';

  Map<String, String> _webuiPaths = {};
  @override
  Map<String, String> get webuiPaths => _webuiPaths;

  // Other
  List<StreamSubscription<FileSystemEvent>> watchList = [];
  Map<int, ParseJob> _jobs = {};
  Map<int, ParseJob> get getJobs => _jobs;

  int getJobCountActive() {
    _jobs.removeWhere((key, value) => value.controller.isClosed);
    return _jobs.length;
  }

  List<String> _tabs = [];
  @override
  List<String> get tabs => _tabs;
  List<RenderEngine> _internalTabs = [];


  @override
  Future<void> init() async {
    for (var e in watchList) {
      e.cancel();
    }
    _tabs.clear();
    _internalTabs.clear();
    _webuiPaths.clear();

    String? webuiFolder = prefs.getString('webui_folder');
    if(webuiFolder == null) {
      int notID = notificationManager!.show(
          thumbnail: const Icon(Icons.error, color: Colors.redAccent),
          title: 'Initialization problem',
          description: 'The folder containing Stable Diffusion WebUI is not specified. Specify in the settings',
          content: Padding(padding: EdgeInsets.only(top: 7), child: ElevatedButton(
              style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                  shape: WidgetStateProperty.all<RoundedRectangleBorder>(const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))))
              ),
              onPressed: () => init(),
              child: const Text("Try again", style: TextStyle(fontSize: 12))
          ))
      );
      audioController!.player.play(AssetSource('audio/error.wav'));
      return;
    }
    _webui_root = webuiFolder;
    //if swarnUI
    bool swarnPS = File('$_webui_root/SwarmUI.sln').existsSync();
    bool sdWebUIConfig = File('$webuiFolder/config.json').existsSync();
    if(swarnPS){
      // Output / local /
    } else if(sdWebUIConfig){
      final String response = File('$webuiFolder/config.json').readAsStringSync();
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
      _tabs = ['txt2img', 'img2img'];
      _internalTabs = [RenderEngine.txt2img, RenderEngine.img2img];
      objectbox.cleanUp(host);
      loaded = true;
      int notID = notificationManager!.show(
          thumbnail: const Icon(Icons.account_tree_outlined, color: Colors.blue),
          title: 'Welcome to Stable Diffusion',
          description: 'Initialization was successful'
      );
      audioController!.player.play(AssetSource('audio/info.wav'));
      Future.delayed(const Duration(milliseconds: 10000), () {
        notificationManager!.close(notID);
      });
      notifyListeners();

      if(_webuiPaths['outdir_txt2img-images'] != null) watchDir(RenderEngine.txt2img, _webuiPaths['outdir_txt2img-images']!);
      if(_webuiPaths['outdir_img2img-images'] != null) watchDir(RenderEngine.img2img, _webuiPaths['outdir_img2img-images']!);
    }
  }

  Map<RenderEngine, String> ke = {
    RenderEngine.txt2img: 'outdir_txt2img-images',
    RenderEngine.txt2imgGrid: 'outdir_txt2img_grids',
    RenderEngine.img2img: 'outdir_img2img-images',
    RenderEngine.img2imgGrid: 'outdir_img2img_grids',
    RenderEngine.extra: 'outdir_extras_samples'
  };

  @override
  Future<List<Folder>> getFolders(int index) async {
    return objectbox.getFolders(host: host, re: _internalTabs[index]);
  }

  @override
  Future<List<Folder>> getAllFolders(int index) async {
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
            fullPath: p.normalize(ent.path),
            isLocal: true
        )).toList()
      ));
      ind++;
    }
    return f;
  }

  @override
  Future<List<ImageMeta>> getFolderFiles(int section, int index) async {
    List<Folder> f = await getFolders(section);
    String day = f[index].name;
    return objectbox.getImagesByDay(day, host: host, re: _internalTabs[section]);
  }

  @override
  String getFullUrlImage(ImageMeta im) => '';
  @override
  String getThumbnailUrlImage(ImageMeta im) => '';

  @override
  void exit() {
    for (var e in watchList) {
      e.cancel();
    }
    for(int id in _jobs.keys){
      _jobs[id]!.forceStop();
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
        objectbox.updateIfNado(event.destination!, host: null);
      }
    }));
  }

  Future<List<String>> getFolderHashes(String folder, {String? host}) async {
    return objectbox.getFolderHashes(folder, host: host);
  }

  @override
  bool indexAll(int index) {
    int notID = notificationManager!.show(
        thumbnail: const Icon(Icons.access_time_filled_outlined, color: Colors.lightBlueAccent, size: 64),
        title: 'Starting indexing',
        description: 'Give us a few seconds...'
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
        try{
          // То что уже есть, чтобы не трогать
          List<String> ima = await getFolderHashes(normalizePath(f.getter), host: null);
          StreamController co = await indexFolder(f, hashes: ima, re: _internalTabs[index]);
          bool cont = await _isDone(co);
          d++;
          notificationManager!.update(notID, 'content', Container(
              margin: const EdgeInsets.only(top: 7),
              width: 100,
              child: LinearProgressIndicator(value: (d * 100 / fo.length) / 100)
          ));
        } catch(e){
          int notID = notificationManager!.show(
              thumbnail: const Icon(Icons.error, color: Colors.redAccent),
              title: 'Error processing folder ${f.getter}',
              description: '${e.toString().startsWith('Invalid argument') ? 'Some internal error ?' : 'Unknown error'}\nError: $e'
          );
          audioController!.player.play(AssetSource('audio/error.wav'));
          Future.delayed(const Duration(milliseconds: 10000), () => notificationManager!.close(notID));
        }
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
    while(getJobCountActive() >= 10){
      await Future.delayed(const Duration(seconds: 2));
    }
    return true;
  }

  @override
  Future<StreamController<List<ImageMeta>>> indexFolder(Folder folder, {List<String>? hashes, RenderEngine? re}) async {
    print('indexFolder: ${folder.getter} ${hashes?.length ?? 'null'} with re: ${re != null ? re.toString() : 'null'}');
    // Read all files sizes and get hash
    //print(p.join(_webuiPaths[ke[renderEngine]]!, sub));
    Directory di = Directory(normalizePath(folder.getter));
    List<FileSystemEntity> fe = await dirContents(di); // Filter this shit
    //print('total: ${fe.length}');

    if(hashes != null && hashes.isNotEmpty){
      fe = fe.where((e) => !hashes.contains(genPathHash(normalizePath(e.path)))).toList(growable: false);
      fe = fe.where((e) => !hashes.contains(genPathHash(normalizePath(e.path)))).toList(growable: false);
      if (kDebugMode) {
        print('onLocal:indexFolder: to send: ${fe.length} with ${hashes.length} hashes');
      }
    }

    if(fe.isNotEmpty){
      if(inProcess.contains(di.path)){
        fe = [];
      } else {
        inProcess.add(di.path);
      }
    }

    ParseJob job = ParseJob(re: re);
    int jobID = await job.putAndGetJobID(fe.map((e) => e.path).toList(growable: false));

    int notID = -1;
    if(fe.isNotEmpty) {
      notID = notificationManager!.show(
        title: 'Indexing ${di.path}',
        description: 'We are processing ${fe.length} images, please wait',
        content: Container(
          margin: const EdgeInsets.only(top: 7),
          width: 100,
          child: const LinearProgressIndicator(),
        )
      );
    }
    _jobs[jobID] = job..run(
        onDone: (){
          _jobs.remove(jobID);
          if(notID != -1) notificationManager!.close(notID);
          if(fe.isNotEmpty) inProcess.remove(di.path);
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

    // Return stream
    return job.controller;
  }
}