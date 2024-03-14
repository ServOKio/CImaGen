import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cimagen/components/SetupRequired.dart';
import 'package:cimagen/utils/DataModel.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:cimagen/utils/SQLite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:cimagen/Utils.dart';
import 'package:path/path.dart' as p;

import '../components/CustomMasonryView.dart';
import '../components/PortfolioGalleryDetailPage.dart';

class Gallery extends StatefulWidget{
  const Gallery({ Key? key }): super(key: key);

  @override
  _GalleryState createState() => _GalleryState();
}

Future<List<Folder>> _loadMenu(String path) async {
  List<Folder> f = [];
  int ind = 0;
  Directory di = Directory(path);
  List<FileSystemEntity> fe = await dirContents(di);
  for(FileSystemEntity ent in fe){
    f.add(
        Folder(
            index: ind,
            path: ent.path,
            name: p.basename(ent.path),
            files: (await dirContents(Directory(ent.path))).map((ent) => p.normalize(ent.path)).toList()
        )
    );
    ind++;
  }
  return f;
}

Future<List<FileSystemEntity>> dirContents(Directory dir) {
  var files = <FileSystemEntity>[];
  var completer = Completer<List<FileSystemEntity>>();
  var lister = dir.list(recursive: false);
  lister.listen(
          (file) => files.add(file),
      onDone:   () => completer.complete(files)
  );
  return completer.future;
}

class _GalleryState extends State<Gallery> with TickerProviderStateMixin {
  int _t2iSelected = 0;
  int _i2iSelected = 0;

  bool sr = false;

  SelectedModel model = SelectedModel();

  late Future<List<Folder>> txt2imgList;
  late Future<List<Folder>> img2imgList;

