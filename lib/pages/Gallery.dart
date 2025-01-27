import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:animated_size_and_fade/animated_size_and_fade.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cimagen/components/LoadingState.dart';
import 'package:cimagen/pages/Timeline.dart' as timeline;
import 'package:cimagen/pages/sub/MiniSD.dart';
import 'package:cimagen/utils/DataModel.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:flutter_resizable_container/flutter_resizable_container.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:cimagen/Utils.dart';
import 'package:shimmer/shimmer.dart';

import '../components/CustomActionButton.dart';
import '../components/GalleryImageFullMain.dart';
import '../components/XYZBuilder.dart';
import '../main.dart';
import '../components/CustomMenuItem.dart';
import '../modules/ConfigManager.dart';
import '../modules/DataManager.dart';
import '../modules/webUI/AbMain.dart';
import '../utils/NavigationService.dart';
import '../utils/SQLite.dart';
import '../utils/ThemeManager.dart';
import 'Settings.dart';

import 'package:path/path.dart' as p;

Future<List<Folder>> _loadMenu(int index) async {
  return NavigationService.navigatorKey.currentContext!.read<ImageManager>().getter.getFolders(index);
}

Future<List<FileSystemEntity>> dirContents(Directory dir) {
  var files = <FileSystemEntity>[];
  var completer = Completer<List<FileSystemEntity>>();
  var lister = dir.list(recursive: false);
  lister.listen((file) => files.add(file), onDone:() => completer.complete(files));
  return completer.future;
}

Future<List<String>> dirDirs(String path) async { //Cringe
  Directory di = Directory(path);
  List<String> d = [];
  List<FileSystemEntity> fe = await dirContents(di);
  for (var element in fe) {
    d.add(element.path);
  }
  return d;
}

class Gallery extends StatefulWidget{
  const Gallery({ super.key });

  @override
  State<Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<Gallery> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  int getterID = 0;
  String currentKey = 'null';
  bool debug = false;

  int previewType = 0;

  TabController? _tabController;
  final GlobalKey _key = GlobalKey();

  List<String> _tabs = [];
  Map<int, ScrollController> _scrollControllers = {};
  Map<int, Future<List<Folder>>> _lists = {};
  Map<int, int> _selected = {};

  bool sr = false;

  SelectedModel model = SelectedModel();

  dynamic imagesList;

  @override
  void initState() {
    super.initState();
    debug = prefs!.getBool('debug') ?? false;

    var go = context.read<ImageManager>().getter.loaded;
    if (go) {
      getterID = context.read<ImageManager>().getter.hashCode;
      reloadTabs();
      _lists[0]?.then((value){
        if(mounted && value.isNotEmpty) {
          Future<List<ImageMeta>> _imagesList = context.read<ImageManager>().getter.getFolderFiles(0, 0);
          _imagesList.then((listRes){
            if(listRes.isEmpty){
              context.read<ImageManager>().getter.indexFolder(value[0]).then((controller){
                if(mounted) {
                  setState(() {
                    imagesList = controller.stream;
                  });
                }
              });
            } else if(mounted) {
              setState(() {
                imagesList = _imagesList;
              });
            }
          });
        }
      });
    }
  }

