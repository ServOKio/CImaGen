import 'dart:convert';
import 'dart:io';

import 'package:cimagen/pages/sub/LoraMaker.dart';
import 'package:external_path/external_path.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:path_provider/path_provider.dart';
import 'package:toml/toml.dart';

import '../../../Utils.dart';
import '../../../components/Animations.dart';
import '../../../components/CustomMasonryView.dart';

import 'package:path/path.dart' as p;

import '../../../main.dart';

class LoraMakerList extends StatefulWidget {
  const LoraMakerList({super.key});

  @override
  State<LoraMakerList> createState() => _LoraMakerListState();
}

class _LoraMakerListState extends State<LoraMakerList> {
  late Future<List<LoraProject>> loraProjectsFuture;
  double breakpoint = 600.0;

  @override
  void initState(){
    super.initState();
    loraProjectsFuture = getLoraProjects();
  }

  Future<List<LoraProject>> getLoraProjects() async {
    Directory? dD;
    List<LoraProject> list = [];
    if(Platform.isAndroid){
      dD = Directory(await ExternalPath.getExternalStoragePublicDirectory(ExternalPath.DIRECTORY_DOCUMENTS));
    } else if(Platform.isWindows){
      dD = await getApplicationDocumentsDirectory();
    }
    if(dD != null){
      dynamic lorasPath = Directory(p.join(dD.path, 'CImaGen', 'loras'));
      if (!lorasPath.existsSync()) {
        await lorasPath.create(recursive: true);
      }

      List<FileSystemEntity> files = (await dirContents(lorasPath)).whereType<Directory>().toList();
      for (var el in files) {
        LoraProject project = LoraProject(projectPath: el.path);
        // Get data
        File config = File(p.join(el.path, 'config.json'));
        if(config.existsSync()){
          var data = jsonDecode(config.readAsStringSync());
          if(data['type'] != null) {
            int i = data['type'] as int;
            if(data['type'] < LoraType.values.length-1 && i >= 0) project.type = LoraType.values.elementAt(i);
          }
          if(data['name'] != null) project.name = data['name'];
          Directory datasetDir = Directory(p.join(el.path, 'dataset'));
          if(datasetDir.existsSync()){
            project.datasetDir = datasetDir;
          }
          list.add(project);
        } else {
          List<FileSystemEntity> projectRoot = (await dirContents(Directory(el.path))).whereType<File>().where((el) => p.basename(el.path).split('.').last == 'toml').toList();
          Map<String, dynamic>? document;
          String confPath = '';
          for(var conf in projectRoot){
            confPath = conf.path;
            Map<String, dynamic> documentTest = (await TomlDocument.load(confPath)).toMap();
            if(documentTest['general_args'] != null){
              if(documentTest['train_mode'] != null){
                document = documentTest;
              }
            }
          }
          if(document != null){
            project.type = LoraType.loraEasyTrainingScripts;
            project.name = p.basename(el.path);
            project.configFile = confPath;
            Directory dataset = Directory(document['subsets'][0]['image_dir']);

            String? preview;
            if(dataset.existsSync()){
              project.datasetDir = dataset;
              List<FileSystemEntity> files = (await dirContents(dataset)).whereType<File>().where((el) => ['png', 'jpg', 'jpeg', 'webp'].contains(p.basename(el.path).split('.').last)).toList();
              if(files.isNotEmpty) preview = files.first.path;
            }
            project.previewPath = preview;
            list.add(project);
          }
        }
      }
    }
    // Now OneTrainer

    if(prefs.getString('tools_onetrainer_dir') != null){
      Directory oneTrainDir = Directory(prefs.getString('tools_onetrainer_dir')!);
      if(oneTrainDir.existsSync() && Directory(p.join(oneTrainDir.path, 'training_concepts')).existsSync()){
        //Okay
        File concepts = File(p.join(oneTrainDir.path, 'training_concepts', 'concepts.json'));
        if(concepts.existsSync()){
          List<dynamic> data = jsonDecode(concepts.readAsStringSync()) as List<dynamic>;
          for(Map<String, dynamic> el in data){
            Directory dataset = Directory(el['path']);
            String? preview;
            if(dataset.existsSync()){
              List<FileSystemEntity> files = (await dirContents(dataset)).whereType<File>().where((el) => ['png', 'jpg', 'jpeg', 'webp'].contains(p.basename(el.path).split('.').last)).toList();
              if(files.isNotEmpty) preview = files.first.path;
            }
            LoraProject project = LoraProject(projectPath: el['path'], type: LoraType.oneTrainer, name: el['name'], valid: true, previewPath: preview);
            list.add(project);
          }
        }
      }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return FutureBuilder(
      future: loraProjectsFuture,
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
                    Text('No lora ?', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    Text('Create one', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              )
          ) : SingleChildScrollView(
            child: CustomMasonryView(
              itemRadius: 14,
              itemPadding: 8,
              listOfItem: snapshot.data,
              numberOfColumn: (MediaQuery.of(context).size.width / 400).round(),
              itemBuilder: (ii) {
                LoraProject project = ii.item;
                return InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LoraMaker(project: project))),
                    child: ShowUp(
                        delay: ii.index * 200,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AspectRatio(aspectRatio: 4/5, child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.file(File(project.previewPath ?? p.join(project.projectPath, 'preview.png')), fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (context, exception, stack) => Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.remove_red_eye_outlined,
                                      color: Theme.of(context).colorScheme.primary,
                                      size: 60,
                                    ),
                                    Text('Not found')
                                  ],
                                ),
                              ),
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
                              }),
                            )),
                            Gap(12),
                            Row(
                              children: [
                                SelectableText(project.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Montserrat')),
                                Spacer(),
                                Container(
                                    padding: EdgeInsets.only(left: 3, right: 3, bottom: 2),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: Colors.green,
                                        width: 2,
                                      ),
                                    ),
                                    child: Text(loraTypeToString(project.type), style: TextStyle(color: Colors.green, fontSize: 12))
                                )
                              ],
                            ),
                            Gap(12),
                            FutureBuilder(future: project.getDatasetImagesPaths(), builder: (context, snapshot) {
                              const borderWidth = 1.0;
                              Widget c;
                              if(snapshot.hasData){
                                if(snapshot.data!.isNotEmpty){
                                  c = Row(
                                    children: [
                                      Expanded(child: SizedBox(
                                        height: 24 + (2 * borderWidth),
                                        width: snapshot.data!.length * 24/2,
                                        child: Stack(
                                          children: List.generate(
                                            snapshot.data!.length, (index) {
                                            final path = snapshot.data![index];
                                            return Positioned(
                                              left: index == 0 ? 0 : index * 12,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(3),
                                                  border: Border.all(color: Colors.white, width: borderWidth),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withValues(alpha: 0.5),
                                                      spreadRadius: 5,
                                                      blurRadius: 5,
                                                    ),
                                                  ],
                                                ),
                                                child: Image(image: FileImage(File(path)), width: 24, height: 24, fit: BoxFit.cover, gaplessPlayback: true),
                                              ),
                                            );
                                          },
                                          ),
                                        ),
                                      )),
                                      Gap(8),
                                      Text('${snapshot.data!.length} items')
                                    ],
                                  );
                                } else {
                                  c = Text('No images');
                                }
                              } else {
                                if (snapshot.hasError){
                                  c = Text('Error');
                                } else {
                                  c = LinearProgressIndicator();
                                }
                              }
                              return c;
                            }),
                            const Divider(height: 24),
                          ],
                        )
                    )
                );
              },
            ),
          );
        } else if (snapshot.hasError) {
          children = Text(snapshot.error.toString());
        } else {
          children = Center(
            child: CircularProgressIndicator(),
          );
        }
        return children;
      }
    );
  }
}

