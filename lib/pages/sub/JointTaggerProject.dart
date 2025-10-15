import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cimagen/modules/DataManager.dart';
import 'package:cimagen/pages/sub/PromptAnalyzer.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:get/get_connect/http/src/request/request.dart';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

import '../../Utils.dart';
import '../../components/Animations.dart';

class JointTaggerProject extends StatefulWidget{
  final ImageMeta imageMeta;

  const JointTaggerProject({ super.key, required this.imageMeta});

  @override
  State<JointTaggerProject> createState() => _JointTaggerProjectState();
}

class _JointTaggerProjectState extends State<JointTaggerProject> {
  bool loaded = false;
  bool addToNew = false;

  int state = 0;
  int states = 8;

  Map<String, TagInfo> _tags = {};

  List<String> allTags = [];
  Map<String, double> tagsConfidence = {};
  List<String> selected = [];
  List<String> newList = [];

  // GradioClient? client;

  @override
  void initState(){
    super.initState();
    _tags = context.read<DataManager>().e621Tags;
    initClient();
  }

  Future<void> initClient() async {
    runTagger();
    // client = await GradioClient.connect("RedRocket/JointTaggerProject-Inference-Beta");
    // var result = await client!.predict("/run_classifier", {
    //   'image': exampleImage,
    //   'threshold': 0,
    // });

  }

  Future<void> runTagger() async {
    allTags.clear();
    tagsConfidence.clear();
    selected.clear();

    setState(() {
      loaded = false;
      addToNew = false;
    });

    final Uint8List bytes = await compute(readAsBytesSync, (widget.imageMeta.fullPath ?? widget.imageMeta.tempFilePath)!);
    img.Image? image = await compute(img.decodeImage, bytes);
    image = image!.width == image.height ? img.resize(image, width: 1080, maintainAspect: true) : img.resize(image, width: image.width > image.height ? 1080 : null, height: image.height > image.width ? 1080 : null, maintainAspect: true);
    Uint8List fi = img.encodeJpg(image);

    setState(() {state = 1;});

    // Unload this shit
    var request = http.MultipartRequest('POST', Uri.parse('https://redrocket-jointtaggerproject-inference-beta.hf.space/upload'));
    request.files.add(
      http.MultipartFile(
        'files',
        fi.toStream(),
        fi.length,
        filename: widget.imageMeta.fileName
      )
    );
    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    setState(() {state = 2;});
    if(streamedResponse.statusCode == 200){
      setState(() {state = 3;});
      http.Response res = await http.Client().post(Uri.parse('https://redrocket-jointtaggerproject-inference-beta.hf.space/call/run_classifier'), headers: {
        "User-Agent": context.read<DataManager>().userAgent,
        "Accept": "*/*",
        "Accept-Language": "en,en-US;q=0.5",
        "Content-Type": "application/json"
      }, body: jsonEncode(<String, List<dynamic>>{
        'data': [
          {"path" : await json.decode(response.body)[0]},
          0.01
        ]
      }));
      setState(() {state = 4;});
      if(res.statusCode == 200){
        setState(() {state = 5;});
        String EVENT_ID = await json.decode(res.body)['event_id'];

        Future<void> nex() async {
          http.Response res2 = await http.Client().get(Uri.parse('https://redrocket-jointtaggerproject-inference-beta.hf.space/call/run_classifier/$EVENT_ID'), headers: {
            "User-Agent": context.read<DataManager>().userAgent,
            "Accept": "application/json",
            "Accept-Language": "en,en-US;q=0.5"
          });
          setState(() {state = 6;});
          if(res2.statusCode == 200){
            if(res2.body.startsWith('event: heartbeat')){
              nex();
              return;
            }
            setState(() {state = 7;});
            var data = await json.decode(res2.body.split('\n').join('').replaceFirst('event: completedata: ', ''));
            allTags = data[0].split(', ');

            if(widget.imageMeta.generationParams != null && widget.imageMeta.generationParams!.positive != null){
              addToNew = true;
              List<String> test = getRawTags(widget.imageMeta.generationParams!.positive!).map((el) => el.toLowerCase().replaceAll('_', ' ')).toList();
              allTags.forEach((el){
                if(test.contains(el)) selected.add(el);
              });
            }

            data[1]['confidences'].forEach((d) {
              tagsConfidence[d['label']] = d['confidence'] as double;
            });
            setState(() {state = 8; loaded = true;});
          } else {
            print(res2.statusCode);
            print(res2.body);
          }
        }

        nex();
      } else {
        print(res.statusCode);
        print(res.body);
      }
    }
  }

  @override
  void dispose() {
    _tags.clear();
    super.dispose();
  }

  Future<void> fetchTags() async {
    setState(() {
      loaded = false;

    });

    setState(() {
      loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
            title: const ShowUp(
              delay: 100,
              child: Text('Joint Tagger Project', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600, fontFamily: 'Montserrat')),
            ),
            backgroundColor: const Color(0xaa000000),
            elevation: 0,
            actions: []
        ),
        body: SafeArea(
            child: Row(
              children: [
                Flexible(flex: 1, child: SingleChildScrollView(
                  padding: EdgeInsets.all(7),
                  child: Wrap(
                    runSpacing: 5,
                    spacing: 5.0,
                    children: allTags.map((el) => ChoiceChip(
                      tooltip: _tags[el] != null ? _tags[el]!.count.toString() : 'Not found',
                      labelPadding: EdgeInsetsGeometry.zero,
                      label: Text(el, style: TextStyle(fontSize: 12)),
                      selected: selected.contains(el),
                      checkmarkColor: newList.contains(el) ? Colors.lightGreen : null,
                      onSelected: (bool sel) {
                        if(sel){
                          selected.add(el);
                          if(addToNew) newList.add(el);
                        } else {
                          selected.remove(el);
                          if(addToNew) newList.remove(el);
                        }
                        setState(() {
                        });
                      },
                    )).toList(),
                  ),
                )),
                Flexible(flex: 1, child: Column(
                  children: [
                    Expanded(child: !widget.imageMeta.isLocal ?
                      CachedNetworkImage(imageUrl: widget.imageMeta.fullNetworkPath ?? context.read<ImageManager>().getter.getFullUrlImage(widget.imageMeta)) :
                    Image.file(File(widget.imageMeta.fullPath ?? widget.imageMeta.tempFilePath ?? widget.imageMeta.cacheFilePath ?? 'e.png'))),
                    LinearProgressIndicator(value: state/states)
                  ],
                )),
                Flexible(flex: 1, child: SingleChildScrollView(
                  padding: EdgeInsets.all(7),
                  child: Column(
                    children: [
                      SelectableText(selected.join(', ')),
                      if(addToNew) ...[
                        Gap(8),
                        Text('New tags'),
                        SelectableText(newList.join(', '))
                      ]
                    ],
                  ),
                )),
              ],
            )
        )
    );
  }
}