  void reloadTabs(){
    //Clear
    if(_tabController != null) _tabController!.dispose();
    for (var k in _scrollControllers.keys) {
      _scrollControllers[k]!.dispose();
    }
    _scrollControllers.clear();

    //Init
    _tabs = context.read<ImageManager>().getter.tabs;
    _tabController = TabController(length: _tabs.length, vsync: this);

    for (int i = 0; i < _tabs.length; i++) {
      // Scroll
      _scrollControllers[i] = ScrollController();
      // Lists
      _lists[i] = _loadMenu(i);
      // Selected
      _selected[i] = 0;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      appBarController!.resetActions();
      appBarController!.setActions([
        CustomActionButton(getIcon: () => [Icons.grid_view, Icons.move_up, Icons.vertical_split_rounded][previewType], tooltip: 'Preview mode', onPress: (){
          setState(() {
            previewType = previewType + 1 >= 3 ? 0 : previewType + 1;
          });
        }, isActive: () => previewType != 0),
        CustomActionButton(getIcon: () => Icons.info, tooltip: 'Database info', onPress: (){
          context.read<SQLite>().getTablesInfo(host: context.read<ImageManager>().getter.host).then((value){
            Map<String, double> dataMap = {
              'txt2img (${readableFileSize(value['txt2imgSumSize'] as int)})': (value['txt2imgCount'] as int).toDouble(),
              'img2img (${readableFileSize(value['img2imgSumSize'] as int)})': (value['img2imgCount'] as int).toDouble(),
              'inpaint (${readableFileSize(value['inpaintSumSize'] as int)})': (value['inpaintCount'] as int).toDouble(),
              'comfui (${readableFileSize(value['comfuiSumSize'] as int)})': (value['comfuiCount'] as int).toDouble(),
              'Without meta': (value['totalImages'] as int) - (value['totalImagesWithMetadata'] as int).toDouble()
            };
            showDialog<String>(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                title: const Text('Database info'),
                content: SizedBox(
                  width: MediaQuery.of(context).size.width - 30,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DBChart(dataMap: dataMap),
                    ],
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'OK'),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }).onError((error, stackTrace){

          });
        }, isActive: () => true),
        CustomActionButton(getIcon: () => Icons.grid_on_outlined, tooltip: 'Take the best sids for XYZ', onPress: (){
          _lists[_tabController!.index]?.then((listValue) {
            Folder f = listValue[_selected[_tabController!.index]!];
            showDialog<String>(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                title: const Text('Best for XYZ', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600, fontFamily: 'Montserrat')),
                content: SizedBox(
                  width: MediaQuery.of(context).size.width - 30 > MediaQuery.of(context).size.height - 30 ? MediaQuery.of(context).size.height - 30 : MediaQuery.of(context).size.width - 30,
                  height: MediaQuery.of(context).size.height - 30,
                  child: XYZPlotForHiRes(_tabController!.index, _selected[_tabController!.index]!),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'OK'),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          });
        }, isActive: () => true),
        PopupMenuButton<int>(
          color: Colors.black,
          itemBuilder: (context) => [
            PopupMenuItem<int>(
              child: Text('Index ${_tabs[_tabController!.index]}'),
              onTap: () => context.read<ImageManager>().getter.indexAll(_tabController!.index),
            ),
            PopupMenuItem<int>(
              child: const Text('Find incorrectly located files'),
              onTap: (){

              },
            ),
          ],
        )
      ]);
    });
  }

  @override
  void dispose(){
    appBarController!.resetActions();
    if(_tabController != null) _tabController!.dispose();
    for (var k in _scrollControllers.keys) {
      _scrollControllers[k]!.dispose();
    }
    _scrollControllers.clear();
    super.dispose();
  }

  void reloadTab(){
    _lists[_tabController!.index] = _loadMenu(_tabController!.index);
    setState(() {});
  }

  void changeFolder(int folder, int index) {
    _selected[folder] = index;
    setState(() {
      currentKey = '$folder:$index';
    });


    _lists[folder]?.then((listValue) {
      Folder f = listValue[index];
      imagesList = context.read<ImageManager>().getter.getFolderFiles(folder, index);
      print('changeTab:$folder/${f.name}');
      imagesList?.then((List<ImageMeta> value) {
        bool force = false; //listValue.length-1 == index;
        context.read<ImageManager>().getter.indexFolder(f, hashes: value.map((e) => e.pathHash).toList(growable: false)).then((controller){
          if(value.isEmpty || force){
            setState(() {
              imagesList = controller.stream;
            });
          }
        });
      });
    });
  }

  Widget _buildNavigationRail() {
    return SizedBox(
      width: 200,
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: _tabs.map<Widget>((tab)=>Tab(text: tab)).toList(),
            isScrollable: false
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabs.asMap().map((i, element)=>MapEntry(i, _fBuilder(i))).values.toList()
            )
          ),
          InkWell(
            onTap: () {
              reloadTab();
            },
            child: Container(
              decoration: const BoxDecoration(
                  color: Color(0xFF000000),
              ),
              child: const Align(
                alignment: Alignment.center,
                child: Text ('Rescan'),
              ),
            ),
          )
        ],
      ),
    );
  }

  // Блоки сбоку
  Widget _fBuilder(int tabIndex){
    return FutureBuilder(
        future: _lists[tabIndex],
        builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
          Widget c;
          if (snapshot.hasData) {
            if(snapshot.data.length == 0){
              c = const Padding(padding: EdgeInsets.all(14), child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.nights_stay_rounded,
                    color: Colors.white,
                    size: 60,
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text('It looks like it\'s empty\nTry indexing all'),
                  ),
                ],
              ));
            } else {
              c = AnimationLimiter(
                child: ListView.separated(
                  controller: _scrollControllers[tabIndex],
                  separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 4),
                  itemCount: snapshot.data.length,
                  itemBuilder: (context, index) => FolderBlock(
                      folder: snapshot.data[index],
                      section: tabIndex,
                      index: index,
                      onTap: () => changeFolder(tabIndex, index),
                      active: _selected[tabIndex] == index
                  )
                )
              );
            }
          } else if (snapshot.hasError) {
            c = Padding(padding: const EdgeInsets.all(14), child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 60,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text('Error: ${snapshot.error}'),
                ),
              ],
            ));
          } else {
            c = const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(),
                ),
              ],
            );
          }
          return c;
        }
    );
  }

  double x = 0;
  double y = 0;


  Function(PointerHoverEvent event, ImageMeta im)? func;
  void _initFloat(Function(PointerHoverEvent event, ImageMeta im) func) {
    this.func = func;
  }

  String oldID = '';
  void _updateFloat(PointerHoverEvent event, ImageMeta im){
    if(oldID == im.keyup) return;
    oldID = im.keyup;
    if(func != null) func!(event, im);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final theme = Provider.of<ThemeManager>(context, listen: false);
    const breakpoint = 600.0;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => model),
        ChangeNotifierProvider(create: (_) => context.read<ImageManager>().getter),
      ],
      child: !context.read<ImageManager>().getter.loaded
        ? Center(
          child: LoadingState(
            loaded: context.read<ImageManager>().getter.loaded,
            error: context.read<DataManager>().error
          )
        ) : screenWidth >= breakpoint || !(Platform.isAndroid || Platform.isIOS) ? Row(children: <Widget>[
          _buildNavigationRail(),
          Expanded(
            child: previewType == 2 ? ResizableContainer(
              direction: Axis.horizontal,
              divider: const ResizableDivider(
                thickness: 3,
                padding: 18,
                length: ResizableSize.ratio(0.25),
                color: Colors.white,
              ),
              children: [
                ResizableChild(
                  child: _buildMainSection(),
                ),
                ResizableChild(
                  child: _buildPreviewSection(),
                ),
              ],
            ) : _buildMainSection()
          ),
        ]
      ) : Scaffold(
          body: _buildMainSection(),
          // use SizedBox to contrain the AppMenu to a fixed width
          drawer: Theme(
            data: ThemeData.dark(useMaterial3: false).copyWith(
              canvasColor: Theme.of(context).scaffoldBackgroundColor,
            ),
            child: SizedBox(
              width: 200,
              child: Drawer(
                child: Theme(
                    data: theme.getTheme,
                    child: _buildNavigationRail()
                ),
              ),
            ),
          )
      )
    );
  }

  int _getCount() {
    RenderBox renderBox = _key.currentContext!.findRenderObject() as RenderBox;
    return (renderBox.size.width / 200).round();
  }


  Widget _buildMainSection(){
    return Stack(
      key: _key,
      children: [
        imagesList.runtimeType.toString().startsWith('Future<List<') ? FutureBuilder(
            future: imagesList,
            builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
              Widget children;
              if (snapshot.hasData) {
                children = snapshot.data.length == 0 ? const EmplyFolderPlaceholder() : AlignedGridView.count(
                    physics: const BouncingScrollPhysics(),
                    itemCount: snapshot.data.length,
                    mainAxisSpacing: 5,
                    crossAxisSpacing: 5,
                    crossAxisCount: _getCount(),
                    itemBuilder: (context, index) {
                      var it = snapshot.data[index];
                      return PreviewImage(
                        key: Key(it.keyup),
                        imagesList: snapshot.data,
                        imageMeta: it,
                        selectedModel: model,
                        index: index,
                        onHover: (PointerHoverEvent event, ImageMeta im){
                          _updateFloat(event, im);
                        },
                        onImageTap: () {
                          Navigator.push(
                              context,
                              _createGalleryDetailRoute(
                                  snapshot.data,
                                  index
                              )
                          );
                        },
                      );
                    }
                );
              } else if (snapshot.hasError) {
                children = Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      const Text('Oops, there seems to be a error.'),
                      ExpansionTile(
                        title: const Text('Error Information'),
                        subtitle: const Text('Use this information to solve the problem'),
                        children: <Widget>[
                          Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                  color: Theme.of(context).scaffoldBackgroundColor,
                                  borderRadius: const BorderRadius.all(Radius.circular(4))
                              ),
                              child: SelectableText(
                                  snapshot.error.toString(),
                                  style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 14, color: Colors.white70)
                              )
                          ),
                        ],
                      )
                    ],
                  ),
                );
              } else {
                children = Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(debug ? 'Future<List<ImageMeta>> hasData:${snapshot.hasData} hasError:${snapshot.hasError}' : 'Loading...'),
                        const Gap(8),
                        const LinearProgressIndicator()
                      ],
                    )
                );
              }
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: children,
              );
            }) : imagesList.runtimeType.toString().startsWith('_') && imagesList.runtimeType.toString().contains('<List<')? StreamBuilder<List<ImageMeta>>(
          stream: imagesList,
          builder: (BuildContext context, AsyncSnapshot<List<ImageMeta>> snapshot) {
            Widget children;
            if (snapshot.hasError) {
              children = Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    const Text('Oops, there seems to be a error.'),
                    ExpansionTile(
                      title: const Text('Error Information'),
                      subtitle: const Text('Use this information to solve the problem'),
                      children: <Widget>[
                        Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                                color: Theme.of(context).scaffoldBackgroundColor,
                                borderRadius: const BorderRadius.all(Radius.circular(4))
                            ),
                            child: SelectableText(
                                snapshot.error.toString(),
                                style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 14, color: Colors.white70)
                            )
                        ),
                      ],
                    )
                  ],
                ),
              );
            } else {
              switch (snapshot.connectionState) {
                case ConnectionState.none:
                  children = const Text('Hyi');
                case ConnectionState.waiting:
                  children = Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(debug ? '_ControllerStream<List<ImageMeta>> hasError:${snapshot.hasError} connectionState:${snapshot.connectionState}' : 'Loading...'),
                          const Gap(8),
                          const LinearProgressIndicator()
                        ],
                      )
                  );
                case ConnectionState.active:
                  children = AlignedGridView.count(
                      physics: const BouncingScrollPhysics(),
                      itemCount: snapshot.data!.length,
                      mainAxisSpacing: 5,
                      crossAxisSpacing: 5,
                      crossAxisCount: _getCount(),
                      itemBuilder: (context, index) {
                        var it = snapshot.data![index];
                        return PreviewImage(
                          key: Key(it.keyup),
                          imagesList: snapshot.data!,
                          imageMeta: it,
                          selectedModel: model,
                          index: index,
                          onImageTap: () {
                            Navigator.push(
                                context,
                                _createGalleryDetailRoute(
                                    snapshot.data!,
                                    index
                                )
                            );
                          },
                          onHover: (PointerHoverEvent event, ImageMeta im){
                            _updateFloat(event, im);
                          },
                        );
                      }
                  );
                case ConnectionState.done:
                  children = snapshot.data == null || snapshot.data!.isEmpty ? const EmplyFolderPlaceholder() : AlignedGridView.count(
                      physics: const BouncingScrollPhysics(),
                      itemCount: snapshot.data!.length,
                      mainAxisSpacing: 5,
                      crossAxisSpacing: 5,
                      crossAxisCount: _getCount(),
                      itemBuilder: (context, index) {
                        var it = snapshot.data![index];
                        return PreviewImage(
                          key: Key(it.keyup),
                          imagesList: snapshot.data!,
                          imageMeta: it,
                          selectedModel: model,
                          index: index,
                          onHover: (PointerHoverEvent event, ImageMeta im){
                            _updateFloat(event, im);
                          },
                          onImageTap: () {
                            Navigator.push(
                                context,
                                _createGalleryDetailRoute(
                                    snapshot.data!,
                                    index
                                )
                            );
                          },
                        );
                      }
                  );
              }
            }
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: children,
            );
          },
        ) : Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SelectableText(debug ? 'other ${imagesList.runtimeType.toString()}' : 'Loading...'),
                const Gap(8),
                const LinearProgressIndicator()
              ],
            )
        ),
        if(previewType == 1) FloatPreview(
          initializer: _initFloat,
        )
      ],
    );
  }

  Widget _buildPreviewSection() {
    return SizedBox(
      width: MediaQuery.of(context).size.width / 3,
      child: SidePreview(
        initializer: _initFloat,
      ),
    );
  }

  @override
  bool get wantKeepAlive{
    return false;
    if (context.read<ImageManager>().getter.hashCode != getterID) {
      getterID = context.read<ImageManager>().getter.hashCode;
      return false;
    }
    return true;
  }
}

