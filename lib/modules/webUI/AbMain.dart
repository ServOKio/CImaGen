import 'dart:async';
import 'dart:io';

import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

abstract class AbMain extends ChangeNotifier{
  bool loaded = false;
  String? error;
  bool get hasError => error != null;

  String? _host;
  String? get host => _host;

  Map<String, String> _webuiPaths = {};
  Map<String, String> get webuiPaths => _webuiPaths;

  void init() async {
    print("Not Implemented");
  }

  Future<List<Folder>> getFolders(RenderEngine renderEngine) async{
    return [];
  }

  Future<List<ImageMeta>> getFolderFiles(RenderEngine renderEngine, String sub) async{
    return [];
  }

  Future<Stream<List<ImageMeta>>> indexFolder(RenderEngine renderEngine, String sub, {List<String>? hashes}) async{
    // Read all files sizes and get hash
    late final StreamController<List<ImageMeta>> controller;
    controller = StreamController<List<ImageMeta>>(
      onListen: () async {
        await controller.close();
      },
    );

    // Return job id
    return controller.stream;
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