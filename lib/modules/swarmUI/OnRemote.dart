import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:cimagen/main.dart';
import 'package:cimagen/modules/webUI/AbMain.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../Utils.dart';
import '../../utils/NavigationService.dart';
import '../../utils/SQLite.dart';

class OnRemote extends ChangeNotifier implements AbMain{
  @override
  bool loaded = false;
  String? error;
  @override
  bool get hasError => error != null;

  List<String> inProcess = [];
  bool isIndexingAll = false;

  String _host = '-';
  @override
  String? get host => _host;

  String _remoteAddress = '';

  void findError(){
    int notID = notificationManager!.show(
        thumbnail: const Icon(Icons.error, color: Colors.redAccent),
        title: 'Initialization problem',
        description: '${error!.startsWith('TimeoutException') ? 'The host did not return the information within 10 seconds' : 'Unknown error'}\nError: $error'
    );
    audioController!.player.play(AssetSource('audio/error.wav'));
  }

  String _sd_root = '';

  Map<String, String> _webuiPaths = {};
  @override
  Map<String, String> get webuiPaths => _webuiPaths;

  Map<int, ParseJob> _jobs = {};

  @override
  Future<void> init() async {
    if(prefs!.containsKey('sd_remote_webui_address')){
      _remoteAddress = prefs!.getString('sd_remote_webui_address')!;
      Uri parse = Uri.parse(_remoteAddress);
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
      print(base.toString());
      http.Client().get(base).timeout(const Duration(seconds: 10)).then((res) async {
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
          loaded = true;
        } else {
          if (kDebugMode) {
            print('idi naxyi ${res.statusCode}');
          }
          error = 'The host returned an invalid response: 404';
        }
        notifyListeners();
        if(!loaded) findError();
      }).catchError((e, t) {
        error = e.toString();
        notifyListeners();

        int notID = notificationManager!.show(
            thumbnail: const Icon(Icons.error, color: Colors.redAccent, size: 32),
            title: 'Error on OnRemote',
            description: e.toString()
        );
        audioController!.player.play(AssetSource('audio/error.wav'));

        findError();
      });
    }
  }

  @override
  Future<List<Folder>> getFolders(RenderEngine renderEngine) async {
    // http://gg:7860/infinite_image_browsing/files?folder_path=Z:%2Fstable-diffusion-webui%2Foutputs%2Ftxt2img-images
    List<Folder> list = [];
    Uri parse = Uri.parse(_remoteAddress);
    Uri base = Uri(
        scheme: parse.scheme,
        host: parse.host,
        port: parse.port,
        path: '/infinite_image_browsing/files',
        queryParameters: {
          'folder_path': _webuiPaths[ke[renderEngine]]
        }
    );
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
          folderFiles.add(FolderFile(fullPath: file['fullpath'], isLocal: false, thumbnail: thumb.toString()));
        }
        list.add(Folder(index: i, path: f['fullpath'], name: f['name'], files: folderFiles));
        i++;
      }
    } else {
      print('idi naxyi ${res.statusCode}');
    }

    return list;
  }

  @override
  Future<List<ImageMeta>> getFolderFiles(RenderEngine renderEngine, String sub) async{
    return NavigationService.navigatorKey.currentContext!.read<SQLite>().getImagesByParent(renderEngine == RenderEngine.img2img ? [RenderEngine.img2img, RenderEngine.inpaint] : renderEngine, sub, host: _host);
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
  bool indexAll(RenderEngine re) {
    int notID = notificationManager!.show(
        thumbnail: const Icon(Icons.access_time_filled_outlined, color: Colors.lightBlueAccent, size: 64),
        title: 'Starting indexing',
        description: 'Give us a few seconds...'
    );
    getFolders(re).then((fo) async {
      if(isIndexingAll) return false;
      isIndexingAll = true;
      notificationManager!.update(notID, 'title', 'Indexing ${re.name}');
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
        List<ImageMeta> ima = await getFolderFiles(RenderEngine.values[re.index], f.name);
        StreamController co = await indexFolder(RenderEngine.values[re.index], f.name, hashes: ima.map((e) => e.pathHash).toList(growable: false));
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
  Future<StreamController<List<ImageMeta>>> indexFolder(RenderEngine renderEngine, String sub, {List<String>? hashes}) async {
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
      int jobID = await job.putAndGetJobID(renderEngine, folderFilesRaw, host: _host, remote: parse);

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
  }
}