class FolderBlock extends StatefulWidget{
  final Folder folder;
  final int section;
  final int index;
  final void Function() onTap;
  final bool active;
  const FolderBlock({ super.key, required this.folder, required this.section, required this.index, required this.onTap, required this.active});

  @override
  State<FolderBlock> createState() => _FolderBlockState();
}

class _FolderBlockState extends State<FolderBlock> {
  bool loaded = false;
  bool first = true;
  List<FolderFile> origFiles = [];
  List<FolderFile> displayFiles = [];

  @override
  void initState(){
    print('init ${widget.index}');
    widget.folder.files ??= context.read<ImageManager>().getter.getFolderThumbnails(widget.section, widget.index);
    widget.folder.files!.then((files) {
      if(files.length <= 4){
        displayFiles = files;
      } else {
        int l = files.length;
        // 123 = 100
        //  ?  = 33
        displayFiles.add(files[0]);
        displayFiles.add(files[(l*33/100).round()]);
        displayFiles.add(files[(l*66/100).round()]);
        displayFiles.add(files[files.length - 1]);
      }
      if(mounted) {
        setState(() {
          origFiles = files;
          loaded = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries = <ContextMenuEntry>[
      // MenuItem(
      //     label: 'Index this folder',
      //     icon: Icons.waterfall_chart,
      //     onSelected: () => context.read<ImageManager>().getter.indexFolder(snapshot.data[index])
      // ),
      const MenuDivider(),
      // MenuItem.submenu(
      //   label: 'I see...',
      //   icon: Icons.view_list_sharp,
      //   items: [
      //     CustomMenuItem(
      //       label: 'Delete',
      //       value: 'delete',
      //       icon: Icons.delete,
      //       iconColor: Colors.redAccent,
      //       onSelected: () {
      //         showDialog<String>(
      //           context: context,
      //           builder: (BuildContext context) => AlertDialog(
      //             icon: const Icon(Icons.warning),
      //             iconColor: Colors.redAccent,
      //             title: const Text('Are you serious ?'),
      //             content: const Text('This action will delete this image'),
      //             actions: <Widget>[
      //               TextButton(
      //                 onPressed: () => Navigator.pop(context, 'cancel'),
      //                 child: const Text('Cancel'),
      //               ),
      //               TextButton(
      //                 onPressed: (){
      //                   Navigator.pop(context, 'ok');
      //                 },
      //                 child: const Text('Okay'),
      //               ),
      //             ],
      //           ),
      //         );
      //       },
      //     )
      //   ],
      // ),
    ];
    final contextMenu = ContextMenu(
      entries: entries,
      padding: const EdgeInsets.all(8.0),
    );

    return AnimationConfiguration.staggeredList(
      position: widget.index,
      duration: const Duration(milliseconds: 375),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: ContextMenuRegion(
              contextMenu: contextMenu,
              child: Container(
                height: 100,
                color: Colors.black,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    int i = -1;
                    List<Widget> goto = displayFiles.map<Widget>((ent){
                      i++;
                      return Positioned(
                          height: 100,
                          width: constraints.biggest.width / displayFiles.length,
                          top: 0,
                          left: ((constraints.biggest.width / displayFiles.length) * i).toDouble(),
                          child: Image.memory(
                            base64Decode(ent.thumbnail!),
                            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                              if (wasSynchronouslyLoaded) {
                                return child;
                              } else {
                                return AnimatedOpacity(
                                  opacity: frame == null ? 0 : 1,
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOut,
                                  child: child,
                                );
                              }
                            },
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          )
                        // child: ent.isLocal ? Image.file(
                        //   File(ent.fullPath),
                        //   gaplessPlayback: true,
                        //   frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                        //     if (wasSynchronouslyLoaded) {
                        //       return child;
                        //     } else {
                        //       return AnimatedOpacity(
                        //         opacity: frame == null ? 0 : 1,
                        //         duration: const Duration(milliseconds: 200),
                        //         curve: Curves.easeOut,
                        //         child: child,
                        //       );
                        //     }
                        //   },
                        //   // cacheWidth: files.length == 4 ? 100 : (constraints.biggest.width / files.length).round(),
                        //   fit: BoxFit.cover,
                        // ) : Image.network(
                        //     ent.thumbnail ?? ent.fullPath,
                        //     fit: BoxFit.cover
                        // ),
                      );
                    }).toList();
                    goto.add(Container(color: Colors.black.withOpacity(0.35)));
                    goto.add(Positioned(
                        bottom: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.folder.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                              Container(
                                  decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.3),
                                      border: Border.all(
                                        color: Colors.black.withOpacity(0.5),
                                      ),
                                      borderRadius: const BorderRadius.all(Radius.circular(20))
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 4),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.image, color: Colors.white70, size: 12),
                                      const Gap(3),
                                      Text(origFiles.length.toString(), style: const TextStyle(fontSize: 12, color: Colors.white)),
                                    ],
                                  )
                              )
                            ],
                          ),
                        )
                    ));
                    goto.add(Positioned.fill(child: Material(color: Colors.transparent, child: InkWell(onTap: () => widget.onTap()))));
                    goto.add(AnimatedPositioned(
                      top: 100 / 2 - 42 / 2,
                      right: widget.active ? 0 : -12,
                      duration: const Duration(seconds: 1),
                      curve: Curves.ease,
                      child: Container(
                        width: 12,
                        height: 42,
                        decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8))
                        ),
                      ),
                    ));
                    return Stack(clipBehavior: Clip.none, children: goto);
                  },
                ),
              )
          ),
        ),
      ),
    );
  }
}