  Future<List<ImageMeta>>? imagesList;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    var go = context
        .read<ConfigManager>()
        .config['outdir_txt2img_samples'];
    if (go == null) {
      sr = true;
    } else {
      String path = context
          .read<ConfigManager>()
          .config['outdir_txt2img_samples'];
      txt2imgList = _loadMenu(path);
      txt2imgList.then((value) => imagesList = context.read<SQLite>().getImagesByParent(_tabController.index == 0 ? RenderEngine.txt2img : RenderEngine.img2img, value[0].name));
      path = context
          .read<ConfigManager>()
          .config['outdir_img2img_samples'];
      img2imgList = _loadMenu(path);
    }
  }

  void changeTab(int type, int index) {
    setState(() {
      if(type == 0){
        _t2iSelected = index;
      } else {
        _i2iSelected = index;
      }
    });

    [txt2imgList, img2imgList][type].then((value) {
      Folder f = value[index];
      imagesList = context.read<SQLite>().getImagesByParent(type == 0 ? RenderEngine.txt2img : RenderEngine.img2img, f.name);
      imagesList?.then((value) {
        if(value.isEmpty) {
          for (String p in f.files) {
            context.read<ImageManager>().updateIfNado(type == 0 ? RenderEngine.txt2img : RenderEngine.img2img, p);
          }
        }
      });
    });
  }

  late final TabController _tabController;

  Widget _buildNavigationRail() {
    return SizedBox(
      width: 200,
      child: Column(
        children: [
          TabBar.secondary(
            controller: _tabController,
            tabs: const <Widget>[
              Tab(text: 'txt2img'),
              Tab(text: 'img2img'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: <Widget>[
                FutureBuilder(
                  future: txt2imgList,
                  builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
                    Widget c;
                    if (snapshot.hasData) {
                      c = ListView.separated(
                        separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 4),
                        itemCount: snapshot.data.length,
                        itemBuilder: (context, index) {
                          List<String> paths = [];

                          if(snapshot.data[index].files.length <= 4){
                            paths = snapshot.data[index].files;
                          } else {
                            for (var i = 0; i < 4; i++) {
                              paths.add(snapshot.data[index].files[i]);
                            }
                          }

                          return Container(
                            height: 100,
                            color: Colors.black,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                int i = -1;
                                List<Widget> goto = paths.map<Widget>((ent){
                                  i++;
                                  return Positioned(
                                    height: 100,
                                    width: constraints.biggest.width / paths.length,
                                    top: 0,
                                    left: ((constraints.biggest.width / paths.length) * i).toDouble(),
                                    child: Image.file(File(ent), fit: BoxFit.cover),
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
                                          Text('${snapshot.data[index].name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
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
                                                const Gap(2),
                                                Text(snapshot.data[index].files.length.toString(), style: const TextStyle(fontSize: 12, color: Colors.white))
                                              ],
                                            )
                                          )
                                        ],
                                      ),
                                    )
                                ));
                                goto.add(Positioned.fill(
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => changeTab(0, index),
                                    )
                                  )
                                ));
                                return Stack(children: goto);
                              },
                            ),
                          );
                        },
                      );
                    } else if (snapshot.hasError) {
                      c = Column(
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
                      );
                    } else {
                      c = const Column(
                        children: [
                          SizedBox(
                            width: 60,
                            height: 60,
                            child: CircularProgressIndicator(),
                          ),
                          Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Text('Awaiting result...'),
                          ),
                        ],
                      );
                    }
                    return c;
                  }
                ),
                FutureBuilder(
                  future: img2imgList,
                  builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
                    Widget c;
                    if (snapshot.hasData) {
                      c = ListView.builder(
                        itemCount: snapshot.data.length,
                        itemBuilder: (context, index) {
                          List<String> paths = [];

                          if(snapshot.data[index].files.length <= 4){
                            paths = snapshot.data[index].files;
                          } else {
                            for (var i = 0; i < 4; i++) {
                              paths.add(snapshot.data[index].files[i]);
                            }
                          }

                          return Container(
                            height: 100,
                            color: Colors.black,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                int i = -1;
                                List<Widget> goto = paths.map<Widget>((ent){
                                  i++;
                                  return Positioned(
                                    height: 100,
                                    width: constraints.biggest.width / paths.length,
                                    top: 0,
                                    left: ((constraints.biggest.width / paths.length) * i).toDouble(),
                                    child: Image.file(File(ent), fit: BoxFit.cover),
                                  );
                                }).toList();
                                goto.add(Container(color: Colors.black.withOpacity(0.35)));
                                goto.add(Positioned(
                                    bottom: 0,
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Column(
                                        children: [
                                          Text('${snapshot.data[index].name} (${snapshot.data[index].files.length})')
                                        ],
                                      ),
                                    )
                                ));
                                goto.add(Positioned.fill(
                                    child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap:() => changeTab(0, index),
                                        )
                                    )
                                ));
                                return Stack(children: goto);
                              },
                            ),
                          );
                        },
                      );
                    } else if (snapshot.hasError) {
                      c = Column(
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
                      );
                    } else {
                      c = const Column(
                        children: [
                          SizedBox(
                            width: 60,
                            height: 60,
                            child: CircularProgressIndicator(),
                          ),
                          Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Text('Awaiting result...'),
                          ),
                        ],
                      );
                    }
                    return c;
                  }
                ),
              ],
            )
          )
        ],
      ),
    );
  }

  double x = 0;
  double y = 0;

  void _updateLocation(PointerEvent details) {
    // setState(() {
    //   x = details.position.dx;
    //   y = details.position.dy;
    // });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => model,
      child:  sr
        ? const Expanded(
            child: Center(
              child: SetupRequired(webui: true, comfyui: false),
            ),
          )
        : Row(children: <Widget>[
          _buildNavigationRail(),
          Expanded(
            child: MouseRegion(
              onHover: _updateLocation,
              child: imagesList == null ? const InProcess() : FutureBuilder(
                  future: imagesList,
                  builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
                    Widget children;
                    if (snapshot.hasData) {
                      children = snapshot.data.length == 0 ? const InProcess() : SingleChildScrollView(
                        child: CustomMasonryView(
                          key: Key((_tabController.index == 0 ? _t2iSelected : _i2iSelected).toString()),
                          itemRadius: 0,
                          itemPadding: 4,
                          listOfItem: snapshot.data,
                          numberOfColumn: (MediaQuery.of(context).size.width / 200).round(),
                          itemBuilder: (ii) {
                            return PreviewImage(
                              key: Key(ii.item.keyup),
                              imagesList: snapshot.data,
                              imageMeta: ii.item,
                              selectedModel: model,
                              index: ii.index,
                              onImageTap: () {
                                Navigator.push(
                                    context,
                                    _createGalleryDetailRoute(
                                        snapshot.data,
                                        ii.index
                                    )
                                );
                              },
                            );
                          },
                        ),
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
                      children = const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Text('Awaiting result...'),
                      );
                    }
                    return children;
                  }
                  )
              )
          )
        ]
      )
    );
  }

  MaterialPageRoute _createGalleryDetailRoute(List<ImageMeta> images, int currentIndex) {
      return MaterialPageRoute(
        builder: (context) => PortfolioGalleryDetailPage(
          images: images,
          currentIndex: currentIndex,
        ),
      );
  }
}

