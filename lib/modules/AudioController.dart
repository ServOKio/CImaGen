import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

class AudioController {
  AudioController();

  final Map<NtSound, AudioSource> _sounds = {};
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await SoLoud.instance.init();
    for(NtSound v in NtSound.values){
      try{
        _sounds[v] = await SoLoud.instance.loadAsset('assets/audio/${v.name}.wav', mode: kIsWeb ? LoadMode.disk : LoadMode.memory);
      } on FlutterError catch(e) {
        debugPrint('${v.name}\n$e');
      }
    }
    _initialized = true;
  }

  Future<void> play(NtSound sound) async {
    if (_sounds[sound] == null) return;
    await SoLoud.instance.play(_sounds[sound]!);
  }

  Future<void> dispose() async {
    for(NtSound s in _sounds.keys){
      await SoLoud.instance.disposeSource(_sounds[s]!);
    }
    SoLoud.instance.deinit();
    _initialized = false;
  }
}

enum NtSound{
  error,
  info,
  okay,
  open,
  sended,
  wrong,

  prowler,
  roblox_death,
  roblox_doors_eyes,
  you_are_an_idiot
}