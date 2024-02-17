import 'dart:io';

import 'package:cimagen/components/SetupRequired.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_masonry_view/flutter_masonry_view.dart';
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
  for(FileSystemEntity ent in Directory(path).listSync()){
    f.add(Folder(path: ent.path, name: p.basename(ent.path), files: Directory(ent.path).listSync().map((ent) => ent.path).toList()));
  }
  return f;
}

class _GalleryState extends State<Gallery> {
  int _selectedIndex = 2;
  bool sr = false;

  late Future<List<Folder>> listData;

  @override
  void initState() {
    super.initState();
    var go = context.read<ConfigManager>().config['outdir_txt2img_samples'];
    if(go == null){
      sr = true;
    } else {
      String path = context.read<ConfigManager>().config['outdir_txt2img_samples'];
      listData = _loadMenu(path);
    }
    //load();
  }

  bool _isExpanded = true;
  Widget _buildNavigationRail() {
    return FutureBuilder(
      builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot){
        Widget children;
        if (snapshot.hasData) {
          children = LayoutBuilder(
              builder: (context, constraint) {
                return SingleChildScrollView(
                    child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraint.maxHeight),
                        child: IntrinsicHeight(
                            child: NavigationRail(
                                extended: _isExpanded,
                                labelType: NavigationRailLabelType.none,
                                selectedIndex: _selectedIndex,
                                onDestinationSelected: (int index) {
                                  setState(() {
                                    _selectedIndex = index;
                                  });
                                },
                                // leading: FloatingActionButton(
                                //   elevation: 0,
                                //   onPressed: () {
                                //     // Add your onPressed code here!
                                //   },
                                //   child: const Icon(Icons.add),
                                // ),
                                destinations: snapshot.data.map<NavigationRailDestination>((ent) {
                                      return NavigationRailDestination(
                                        icon: Badge(
                                          backgroundColor: const Color(0xff18171f),
                                          label: Text(ent.files.length.toString()),
                                          child: Icon(Icons.photo),
                                        ),
                                        selectedIcon: Badge(
                                          backgroundColor: const Color(
                                              0xff474565),
                                          label: Text(ent.files.length.toString()),
                                          child: Icon(Icons.photo),
                                        ),
                                        label: Text(ent.name),
                                      );
                                }).toList()
                            )
                        )
                    )
                );
              }
          );
        } else if (snapshot.hasError) {
          children = Column(
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
          children = const Column(
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
        return children;
      },
      future: listData,
    );
  }

  @override
  Widget build(BuildContext context) {
    return sr ? const Expanded(
      child: Center(
        child: SetupRequired(webui: true, comfyui: false),
      ),
    ) : Row(
      children: <Widget>[
        _buildNavigationRail(),
        Expanded(
          child: FutureBuilder(
            builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot){
              return snapshot.hasData ? SingleChildScrollView(
                  child: MasonryView(
                    itemRadius: 0,
                    itemPadding: 4,
                    listOfItem: snapshot.data[_selectedIndex].files,
                    numberOfColumn: 10,
                    itemBuilder: (item) {
                      return GestureDetector(
                        onTap: () => Navigator.push(context, _createGalleryDetailRoute(snapshot.data[_selectedIndex].files, snapshot.data[_selectedIndex].files.indexOf(item))), // Image tapped
                        child: Image.file(File(item))
                      );
                    },
                  ),
                )
              : const Center(child: Text('Loading...'));
            },
            future: listData
          )
        )
      ],
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

class Folder {
  final String path;
  final String name;
  final List<String> files;

  Folder({
    required this.path,
    required this.name,
    required this.files
  });
}