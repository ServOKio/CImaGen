import 'dart:convert';
import 'dart:io';

import 'package:cimagen/Utils.dart';
import 'package:cimagen/components/SetupRequired.dart';
import 'package:cimagen/components/TimeLineLine.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../utils/DataModel.dart';
import '../utils/ImageManager.dart';
import '../utils/SQLite.dart';

class Timeline extends StatefulWidget{
  const Timeline({ Key? key }): super(key: key);

  @override
  _TimelineState createState() => _TimelineState();
}

class _TimelineState extends State<Timeline> {
  bool loaded = false;
  bool sr = false;

  bool debug = false;

  List<ImageRow> rows = [];

  @override
  void initState() {
    super.initState();
    var go = context.read<ImageManager>().getter.loaded;
    if(!go){
      sr = true;
    } else {
      final dataModel = Provider.of<DataModel>(context, listen: false);
      context.read<SQLite>().getImagesBySeed(
          dataModel.timelineBlock.getSeed
      ).then((v2) {
        ImageRow row = ImageRow();
        for (var image in v2) {
          if(debug){
            row.addExtraMain(image);
            rows.add(row);
            row = ImageRow();
            continue;
          }
          if(image.re == RenderEngine.txt2img){
            bool isHiRes = image.generationParams?.denoisingStrength != null;

            if(row.hasMain()){ //Если есть главная
              // ok
              if(row.hasExtraMain()){ //Если есть хайрес
                //ну и похуй, скипаем
                rows.add(row);
                row = ImageRow();
                if(isHiRes){ //Если хайрес
                  row.addExtraMain(image);
                } else row.addMain(image);
              } else { // если нет хайреса
                if(isHiRes){ //Если хайрес
                  if(!isIdenticalPromt(row.main, image)){ //если промты разные у рава и хая
                    rows.add(row);
                    row = ImageRow();
                  }
                  row.addExtraMain(image);
                } else { //если нет - дальше
                  rows.add(row);
                  row = ImageRow();
                  row.addMain(image);
                }
              }
            } else { //Если нет главной
              if(isHiRes){ //Если хайрес - дебик с pnginfo (бля сука)
                if(row.hasSecond()){ //Если там уже есть что-то дальше т.е. тупо лежит img2img
                  rows.add(row);
                  row = ImageRow();
                } else if(row.hasExtraMain()){
                  rows.add(row);
                  row = ImageRow();
                }
                row.addExtraMain(image);
              } else { //Если не хайрес
                if(row.hasExtraMain()){ //Если уже есть hires куда ещё пихать
                  rows.add(row);
                  row = ImageRow();
                  row.addMain(image);
                } else { //Если есть куда пихать
                  if(row.hasSecond()){
                    rows.add(row);
                    row = ImageRow();
                  }
                  row.addMain(image);
                }
              }
            }
          } else if(image.re == RenderEngine.img2img){
            if(row.hasMain() && row.hasExtraMain()){// Есть оба
              // Бля, а вот тут боль - при сохранение, допустим картинка отрендерилась, можно написать хуйню и оно сохранит в хуйней, а не с тем что рендерило
              bool shit = false;

              if(!isIdenticalPromt(row.extraMain, image)) shit = true;
              // TODO потом
              // if(row.extraMain != null && row.extraMain?.size.aspectRatio() != image.size.aspectRatio()) shit = true;
              if(shit){ //Получается онли img2img
                rows.add(row);
                row = ImageRow();
              }
              row.addSecond(image);
            } else {
              if(row.hasMain() && !row.hasExtraMain()){ //Есть основное, но нет хайреса
                // Кидаем в новое
                rows.add(row);
                row = ImageRow();
                row.addSecond(image);
              } else if(!row.hasMain() && row.hasExtraMain()){ // Нет основного, но есть хайрес
                //Продолжаем
                row.addSecond(image);
              }
            }
          }
        }
        if(mounted) {
          setState(() {
          loaded = true;
        });
        }
      });
    }
    //load();
  }