class FloatPreview extends StatefulWidget{
  final void Function(Function(PointerHoverEvent event, ImageMeta im)) initializer;

  const FloatPreview({ super.key, required this.initializer });

  @override
  State<FloatPreview> createState() => _FloatPreviewState();
}

class _FloatPreviewState extends State<FloatPreview> {

  ImageMeta? display;
  bool top = true;
  bool left = true;

  void changePos(PointerHoverEvent event, ImageMeta im){
    if(mounted) {
      setState(() {
      display = im;
      top = event.position.dy > MediaQuery.of(context).size.height / 2;
      left = event.position.dx > MediaQuery.of(context).size.width / 2;
    });
    }
  }

  @override
  void initState(){
    super.initState();
    widget.initializer(changePos);
  }

  @override
  Widget build(BuildContext context) {
    return display != null ? AnimatedAlign(
      alignment: top && left ? Alignment.bottomLeft : top && !left ? Alignment.bottomRight : !top && left ? Alignment.topLeft : Alignment.topRight,
      duration: const Duration(milliseconds: 50),
      curve: Curves.ease,
      child: AnimatedSizeAndFade(
        sizeDuration: const Duration(milliseconds: 50),
        sizeCurve: Curves.linear,
        child: Container(
          margin: const EdgeInsets.all(18),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 80 / 100,
            maxWidth: MediaQuery.of(context).size.width / 3
          ),
          decoration: BoxDecoration(
            color: Colors.black,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                spreadRadius: 5,
                blurRadius: 7,
                offset: const Offset(0, 3), // changes position of shadow
              ),
            ],
          ),
          child: display!.isLocal ? Image.file(File(display!.fullPath!), gaplessPlayback: true) : CachedNetworkImage(
            imageUrl: display!.fullNetworkPath ?? context.read<ImageManager>().getter.getFullUrlImage(display!),
              progressIndicatorBuilder: (context, url, downloadProgress) => Stack(
                children: [
                  Image.memory(
                    base64Decode(display!.thumbnail ?? ''),
                    filterQuality: FilterQuality.low,
                    gaplessPlayback: true,
                  ),
                  Shimmer.fromColors(
                      baseColor: Colors.transparent,
                      highlightColor: Colors.white.withAlpha(90),
                      child: Image.memory(
                        base64Decode(display!.thumbnail ?? ''),
                        filterQuality: FilterQuality.low,
                        gaplessPlayback: true,
                      )
                  ),
                ],
              )
          )
        ),
      )
    ) : const SizedBox.shrink();
  }
}

