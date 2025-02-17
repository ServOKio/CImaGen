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
import '../DataManager.dart';
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

  String? _host;
  @override
  String? get host => _host;

  String _remoteAddress = '';
  String _userAgent = 'CImaGen/Undefined.version';

  // Config
  Map<String, dynamic> _config = <String, dynamic>{};
  Map<String, dynamic> get config => _config;

  // WebUI
  String _webui_root = '';
  String _webui_outputs_folder = '';

  List<String> _tabs = [];
  @override
  List<String> get tabs => _tabs;
  List<RenderEngine> _internalTabs = [];

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
  Map<int, ParseJob> get getJobs => _jobs;
  int getJobCountActive() {
    _jobs.removeWhere((key, value) => value.controller.isClosed);
    return _jobs.length;
  }

  List<StreamSubscription<FileSystemEvent>> watchList = [];

  List<RenderEngine> useAddon = [];
  List<RenderEngine> inSMB = [];

  @override
  Future<void> init() async {
    bool _has_connection = false;
    bool _has_200_code = false;
    bool _has_infinite_image_browsing_extension = false;

    for (var e in watchList) {
      e.cancel();
    }
    _tabs.clear();
    _internalTabs.clear();
    _webuiPaths.clear();
    useAddon.clear();
    inSMB.clear();


    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    _userAgent = "CImaGen/${packageInfo.version} (platform; ${Platform.isAndroid ? 'android' : Platform.isWindows ? 'windows' : Platform.isIOS ? 'IOS' : Platform.isLinux ? 'linux' : Platform.isFuchsia ? 'fuchsia' : Platform.isMacOS ? 'MacOs' : 'Unknown'})";
    // 0. Initial check
    if(!(prefs.containsKey('remote_webui_address') || prefs.containsKey('remote_webui_folder'))){
      int notID = 0;
      notID = notificationManager!.show(
          thumbnail: const Icon(Icons.error, color: Colors.redAccent),
          title: 'Initialization problem',
          description: 'You have not specified either the panel address or the remote folder - specify them in the settings and try again',
          content: Padding(padding: EdgeInsets.only(top: 7), child: ElevatedButton(
              style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                  shape: WidgetStateProperty.all<RoundedRectangleBorder>(const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))))
              ),
              onPressed: (){
                notificationManager!.close(notID);
                init();
              },
              child: const Text('Try again', style: TextStyle(fontSize: 12))
          ))
      );
      audioController!.player.play(AssetSource('audio/error.wav'));
      return;
    }

    // 1. We need to know the system we are working with
    if(prefs.containsKey('remote_webui_folder')){
      String remoteWebuiFolder = prefs.getString('remote_webui_folder')!;
      bool swarnPS = File('$remoteWebuiFolder/SwarmUI.sln').existsSync();
      bool sdWebUIConfig = File('$remoteWebuiFolder/config.json').existsSync();
      if(swarnPS){
        // Output / local /
        int notID = notificationManager!.show(
            thumbnail: const Icon(Icons.forest_outlined, color: Colors.yellow),
            title: 'SwarmUI is not supported locally at this time',
            description: 'In the future we will add support for it as soon as we understand how it differs from the swan'
        );
        audioController!.player.play(AssetSource('audio/wrong.wav'));
        Future.delayed(const Duration(milliseconds: 10000), () => notificationManager!.close(notID));
      } else if(sdWebUIConfig){
        // HAhhDbawey8dQ3EDI7vw673vf6 (died)
        String sdWebuiFolder = prefs.getString('remote_webui_folder') ?? '';
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

        software = Software.stableDiffusionWebUI;
        _tabs = ['txt2img', 'img2img'];
        _internalTabs = [RenderEngine.txt2img, RenderEngine.img2img];
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
            int notID = 0;
            notID = notificationManager!.show(
                thumbnail: const Icon(Icons.network_ping, color: Colors.redAccent, size: 32),
                title: 'Some access points require remote access',
                description: '${useAddon.map((e) => renderEngineToString(e)).join(', ')} should be processed over the internet, not locally, but "outputs folder" is not configured',
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
            audioController!.player.play(AssetSource('audio/error.wav'));
          }
        } else {
          int notID = notificationManager!.show(
              thumbnail: const Icon(Icons.auto_awesome, color: Colors.blue),
              title: 'Welcome to remote Stable Diffusion',
              description: 'It seems that all folders work stably, the application will work through a remote folder at maximum speed\n${_webuiPaths.keys.map((key) => _webuiPaths[key]).join('\n')}'
          );
          audioController!.player.play(AssetSource('audio/info.wav'));
          Future.delayed(const Duration(milliseconds: 10000), () => notificationManager!.close(notID));
        }

        if(_webuiPaths['outdir_txt2img-images'] != null) watchDir(RenderEngine.txt2img, _webuiPaths['outdir_txt2img-images']!);
        if(_webuiPaths['outdir_img2img-images'] != null) watchDir(RenderEngine.img2img, _webuiPaths['outdir_img2img-images']!);
      }
    } else {
      if(!prefs.containsKey('remote_webui_address')){
        int notID = 0;
        notID = notificationManager!.show(
            thumbnail: const Icon(Icons.error, color: Colors.redAccent),
            title: 'Initialization problem',
            description: 'The remote address of the panel is not specified. Specify it in the settings in the remote connection section\bDev: remote_webui_address key',
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
        audioController!.player.play(AssetSource('audio/error.wav'));
        return;
      }
      _remoteAddress = prefs.getString('remote_webui_address')!;
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
            int notID = 0;
            notID = notificationManager!.show(
                thumbnail: const Icon(Icons.warning, color: Colors.redAccent),
                title: 'One of the Dependencies is missing',
                description: 'sd-webui-infinite-image-browsing addon not found',
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
              _internalTabs = [RenderEngine.txt2img, RenderEngine.img2img];
              loaded = true;
              int notID = notificationManager!.show(
                  thumbnail: const Icon(Icons.account_tree_outlined, color: Colors.blue),
                  title: 'Welcome to remote Stable Diffusion',
                  description: 'Connected to $_remoteAddress'
              );
              audioController!.player.play(AssetSource('audio/info.wav'));
              Future.delayed(const Duration(milliseconds: 10000), () {
                notificationManager!.close(notID);
              });
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

            int notID = 0;
            notID = notificationManager!.show(
                thumbnail: const Icon(Icons.error, color: Colors.redAccent, size: 32),
                title: 'Error on OnRemote.dart',
                description: e.toString(),
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
                    countRunning: data['count_running'] ?? 0,
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
              Future.delayed(const Duration(milliseconds: 10000), () => notificationManager!.close(notID));
            } else {
              // TODO
              // Not swarm, comfui ?
              int notID = 0;
              notID = notificationManager!.show(
                  thumbnail: const Icon(Icons.error, color: Colors.redAccent, size: 32),
                  title: 'Initialization problem',
                  description: 'Error: Code is not 200: ${res.statusCode}\n${res.body}',
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
              audioController!.player.play(AssetSource('audio/error.wav'));
            }
            notifyListeners();
            if(!loaded) findError();
          }).catchError((e, stack){
            int notID = 0;
            notID = notificationManager!.show(
                thumbnail: const Icon(Icons.error, color: Colors.redAccent, size: 32),
                title: 'SwarmUI initialization problem',
                description: 'Error: $e\n$stack',
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
            audioController!.player.play(AssetSource('audio/error.wav'));
          });
        }
      }).catchError((e){
        int notID = 0;
        notID = notificationManager!.show(
            thumbnail: const Icon(Icons.error, color: Colors.redAccent, size: 32),
            title: 'Initialization problem',
            description: 'Error: $e',
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
        audioController!.player.play(AssetSource('audio/error.wav'));
      });
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
      if (event is FileSystemCreateEvent && !event.isDirectory) {
        Future.delayed(const Duration(seconds: 7), () =>  objectbox.updateIfNado(event.path, host: _host));
      }
    }));
  }

  @override
  Future<List<Folder>> getFolders(int index) async {
    return objectbox.getFolders(host: _host);
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
    // http://gg:7860/infinite_image_browsing/files?folder_path=Z:%2Fstable-diffusion-webui%2Foutputs%2Ftxt2img-images
    List<Folder> list = [];
    Uri parse = Uri.parse(_remoteAddress);

    if(software == Software.stableDiffusionWebUI) {
      if(useAddon.contains(_internalTabs[index])){
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
            list.add(
                Folder(
                  index: i,
                  getter: f['fullpath'],
                  type: FolderType.path,
                  name: f['name'],
                  files: folderFiles,
                  isLocal: false
                ));
            i++;
          }
        } else {
          print('idi naxyi ${res.statusCode}');
        }
      } else {
        // Local files (SMB!)
        List<Folder> f = [];
        int ind = 0;
        Directory di = Directory(_webuiPaths[ke[_internalTabs[index]]!]!);
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
              )).toList(),
          ));
          ind++;
        }
        return f;
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
              folderFiles.add(FolderFile(fullPath: full.toString(), isLocal: false, networkThumbnail: thumb.toString()));
            }
            list.add(Folder(
                index: i,
                getter: folderPath,
                type: FolderType.path,
                name: folderPath,
                files: folderFiles,
                isLocal: false
            ));
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
    return objectbox.getImagesByDay(day, host: host);
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

  @override
  void exit() {
    for (var element in watchList) {
      element.cancel();
    }
    for(int id in _jobs.keys){
      _jobs[id]!.forceStop();
    }
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
      for(Folder f in fo){
        try{
          // То что уже есть, чтобы не трогать
          List<String> ima = await getFolderHashes(normalizePath(f.getter), host: null);
          StreamController co = await indexFolder(f, hashes: ima);
          print('jobs co $getJobCountActive()');
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
    return objectbox.getFolderHashes(folder, host: _host);
  }

  @override
  Future<StreamController<List<ImageMeta>>> indexFolder(Folder folder, {List<String>? hashes}) async {
    Uri parse = Uri.parse(_remoteAddress);
    if (kDebugMode) {
      print('indexFolder: ${folder.getter} ${hashes?.length}');
    }
    if(software == Software.stableDiffusionWebUI) {
      if(folder.isLocal){
        // local
        Directory di = Directory(normalizePath(folder.getter));
        List<FileSystemEntity> fe = await dirContents(di); // Filter this shit
        //print('total: ${fe.length}');

        if(hashes != null && hashes.isNotEmpty){
          print(hashes.first);
          for(FileSystemEntity te in fe){
            print(te.path);
            print(normalizePath(p.normalize(te.path)));
            print(genPathHash(normalizePath(p.normalize(te.path))));
          }
          fe = fe.where((e) => !hashes.contains(genPathHash(normalizePath(e.path)))).toList(growable: false);
          fe = fe.where((e) => !hashes.contains(genPathHash(normalizePath(e.path)))).toList(growable: false);
          if (kDebugMode) {
            print('onLocal:indexFolder: to send: ${fe.length}');
          }
        }

        if(fe.isNotEmpty){
          if(inProcess.contains(di.path)){
            fe = [];
          } else {
            inProcess.add(di.path);
          }
        }

        ParseJob job = ParseJob();
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
      } else {
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
          }).toList(), host: _host);

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
          folderFilesPaths = folderFilesPaths.where((path) => !hashes.contains(genPathHash(normalizePath(path)))).toList(growable: false);
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
}

// await fetch("http://foxwebui.ddns.net:7860/API/DeleteImage", {
// "credentials": "include",
// "headers": {
// "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:136.0) Gecko/20100101 Firefox/136.0",
// "Accept": "*/*",
// "Accept-Language": "en,en-US;q=0.5",
// "Content-Type": "application/json",
// "Sec-GPC": "1",
// "Priority": "u=0"
// },
// "referrer": "http://foxwebui.ddns.net:7860/Text2Image",
// "body": "{\"path\":\"raw/2024-12-30/0951-905300696.png\",\"session_id\":\"F0ED6196F00B3C5A9E3E6909194CDD561D187AEC\"}",
// "method": "POST",
// "mode": "cors"
// });