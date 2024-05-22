import 'dart:io';

import 'package:cimagen/utils/ImageManager.dart';
import 'package:path/path.dart' as p;

abstract class AbMain {
  bool loaded = false;

  Map<String, String> _webuiPaths = {};
  Map<String, String> get webuiPaths => _webuiPaths;

  void init() async {
    print("Not Implemented");
  }

  Future<List<Folder>> getFolders(RenderEngine renderEngine) async{
    return [];
  }

  Future<List<dynamic>> getFolderFiles(RenderEngine renderEngine, String sub) async{
    return [];
  }

  Future<int> indexFolder(RenderEngine renderEngine, String sub) async{
    // Read all files sizes and get hash

    // Return job id
    return -1;
  }

  void exit() async {
    print("Not Implemented");
  }
}

class Folder {
  final int index;
  final String path;
  final String name;
  final List<dynamic> files;
  bool? isLocal = true;

  Folder({
    required this.index,
    required this.path,
    required this.name,
    required this.files,
    this.isLocal
  });
}

class FolderFile {
  String keyup = '';
  bool isLocal = true;
  String? host;
  String fileName = '';
  final String fullPath;
  String? thumbnail;

  FolderFile({
    required this.fullPath,
    required this.isLocal,
    this.thumbnail,
    this.host
  }){
    fileName = p.basename(fullPath);
    final String parentFolder = p.basename(File(fullPath).parent.path);
    keyup = genHash(RenderEngine.unknown, parentFolder, fileName, host: host);
  }
}