class LoraProject{
  bool valid;
  String name;
  LoraType type;
  String projectPath;
  String? previewPath;
  String? configFile;
  Directory? datasetDir;

  LoraProject({
    required this.projectPath,
    this.valid = true,
    this.name = 'New project',
    this.type = LoraType.unknown,
    this.previewPath,
    this.configFile,
    this.datasetDir
  });

  Future<List<String>> getDatasetImagesPaths() async{
    if(type == LoraType.lora && datasetDir != null){
      return (await dirContents(datasetDir!)).whereType<File>().where((el) => ['png', 'jpg', 'jpeg', 'webp'].contains(p.basename(el.path).split('.').last)).map((e) => e.path).toList();
    } else if(type == LoraType.oneTrainer){
      return (await dirContents(Directory(projectPath))).whereType<File>().where((el) => ['png', 'jpg', 'jpeg', 'webp'].contains(p.basename(el.path).split('.').last)).map((e) => e.path).toList();
    } else if(type == LoraType.loraEasyTrainingScripts && datasetDir != null){
      return (await dirContents(datasetDir!)).whereType<File>().where((el) => ['png', 'jpg', 'jpeg', 'webp'].contains(p.basename(el.path).split('.').last)).map((e) => e.path).toList();
    } else {
      return [];
    }
  }
}

enum LoraType {
  unknown,
  lora,
  negativeEmbedding,
  oneTrainer,
  loraEasyTrainingScripts,
}

String loraTypeToString(LoraType type){
  return {
    LoraType.unknown: 'Unknown',
    LoraType.lora: 'Lora',
    LoraType.negativeEmbedding: 'N-Embedidng',
    LoraType.oneTrainer: 'OneTrainer',
    LoraType.loraEasyTrainingScripts: 'LoRA Easy Training Scripts'
  }[type] ?? 'Unknown';
}