class SidePreview extends StatefulWidget{
  final void Function(Function(PointerHoverEvent event, ImageMeta im)) initializer;

  const SidePreview({ super.key, required this.initializer });

  @override
  State<SidePreview> createState() => _SidePreviewState();
}

class _SidePreviewState extends State<SidePreview> {

  ImageMeta? display;

  void changeImage(PointerHoverEvent event, ImageMeta im){
    if(mounted) {
      setState(() {
      display = im;
    });
    }
  }

  @override
  void initState(){
    super.initState();
    widget.initializer(changeImage);
  }

  @override
  Widget build(BuildContext context) {
    return display != null ? display!.isLocal ? Image.file(File(display!.fullPath!), gaplessPlayback: true) : CachedNetworkImage(
      imageUrl: display!.fullNetworkPath ?? context.read<ImageManager>().getter.getFullUrlImage(display!),
      progressIndicatorBuilder: (context, url, downloadProgress) => Stack(
          children: [
            Center(
              child: Stack(
                children: [
                  Image.memory(
                    base64Decode(display!.thumbnail ?? ''),
                    filterQuality: FilterQuality.low,
                    gaplessPlayback: true,
                  ),
                  Shimmer.fromColors(
                      baseColor: Colors.transparent,
                      highlightColor: Colors.white.withAlpha(90),
                      child: Image.memory(
                        base64Decode(display!.thumbnail ?? ''),
                        filterQuality: FilterQuality.low,
                        gaplessPlayback: true,
                      )
                  ),
                ],
              ),
            ),
            Padding(padding: EdgeInsets.all(14), child: LinearProgressIndicator(value: downloadProgress.progress, color: Colors.white))
          ]
      )
    ) : const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_search_outlined, size: 50, color: Colors.white),
          Gap(4),
          Text('Well well well...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          Text('Just hover over the image to see it', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}


MaterialPageRoute _createGalleryDetailRoute(List<dynamic> images, int currentIndex) {
  return MaterialPageRoute(
    builder: (context) => GalleryImageFullMain(
      images: images,
      currentIndex: currentIndex,
    ),
  );
}

class XYZPlotForHiRes extends StatefulWidget{
  final int sectionID;
  final int index;

  const XYZPlotForHiRes(this.sectionID, this.index, { super.key });

  @override
  State<XYZPlotForHiRes> createState() => _XYZPlotForHiResState();
}

class _XYZPlotForHiResState extends State<XYZPlotForHiRes> {
  bool loaded = false;
  List<ImageMeta> images = [];

  Map<String, List<ImageMeta>> hashes = {};

  @override
  void initState(){
    super.initState();
    get();
  }

  void get(){
    context.read<ImageManager>().getter.getFolderFiles(widget.sectionID, widget.index).then((List<ImageMeta> value) {
      for (var i = 0; i < value.length-1; i++) {
        List<timeline.Difference> d = timeline.findDifference(value[i], value[i+1]);
        //print('${d.length} ${d.length == 1 ? d.first.key : '-'}');
        if(d.length == 1){
          String hash = timeline.getGenerationHash(value[i+1], except: d.first.key);
          if(hashes.containsKey(hash)){
            hashes[hash]!.add(value[i+1]);
          } else {
            hashes[hash] = [value[i], value[i+1]];
          }
        }
      }
      setState(() {
        loaded = true;
        images = value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final imageManager = Provider.of<ImageManager>(context);
    return loaded ? ListView.separated(
      separatorBuilder: (BuildContext context, int index){
        return const Divider(height: 17, color: Colors.red,);
      },
      itemCount: hashes.keys.length,
      itemBuilder: (BuildContext context, int index) {
        List<ImageMeta> l = hashes[hashes.keys.toList(growable: false)[index]]!;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 250,
              height: 250,
              child: GridView.count(
                crossAxisSpacing: 3,
                mainAxisSpacing: 3,
                crossAxisCount: 2,
                children: l.map((e) => GestureDetector(
                  onTap: () {
                    Navigator.push(
                        context,
                        _createGalleryDetailRoute(
                            [e],
                            0
                        )
                    );
                  },
                  child: ImageWidget(e),
                )).toList(),
              ),
            ),
            const Gap(8),
            Expanded(child: SelectableText(l.where((e) => imageManager.favoritePaths.contains(e.fullPath)).map((e) => e.generationParams?.seed ?? '-').join(',')))
          ],
        );
      },
    ) : const CircularProgressIndicator();
  }
}

class PreviewImage extends StatelessWidget {
  final ImageMeta imageMeta;
  final SelectedModel selectedModel;
  final List<ImageMeta> imagesList;
  final VoidCallback onImageTap;
  final Function(PointerHoverEvent event, ImageMeta im) onHover;
  final int index;

  final bool dontBlink = true;

  const PreviewImage({ super.key, required this.imageMeta, required this.selectedModel, required this.imagesList, required this.onImageTap, required this.onHover, this.index = -1});

  @override
  Widget build(BuildContext context) {
    final imageManager = Provider.of<ImageManager>(context);
    return Consumer<SelectedModel>(
        builder: (context, sp, child) {
          final dataModel = Provider.of<DataModel>(context, listen: false);

          final entries = <ContextMenuEntry>[
            if(!sp.hasSelected) MenuItem(
              label: 'Select',
              icon: Icons.add_circle_outline,
              onSelected: () {
                sp.add(imageMeta.keyup);
              },
            ),
            MenuItem(
              label: 'DeSelect all',
              icon: Icons.remove_circle_outline,
              onSelected: () {
                sp.removeAll();
              },
            ),
            MenuItem(
              label: imageManager.favoritePaths.contains(imageMeta.fullPath) ? 'UnLike': 'Like',
              icon: imageManager.favoritePaths.contains(imageMeta.fullPath) ? Icons.star : Icons.star_outline,
              onSelected: () {
                imageManager.toogleFavorite(imageMeta.fullPath!, host: imageMeta.host);
              },
            ),
            const MenuDivider(),
            MenuItem(
              label: 'View render tree',
              icon: Icons.account_tree_sharp,
              onSelected: () {
                // implement copy
              },
            ),
            MenuItem.submenu(
              label: 'Send to comparison',
              icon: Icons.edit,
              items: [
                MenuItem(
                  label: 'Go to viewer',
                  value: 'comparison_view',
                  icon: Icons.compare,
                  onSelected: () {
                    if(sp.selectedCo == 0){
                      dataModel.comparisonBlock.addAllImages(imagesList);
                    }
                    dataModel.jumpToTab(3);
                  },
                ),
                MenuItem(
                  label: 'View only favorite',
                  value: 'comparison_view_favorite',
                  icon: Icons.compare,
                  onSelected: () {
                    if(sp.selectedCo == 0){
                      dataModel.comparisonBlock.addAllImages(imagesList.where((el) => imageManager.favoritePaths.contains(el.fullPath)).toList());
                    }
                    dataModel.jumpToTab(3);
                  },
                ),
                const MenuDivider(),
                MenuItem(
                  label: 'As main',
                  value: 'comparison_as_main',
                  icon: Icons.swipe_left,
                  onSelected: () {
                    dataModel.comparisonBlock.changeSelected(0, imageMeta);
                    // implement redo
                  },
                ),
                MenuItem(
                  label: 'As test',
                  value: 'comparison_as_test',
                  icon: Icons.swipe_right,
                  onSelected: () {
                    dataModel.comparisonBlock.changeSelected(1, imageMeta);
                  },
                ),
              ],
            ),
            if(imageMeta.generationParams!.seed != null )MenuItem.submenu(
              label: 'View in timeline',
              icon: Icons.view_timeline_outlined,
              items: [
                MenuItem(
                  label: 'by seed',
                  value: 'timeline_by_seed',
                  icon: Icons.compare,
                  onSelected: () {
                    dataModel.timelineBlock.setSeed(imageMeta.generationParams!.seed!);
                    dataModel.jumpToTab(2);
                  },
                ),
              ],
            ),
            const MenuDivider(),
            MenuItem(
              label: 'Send to MiniSD',
              value: 'send_to_minisd',
              icon: Icons.web_rounded,
              onSelected: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => MiniSD(imageMeta: imageMeta)));
                // implement redo
              },
            ),
            MenuItem.submenu(
              label: 'Build...',
              icon: Icons.build,
              items: [
                MenuItem(
                  label: 'XYZ plot',
                  icon: Icons.grid_view,
                  onSelected: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => XYZBuilder(images: imagesList)));
                  },
                )
              ],
            ),
            const MenuDivider(),
            MenuItem(
              label: 'Show in explorer',
              value: 'show_in_explorer',
              icon: Icons.compare,
              onSelected: () {
                showInExplorer(imageMeta.fullPath!);
              },
            ),
            MenuItem.submenu(
              label: 'Copy...',
              icon: Icons.copy,
              items: [
                if(imageMeta.generationParams?.seed != null) MenuItem(
                  label: 'Seed',
                  icon: Icons.abc,
                  onSelected: () async {
                    String seed = imageMeta.generationParams!.seed.toString();
                    Clipboard.setData(ClipboardData(text: seed)).then((value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Seed $seed copied'),
                    )));
                  },
                ),
                MenuItem(
                  label: 'Folder/file.name',
                  icon: Icons.arrow_forward,
                  onSelected: () {
                    Clipboard.setData(ClipboardData(text: '${File(imageMeta.fullPath!).parent}/${imageMeta.fileName}')).then((value) => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Copied'),
                    )));
                  },
                ),
                MenuItem(
                  label: 'Favorite images to folder...',
                  icon: Icons.star,
                  onSelected: () async {
                    // imagesList.where((el) => imageManager.favoritePaths.contains(el.fullPath)
                    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
                    if (selectedDirectory != null) {
                      Iterable<ImageMeta> l = imagesList.where((el) => imageManager.favoritePaths.contains(el.fullPath));
                      if(l.isNotEmpty){
                        int notID = notificationManager!.show(
                            title: 'Copying files',
                            description: 'Now we will copy ${l.length} files to\n$selectedDirectory',
                            content: Container(
                              margin: const EdgeInsets.only(top: 7),
                              width: 100,
                              child: const LinearProgressIndicator(),
                            )
                        );
                        for(ImageMeta m in l){
                          await File(m.fullPath!).copy(p.join(selectedDirectory, m.fileName));
                        }
                        notificationManager!.close(notID);
                      }
                    }
                  },
                )
              ],
            ),
            if(sp.hasSelected) CustomMenuItem(
              label: 'Delete selected',
              value: 'delete_selected',
              icon: Icons.delete,
              iconColor: Colors.redAccent,
              onSelected: () {
                showDialog<String>(
                  context: context,
                  builder: (BuildContext context) => AlertDialog(
                    icon: const Icon(Icons.warning),
                    iconColor: Colors.redAccent,
                    title: const Text('Are you serious ?'),
                    content: Text('This action will delete ${sp.totalSelected} images permanently'),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.pop(context, 'cancel'),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: (){
                          Navigator.pop(context, 'ok');
                        },
                        child: const Text('Okay'),
                      ),
                    ],
                  ),
                );
              },
            ),
            CustomMenuItem(
              label: 'Delete',
              value: 'delete',
              icon: Icons.delete,
              iconColor: Colors.redAccent,
              onSelected: () {
                showDialog<String>(
                  context: context,
                  builder: (BuildContext context) => AlertDialog(
                    icon: const Icon(Icons.warning),
                    iconColor: Colors.redAccent,
                    title: const Text('Are you serious ?'),
                    content: const Text('This action will delete this image'),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.pop(context, 'cancel'),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: (){
                          Navigator.pop(context, 'ok');
                        },
                        child: const Text('Okay'),
                      ),
                    ],
                  ),
                );
              },
            )
          ];
          final contextMenu = ContextMenu(
            entries: entries,
            padding: const EdgeInsets.all(8.0),
          );

          //Rating
          ContentRating r = imageMeta.generationParams!.contentRating;
          Widget ratingBlock = Container(
            margin: const EdgeInsets.only(bottom: 3),
            width: 18,
            height: 18,
            padding: const EdgeInsets.only(left: 2, right: 2, bottom: 1),
            decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(2)),
                color: Color(r == ContentRating.X || r == ContentRating.XXX ? 0xff000000 : 0xffffffff).withOpacity(0.7)
            ),
            child: Text(r.name, textAlign: TextAlign.center, style: TextStyle(color: Color([
              0xff5500ff,
              0xff006835,
              0xfff15a24,
              0xff803d99,
              0xffd8121a,
              0xff1b3e9b,
              0xffffffff,
              0xffffffff
            ][r.index]), fontSize: 12, fontWeight: FontWeight.bold)),
          );

          return GestureDetector(
              onLongPress: () {
                if (sp.selected.isEmpty) {
                  sp.add(imageMeta.keyup);
                } else {
                  sp.removeAll();
                }
              },
              onTap: () {
                //print('tap ${sp.selected.isNotEmpty} ${sp.selected.length}');
                if (sp.selected.isNotEmpty) {
                  //print(imageMeta.keyup);
                  if (sp.selected.contains(imageMeta.keyup)) {
                    sp.remove(imageMeta.keyup);
                  } else {
                    sp.add(imageMeta.keyup);
                  }
                } else {
                  onImageTap();
                }
              },
              child: MouseRegion(
                onHover: (PointerHoverEvent event){
                  onHover(event, imageMeta);
                },
                child: ContextMenuRegion(
                    contextMenu: contextMenu,
                    child: AspectRatio(
                        aspectRatio: imageMeta.size!.width / imageMeta.size!.height,
                        child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Stack(
                              alignment: Alignment.topRight,
                              children: [
                                AnimatedScale(
                                    scale: sp.selected.contains(imageMeta.keyup) ? 0.9 : 1,
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.ease,
                                    child: ImageWidget(imageMeta, dontBlink: dontBlink)
                                ),
                                AnimatedScale(
                                  scale: imageManager.favoritePaths.contains(imageMeta.fullPath) ? 1 : 0,
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.ease,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    padding:
                                    const EdgeInsets.all(4),
                                    margin: const EdgeInsets.only(top: 4, right: 4),
                                    child: Icon(Icons.star, size: 16, color: Theme.of(context).colorScheme.onSecondary),
                                  ),
                                ),
                                AnimatedScale(
                                  scale: imageMeta.runtimeType == ImageMeta ? sp.selected.contains(imageMeta.keyup) ? 1 : 0 : 0,
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.ease,
                                  child: Container(
                                      decoration:
                                      BoxDecoration(
                                        color: Theme.of(context).colorScheme.secondary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.check, color: Theme.of(context).colorScheme.onSecondary)
                                  ),
                                ),
                                Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                              colors: [
                                                Color.fromRGBO(0, 0, 0, 0.0),
                                                Color.fromRGBO(0, 0, 0, 0.4),
                                                Color.fromRGBO(0, 0, 0, 0.8)
                                              ],
                                              stops: [0, 0.2, 1.0],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            ratingBlock,
                                            Container(
                                              margin: const EdgeInsets.only(bottom: 3),
                                              padding: const EdgeInsets.only(left: 2, right: 2, bottom: 1),
                                              decoration: BoxDecoration(
                                                  borderRadius: const BorderRadius.all(Radius.circular(2)),
                                                  color: Colors.grey.withOpacity(0.7)
                                              ),
                                              child: Text(imageMeta.fileName.split('-').first, style: const TextStyle(color: Color(0xfff1fcff), fontSize: 8)),
                                            ),
                                            Container(
                                              margin: const EdgeInsets.only(bottom: 3),
                                              padding: const EdgeInsets.only(left: 2, right: 2, bottom: 1),
                                              decoration: BoxDecoration(
                                                  borderRadius: const BorderRadius.all(Radius.circular(2)),
                                                  color: const Color(0xFF5fa9b5).withOpacity(0.7)
                                              ),
                                              child: Text(renderEngineToString(imageMeta.re), style: const TextStyle(color: Color(0xfff1fcff), fontSize: 8)),
                                            ),
                                            imageMeta.generationParams?.denoisingStrength != null && imageMeta.generationParams?.hiresUpscale != null ? Tooltip(
                                              message: '${imageMeta.generationParams?.hiresUpscale != null ? '${imageMeta.generationParams!.hiresUpscale}x ${imageMeta.generationParams!.hiresUpscaler != null ? imageMeta.generationParams!.hiresUpscaler == 'None' ? 'None (Lanczos)' : imageMeta.generationParams!.hiresUpscaler : 'None (Lanczos)'}, ' : ''}${imageMeta.generationParams!.denoisingStrength}',
                                              child: Container(
                                                padding: const EdgeInsets.only(left: 2, right: 2, bottom: 1),
                                                decoration: BoxDecoration(
                                                    borderRadius: const BorderRadius.all(Radius.circular(2)),
                                                    color: const Color(0xff5f55a6).withOpacity(0.7)
                                                ),
                                                child: const Text('Hi-Res', style: TextStyle(color: Color(0xffc8c4f5), fontSize: 12)),
                                              ),
                                            ) : const SizedBox.shrink(),
                                          ],
                                        )
                                    )
                                ),
                                // Positioned(
                                //     top: 4,
                                //     left: 4,
                                //     child: Container(width: 10, height: 10, color: imageMeta.isLocal ? Colors.greenAccent : Colors.red)
                                // )
                              ],
                            )
                        )
                    )
                ),
              )
          );
        }
    );
  }
}

