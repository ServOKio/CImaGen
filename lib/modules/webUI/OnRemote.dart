import 'dart:async';
import 'dart:convert';

import 'package:cimagen/main.dart';
import 'package:cimagen/modules/webUI/AbMain.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

// Required "Infinite image browsing" addon
class OnRemote implements AbMain{
  @override
  bool loaded = false;

  void findError(){

  }

  String _sd_root = '';

  Map<String, String> _webuiPaths = {};
  @override
  Map<String, String> get webuiPaths => _webuiPaths;

  @override
  Future<void> init() async {
    if(prefs!.containsKey('sd_remote_webui_address')){
      Uri parse = Uri.parse(prefs!.getString('sd_remote_webui_address') ?? '');
      Uri base = Uri(
          scheme: parse.scheme,
          host: parse.host,
          port: parse.port,
          path: '/infinite_image_browsing/global_setting',
      );
      http.Response res = await http.Client().get(base);
      if(res.statusCode == 200){
        var data = await json.decode(res.body);
        _sd_root = data['sd_cwd'];

        _webuiPaths.addAll({
          'outdir_extras-images': p.normalize(p.join(_sd_root, data['global_setting']['outdir_extras_samples'])),
          'outdir_img2img-grids': p.normalize(p.join(_sd_root, data['global_setting']['outdir_img2img_grids'])),
          'outdir_img2img-images': p.normalize(p.join(_sd_root, data['global_setting']['outdir_img2img_samples'])),
          'outdir_txt2img-grids': p.normalize(p.join(_sd_root, data['global_setting']['outdir_txt2img_grids'])),
          'outdir_txt2img-images': p.normalize(p.join(_sd_root, data['global_setting']['outdir_txt2img_samples'])),
          'outdir_save': p.normalize(p.join(_sd_root, data['global_setting']['outdir_save'])),
          'outdir_init': p.normalize(p.join(_sd_root, data['global_setting']['outdir_init_images']))
        });
        loaded = true;
      } else {
        print('idi naxyi ${res.statusCode}');
      }
    }
    if(!loaded) findError();
  }

  @override
  Future<List<Folder>> getFolders(RenderEngine renderEngine) async {
    // http://gg:7860/infinite_image_browsing/files?folder_path=Z:%2Fstable-diffusion-webui%2Foutputs%2Ftxt2img-images
    List<Folder> list = [];
    Uri parse = Uri.parse(prefs!.getString('sd_remote_webui_address') ?? '');
    Uri base = Uri(
        scheme: parse.scheme,
        host: parse.host,
        port: parse.port,
        path: '/infinite_image_browsing/files',
        queryParameters: {'folder_path': _webuiPaths[ke[renderEngine]]}
    );
    var res = await http.Client().get(base).timeout(const Duration(seconds: 5));
    if(res.statusCode == 200){
      List<dynamic> files = await json.decode(res.body)['files'];
      print(files.length);
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
    List<ImageMeta> list = [];
    Uri parse = Uri.parse(prefs!.getString('sd_remote_webui_address') ?? '');
    Uri base = Uri(
        scheme: parse.scheme,
        host: parse.host,
        port: parse.port,
        path: '/infinite_image_browsing/files',
        queryParameters: {'folder_path': p.join(_webuiPaths[ke[renderEngine]]!, sub)}
    );
    var res = await http.Client().get(base);
    if(res.statusCode == 200){
      var folderFilesRaw = await json.decode(res.body)['files'].where((e) => ['.png', 'jpg', '.jpeg', '.gif', '.webp'].contains(p.extension(e['name']))).toList();
      for (var i = 0; i < folderFilesRaw.length; i++) {
        var f = folderFilesRaw[i];
        Uri thumb = Uri(
            scheme: parse.scheme,
            host: parse.host,
            port: parse.port,
            path: '/infinite_image_browsing/image-thumbnail',
            queryParameters: {
              'path': f['fullpath'],
              'size': '512x512',
              't': f['date']
            }
        );
        Uri full = Uri(
            scheme: parse.scheme,
            host: parse.host,
            port: parse.port,
            path: '/infinite_image_browsing/file',
            queryParameters: {
              'path': f['fullpath'],
              't': f['date']
            }
        );

        final String e = p.extension(f['fullpath']);

        ImageMeta im = ImageMeta(
            host: Uri(
                host: parse.host,
                port: parse.port
            ).toString(),
            re: RenderEngine.unknown,
            fileTypeExtension: e.replaceFirst('.', ''),
            fileSize: f['bytes'],
            dateModified: DateTime.parse(f['date']),
            fullPath: f['fullpath'],
            fullNetworkPath: full.toString(),
            networkThumbnail: thumb.toString()
        );

        await im.parseNetworkImage();
        list.add(im);
      }
    } else {
      print('idi naxyi ${res.statusCode}');
    }
    return list;
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
  Future<Stream<List<ImageMeta>>> indexFolder(RenderEngine renderEngine, String sub) {
    // TODO: implement indexFolder
    throw UnimplementedError();
  }
}