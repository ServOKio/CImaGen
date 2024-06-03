import 'dart:io';
import 'dart:ui';

import 'package:cimagen/Utils.dart';
import 'package:crypto/crypto.dart' as cr;
import 'package:convert/convert.dart';
import 'dart:convert';
import 'package:path/path.dart' as p;

class CheckpointInfo{
  String fileName = '';
  String path = '';
  bool isSafetensors = '' == ".safetensors";
  String name = ''; //path.basename('filename');
  var metadata = {};
  Image? modelSpecThumbnail;
  String nameForExtra = '';
  String modelName = '';
  String hash = '';
  String sha256 = '';
  String shortHash = '';
  String title = '';
  String shortTitle = '';
  List<String> ids = [];

  CheckpointInfo({
    required this.path
  });

  Future<void> init() async {
    name = p.basename(path);
    nameForExtra = p.basename(path).split('.')[0];
    modelName = name.replaceAll("/", "_").replaceAll("\\", "_");

    // https://github.com/AUTOMATIC1111/stable-diffusion-webui/blob/bef51aed032c0aaa5cfd80445bc4cf0d85b408b5/modules/hashes.py#L22
    hash = modelHash(path);

    final file = File(path);
    final stream = file.openRead();
    var output = AccumulatorSink<cr.Digest>();
    ByteConversionSink input = cr.sha256.startChunkedConversion(output);
    stream.listen((chunk) => input.add(chunk)).onDone(() {
      input.close();

      sha256 = output.events.single.toString();
      shortHash = sha256.substring(0,10);
      title = '$name${shortHash != '' ? ' [$shortHash]' : ''}';
      shortTitle = shortHash != '' ? '$nameForExtra [$shortHash]' : nameForExtra;
      ids = [hash, modelName, title, name, nameForExtra, '$name [$hash]'];
      if(shortHash != ''){
        ids += [shortHash, sha256, '$name [$shortHash]', '$nameForExtra [$shortHash]'];
      }
    });

    //sha256 = await getSha256(path, 'checkpoint/$name');
  }

  void readMetadata(){
    var metadataTest = readMetadataFromSafetensors(path);
    if(metadataTest != null){
      //modelspec_thumbnail = metadata.pop('modelspec.thumbnail', None)
    }
  }

  String modelHash(String omg){
    // try:
    // with open(filename, "rb") as file:
    // import hashlib
    // m = hashlib.sha256()
    //
    // file.seek(0x100000)
    // m.update(file.read(0x10000))
    // return m.hexdigest()[0:8]
    // except FileNotFoundError:
    // return 'NOFILE'
    return "";
  }

  // Future<String> getSha256(String path, String title, {bool use_addnet_hash = false}){
  //   //var hashes =  use_addnet_hash ? cache("hashes-addnet") : cache("hashes");
  //   return calculateSha256(path);
  // }

  // Future<String> calculateSha256(String path) async {
  //   final fileBytes = await compute(readAsBytesSync, path);
  //   return cr.sha256.convert(utf8.encode(fileBytes.toString())).toString();
  // }
  // hashes = cache("hashes-addnet") if use_addnet_hash else cache("hashes")
  // try:
  // ondisk_mtime = os.path.getmtime(filename)
  // except FileNotFoundError:
  // return None
  //
  // if title not in hashes:
  // return None
  //
  // cached_sha256 = hashes[title].get("sha256", None)
  // cached_mtime = hashes[title].get("mtime", 0)
  //
  // if ondisk_mtime > cached_mtime or cached_sha256 is None:
  // return None
  //
  // return cached_sha256
}