class ImageWidget extends StatelessWidget{
  final ImageMeta imageMeta;
  final bool dontBlink;

  const ImageWidget(this.imageMeta, {this.dontBlink = true, super.key});

  @override
  Widget build(BuildContext context) {
    return imageMeta.thumbnail != null ? AspectRatio(aspectRatio: imageMeta.size!.width / imageMeta.size!.height, child: Image.memory(
      base64Decode(imageMeta.thumbnail ?? ''),
      filterQuality: FilterQuality.low,
      gaplessPlayback: dontBlink,
    )) : !imageMeta.isLocal && imageMeta.networkThumbnail != null ? CachedNetworkImage(
      imageUrl: imageMeta.networkThumbnail!,
      imageBuilder: (context, imageProvider) {
        return AspectRatio(aspectRatio: imageMeta.size!.width / imageMeta.size!.height, child: Image(image: imageProvider, gaplessPlayback: true));
      },
      progressIndicatorBuilder: (context, url, downloadProgress) => Shimmer.fromColors(
        baseColor: Colors.transparent,
        highlightColor: Colors.white30,
        child: AspectRatio(aspectRatio: imageMeta.size!.width / imageMeta.size!.height),
      ),
      errorWidget: (context, url, error) => Padding(padding: const EdgeInsets.all(8), child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, color: Colors.white, size: 28),
          const Text('Error', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const Gap(8),
          SelectableText(error.toString(), style: const TextStyle(color: Colors.grey))
        ],
      )),
    ) : const Text('No preview ?');
  }

}

