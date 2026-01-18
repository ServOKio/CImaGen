import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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

  List<String> _tabs = [];
  List<String> get tabs => _tabs;

  Map<int, ParseJob> _jobs = {};
  Map<int, ParseJob> get getJobs => _jobs;

  void init() async {
    print("Not Implemented");
  }

  Future<List<Folder>> getFolders(int index) async{
    return [];
  }

  Future<List<Folder>> getAllFolders(int index) async{
    return [];
  }

  Future<void> fixLorasMetadata();

  // Тут мы ебашим id вкладки и index селектора потому-что ну а хуй пойми из какой системы запрос, пусть сам разбирается
  // Миша всё хуйня давай по новой
  Future<List<ImageMeta>> getFolderFiles(int section, String day) async {
    return [];
  }


  String getFullUrlImage(ImageMeta im) => '';
  String getThumbnailUrlImage(ImageMeta im) => '';

  bool indexAll(int index){
    return false;
  }

  Future<StreamController<List<ImageMeta>>> indexFolder(Folder folder, {List<String>? hashes, RenderEngine? re}) async{
    // Read all files sizes and get hash
    late final StreamController<List<ImageMeta>> controller;
    controller = StreamController<List<ImageMeta>>(
      onListen: () async {
        await controller.close();
      },
    );

    // Return job id
    return controller;
  }

  void exit() async {
    print("Not Implemented");
  }

  Future getFoldersPaged(int tabIndex, {required int offset, required int limit}) async {
  }
}

enum FolderType {
  path,
  byDay
}
class Folder {
  final int index;
  final FolderType type;
  final String getter;
  String name;
  final List<FolderFile> files;
  bool isLocal;

  Folder({
    required this.index,
    required this.type,
    required this.getter,
    required this.name,
    required this.files,
    this.isLocal = true
  });
}

class FolderFile {
  String keyup = '';
  bool isLocal = true;
  String? host;
  String fileName = '';
  final String fullPath;
  Uint8List? thumbnail;
  String? networkThumbnail;

  FolderFile({
    required this.fullPath,
    required this.isLocal,
    this.thumbnail,
    this.networkThumbnail,
    this.host
  }){
    fileName = p.basename(fullPath);
    final String parentFolder = p.basename(File(fullPath).parent.path);
    keyup = genHash(RenderEngine.unknown, parentFolder, fileName, host: host);
  }
}