  @override
  Widget build(BuildContext context) {
    return sr ? const Center(
      child: SetupRequired(webui: true, comfyui: false),
    ) : Row(
        children: <Widget>[
          _buildNavigationRail(),
          loaded ? Expanded(
              child: ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (BuildContext context, int index) {
                    // return Container(
                    //   width: 300,
                    //   height: 300,
                    //   color: Colors.green,
                    // );
                    return RowList(rowData: rows[index], index: index, rows: rows);
                  }
              )) : const CircularProgressIndicator()
        ]
    );
  }

  Widget _buildNavigationRail() {
    return LayoutBuilder(
        builder: (context, constraint) {
          return SingleChildScrollView(
              child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraint.maxHeight),
                  child: const IntrinsicHeight(
                      child: Column(
                        children: [
                          Text('1')
                        ],
                      )
                  )
              )
          );
        }
    );
  }
}

bool isIdenticalPromt(ImageMeta? one, ImageMeta? two){
  if(one == null || two == null) return false;
  return one.generationParams?.positive == two.generationParams?.positive && one.generationParams?.negative == two.generationParams?.negative;
}

String getGenerationHash(ImageMeta im, {String? except}){
  if(im.generationParams == null) return '-';
  String f = '';
  if(except != 'checkpoint' && im.generationParams?.checkpoint != null) f+= im.generationParams!.checkpoint!;
  if(except != 'positive') f+= im.generationParams!.positive;
  if(except != 'negative') f+= im.generationParams!.negative;
  if(except != 'cfgScale') f+= im.generationParams!.cfgScale.toString();
  if(except != 'seed') f+= im.generationParams!.seed.toString();
  if(except != 'size') f+= im.generationParams!.size.toString();
  if(except != 'rng' && im.generationParams?.rng != null) f+= im.generationParams!.rng.toString();
  if(except != 'version' && im.generationParams?.version != null) f+= im.generationParams!.version.toString();
  return f;
}

List<Difference> findDifference(ImageMeta? one, ImageMeta two){ //TODO
  List<Difference> d = [];
  GenerationParams? o = one?.generationParams;
  GenerationParams? t = two.generationParams;
  if(o == null || t == null) return d;

  // final String positive;
  if(o.positive.trim() != t.positive.trim()) d.add(Difference(key: 'positive', oldValue: o.positive, newValue: t.positive));
  // final String negative;
  if(o.negative.trim() != t.negative.trim()) d.add(Difference(key: 'negative', oldValue: o.negative, newValue: t.negative));
  // final int steps;
  if(o.steps != t.steps) d.add(Difference(key: 'steps', oldValue: o.steps.toString(), newValue: t.steps.toString()));
  // final String sampler;
  if(o.sampler != t.sampler) d.add(Difference(key: 'sampler', oldValue: o.sampler, newValue: t.sampler));
  // final double cfgScale;
  if(o.cfgScale != t.cfgScale) d.add(Difference(key: 'cfgScale', oldValue: o.cfgScale.toString(), newValue: t.cfgScale.toString()));
  // final int seed;
  if(o.seed != t.seed) d.add(Difference(key: 'seed', oldValue: o.seed.toString(), newValue: t.seed.toString()));
  // final Size size;
  if(o.size.toString() != t.size.toString()) d.add(Difference(key: 'size', oldValue: o.size.toString(), newValue: t.size.toString()));
  // final CheckpointType checkpointType;
  if(o.checkpointType != t.checkpointType) d.add(Difference(key: 'checkpointType', oldValue: o.checkpointType.toString(), newValue: t.checkpointType.toString()));
  // final String model;
  if(o.checkpoint != t.checkpoint) d.add(Difference(key: 'checkpoint', oldValue: o.checkpoint ?? '-', newValue: t.checkpoint ?? '-'));
  // final String modelHash;
  if(o.checkpointHash != t.checkpointHash) d.add(Difference(key: 'checkpointHash', oldValue: o.checkpointHash ?? '-', newValue: t.checkpointHash ?? '-'));
  // final double? denoisingStrength;
  if(o.denoisingStrength != t.denoisingStrength) d.add(Difference(key: 'denoisingStrength', oldValue: (o.denoisingStrength ?? '-').toString(), newValue: (t.denoisingStrength ?? '-').toString()));
  // final String? rng;
  if(o.rng != t.rng) d.add(Difference(key: 'rng', oldValue: o.rng ?? '-', newValue: t.rng ?? '-'));
  // final String? hiresSampler;
  if(o.hiresSampler != t.hiresSampler) d.add(Difference(key: 'hiresSampler', oldValue: o.hiresSampler ?? '-', newValue: t.hiresSampler ?? '-'));

  if(o.hiresUpscaler != t.hiresUpscaler) d.add(Difference(key: 'hiresUpscale', oldValue: (o.hiresUpscaler ?? '-').toString(), newValue: (t.hiresUpscaler ?? '-').toString()));
  // final double? hiresUpscale;
  if(o.hiresUpscale != t.hiresUpscale) d.add(Difference(key: 'hiresUpscale', oldValue: (o.hiresUpscale ?? '-').toString(), newValue: (t.hiresUpscale ?? '-').toString()));

  if(o.params?['hires_steps'] != t.params?['hires_steps']) d.add(Difference(key: 'hiresSteps', oldValue: (o.params?['hires_steps'] ?? '-').toString(), newValue: (t.params?['hires_steps'] ?? '-').toString()));
  // final Map<String, String>? tiHashes;
  // final String version;
  if(o.version != t.version) d.add(Difference(key: 'version', oldValue: o.version ?? '-', newValue: t.version ?? '-'));

  return d;
}

