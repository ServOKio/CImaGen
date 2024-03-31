
import 'package:cimagen/modules/CheckpointInfo.dart';

class SDModels {

  String modelDir = "Stable-diffusion";
  Map<String, CheckpointInfo> checkpointsList = {};
  Map<String, CheckpointInfo> checkpointAliases = {};

  // TODO: recheck this shit
  Map<String, CheckpointInfo> replaceKey(Map<String, CheckpointInfo> d, String key, String newKey, CheckpointInfo value){
    var keys = d.keys.toList();

    d[newKey] = value;

    if(!keys.contains(key)) return d;

    int index = keys.indexOf(key);
    keys[index] = newKey;

    Map<String, CheckpointInfo> newD = {};
    for(String k in keys){
      newD[k] = d[k]!;
    }

    d.clear();

    // d.update(newD); wtf
    return newD;
  }
}