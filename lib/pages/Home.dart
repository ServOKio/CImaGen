import 'dart:io';

import 'package:cimagen/utils/ImageManager.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../Utils.dart';
import '../modules/CheckpointInfo.dart';

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool _dragging = false;

  Future<void> readDraged(List<XFile> files) async {
    XFile f = files.first;
    if(isImage(f)){
      parseImage(RenderEngine.unknown, f.path).then((value){
        value?.toMap().then((value){
          print(value);
        });
        if(value?.generationParams != null) print(value!.generationParams?.toMap());
      });
    } else {
      final String e = p.extension(f.path);
      if(e == '.safetensors'){
        RandomAccessFile file = await File(f.path).open(mode: FileMode.read);
        var metadataLen = file.read(8);
        if (kDebugMode) print(metadataLen);

        // int metadata_len = file.elementAt(8);
        // metadata_len = int.from_bytes(metadata_len, "little")
        // int json_start = file.read(2)
        //
        // assert metadata_len > 2 and json_start in (b'{"', b"{'"), f"{filename} is not a safetensors file"
        // json_data = json_start + file.read(metadata_len-2)
        // json_obj = json.loads(json_data)
        //
        // res = {}
        // for k, v in json_obj.get("__metadata__", {}).items():
        //   res[k] = v
        //   if isinstance(v, str) and v[0:1] == '{':
        //     try:
        //       res[k] = json.loads(v2
        //       except Exception:
        //       pass
        //
        // return res
      }
    }
  }

  Future<void> test() async {
    var prefs = await SharedPreferences.getInstance();

    String data_path = (prefs.getString('sd_webui_folter') ?? 'none');

    String models_path = p.join(data_path, "models");
    String extensions_dir = p.join(data_path, "extensions");
    String default_output_dir = p.join(data_path, "output");

    Directory dir = Directory(p.join(models_path, 'Stable-diffusion'));
    final List<FileSystemEntity> entities = await dir.list().toList();
    CheckpointInfo ci = CheckpointInfo(path: entities[0].path);
    ci.init();
  }

  @override
  void initState() {
    super.initState();
    //test();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          color: Theme.of(context).colorScheme.background,
          width: 350,
          child: Column(
            children: [
              const Spacer(),
              Container(
                height: 1,
                color: const Color(0xFF2d2f32),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: DropTarget(
                  onDragDone: (detail) {
                    readDraged(detail.files);
                  },
                  onDragEntered: (detail) {
                    setState(() {
                      _dragging = true;
                    });
                  },
                  onDragExited: (detail) {
                    setState(() {
                      _dragging = false;
                    });
                  },
                  child: DottedBorder(
                    dashPattern: const [6, 6],
                    color: const Color(0xFF2d2f32),
                    borderType: BorderType.RRect,
                    strokeWidth: 2,
                    radius: const Radius.circular(12),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          color: _dragging ? Colors.blue.withOpacity(0.4) : Theme.of(context).scaffoldBackgroundColor,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.file_open_outlined, color: Color(0xFF0068ff), size: 36),
                                Gap(6),
                                Text('Drag-n-Drop to unload', style: TextStyle(fontWeight: FontWeight.w500)),
                                Text('or'),
                                Text('Enter URL', style: TextStyle(fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ),
                      )
                    ),
                  ),
                )
              )
            ],
          )
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsetsDirectional.symmetric(horizontal: 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Text('categories'.toUpperCase()),
                    const Gap(12),
                    Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          color: Colors.red,
                        ),
                        Gap(4),
                        Text('Main'.toUpperCase())
                      ],
                    )
                  ],
                ),
                const Gap(8),
                Row(
                  children: [
                    Text('Categories', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.grid_view_rounded, color: Theme.of(context).primaryColor),
                        Gap(14),
                        Icon(Icons.view_list_rounded, color: Colors.grey),
                        Gap(21),
                        ElevatedButton(
                            style: ButtonStyle(
                                foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
                                backgroundColor: MaterialStateProperty.all<Color>(Theme.of(context).primaryColor),
                                shape: MaterialStateProperty.all<RoundedRectangleBorder>(const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))))
                            ),
                            onPressed: () async {
                              await showDialog<void>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  content: Form(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        TextFormField(
                                          decoration: const InputDecoration(
                                            icon: Icon(Icons.yard),
                                            hintText: 'Briefly, but clearly',
                                            labelText: 'Title *',
                                          ),
                                        ),
                                        TextFormField(
                                          decoration: const InputDecoration(
                                            icon: Icon(Icons.textsms),
                                            hintText: 'Description of what\'s here',
                                            labelText: 'Description',
                                          ),
                                        ),
                                        Gap(12),
                                        ElevatedButton(
                                          child: const Text('Create'),
                                          onPressed: () {

                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              );
                            },
                            child: const Text(
                                "Create new",
                                style: TextStyle(fontSize: 14)
                            )
                        )
                      ],
                    )
                  ],
                )
              ],
            ),
          )
        )
      ]
    );
  }
}