String getDifferencesHash(List<Difference> list){
  return list.isEmpty ? '-' : sha256.convert(utf8.encode(list.map((e) => e.key).join('-'))).toString();
}

class Difference {
  final String key;
  final String oldValue;
  final String newValue;

  Difference({
    required this.key,
    required this.oldValue,
    required this.newValue
  });
}

class RowList extends StatefulWidget{
  final ImageRow rowData;
  final int index;
  final List<ImageRow> rows;
  const RowList({ Key? key, required this.rowData, required this.index, required this.rows }): super(key: key);


  @override
  _RowListState createState() => _RowListState();
}

class _RowListState extends State<RowList> {

  bool compareWithExtra = false;

  @override
  void initState() {
    super.initState();
    if(widget.rowData.hasExtraMain() && widget.rowData.hasSecond()) compareWithExtra = true;
  }

  // final String positive;
  // final String negative;
  // final int steps;
  // final String sampler;
  // final double cfgScale;
  // final int seed;
  // final Size size;
  // final String modelHash;
  // final String model;
  // final double? denoisingStrength;
  // final String? rng;
  // final String? hiresSampler;
  // final double? hiresUpscale;
  // final Map<String, String>? tiHashes;
  // final String version;
  Map<String, String> keysMap = {
    'cfgScale': 'cfgS',
    'size': 'w&h',
    'modelHash': 'mHash',
    'denoisingStrength': 'D.s.',
    'rng': 'RNG',
    'hiresSampler': 'hSampler',
    'hiresUpscale': 'hUpscale',
    'version': 'v'
  };

