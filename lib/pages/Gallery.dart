import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cimagen/components/SetupRequired.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:cimagen/utils/SQLite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:flutter_masonry_view/flutter_masonry_view.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:cimagen/Utils.dart';
import 'package:path/path.dart' as p;

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
  int selectedCo = 0;

  bool selectMode = false;
  List<int> selected = [];

  void addSelected(int index) {
    if (selected.contains(index)) return;
    selected.add(index);
    setState(() {
      selectedCo = selected.length;
    });
  }

  void removeSelected(int index) {
    if (!selected.contains(index)) return;
    selected.remove(index);
    setState(() {
      selectedCo = selected.length;
    });
  }


  void dropSelected() {
    selected = [];
    setState(() {
      selectedCo = 0;
      selectMode = false;
    });
  }

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
      path = context
          .read<ConfigManager>()
          .config['outdir_img2img_samples'];
      img2imgList = _loadMenu(path);
    }
  }

  void changeTab(int type, int index) {
    type == 0 ? setState(() {
      _t2iSelected = index;
    }) : setState(() {
      _i2iSelected = index;
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

  final bool _isExpanded = true;
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
                      builder: (BuildContext context,
                          AsyncSnapshot<dynamic> snapshot) {
                        Widget c;
                        if (snapshot.hasData) {
                          c = SingleChildScrollView(
                              child: IntrinsicHeight(
                                  child: NavigationRail(
                                      extended: _isExpanded,
                                      labelType: NavigationRailLabelType.none,
                                      selectedIndex: _t2iSelected,
                                      onDestinationSelected: (int index) => changeTab(0, index),
                                      destinations: snapshot.data.map<NavigationRailDestination>((ent) {
                                        return NavigationRailDestination(
                                          icon: Badge(
                                            backgroundColor: const Color(
                                                0xff18171f),
                                            label: Text(
                                                ent.files.length.toString()),
                                            child: const Icon(Icons.photo),
                                          ),
                                          selectedIcon: Badge(
                                            backgroundColor: const Color(
                                                0xff474565),
                                            label: Text(
                                                ent.files.length.toString()),
                                            child: const Icon(Icons.photo),
                                          ),
                                          label: Text(ent.name + ' ' +
                                              ent.index.toString()),
                                        );
                                      }).toList()
                                  )
                              )
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
                      builder: (BuildContext context,
                          AsyncSnapshot<dynamic> snapshot) {
                        Widget c;
                        if (snapshot.hasData) {
                          c = SingleChildScrollView(
                              child: IntrinsicHeight(
                                  child: NavigationRail(
                                      extended: _isExpanded,
                                      labelType: NavigationRailLabelType.none,
                                      selectedIndex: _i2iSelected,
                                      onDestinationSelected: (int index) => changeTab(1, index),
                                      destinations: snapshot.data.map<
                                          NavigationRailDestination>((ent) {
                                        return NavigationRailDestination(
                                          icon: Badge(
                                            backgroundColor: const Color(
                                                0xff18171f),
                                            label: Text(
                                                ent.files.length.toString()),
                                            child: const Icon(Icons.photo),
                                          ),
                                          selectedIcon: Badge(
                                            backgroundColor: const Color(
                                                0xff474565),
                                            label: Text(
                                                ent.files.length.toString()),
                                            child: const Icon(Icons.photo),
                                          ),
                                          label: Text(ent.name + ' ' +
                                              ent.index.toString()),
                                        );
                                      }).toList()
                                  )
                              )
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
    final imageManager = Provider.of<ImageManager>(context, listen: false);
    print('render _GalleryState');
    return sr
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
                          child: MasonryView(
                            itemRadius: 0,
                            itemPadding: 4,
                            listOfItem: snapshot.data,
                            numberOfColumn: (MediaQuery.of(context).size.width / 200).round(),
                            itemBuilder: (item) {
                              return FutureBuilder(
                                future: [txt2imgList, img2imgList][_tabController.index],
                                builder: (BuildContext context1, AsyncSnapshot<dynamic> snapshot1) {
                                  if(snapshot.hasData){
                                    if(snapshot1.data == null) return const SizedBox.shrink();
                                    int index = snapshot1.data[_tabController.index == 0 ? _t2iSelected : _i2iSelected].files.indexOf(item.fullPath);
                                    final entries = <ContextMenuEntry>[
                                      const MenuHeader(text: "Context Menu"),
                                      MenuItem(
                                        label: imageManager.favoritePaths.contains(item) ? 'UnLike': 'Like',
                                        icon: imageManager.favoritePaths.contains(item) ? Icons.star : Icons.star_outline,
                                        onSelected: () {
                                          imageManager.toogleFavorite(item);
                                        },
                                      ),
                                      MenuItem(
                                        label: 'View render history',
                                        icon: Icons.select_all,
                                        onSelected: () {
                                          // implement copy
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
                                            label: 'As test',
                                            icon: Icons.swipe_left,
                                            onSelected: () {
                                              // implement undo
                                            },
                                          ),
                                          const MenuDivider(),
                                          MenuItem(
                                            label: 'As main',
                                            icon: Icons.swipe_right,
                                            onSelected: () {
                                              // implement redo
                                            },
                                          ),
                                        ],
                                      ),
                                      const MenuDivider(),
                                      MenuItem.submenu(
                                        label: 'Edit',
                                        icon: Icons.edit,
                                        items: [
                                          MenuItem(
                                            label: 'Undo',
                                            value: "Undo",
                                            icon: Icons.undo,
                                            onSelected: () {
                                              // implement undo
                                            },
                                          ),
                                          MenuItem(
                                            label: 'Redo',
                                            value: 'Redo',
                                            icon: Icons.redo,
                                            onSelected: () {
                                              // implement redo
                                            },
                                          ),
                                        ],
                                      ),
                                    ];

                                    final contextMenu = ContextMenu(
                                      entries: entries,
                                      position: Offset(x, y),
                                      padding: const EdgeInsets.all(8.0),
                                    );
                                    return GestureDetector(
                                        onLongPress: () {
                                          if (selected.isEmpty &&
                                              !selectMode) {
                                            selected.add(index);
                                            setState(() {
                                              selectMode = true;
                                            });
                                          } else {
                                            dropSelected();
                                          }
                                        },
                                        onTap: () {
                                          if (selectMode) {
                                            if (selected.contains(index)) {
                                              removeSelected(index);
                                            } else {
                                              addSelected(index);
                                            }
                                          } else {
                                            Navigator.push(
                                                context,
                                                _createGalleryDetailRoute(
                                                    snapshot
                                                        .data[_tabController
                                                        .index ==
                                                        0
                                                        ? _t2iSelected
                                                        : _i2iSelected]
                                                        .files,
                                                    index));
                                          }
                                        }, // Image tapped
                                        child: ContextMenuRegion(
                                            contextMenu: contextMenu,
                                            onItemSelected: (value) {
                                              print(value);
                                            },
                                            child: Stack(
                                              alignment: Alignment.topRight,
                                              children: [
                                                AnimatedScale(
                                                    scale: selected
                                                        .contains(index)
                                                        ? 0.9
                                                        : 1,
                                                    duration: const Duration(
                                                        milliseconds: 200),
                                                    curve: Curves.ease,
                                                    child: Image.memory(base64Decode(item.thumbnail))
                                                ),
                                                AnimatedScale(
                                                  scale: imageManager
                                                      .favoritePaths
                                                      .contains(item.fullPath)
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
                                                  selected.contains(index)
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
                                                )
                                              ],
                                            )
                                        )
                                    );
                                  } else {
                                    return const Text('none');
                                  }
                                }
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
    );
  }

  MaterialPageRoute _createGalleryDetailRoute(List<String> imagePaths, int index) {
      return MaterialPageRoute(
        builder: (context) => PortfolioGalleryDetailPage(
          imagePaths: imagePaths,
          currentIndex: index,
        ),
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