class PreviewImage extends StatelessWidget {
  final ImageMeta imageMeta;
  final SelectedModel selectedModel;
  final List<ImageMeta> imagesList;
  final VoidCallback onImageTap;
  int? index = -1;

  final bool dontBlink = false;

  PreviewImage({ Key? key, required this.imageMeta, required this.selectedModel, required this.imagesList, required this.onImageTap, this.index}): super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<SelectedModel>(
        builder: (context, sp, child) {
          final imageManager = Provider.of<ImageManager>(context);
          final dataModel = Provider.of<DataModel>(context, listen: false);
          final entries = <ContextMenuEntry>[
            MenuItem(
              label: 'Select',
              icon: Icons.add_circle_outline,
              onSelected: () {
                sp.add(imageMeta.keyup);
              },
            ),
            MenuItem(
              label: imageManager.favoritePaths.contains(imageMeta.fullPath) ? 'UnLike': 'Like',
              icon: imageManager.favoritePaths.contains(imageMeta.fullPath) ? Icons.star : Icons.star_outline,
              onSelected: () {
                imageManager.toogleFavorite(imageMeta.fullPath);
              },
            ),
            MenuItem(
              label: 'View render history',
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
                const MenuDivider(),
                MenuItem(
                  label: 'As test',
                  value: 'comparison_as_test',
                  icon: Icons.swipe_right,
                  onSelected: () {
                    dataModel.comparisonBlock.changeSelected(1, imageMeta);
                  },
                ),
                MenuItem(
                  label: 'As main',
                  value: 'comparison_as_main',
                  icon: Icons.swipe_left,
                  onSelected: () {
                    dataModel.comparisonBlock.changeSelected(0, imageMeta);
                    // implement redo
                  },
                ),
              ],
            ),
          ];

          final contextMenu = ContextMenu(
            entries: entries,
            padding: const EdgeInsets.all(8.0),
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
              child: ContextMenuRegion(
                  contextMenu: contextMenu,
                  onItemSelected: (value) {
                    print(value);
                  },
                  child: Stack(
                    alignment: Alignment.topRight,
                    children: [
                      AnimatedScale(
                          scale: sp.selected.contains(imageMeta.keyup) ? 0.9 : 1,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.ease,
                          child: imageMeta.thumbnail != null ? Image.memory(
                            base64Decode(imageMeta.thumbnail ?? ''),
                            filterQuality: FilterQuality.low,
                            gaplessPlayback: dontBlink,
                            frameBuilder: dontBlink ? null : ((context, child, frame, wasSynchronouslyLoaded) {
                              if (wasSynchronouslyLoaded) return child;
                              return AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: frame != null ? child : AspectRatio(aspectRatio: imageMeta.size.width / imageMeta.size.height)
                              );
                            }),
                          ) : const Text('')
                      ),
                      AnimatedScale(
                        scale: imageManager
                            .favoritePaths
                            .contains(imageMeta.fullPath)
                            ? 1
                            : 0,
                        duration: const Duration(
                            milliseconds: 200),
                        curve: Curves.ease,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black
                                .withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          padding:
                          const EdgeInsets.all(
                              4),
                          margin:
                          const EdgeInsets.only(
                              top: 4, right: 4),
                          child: Icon(Icons.star,
                              size: 16,
                              color:
                              Theme.of(context)
                                  .colorScheme
                                  .onSecondary),
                        ),
                      ),
                      AnimatedScale(
                        scale:
                        sp.selected.contains(imageMeta.keyup)
                            ? 1
                            : 0,
                        duration: const Duration(
                            milliseconds: 200),
                        curve: Curves.ease,
                        child: Container(
                            decoration:
                            BoxDecoration(
                              color:
                              Theme.of(context)
                                  .colorScheme
                                  .secondary,
                              shape:
                              BoxShape.circle,
                            ),
                            child: Icon(Icons.check,
                                color: Theme.of(
                                    context)
                                    .colorScheme
                                    .onSecondary)),
                      ),
                      // Text('${index}')
                    ],
                  )
              )
          );
        }
    );
  }

}

class InProcess extends StatelessWidget{
  const InProcess({super.key});

  @override
  Widget build(BuildContext context) {
    final imageManager = Provider.of<ImageManager>(context);
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

class SelectedModel extends ChangeNotifier {
  int selectedCo = 0;

  final List<String> _selectedKeyUp = [];

  List<String> get selected => _selectedKeyUp;

  int get totalSelected => _selectedKeyUp.length;

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

class Folder {
  final int index;
  final String path;
  final String name;
  final List<String> files;

  Folder({
    required this.index,
    required this.path,
    required this.name,
    required this.files
  });
}