class InProcess extends StatelessWidget{
  const InProcess({super.key});

  @override
  Widget build(BuildContext context) {
    final imageManager = Provider.of<ImageManager>(context, listen: true);
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Processing in the process lol', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(imageManager.lastJob, textAlign: TextAlign.center),
            const Gap(6),
            Stack(
              alignment: Alignment.center,
              children: [
                const CircularProgressIndicator(),
                Center(
                  child: Text(imageManager.jobCount.toString()),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}

class EmplyFolderPlaceholder extends StatelessWidget{
  const EmplyFolderPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    bool isNull = context.read<ConfigManager>().isNull;
    return LayoutBuilder(builder: (context, constraints) {
      return Container(
        color: const Color(0xffe5e5e5),
        child: Center(
          child: Container(
            height: constraints.maxHeight / 2,
            color: Colors.white,
            child: Stack(
              children: [
                Positioned(
                  right: 0,
                  top: 0,
                  left: constraints.maxWidth / 2,
                  bottom: 0,
                  child: Icon(Icons.folder_copy, color: const Color(0xffd87034), size: constraints.maxHeight / 3),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  bottom: 0,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 50),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Уууупсс!', style: TextStyle(color: Colors.black, fontSize: 32, fontWeight: FontWeight.bold)),
                        const Gap(8),
                        const Text('Кажется, произошла ошибка', style: TextStyle(color: Colors.grey)),
                        isNull ? Row(
                          children: [
                            const Text('П', style: TextStyle(color: Colors.grey)),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                const Text('о', style: TextStyle(color: Colors.grey)),
                                Positioned(
                                  top: 12,
                                    child: Container(
                                    height: 1,
                                    width: 10,
                                    color: Colors.grey,
                                  )
                                )
                              ],
                            ),
                            const Text('апка пустая, поэтому наполните её чем-то и мы проверим её', style: TextStyle(color: Colors.grey))
                          ],
                        ) : const Text('Похоже папка пустая. Проверьте пустая ли папка или нет', style: TextStyle(color: Colors.grey)),
                        const Gap(14),
                        TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xffd87034).withOpacity(0.2),
                            foregroundColor: const Color(0xffd87034)
                          ),
                          onPressed: () {
                            showDialog<String>(
                              context: context,
                              builder: (BuildContext context) => AlertDialog(
                                icon: const Icon(Icons.warning),
                                iconColor: Colors.yellowAccent,
                                title: const Text('This feature is not ready yet'),
                                content: const Text('sorry ('),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, 'OK'),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Text(isNull ? 'Уже заполнили ? Проверить' : 'Проверили ? Проиндексировать',style: const TextStyle(fontWeight: FontWeight.w400)),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ); // Create a function here to adapt to the parent widget's constraints
    });
  }
}

class SelectedModel extends ChangeNotifier {
  int selectedCo = 0;

  final List<String> _selectedKeyUp = [];

  List<String> get selected => _selectedKeyUp;

  int get totalSelected => _selectedKeyUp.length;

  bool get hasSelected => _selectedKeyUp.isNotEmpty;

  void add(String keyup) {
    if (_selectedKeyUp.contains(keyup)) return;
    _selectedKeyUp.add(keyup);
    notifyListeners();
  }

  void remove(String keyup) {
    if (!_selectedKeyUp.contains(keyup)) return;
    _selectedKeyUp.remove(keyup);
    notifyListeners();
  }

  void removeAll() {
    _selectedKeyUp.clear();
    notifyListeners();
  }
}