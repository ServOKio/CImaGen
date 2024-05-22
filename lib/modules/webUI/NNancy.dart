
import 'dart:convert';
import 'dart:io';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart' as cr;

class NNancy {
  static void calculateTransformersCacheHash(String path){
    Directory dir = Directory(path);
    List<String> files = [];
    Map<String, String> hashes = {};
    int done = 0;
    List<FileSystemEntity> aga = dir.listSync(recursive: true, followLinks: true);
    for (var f in aga) {
      if (f is File) {
        files.add(f.path);
      }
    }
    print('finded ${files.length}');
    for (var f in files) {
      final file = File(f);
      final stream = file.openRead();
      var output = AccumulatorSink<cr.Digest>();
      ByteConversionSink input = cr.sha256.startChunkedConversion(output);
      stream.listen((chunk) => input.add(chunk)).onDone(() async {
        input.close();

        hashes[f] = output.events.single.toString();
        done++;

        if(files.length == done){
          File file = File("w:/hash.json");
          if(file.existsSync()){
            var data = jsonDecode(file.readAsStringSync());
            List<String> all = files;
            for(String pa in data.keys){
              if(!all.contains(pa)) all.add(pa);
            }

            for(String finalPath in all){
              if((hashes[finalPath] ?? '') != (data[finalPath]  ?? '')){
                print('error: ${hashes[finalPath] != null ? '$finalPath (${hashes[finalPath]})' : '$finalPath (null)'} != ${data[finalPath] != null ? '$finalPath (${data[finalPath]})' : '$finalPath (null)'}');
              } else {
                print('$finalPath ok');
              }
            }
          } else {
            await file.writeAsString(jsonEncode(hashes));
          }
        }
        // shortHash = sha256.substring(0,10);
        // title = '$name${shortHash != '' ? ' [$shortHash]' : ''}';
        // shortTitle = shortHash != '' ? '$nameForExtra [$shortHash]' : nameForExtra;
        // ids = [hash, modelName, title, name, nameForExtra, '$name [$hash]'];
        // if(shortHash != ''){
        //   ids += [shortHash, sha256, '$name [$shortHash]', '$nameForExtra [$shortHash]'];
        // }
      });
    }
  }
}