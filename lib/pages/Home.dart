import 'dart:convert';
import 'dart:io';

import 'package:cimagen/components/CharacterCard.dart';
import 'package:cimagen/components/XYZBuilder.dart';
import 'package:cimagen/pages/sub/ImageView.dart';
import 'package:cimagen/pages/sub/MiniWorld.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:cimagen/modules/SaveManager.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:gap/gap.dart';

import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../Utils.dart';
import '../components/CustomMasonryView.dart';
import '../components/ImageInfo.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import '../modules/Animations.dart';
import '../modules/CheckpointInfo.dart';
import '../modules/ICCProfiles.dart';
import '../modules/SaveManager.dart' as sm;
import '../utils/DataModel.dart';
import '../utils/SQLite.dart';
import '../utils/ThemeManager.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

final Map<int, dynamic> _readHistory = {};
class HistoryObject {
  final int id;
  final dynamic content;

  const HistoryObject({
    required this.id,
    required this.content
  });
}

class _HomeState extends State<Home> {
  double breakpoint = 600.0;
  int c = 1;

  final ScrollController _scrollController = ScrollController();

  void pushToHistory(HistoryObject obj){
    _readHistory[obj.id] = obj.content;
    setState(() {
      c = c+1;
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          curve: Curves.easeOut,
          duration: const Duration(milliseconds: 150),
        );
      });
    });
  }

  void updateObject(HistoryObject obj){
    _readHistory[obj.id] = obj.content;
    setState(() {
      c = c+1;
    });
  }

  Future<void> readDragged(dynamic file) async {
    if(isImage(file)){
      try{
        ImageMeta? im = await parseImage(RenderEngine.unknown, file.path);
        if(im != null){
          if(mounted) pushToHistory(HistoryObject(id: getRandomID(), content: im));
        }
      } catch(e, s){
        if (kDebugMode) {
          print("Exception $e");
          print(file.path);
          print("StackTrace $s");
        }

        if(mounted) {
          showDialog<String>(
            context: context,
            builder: (BuildContext context) => AlertDialog(
              icon: const Icon(Icons.error),
              iconColor: Colors.redAccent,
              title: Text(AppLocalizations.of(context)!.home_reader_dialog_title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText('${AppLocalizations.of(context)!.home_reader_dialog_error_prefix} $e'),
                  Text(AppLocalizations.of(context)!.home_reader_dialog_error_description),
                  SelectableText(file.path)
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context, 'ok'),
                  child: Text(AppLocalizations.of(context)!.home_reader_dialog_error_buttons_ok),
                ),
              ],
            ),
          );
        }
      }
    } else {
      final String e = p.extension(file.path);
      if(e == '.safetensors'){
        RandomAccessFile randomAccessFile = await File(file.path).open(mode: FileMode.read);
        var metadataLen = randomAccessFile.read(8);
        if (kDebugMode) print(metadataLen);

        pushToHistory(HistoryObject(id: getRandomID(), content: UnknownFile(
          file: p.basename(file.path),
          icon: Icons.pest_control_rodent_outlined,
          color: Color(0xFFD87CEE),
          title: 'We know what it is, but we\'re not ready to read it',
          message: 'Give us some time and we\'ll deal with this file in a future update.'
        )));
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
      } else if(e == '.json') {
        File jsFile = File(file.path);
        jsFile.readAsString().then((value) async {
          if(await isJson(value)){
            var data = jsonDecode(value);
            // CharacterCard ?

            if(isRPCard(data)){
              pushToHistory(HistoryObject(id: getRandomID(), content: CharacterCardFile(data: data)));
            } else {
              pushToHistory(HistoryObject(id: getRandomID(), content: UnknownFile(
                  file: p.basename(file.path),
                  icon: Icons.warning,
                  color: Color(0xFF8C54E1),
                  title: 'Some json data...',
                  message: 'It seems we don\'t know what exactly this file contains.'
              )));
            }
          } else {
            pushToHistory(HistoryObject(id: getRandomID(), content: UnknownFile(
                file: p.basename(file.path),
                icon: Icons.error_outline,
                color: Color(0xFFE15454),
                title: 'Corrupted file?',
                message: 'We are unable to get the file data because it is incorrect. Is the file corrupted or in the wrong format?'
            )));
          }
        });
      } else {
        pushToHistory(HistoryObject(id: getRandomID(), content: UnknownFile(
            file: p.basename(file.path),
            icon: Icons.question_mark,
            color: Color(0xFFF8CA84),
            title: 'We don\'t know what this is',
            message: 'It looks like it\'s some unknown file type or content that we can\'t read.',
            details: 'Path: ${file.path}\nBaseName: ${p.basename(file.path)}\nExtension: $e'
        )));
      }
    }
  }

  Future<void> test() async {
    var prefs = await SharedPreferences.getInstance();

    String data_path = (prefs.getString('sd_webui_folder') ?? 'none');

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appBarController!.resetActions();
    });
    loadCaregories();
  }

  late Future<List<sm.Category>> categoriesFuture;

  void loadCaregories(){
    categoriesFuture = context.read<SQLite>().getCategories();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeManager>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth >= breakpoint || !(Platform.isAndroid || Platform.isIOS) ? Row(children: <Widget>[
      _buildMenu(),
      Expanded(
          child: _buildMainSection()
      )
    ]
    ) : Scaffold(
      body: _buildMainSection(),
      // use SizedBox to contrain the AppMenu to a fixed width
      drawer: Theme(
        data: ThemeData.dark(useMaterial3: false).copyWith(
          canvasColor: Theme.of(context).scaffoldBackgroundColor,
        ),
        child: Drawer(
          width: 350,
          child: Theme(
            data: theme.getTheme,
            child:  _buildMenu(),
          ),
        )
      ),
      drawerEdgeDragWidth: MediaQuery.of(context).size.width / 2,
    );
  }

  DropOperation _onDropOver(DropOverEvent event) {
    setState(() {
      _isDragOver = true;
    });
    return event.session.allowedOperations.firstOrNull ?? DropOperation.none;
  }

  Future<void> _onPerformDrop(PerformDropEvent event) async {
    for(var item in event.session.items){
      final reader = item.dataReader!;
      if (reader.canProvide(Formats.fileUri)) {
        reader.getValue(Formats.fileUri, (value) => readDragged(File(Uri.parse(value!.path).toFilePath(windows: Platform.isWindows))));
      }
    }

    if (!mounted) {
      return;
    }
  }

  void _onDropLeave(DropEvent event) {
    setState(() {
      _isDragOver = false;
    });
  }

  bool _isDragOver = false;

  Widget _buildMenu(){
    return Container(
        color: Theme.of(context).colorScheme.background,
        width: 350,
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                separatorBuilder: (BuildContext context, int index) => const Divider(height: 14),
                itemCount: _readHistory.length,
                itemBuilder: (BuildContext context, int index) {
                  dynamic element = _readHistory[_readHistory.keys.toList()[index]];
                  return ShowUp(
                    child: element.runtimeType == UnknownFile ? Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: Theme.of(context).scaffoldBackgroundColor
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(7),
                                    color: element.color ?? const Color(0x00d75252)
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: Colors.black87,
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Icon(element.icon ?? Icons.question_mark, color: Colors.white),
                                    ),
                                    const Gap(7),
                                    Expanded(
                                        flex: 1,
                                        child: Text(element.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontFamily: 'Montserrat'), maxLines: 1, overflow: TextOverflow.ellipsis)
                                    ),
                                  ],
                                ),
                              ),
                              Gap(7),
                              Text(element.message, style: TextStyle(color: Colors.white70, fontSize: 12)),
                              Gap(3),
                              SelectableText('File: ${element.file}', style: TextStyle(fontSize: 12)),
                              if(element.details != null) ExpansionTile(
                                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                                  expandedAlignment: Alignment.topLeft,
                                  tilePadding: EdgeInsets.zero,
                                  title:  Text('Details'),
                                  children: <Widget>[
                                    SelectableText(element.details)
                                  ]
                              )
                            ]
                        )
                    ) : element.runtimeType == CharacterCardFile ? LayoutBuilder(
                        builder: (BuildContext context, BoxConstraints constraints) {
                          return Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: Theme.of(context).scaffoldBackgroundColor
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(7.0),
                                      child: Stack(
                                        children: [
                                          SizedBox(
                                            width: constraints.maxWidth / 2,
                                            child: AspectRatio(
                                              aspectRatio: 1/1,
                                              child: DottedBorder(
                                                options: RectDottedBorderOptions(
                                                  dashPattern: const [6, 6],
                                                  color: Colors.redAccent,
                                                  //borderType: BorderType.RRect,
                                                  strokeWidth: 2,
                                                  //radius: const Radius.circular(12),
                                                ),
                                                child: const Center(child: Icon(Icons.chat, color: Colors.blueAccent)),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Gap(7),
                                    SizedBox(
                                      width: constraints.maxWidth / 2 - 7 - 14, // size - Gap - 14(7*2) padding
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('fsdf', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          InfoBox(one: 'RE', two: 'sdf'),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                                const Gap(7),
                                Row(
                                  children: [
                                    ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          minimumSize: Size.zero, // Set this
                                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                                        ),
                                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CharacterCardFullView(jsonData: element.data))),
                                        child: const Text("View", style: TextStyle(fontSize: 12))
                                    ),
                                  ],
                                )
                              ],
                            ),
                          );
                        }
                    ) : element.runtimeType == FileProcess ? Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: Theme.of(context).scaffoldBackgroundColor
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                child: Row(
                                  children: [
                                    Icon(Icons.monitor),
                                    Gap(3),
                                    Expanded(child: LinearProgressIndicator(minHeight: 2)),
                                    Gap(3),
                                    Icon(Icons.public),
                                    Gap(3),
                                    Expanded(child: LinearProgressIndicator(minHeight: 2)),
                                    Gap(3),
                                    Icon(Icons.accessibility)
                                  ],
                                ),
                              ),
                              Gap(7),
                              Text(element.message, style: TextStyle(color: Colors.white70, fontSize: 12)),
                              Gap(3),
                              SelectableText('File: ${element.file}', style: TextStyle(fontSize: 12)),
                            ]
                        )
                    ) : FileInfoPreview(type: element.runtimeType == ImageMeta ? 1 : 0, data: element),
                  );
                },
              ),
            ),
            Container(
              height: 1,
              color: const Color(0xFF2d2f32),
            ),
            Padding(
                padding: const EdgeInsets.all(20),
                child: GestureDetector(
                  onTap: () async {
                    final ImagePicker picker = ImagePicker();
                    final img = await picker.pickImage(source: ImageSource.gallery);
                    if(img != null){
                      readDragged(img);
                    }
                  },
                  child: DropRegion(
                    formats: const [
                      ...Formats.standardFormats,
                    ],
                    hitTestBehavior: HitTestBehavior.opaque,
                    onDropOver: _onDropOver,
                    onPerformDrop: _onPerformDrop,
                    onDropLeave: _onDropLeave,
                    child: selectBlock(),
                  )
                  // DropTarget(
                  //     onDragDone: (detail) async {
                  //       for(XFile file in detail.files) {
                  //         await readDragged(file);
                  //       }
                  //     },
                  //     onDragEntered: (detail) {
                  //       setState(() {
                  //         _dragging = true;
                  //       });
                  //     },
                  //     onDragExited: (detail) {
                  //       setState(() {
                  //         _dragging = false;
                  //       });
                  //     },
                  //     child: selectBlock()
                  // ),
                )
            )
          ],
        )
    );
  }

  Widget selectBlock(){
    return DottedBorder(
      options: RectDottedBorderOptions(
        dashPattern: const [6, 6],
        color: const Color(0xFF2d2f32),
        // borderType: BorderType.RRect,
        strokeWidth: 2,
        // radius: const Radius.circular(12),
      ),
      child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: _isDragOver ? Colors.blue.withOpacity(0.4) : Theme.of(context).scaffoldBackgroundColor,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: Platform.isAndroid || Platform.isIOS ? [
                    const Icon(Icons.file_open_outlined, color: Color(0xFF0068ff), size: 36),
                    const Gap(8),
                    Text(AppLocalizations.of(context)!.home_reader_form_select_file_mobile0, style: const TextStyle(fontWeight: FontWeight.w500)),
                  ] :[
                    const Icon(Icons.file_open_outlined, color: Color(0xFF0068ff), size: 36),
                    const Gap(8),
                    Text(AppLocalizations.of(context)!.home_reader_form_select_file_desktop0, style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text(AppLocalizations.of(context)!.home_reader_form_select_file_desktop1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: TextField(
                        onSubmitted: (value) async {
                          int id = getRandomID();
                          pushToHistory(HistoryObject(id: id, content: FileProcess(
                              file: value,
                              title: 'Attempting to retrieve data',
                              message: 'It won\'t take long...'
                          )));
                          try{
                            ImageMeta? im = await parseUrlImage(value);
                            if(im != null){
                              updateObject(HistoryObject(id: id, content: im));
                            } else {
                              updateObject(HistoryObject(id: id, content: FileProcess(
                                  file: value,
                                  title: 'Failed to read data',
                                  message: 'The file was downloaded and verified, but the content... well, we can\'t process it'
                              )));
                            }
                          } catch(e){
                            updateObject(HistoryObject(id: id, content: UnknownFile(
                                file: value,
                                icon: Icons.error,
                                color: Color(0xFFEE7C7C),
                                title: 'Error retrieving data',
                                message: 'Looks like the link is broken or something is blocking access',
                                details: 'E: $e'
                            )));
                            rethrow;
                          }
                        },
                        textInputAction: TextInputAction.done,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                            alignLabelWithHint: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            label: Center(
                              child: Text(AppLocalizations.of(context)!.home_reader_form_select_file_desktop2, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                  width: 1, color: Theme.of(context).colorScheme.primary
                              ),
                            )
                        ),
                      ),
                    )
                    // Text(, style: TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          )
      ),
    );
  }

  Widget _buildMainSection(){
    final screenWidth = MediaQuery.of(context).size.width;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
      child: Column(
        children: [
          const Gap(12),
          ShowUp(
            delay: 50,
            child: Row(
              children: [
                Text('categories'.toUpperCase(), style: const TextStyle(color: Colors.grey)),
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
          ),
          const Gap(8),
          screenWidth <= breakpoint ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ShowUp(
                delay: 200,
                child: Text('Categories', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w600, fontFamily: 'Montserrat')),
              ),
              const Gap(4),
              _topButtons(withSpacer: screenWidth <= breakpoint)
            ],
          ) : Row(
            children: [
              const ShowUp(
                delay: 200,
                child: Text('Categories', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w600, fontFamily: 'Montserrat')),
              ),
              const Spacer(),
              _topButtons()
            ],
          ),
          const Gap(8),
          Expanded(
            child: FutureBuilder(
                future: categoriesFuture,
                builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
                  Widget children;
                  if (snapshot.hasData) {
                    children = snapshot.data.length == 0 ? Center(
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: screenWidth <= breakpoint ? screenWidth * 70 / 100 : 500,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.create_new_folder, size: 50, color: Colors.white),
                              const Gap(4),
                              Text(AppLocalizations.of(context)!.home_main_categories_start_title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                              Text(AppLocalizations.of(context)!.home_main_categories_start_description, style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                    ) : SingleChildScrollView(
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
                                            ]
                                          ),
                                          padding: const EdgeInsets.all(4),
                                          child: Center(child: Icon(ii.item.icon, color: ii.item.color, size: 21),)
                                        ),
                                        const Spacer(),
                                        Text(ii.item.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 21)),
                                        ii.item.description != null ? Text(ii.item.description, style: const TextStyle(color: Colors.grey, fontSize: 14)) : const SizedBox.shrink(),
                                        const Spacer(),
                                        Row(
                                          children: [
                                            TextButton(
                                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MiniWorld())),
                                              child: Text(AppLocalizations.of(context)!.home_main_categories_block_fast_preview),
                                            )
                                          ]
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
                    children = Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                  return children;
                }
            ),
          )
        ],
      ),
    );
  }

  Widget _topButtons({bool withSpacer = false}){
    return Row(
      children: [
        Icon(Icons.grid_view_rounded, color: Theme.of(context).primaryColor),
        const Gap(14),
        const Icon(Icons.view_list_rounded, color: Colors.grey),
        withSpacer ? const Spacer() : const Gap(21),
        ElevatedButton(
            style: ButtonStyle(
                foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                backgroundColor: WidgetStateProperty.all<Color>(Theme.of(context).primaryColor),
                shape: WidgetStateProperty.all<RoundedRectangleBorder>(const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))))
            ),
            onPressed: () async {
              // notificationManager?.show(title: 'Hello');
              // return;
              TextEditingController title = TextEditingController();
              TextEditingController description = TextEditingController();

              final formKey = GlobalKey<FormState>();
              await showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    content: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          TextFormField(
                            controller: title,
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
                            controller: description,
                            decoration: const InputDecoration(
                              icon: Icon(Icons.textsms),
                              hintText: 'Description of what\'s here',
                              labelText: 'Description',
                            ),
                          ),
                          const Gap(12),
                          ElevatedButton(
                            child: Text(AppLocalizations.of(context)!.home_main_categories_buttons_create),
                            onPressed: () {
                              if (formKey.currentState!.validate()) {
                                context.read<SQLite>().createCategory(
                                    title: title.text.trim(),
                                    description: description.text.trim()
                                ).then((category){
                                  context.read<SaveManager>().addCategory(category);
                                  loadCaregories();
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
            child: Text(AppLocalizations.of(context)!.home_main_categories_buttons_create, style: const TextStyle(fontSize: 14))
        )
      ],
    );
  }
}

class FileInfoPreview extends StatelessWidget{
  final int type;
  final dynamic data;

  const FileInfoPreview({
    super.key,
    required this.type,
    required this.data
  });

  @override
  Widget build(BuildContext context) {
    ImageMeta? im = type == 1 ? data as ImageMeta : null;

    bool hasICC = im?.specific?['hasIccProfile'] ?? false;
    bool isHDRimage = im?.specific?['iccProfileName'] != null && isHDR(im!.specific?['iccProfileName']);
    String pn = '';
    if(hasICC){
      var t = im?.specific?['iccTagKeys'].where((el) => int.parse(el.replaceFirst('iccTag', '')) == 1684370275);
      if(t.length != 0) {
        pn = readTag(im?.specific?[t.first]);
      }
    }

    final dataModel = Provider.of<DataModel>(context, listen: false);
    final entries = <ContextMenuEntry>[
      MenuItem.submenu(
        label: 'Send to comparison',
        icon: Icons.edit,
        items: [
          MenuItem(
            label: 'Go to viewer',
            value: 'comparison_view',
            icon: Icons.compare,
            onSelected: () {
              dataModel.jumpToTab(3);
            },
          ),
          const MenuDivider(),
          MenuItem(
            label: 'As main',
            value: 'comparison_as_main',
            icon: Icons.swipe_left,
            onSelected: () {
              dataModel.comparisonBlock.addImage(im!);
              dataModel.comparisonBlock.changeSelected(0, im);
              // implement redo
            },
          ),
          MenuItem(
            label: 'As test',
            value: 'comparison_as_test',
            icon: Icons.swipe_right,
            onSelected: () {
              dataModel.comparisonBlock.addImage(im!);
              dataModel.comparisonBlock.changeSelected(1, im);
            },
          ),
        ],
      ),
      MenuItem.submenu(
        label: 'Build...',
        icon: Icons.build,
        items: [
          MenuItem(
            label: 'XYZ plot',
            icon: Icons.grid_view,
            onSelected: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => XYZBuilder(images: List<ImageMeta>.from(_readHistory.values.where((el) => el.content.runtimeType == ImageMeta).toList(growable: false)))));
            },
          )
        ],
      ),
      // MenuItem.submenu(
      //   label: 'View in timeline',
      //   icon: Icons.view_timeline_outlined,
      //   items: [
      //     MenuItem(
      //       label: 'by seed',
      //       value: 'timeline_by_seed',
      //       icon: Icons.compare,
      //       onSelected: () {
      //         dataModel.timelineBlock.setSeed(widget.imageMeta!.generationParams?.seed);
      //         dataModel.jumpToTab(2);
      //       },
      //     ),
      //   ],
      // ),
      const MenuDivider(),
      // MenuItem(
      //   label: 'Send to MiniSD',
      //   value: 'send_to_minisd',
      //   icon: Icons.web_rounded,
      //   onSelected: () {
      //     Navigator.push(context, MaterialPageRoute(builder: (context) => MiniSD(imageMeta: imageMeta)));
      //     // implement redo
      //   },
      // ),
      // const MenuDivider(),
      MenuItem(
        label: 'Show in explorer',
        value: 'show_in_explorer',
        icon: Icons.compare,
        onSelected: () {
          showInExplorer(im!.fullPath!);
        },
      ),
    ];

    final contextMenu = ContextMenu(
      entries: entries,
      padding: const EdgeInsets.all(8.0),
    );

    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
        return Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Theme.of(context).scaffoldBackgroundColor
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  type == 1 ? ContextMenuRegion(
                    contextMenu: contextMenu,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7.0),
                      child: Stack(
                        children: [
                          SizedBox(
                            width: constraints.maxWidth / 2,
                            child: AspectRatio(
                              aspectRatio: im?.error == null ? im!.size!.aspectRatio() : 1/1,
                              child: im?.error == null ? im?.thumbnail != null ? Hero(tag: im!.fileName, child: Image.memory(im.thumbnail!, gaplessPlayback: true)) : Icon(Icons.error) : DottedBorder(
                                options: RectDottedBorderOptions(
                                  dashPattern: const [6, 6],
                                  color: Colors.redAccent,
                                  strokeWidth: 2,
                                ),
                                child: const Center(child: Icon(Icons.error, color: Colors.redAccent)),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.only(left: 2, right: 2, bottom: 1),
                                    decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.all(Radius.circular(2)),
                                        color: Colors.black.withOpacity(0.7)
                                    ),
                                    child: Text(im?.fileTypeExtension ?? '', style: const TextStyle(color: Colors.white, fontSize: 10)),
                                  ),
                                  isHDRimage ? const Gap(4) : const SizedBox.shrink(),
                                  isHDRimage ? Container(
                                    padding: const EdgeInsets.only(left: 2, right: 2, bottom: 1),
                                    decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.all(Radius.circular(2)),
                                        color: Colors.black.withOpacity(0.7)
                                    ),
                                    child: const Text('HDR', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ) : const SizedBox.shrink()
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ) : const Icon(Icons.file_open),
                  const Gap(7),
                  SizedBox(
                    width: constraints.maxWidth / 2 - 7 - 14, // size - Gap - 14(7*2) padding
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(im!.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                        InfoBox(one: 'RE', two: renderEngineToString(im.re)),
                        if(im.other?['chara'] != null) const InfoBox(one: 'Has', two: 'Character card'),
                        im.error == null ? InfoBox(one: 'Size', two: im.size.toString()) : const SizedBox.shrink(),
                        im.other?['softwareType'] != null ? InfoBox(one: 'Software', two: softwareToString(Software.values[im.other?['softwareType']])) : const SizedBox.shrink(),
                        im.generationParams?.version != null ? InfoBox(one: 'Version', two: im.generationParams?.version ?? 'error') : const SizedBox.shrink(),
                      ],
                    ),
                  )
                ],
              ),
              const Gap(7),
              im.error != null ? InfoBox(one: 'Error', two: im.error, inner: true) : const SizedBox.shrink(),
              hasICC ? (im.specific?['iccProfileName'] != null) ? InfoBox(one: 'Raw Profile Name', two: im.specific?['iccProfileName'], inner: true) : InfoBox(one: 'Color profile', two: pn) : const SizedBox.shrink(),
              im.generationParams?.checkpoint != null ? InfoBox(one: 'Checkpoint', two: im.generationParams?.checkpoint, inner: true) : const SizedBox.shrink(),
              im.generationParams?.sampler != null ? InfoBox(one: 'Sampler', two: im.generationParams?.sampler, inner: true) : const SizedBox.shrink(),
              if(im.specific?['comfUINodes'] != null) ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: InfoBox(one: 'Node Count', two: im.specific!['comfUINodes'].length.toString()),
                children: withSpaceBetween(list: im.specific!['comfUINodes'].map<Widget>((el)=>Text(el['type'], style: const TextStyle(fontSize: 12))).toList(), element: const Icon(Icons.arrow_downward, size: 10,)),
              ),
              const Gap(7),
              Row(
                children: [
                  im.error == null ? ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size.zero, // Set this
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                      ),
                      onPressed: () async {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => ImageView(imageMeta: im)));
                      },
                      child: const Text("View data", style: TextStyle(fontSize: 12))
                  ) : const SizedBox.shrink(),
                ],
              )
            ],
          ),
        );
      }
    );
  }
}

class InfoBox extends StatelessWidget{
  final String one;
  final dynamic two;
  final bool inner;
  final bool withGap;

  const InfoBox({ Key? key, required this.one, required this.two, this.inner = false, this.withGap = true}): super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
        margin: withGap ? const EdgeInsets.only(top: 7) : null,
        child: Row( // This shit killed four hours of my life.
          children: [
            SelectableText(one, style: const TextStyle(fontSize: 12, color: Colors.white70)),
            const Gap(6),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: two.runtimeType == String ? SelectableText(two, style: const TextStyle(fontSize: 13)) : two,
                ),
              ),
            )
          ],
        )
    );
  }
}

class CharacterCardFile {
  final dynamic data;

  const CharacterCardFile({
    required this.data
  });
}

class UnknownFile {
  final IconData? icon;
  final Color? color;
  final String file;
  final String title;
  final String message;
  final String? details;

  const UnknownFile({
    this.icon,
    this.color,
    required this.title,
    required this.message,
    required this.file,
    this.details
  });
}

class FileProcess {
  final String file;
  final String title;
  final String message;

  const FileProcess({
    required this.title,
    required this.message,
    required this.file
  });
}