  @override
  Widget build(BuildContext context) {
    ImageMeta? meta = widget.rowData.main;
    ImageMeta? metaExtra = widget.rowData.extraMain;
    final screenHeight = MediaQuery.of(context).size.height;
    double height = 512 * 0.7;
    return Padding(
      padding: meta != null ? const EdgeInsets.only(top: 20) : const EdgeInsets.only(bottom: 0),
      child: Row(
        children: [
          Container(
            width: 200,
            height: height,
            decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.horizontal(left: Radius.circular(4))
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: meta != null ? [
                  Text('Parameters', style: TextStyle(color: Colors.deepPurple.shade50, fontWeight: FontWeight.w600, fontSize: 16)),
                  Container(width: 20, height: 2, color: Colors.deepPurple.shade400),
                  InfoBox(one: 'S.Method', two: meta.generationParams?.sampler ?? 'err'),
                  InfoBox(one: 'S.Steps ', two: meta.generationParams?.steps.toString() ?? 'err'),
                  InfoBox(one: 'Size', two: meta.generationParams?.size.toString() ?? 'err'),
                  InfoBox(one: 'Seed', two: meta.generationParams?.seed.toString() ?? 'err'),
                ] : [],
              ),
            ),
          ),
          // TODO Fix
          Row(
            children: [
              SizedBox( // Основное
                height: height,
                child: meta != null ? Stack(
                  children: [
                    Image.file(File(widget.rowData.main!.fullPath)),
                    Padding(
                        padding: const EdgeInsets.all(5),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            meta.generationParams != null ? TagBox(text: meta.generationParams!.denoisingStrength != null ? 'Hi-Res' : 'Raw') : const SizedBox.shrink(),
                            meta.generationParams != null && meta.generationParams?.sampler != null ? Padding(padding: const EdgeInsets.only(top: 4), child: TagBox(text: meta.generationParams!.sampler)) : const SizedBox.shrink()
                          ],
                        )
                    )
                  ],
                ) : metaExtra != null && (findFirstMain(widget.rows, widget.index) != null && isIdenticalPromt(findFirstMain(widget.rows, widget.index)!.main, metaExtra)) ? AspectRatio(
                  aspectRatio: metaExtra.size!.aspectRatio(),
                  child: CustomPaint(
                    painter: TimeLineLine(),
                    child: Container(),
                  ),
                ) : widget.rowData.hasSecond() ? AspectRatio(
                  aspectRatio: widget.rowData.images2[0].size!.aspectRatio(),
                  child: Container(
                    height: height,
                    color: Colors.pink,
                  ),
                ) : metaExtra != null ? AspectRatio(
                  aspectRatio: metaExtra.size!.aspectRatio(),
                  child: Container(
                    height: height,
                    color: Colors.indigoAccent,
                  ),
                ) : Container(
                  height: height,
                  width: 10,
                  color: Colors.green,
                ),
              ),
              widget.rowData.hasExtraMain() ? Container( // HiRes
                  height: height,
                  color: Colors.orange,
                  child: metaExtra != null ? Stack(
                    children: [
                      Image.file(File(widget.rowData.extraMain!.fullPath)),
                      Padding(
                          padding: const EdgeInsets.all(5),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              metaExtra.generationParams != null ? TagBox(text: metaExtra.generationParams!.denoisingStrength != null ? 'Hi-Res${metaExtra.generationParams?.hiresSampler != null ? ' ${metaExtra.generationParams!.hiresSampler}' : ' Lanczos'}${metaExtra.generationParams?.hiresUpscale != null ? ' x${metaExtra.generationParams!.hiresUpscale}' : ''}' : 'Raw') : const SizedBox.shrink(),
                              metaExtra.generationParams != null ? Padding(padding: const EdgeInsets.only(top: 4), child: TagBox(text: 'W&H:${metaExtra.generationParams!.size.toString()}')) : const SizedBox.shrink(),
                              metaExtra.generationParams != null && metaExtra.generationParams!.denoisingStrength != null ? Padding(padding: const EdgeInsets.only(top: 4), child: TagBox(text: 'Ds:${metaExtra.generationParams!.denoisingStrength}')) : const SizedBox.shrink()
                            ],
                          )
                      )
                    ],
                  ) : const Text('none')
              ) : meta != null && widget.rowData.hasSecond() ? AspectRatio(
                aspectRatio: meta.size!.aspectRatio(),
                child: Container(
                  color: Colors.blue,
                  child: const Text('fdf'),
                ),
              ) : widget.rowData.hasSecond() ? SizedBox(
                height: height,
                child: AspectRatio(
                  aspectRatio: widget.rowData.images2[0].size!.aspectRatio(),
                  child: Container(
                    color: Colors.cyanAccent,
                  ),
                ),
              ) : const SizedBox.shrink(),
            ],
          ),
          // Expanded(child: SizedBox(
          //   height: height,
          //   child: ListView.builder(
          //       scrollDirection: Axis.horizontal,
          //       itemCount: widget.rowData.images2.length,
          //       itemBuilder: (BuildContext context, int index) {
          //         return Container(
          //             height: height,
          //             color: Colors.green,
          //             child: Stack(
          //               children: [
          //                 Image.file(File(widget.rowData.images2[index].fullPath)),
          //                 Padding(
          //                     padding: const EdgeInsets.all(5),
          //                     child: Column(
          //                         mainAxisAlignment: MainAxisAlignment.start,
          //                         crossAxisAlignment: CrossAxisAlignment.start,
          //                         children: compareWithExtra || (index == 0 && widget.rowData.images2.length > 1) ? findDifference(compareWithExtra ? widget.rowData.extraMain : widget.rowData.images2[index-1], widget.rowData.images2[index]).map((ent){
          //                           return Padding(padding: const EdgeInsets.only(bottom: 4), child: ['positive', 'negative'].contains(ent.key) ? TagBox(text: keysMap[ent.key] ?? ent.key) : TagBox(text: '${keysMap[ent.key] ?? ent.key} ${ent.newValue}', lineThrough: ent.newValue == '-'));
          //                         }).toList() : [
          //                           const TagBox(text: 'first')
          //                         ]
          //                     )
          //                 )
          //               ],
          //             )
          //         );
          //       }
          //   ),
          // ))
        ],
      ),
    );
  }
}

