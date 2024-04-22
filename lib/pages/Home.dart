import 'dart:convert';
import 'dart:io';

import 'package:cimagen/pages/sub/ImageView.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:cimagen/utils/SaveManager.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Utils.dart';
import '../components/CustomMasonryView.dart';
import '../modules/CheckpointInfo.dart';
import '../utils/SQLite.dart';

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool _dragging = false;

  List<dynamic> _readHistory = [];
  int c = 1;

  Future<void> readDraged(List<XFile> files) async {
    XFile f = files.first;
    if(isImage(f)){
      parseImage(RenderEngine.unknown, f.path).then((value){
        _readHistory.add(value);
        setState(() {
          c = c+1;
        });
        // value?.toMap().then((value){
        //   print(value);
        // });
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
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  separatorBuilder: (BuildContext context, int index) => const Divider(height: 14),
                  itemCount: _readHistory.length,
                  itemBuilder: (BuildContext context, int index) {
                    var element = _readHistory[index];
                    return FileInfoPreview(type: element.runtimeType == ImageMeta ? 1 : 0, data: element);
                  },
                ),
              ),
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
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
            child: Column(
              children: [
                const Gap(12),
                Row(
                  children: [
                    Text('categories'.toUpperCase()),
                    const Gap(6),
                    const Text('/', style: TextStyle(color: Colors.grey)),
                    const Gap(6),
                    Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(7)),
                            color: Colors.red,
                          ),
                        ),
                        const Gap(4),
                        Text('all'.toUpperCase())
                      ],
                    )
                  ],
                ),
                const Gap(8),
                Row(
                  children: [
                    const Text('Categories', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.grid_view_rounded, color: Theme.of(context).primaryColor),
                        const Gap(14),
                        const Icon(Icons.view_list_rounded, color: Colors.grey),
                        const Gap(21),
                        ElevatedButton(
                            style: ButtonStyle(
                                foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
                                backgroundColor: MaterialStateProperty.all<Color>(Theme.of(context).primaryColor),
                                shape: MaterialStateProperty.all<RoundedRectangleBorder>(const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))))
                            ),
                            onPressed: () async {
                              // notificationManager?.show(title: 'Hello');
                              // return;
                              TextEditingController _title = TextEditingController();
                              TextEditingController _description = TextEditingController();

                              final _formKey = GlobalKey<FormState>();
                              await showDialog<void>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  content: Form(
                                    key: _formKey,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        TextFormField(
                                          controller: _title,
                                          validator: (text) {
                                            if (text == null || text.isEmpty || text.trim().isEmpty) {
                                              return 'Text is empty';
                                            } else if (text.length > 256) {
                                              return 'Max: 256 symbols';
                                            }
                                            return null;
                                          },
                                          decoration: const InputDecoration(
                                            icon: Icon(Icons.yard),
                                            hintText: 'Briefly, but clearly',
                                            labelText: 'Title *',
                                          ),
                                        ),
                                        TextFormField(
                                          controller: _description,
                                          decoration: const InputDecoration(
                                            icon: Icon(Icons.textsms),
                                            hintText: 'Description of what\'s here',
                                            labelText: 'Description',
                                          ),
                                        ),
                                        const Gap(12),
                                        ElevatedButton(
                                          child: const Text('Create'),
                                          onPressed: () {
                                            if (_formKey.currentState!.validate()) {
                                              context.read<SQLite>().createCategory(
                                                title: _title.text.trim(),
                                                description: _description.text.trim()
                                              ).then((category){
                                                context.read<SaveManager>().addCategory(category);
                                                Navigator.pop(context, 'Ok');
                                              });
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              );
                            },
                            child: const Text("Create new", style: TextStyle(fontSize: 14))
                        )
                      ],
                    )
                  ],
                ),
                const Gap(8),
                FutureBuilder(
                    future: context.read<SQLite>().getCategories(),
                    builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
                      Widget children;
                      if (snapshot.hasData) {
                        children = snapshot.data.length == 0 ? const CircularProgressIndicator() : SingleChildScrollView(
                          child: CustomMasonryView(
                            itemRadius: 14,
                            itemPadding: 4,
                            listOfItem: snapshot.data,
                            numberOfColumn: (MediaQuery.of(context).size.width / 500).round(),
                            itemBuilder: (ii) {
                              return AspectRatio(aspectRatio: 16/9, child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFF2d2f32),
                                    width: 2,
                                  ),
                                  gradient: RadialGradient(
                                    colors: [ii.item.color, Colors.black],
                                    stops: const [0, 1],
                                    center: Alignment.topCenter,
                                    focalRadius: 2,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black, spreadRadius: 3),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Stack(
                                        alignment: Alignment.bottomRight,
                                        children: [
                                          Icon(ii.item.icon, color: ii.item.color, size: 205),
                                          Icon(ii.item.icon, color: Colors.black, size: 200),
                                        ],
                                      ),
                                    ),
                                    Positioned(
                                      left: 0,
                                      top: 0,
                                      bottom: 0,
                                      child: Padding(
                                        padding: const EdgeInsets.all(21),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.start,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(4),
                                                color: ii.item.color.withOpacity(0.3),
                                                boxShadow: const [
                                                  BoxShadow(color: Colors.black, spreadRadius: 3),
                                                ],
                                              ),
                                              padding: const EdgeInsets.all(4),
                                              child: Center(
                                                child: Icon(ii.item.icon, color: ii.item.color, size: 21),
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(ii.item.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 21)),
                                            ii.item.description != null ? Text(ii.item.description, style: const TextStyle(color: Colors.grey, fontSize: 14)) : SizedBox.shrink(),
                                            const Spacer(),
                                            Row(
                                              children: [
                                                TextButton(
                                                  onPressed: () {},
                                                  child: const Text('Fast preview'),
                                                ),
                                              ],
                                            )
                                          ],
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ));
                            },
                          ),
                        );
                      } else if (snapshot.hasError) {
                        children = const Text('error');
                      } else {
                        children = const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: Text('Awaiting result...'),
                        );
                      }
                      return children;
                    }
                )
              ],
            ),
          )
        )
      ]
    );
  }
}

