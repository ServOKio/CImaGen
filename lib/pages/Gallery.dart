import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cimagen/components/SetupRequired.dart';
import 'package:cimagen/pages/sub/MiniSD.dart';
import 'package:cimagen/utils/DataModel.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:cimagen/Utils.dart';
import 'package:shimmer/shimmer.dart';

import '../components/PortfolioGalleryDetailPage.dart';
import '../modules/webUI/AbMain.dart';
import '../utils/NavigationService.dart';

Future<List<Folder>> _loadMenu(RenderEngine re) async {
  return NavigationService.navigatorKey.currentContext!.read<ImageManager>().getter.getFolders(re);
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
  const Gallery({ Key? key }): super(key: key);

  @override
  State<Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<Gallery> with TickerProviderStateMixin {
  String currentKey = 'null';
  int _t2iSelected = 0;
  int _i2iSelected = 0;

  bool sr = false;

  SelectedModel model = SelectedModel();

  late Future<List<Folder>> txt2imgList;
  final ScrollController _scrollControllerOne = ScrollController();

  late Future<List<Folder>> img2imgList;
  final ScrollController _scrollControllerTwo = ScrollController();

  Future<List<dynamic>>? imagesList;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    var go = context.read<ImageManager>().getter.loaded;
    if (!go) {
      sr = true;
    } else {
      go = context.read<ImageManager>().getter.webuiPaths['outdir_txt2img-images'] != null;
      if(go){
        txt2imgList = _loadMenu(RenderEngine.txt2img);
        txt2imgList.then((value){
          if(mounted && value.isNotEmpty) {
            setState(() {
              imagesList = context.read<ImageManager>().getter.getFolderFiles(RenderEngine.txt2img, value[0].name);
            });
          }

        });
        go = context.read<ImageManager>().getter.webuiPaths['outdir_img2img-images'] != null;
        if (go) {
          img2imgList = _loadMenu(RenderEngine.img2img);
        }
      }

      _scrollControllerOne.addListener(onScrollOne);
      _scrollControllerTwo.addListener(onScrollTwo);
    }
  }

  void onScrollOne(){
    print(_scrollControllerOne.position.pixels);
  }

  void onScrollTwo(){
    print(_scrollControllerTwo.position.pixels);
  }

  @override
  void dispose(){
    super.dispose();
    _scrollControllerOne.removeListener(onScrollOne);
    _scrollControllerTwo.removeListener(onScrollTwo);
  }

  void changeTab(int type, int index) {
    setState(() {
      if(type == 0){
        _t2iSelected = index;
      } else {
        _i2iSelected = index;
      }
      currentKey = '$type:$index';
    });


    [txt2imgList, img2imgList][type].then((listValue) {
      Folder f = listValue[index];
      imagesList = context.read<ImageManager>().getter.getFolderFiles(type == 0 ? RenderEngine.txt2img : RenderEngine.img2img, f.name);
      // imagesList = context.read<SQLite>().getImagesByParent(type == 0 ? RenderEngine.txt2img : RenderEngine.img2img, f.name);
      imagesList?.then((value) {
        bool force = value.length-1 == index;
        if(value.isEmpty || force) {
          // context.read<ImageManager>().getter.indexFolder(type == 0 ? RenderEngine.txt2img : RenderEngine.img2img, f.name).then((jobID){
          //
          // });
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
                _fBuilder(0),
                _fBuilder(1)
              ],
            )
          )
        ],
      ),
    );
  }

  Widget _fBuilder(int type){
    return FutureBuilder(
        future: type == 0 ? txt2imgList : img2imgList,
        builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
          Widget c;
          if (snapshot.hasData) {
            c = ListView.separated(
              controller: _scrollControllerOne,
              separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 4),
              itemCount: snapshot.data.length,
              itemBuilder: (context, index) {
                List<FolderFile> files = [];

                if(snapshot.data[index].files.length <= 4){
                  files = snapshot.data[index].files;
                } else {
                  for (var i = 0; i < 4; i++) {
                    files.add(snapshot.data[index].files[i]);
                  }
                }

                return Container(
                  height: 100,
                  color: Colors.black,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      int i = -1;
                      List<Widget> goto = files.map<Widget>((ent){
                        i++;
                        return Positioned(
                          height: 100,
                          width: constraints.biggest.width / files.length,
                          top: 0,
                          left: ((constraints.biggest.width / files.length) * i).toDouble(),
                          child: ent.isLocal ? Image.file(File(ent.fullPath), fit: BoxFit.cover) : Image.network(ent.thumbnail ?? ent.fullPath, fit: BoxFit.cover),
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
                      goto.add(Positioned.fill(child: Material(color: Colors.transparent, child: InkWell(onTap: () => changeTab(type, index)))));
                      goto.add(AnimatedPositioned(
                        top: 100 / 2 - 42 / 2,
                        right: (type == 0 ? _t2iSelected : _i2iSelected) == index ? 0 : -12,
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
                );
              },
            );
          } else if (snapshot.hasError) {
            c = Column(
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
            );
          } else {
            c = const Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
    final screenWidth = MediaQuery.of(context).size.width;
    const breakpoint = 600.0;
    return ChangeNotifierProvider(
      create: (context) => model,
      child:  sr
        ? const Center(child: SetupRequired(webui: true, comfyui: false))
        : screenWidth >= breakpoint || !(Platform.isAndroid || Platform.isIOS) ? Row(children: <Widget>[
          _buildNavigationRail(),
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
          child: SizedBox(
            width: 200,
            child: Drawer(
            child: _buildNavigationRail(),
            ),
          ),
        )
      )
    );
  }

  Widget _buildMainSection(){
    return MouseRegion(
        onHover: _updateLocation,
        child: imagesList == null ? const InProcess() : FutureBuilder(
            key: Key(currentKey),
            future: imagesList,
            builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
              Widget children;
              if (snapshot.hasData) {
                children = snapshot.data.length == 0 ? const EmplyFolderPlaceholder() : MasonryGridView.count(
                    itemCount: snapshot.data.length,
                    mainAxisSpacing: 5,
                    crossAxisSpacing: 5,
                    crossAxisCount: (MediaQuery.of(context).size.width / 200).round(),
                    itemBuilder: (context, index) {
                      var it = snapshot.data[index];
                      return PreviewImage(
                        key: Key(it.keyup),
                        imagesList: snapshot.data,
                        imageMeta: it,
                        selectedModel: model,
                        index: index,
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
                    });
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Loading...'),
                      Gap(8),
                      LinearProgressIndicator()
                    ],
                  )
                );
              }
              return children;
            })
    );
  }

  MaterialPageRoute _createGalleryDetailRoute(List<dynamic> images, int currentIndex) {
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
  final List<dynamic> imagesList;
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
                imageManager.toogleFavorite(imageMeta.fullPath);
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
            MenuItem.submenu(
              label: 'View in timeline',
              icon: Icons.view_timeline_outlined,
              items: [
                MenuItem(
                  label: 'by seed',
                  value: 'timeline_by_seed',
                  icon: Icons.compare,
                  onSelected: () {
                    dataModel.timelineBlock.setSeed(imageMeta.generationParams!.seed);
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
            const MenuDivider(),
            MenuItem(
              label: 'Show in explorer',
              value: 'show_in_explorer',
              icon: Icons.compare,
              onSelected: () {
                showInExplorer(imageMeta.fullPath);
              },
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
                print(imageMeta.generationParams!.toJsonString());
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
                          child: imageMeta.isLocal && imageMeta.thumbnail != null ? Image.memory(
                            base64Decode(imageMeta.thumbnail ?? ''),
                            filterQuality: FilterQuality.low,
                            gaplessPlayback: dontBlink,
                            frameBuilder: dontBlink ? null : ((context, child, frame, wasSynchronouslyLoaded) {
                              if (wasSynchronouslyLoaded) return child;
                              return AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: frame != null ? child : imageMeta.size != null ? AspectRatio(aspectRatio: imageMeta.size!.width / imageMeta.size!.height) : CircularProgressIndicator()
                              );
                            }),
                          ) : !imageMeta.isLocal && imageMeta.networkThumbnail != null ? CachedNetworkImage(
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
                          ) : const Text('No preview ?')
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
                        scale: imageMeta.runtimeType == ImageMeta ? sp.selected.contains(imageMeta.keyup)
                            ? 1
                            : 0 : 0,
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
                            child: Icon(Icons.check, color: Theme.of(context).colorScheme.onSecondary)
                        ),
                      ),
                      imageMeta.generationParams != null ? Positioned(
                        bottom: 4,
                        left: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            imageMeta.generationParams!.denoisingStrength != null && imageMeta.generationParams?.hiresUpscale != null ? Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.only(left: 2, right: 2, bottom: 1),
                                  decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.all(Radius.circular(2)),
                                      color: const Color(0xff5f55a6).withOpacity(0.7)
                                  ),
                                  child: const Text('Hi-Res', style: TextStyle(color: Color(
                                      0xffc8c4f5), fontSize: 8)),
                                ),
                                const Gap(3),
                                Text('${imageMeta.generationParams?.hiresUpscale != null ? '${imageMeta.generationParams!.hiresUpscale} ${imageMeta.generationParams!.hiresUpscaler != null ? imageMeta.generationParams!.hiresUpscaler == 'None' ? 'None (Lanczos)' : imageMeta.generationParams!.hiresUpscaler : 'None (Lanczos)'}, ' : ''}${imageMeta.generationParams!.denoisingStrength}', style: const TextStyle(fontSize: 10, color: Colors.white))
                              ],
                            ) : const SizedBox.shrink(),
                          ],
                        )
                      ) : const SizedBox.shrink(),
                      // Positioned(
                      //     top: 4,
                      //     left: 4,
                      //     child: Container(width: 10, height: 10, color: imageMeta.size == null ? Colors.redAccent : Colors.greenAccent)
                      // )
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
        color: Color(0xffe5e5e5),
        child: Center(
          child: Container(
            height: constraints.maxHeight / 2,
            color: Colors.white,
            child: Stack(
              children: [
                Positioned(
                  right: 0,
                  top: !isNull ? 0 : null,
                  left: !isNull ? constraints.maxWidth / 2 : null,
                  bottom: !isNull ? 0 : null,
                  child: isNull ? Image.asset('images/uhhh.png', height: constraints.maxHeight / 2) : Icon(Icons.folder_copy, color: Color(0xffd87034), size: constraints.maxHeight / 3),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  bottom: 0,
                  child: Padding(
                    padding: EdgeInsets.only(left: 50),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Уууупсс!', style: TextStyle(color: Colors.black, fontSize: 32, fontWeight: FontWeight.bold)),
                        Gap(8),
                        Text('Кажется, произошла ошибка', style: TextStyle(color: Colors.grey)),
                        isNull ? Row(
                          children: [
                            Text('П', style: TextStyle(color: Colors.grey)),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Text('о', style: TextStyle(color: Colors.grey)),
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
                            Text('апка пустая, поэтому наполните её чем-то и мы проверим её', style: TextStyle(color: Colors.grey))
                          ],
                        ) : Text('Похоже папка пустая. Проверьте пустая ли папка или нет', style: TextStyle(color: Colors.grey)),
                        Gap(14),
                        TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: Color(0xffd87034).withOpacity(0.2),
                            foregroundColor: Color(0xffd87034)
                          ),
                          onPressed: () {
                            showDialog<String>(
                              context: context,
                              builder: (BuildContext context) => AlertDialog(
                                icon: const Icon(Icons.warning),
                                iconColor: Colors.yellowAccent,
                                title: const Text('This feature is not ready yet'),
                                content: Text('sorry ('),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, 'OK'),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Text(isNull ? 'Уже заполнили ? Проверить' : 'Проверили ? Проиндексировать',style: TextStyle(fontWeight: FontWeight.w400)),
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