class InfoBox extends StatelessWidget{
  final String one;
  final String two;

  const InfoBox({ Key? key, required this.one, required this.two }): super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Container(
          decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.all(Radius.circular(4))
          ),
          child: Padding(
              padding: const EdgeInsets.only(left: 4, right: 4, bottom: 2),
              child: Row(
                children: [
                  Text(one, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const Spacer(),
                  SelectableText(two, style: const TextStyle(fontSize: 13))
                ],
              )
          ),
        )
    );
  }
}

ImageRow? findFirstMain(List<ImageRow> rows, int currentIndex){
  ImageRow? row;
  for (int i = currentIndex-1; i > -1; i--) {
    if(rows[i].hasMain()){
      row = rows[i];
      break;
    }
  }
  return row;
}

ImageRow? findFirstExtra(List<ImageRow> rows, int currentIndex){
  ImageRow? row;
  for (int i = currentIndex-1; i > -1; i--) {
    if(rows[i].hasExtraMain()){
      row = rows[i];
      break;
    }
  }
  return row;
}

class TagBox extends StatelessWidget{
  final String text;
  final bool? lineThrough;

  const TagBox({ Key? key, required this.text, this.lineThrough }): super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 2),
      decoration: BoxDecoration(
          color: const Color(0xFF000000).withOpacity(0.5),
          border: Border.all(
              color: const Color(0xFF000000).withOpacity(0.8)
          ),
          borderRadius: const BorderRadius.all(Radius.circular(4))
      ),
      child: Text(text, style: TextStyle(fontSize: 10, color: (lineThrough != null && lineThrough!) ? Colors.white38 : Colors.white, decoration: (lineThrough != null && lineThrough!) ? TextDecoration.lineThrough : null)),
    );
  }
}

class ImageRow{
  ImageMeta? main;
  ImageMeta? extraMain;
  List<ImageMeta> images2 = [];

  bool hasMain() {
    return main != null;
  }

  void addMain(ImageMeta image) {
    main = image;
  }


  void addSecond(ImageMeta image) {
    images2.add(image);
  }

  bool hasExtraMain() {
    return extraMain != null;
  }

  void addExtraMain(ImageMeta image) {
    extraMain = image;
  }

  bool hasSecond(){
    return images2.isNotEmpty;
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