class FileInfoPreview extends StatelessWidget{
  int type = -1;
  dynamic data;

  FileInfoPreview({
    super.key,
    required this.type,
    required this.data
  });

  @override
  Widget build(BuildContext context) {
    ImageMeta? im = type == 1 ? data as ImageMeta : null;
    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
//      height: constraints.maxHeight,
//      width: constraints.maxWidth
        return Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Theme.of(context).scaffoldBackgroundColor
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  type == 1 ?
                  ClipRRect(
                    borderRadius: BorderRadius.circular(7.0),
                    child: Stack(
                      children: [
                        Image.memory(gaplessPlayback: true, base64Decode(im?.thumbnail ?? ''), width: constraints.maxWidth / 2),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Padding(
                            padding: EdgeInsets.all(4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.only(left: 2, right: 2, bottom: 1),
                                  decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.all(Radius.circular(2)),
                                      color: Colors.black.withOpacity(0.7)
                                  ),
                                  child: Text(im!.fileTypeExtension, style: TextStyle(color: Colors.white, fontSize: 10)),
                                ),
                                im.specific?['profileName'] != null ? const Gap(4) : const SizedBox.shrink(),
                                im.specific?['profileName'] != null ? Container(
                                  padding: const EdgeInsets.only(left: 2, right: 2, bottom: 1),
                                  decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.all(Radius.circular(2)),
                                      color: Colors.black.withOpacity(0.7)
                                  ),
                                  child: const Text('HDR', style: TextStyle(color: Colors.white, fontSize: 10)),
                                ) : const SizedBox.shrink()
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                  ) : const Icon(Icons.file_open),
                  const Gap(4),
                  SizedBox(
                    width: constraints.maxWidth / 2 - 4 - 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(im!.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size.zero, // Set this
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                            ),
                            onPressed: () async {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => ImageView(imageMeta: im)));
                            },
                            child: const Text("View data", style: TextStyle(fontSize: 12))
                        )
                      ],
                    ),
                  )
                ],
              )
            ],
          ),
        );
      }
    );
  }
}