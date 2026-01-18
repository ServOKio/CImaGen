import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:animated_size_and_fade/animated_size_and_fade.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cimagen/modules/DataManager.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:get/get_connect/http/src/request/request.dart';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../Utils.dart';
import '../../components/Animations.dart';
import '../../utils/DataModel.dart';
import 'PromptAnalyzer.dart';

class JointTaggerProject extends StatefulWidget{
  final ImageMeta imageMeta;

  const JointTaggerProject({ super.key, required this.imageMeta});

  @override
  State<JointTaggerProject> createState() => _JointTaggerProjectState();
}

class _JointTaggerProjectState extends State<JointTaggerProject> with TickerProviderStateMixin {
  bool loaded = false;
  bool addToNew = false;
  int msgState = 0;
  String? musicMessage;

  late AnimationController animatedController;
  late TabController tabController;

  final String projectHost = 'redrocket-jtp-3-demo.hf.space';

  int state = 0;
  int states = 10;
  String? error;

  Map<String, TagInfo> _tags = {};

  List<String> allTags = [];
  Map<String, double> tagsConfidence = {};
  List<String> selected = [];
  List<String> newList = [];

  List<TagProblem> tagProblems = [];

  ContentRating? origContentRating;
  ContentRating? newContentRating;

  List<String> messages = [
    'Sending an image', //0
    'Entering the queue', //1
    'Shake hands', //2
    'Putting on a badge', //3
    'Moving on', //4
    'Listening to music', //5

    'Entering the door', //6
    'Done' //7
  ];

  List<String> musicMessages = [
    'ketamina - yaego, Kučka sounds retro, but so new',
    'There\'s nothing deeper than Fainted (Slowed) - Narvent',
    'Just listen to Cipher of Death - Gotarux at 1:50!',
    'Love Taste - Moe Shop, Jamie Paige, Shiki-TMNS - indestructible classic'
  ];

  @override
  void initState(){
    super.initState();
    animatedController = AnimationController.unbounded(vsync: this);
    tabController = TabController(length: 2, vsync: this);
    _tags = context.read<DataManager>().e621Tags;
    initClient();
  }

  @override
  void dispose() {
    super.dispose();
    animatedController.dispose();
  }

  Future<void> initClient() async {
    runTagger();
  }

  Future<void> getNewContentRaring() async {
    newContentRating = context.read<DataModel>().contentRatingModule.getContentRating(selected.join(', '));
    tagProblems = context.read<DataModel>().contentRatingModule.findContradictions(selected.map((e) => e.replaceAll(' ', '_')).toList());
  }

  Future<void> runTagger() async {
    allTags.clear();
    tagsConfidence.clear();
    selected.clear();

    if(widget.imageMeta.generationParams != null && widget.imageMeta.generationParams!.positive != null) origContentRating = context.read<DataModel>().contentRatingModule.getContentRating(widget.imageMeta.generationParams!.positive!);

    setState(() {
      loaded = false;
      addToNew = false;
      musicMessage = null;
    });
    
    String sessionHash = getRandomString(18);
    String filePath = (widget.imageMeta.fullPath ?? widget.imageMeta.tempFilePath)!;
    final Uint8List bytes = await compute(readAsBytesSync, filePath);
    img.Image? image = await compute(img.decodeImage, bytes);
    image = image!.width == image.height ? img.resize(image, width: 1080, maintainAspect: true) : img.resize(image, width: image.width > image.height ? 1080 : null, height: image.height > image.width ? 1080 : null, maintainAspect: true);
    Uint8List fi = img.encodeJpg(image);

    setState(() {
      state = 1;
      msgState = 0;
    });

    // Unload this shit
    var request = http.MultipartRequest('POST', Uri.parse('https://$projectHost/gradio_api/upload'));
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
      setState(() {state = 3; msgState = 1;});
      print(response.body);
      print(await json.decode(response.body)[0]);

      String picturePath = await json.decode(response.body)[0];

      //Join que
      http.Response resJoin = await http.Client().post(Uri.parse('https://$projectHost/gradio_api/queue/join'), headers: {
        "User-Agent": context.read<DataManager>().userAgent,
        "Accept": "*/*",
        "Accept-Language": "en,en-US;q=0.5",
        "Content-Type": "application/json"
      }, body: jsonEncode(<String, dynamic>{
        'data': [
          {
            "path": picturePath,
            "url": "https://redrocket-jtp-3-demo.hf.space/gradio_api/file=$picturePath",
            "orig_name": p.basename(filePath),
            "size": bytes.lengthInBytes,
            "mime_type": "image/png",
            "meta": {
              "_type": "gradio.FileData"
            }
          }
        ],
        "event_data": null,
        "fn_index": 0,
        "trigger_id": 9,
        "session_hash": sessionHash
      }));
      setState(() {state = 4;});
      if(resJoin.statusCode == 200){
        setState(() {state = 5; msgState = 2;});
        print(resJoin.body);
        String resJoinEVENT_ID = await json.decode(resJoin.body)['event_id'];
        print(resJoinEVENT_ID);

        //Check if okay
        http.Response resJoinStatus = await http.Client().get(Uri.parse('https://$projectHost/gradio_api/queue/data?session_hash=$sessionHash'), headers: {
          "User-Agent": context.read<DataManager>().userAgent,
          "Accept": "*/*",
          "Accept-Language": "en,en-US;q=0.5",
          "Content-Type": "application/json"
        });
        setState(() {state = 6;});
        if(resJoinStatus.statusCode == 200) {
          setState(() {state = 7; msgState = 3;});
          print('resJoinStatus ${resJoinStatus.statusCode}');

          //Send quePizdets
          http.Response resStartProcess = await http.Client().post(Uri.parse('https://$projectHost/gradio_api/queue/join'), headers: {
            "User-Agent": context.read<DataManager>().userAgent,
            "Accept": "*/*",
            "Accept-Language": "en,en-US;q=0.5",
            "Content-Type": "application/json"
          }, body: jsonEncode(<String, dynamic>{
            "data": [
              null,
              0.3,
              1
            ],
            "event_data": null,
            "fn_index": 1,
            "trigger_id": 9,
            "session_hash": sessionHash
          }));
          setState(() {state = 8;});
          if(resStartProcess.statusCode == 200) {
            setState(() {
              state = 9;
            });
            print(resStartProcess.body);

            //Read stream
            final client = HttpClient();

            final request = await client.getUrl(Uri.parse('https://redrocket-jtp-3-demo.hf.space/gradio_api/queue/data?session_hash=$sessionHash'));
            final response = await request.close();

            final stream = response.transform(utf8.decoder);

            await for (final chunk in stream) {
              if (chunk.trim().isEmpty) continue;
              dynamic raw = await json.decode(chunk.replaceAll('data: ', ''));
              String msg = raw['msg'];
              if (msg == 'estimation') {
                setState(() {
                  msgState = 3;
                });
              } else if (msg == 'process_starts') {
                setState(() {
                  msgState = 4;
                });
              } else if (msg == 'heartbeat') {
                setState(() {
                  msgState = 5;
                  musicMessage = getRandomStringFromList(musicMessages);
                });
              } else if (msg == 'process_completed') {
                var data = raw['output']['data'];
                allTags = data[0].split(', ');

                if(widget.imageMeta.generationParams != null && widget.imageMeta.generationParams!.positive != null){
                  addToNew = true;
                  List<String> test = getRawTags(widget.imageMeta.generationParams!.positive!).map((el) => el.toLowerCase().replaceAll('_', ' ')).toList();
                  for(String w in test){
                    if(!allTags.contains(w)) allTags.add(w);
                  }
                  for (var el in test) {
                    if(!selected.contains(el)) selected.add(el);
                  }
                }

                data[1]['confidences'].forEach((d) {
                  tagsConfidence[d['label']] = d['confidence'] as double;
                });
                getNewContentRaring();
                setState(() {
                  msgState = 6;
                });
              } else if (msg == 'close_stream') {
                setState(() {
                  msgState = 7;
                });
              }
            }

            client.close();
            setState(() {state = 10; loaded = true;});
          } else {
            print('pizda 2');
          }
        } else {
          print('pizda');
        }
      } else {
        print(resJoin.statusCode);
        print(resJoin.body);
        setState(() {
          error = 'Code is not 200';
        });
      }
    } else {
      setState(() {
        error = 'Code is not 200 - ${streamedResponse.statusCode}';
      });
    }
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
                  child: AnimatedSizeAndFade(fadeDuration: const Duration(seconds: 1), sizeDuration: const Duration(seconds: 1), child: Wrap(
                    runSpacing: 5,
                    spacing: 5.0,
                    children: allTags.map((el) => ChoiceChip(
                      tooltip: _tags[el.replaceAll(' ', '_')] != null ? _tags[el.replaceAll(' ', '_')]!.count.toString() : 'Not found',
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
                        getNewContentRaring();
                        setState(() {
                        });
                      },
                    )).toList(),
                  )
                  ),
                )),
                Flexible(flex: 1, child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Hero(
                          tag: widget.imageMeta.fileName,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(7.0),
                            child: Stack(
                              children: [
                                !widget.imageMeta.isLocal ?
                                  CachedNetworkImage(imageUrl: widget.imageMeta.fullNetworkPath ?? context.read<ImageManager>().getter.getFullUrlImage(widget.imageMeta)) :
                                  Image.file(File(widget.imageMeta.fullPath ?? widget.imageMeta.tempFilePath ?? widget.imageMeta.cacheFilePath ?? 'e.png')),
                                if(false) BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                                  child: AspectRatio(aspectRatio: widget.imageMeta.size!.aspectRatio(), child: Container(color: Colors.white.withAlpha(70))),
                                ),
                                if(state == 9) Shimmer.fromColors(
                                  baseColor: Colors.transparent,
                                  highlightColor: Colors.white10.withOpacity(0.3),
                                  period: const Duration(seconds: 2),
                                  child: AspectRatio(aspectRatio: widget.imageMeta.size!.aspectRatio(), child: Container(color: Colors.white))
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    child: Row(
                                      children: [
                                        if(origContentRating != null) Container(
                                          margin: const EdgeInsets.only(bottom: 3),
                                          height: 18,
                                          padding: const EdgeInsets.only(left: 4, right: 4, bottom: 1),
                                          decoration: BoxDecoration(
                                              borderRadius: const BorderRadius.all(Radius.circular(2)),
                                              color: Color(origContentRating == ContentRating.X || origContentRating == ContentRating.XXX ? 0xff000000 : 0xffffffff).withOpacity(0.7)
                                          ),
                                          child: Text(origContentRating!.name, textAlign: TextAlign.center, style: TextStyle(color: Color([
                                            0xff5500ff,
                                            0xff006835,
                                            0xfff15a24,
                                            0xff803d99,
                                            0xffd8121a,
                                            0xff1b3e9b,
                                            0xffffffff,
                                            0xffffffff
                                          ][origContentRating!.index]), fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                        if(newContentRating != origContentRating && newContentRating != null) ...[
                                          Icon(Icons.chevron_right),
                                          Container(
                                            margin: const EdgeInsets.only(bottom: 3),
                                            height: 18,
                                            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 1),
                                            decoration: BoxDecoration(
                                                borderRadius: const BorderRadius.all(Radius.circular(2)),
                                                color: Color(newContentRating == ContentRating.X || newContentRating == ContentRating.XXX ? 0xff000000 : 0xffffffff).withOpacity(0.7)
                                            ),
                                            child: Text(newContentRating!.name, textAlign: TextAlign.center, style: TextStyle(color: Color([
                                              0xff5500ff,
                                              0xff006835,
                                              0xfff15a24,
                                              0xff803d99,
                                              0xffd8121a,
                                              0xff1b3e9b,
                                              0xffffffff,
                                              0xffffffff
                                            ][newContentRating!.index]), fontSize: 12, fontWeight: FontWeight.bold)),
                                          )
                                        ]
                                      ],
                                    ),
                                  )
                                )
                              ],
                            )
                          )
                        )
                      )
                    ),
                    Gap(7),
                    if(musicMessage != null) ShowUp(
                        delay: 200,
                        child: SelectableText(musicMessage!, style: const TextStyle(fontSize: 12, color: Colors.white70))
                    ),
                    ShowUp(
                        delay: 200,
                        child: Text(messages[msgState], style: const TextStyle(fontWeight: FontWeight.w500, fontFamily: 'Montserrat'))
                    ),
                    Padding(padding: EdgeInsets.only(bottom: 10, top: 5), child: LinearProgressIndicator(value: state/states, borderRadius: BorderRadius.circular(5))),
                    if(error != null) SelectableText('Error: $error')
                  ],
                )),
                Flexible(flex: 1, child: SingleChildScrollView(
                  padding: EdgeInsets.all(7),
                  child: AnimatedSizeAndFade(fadeDuration: const Duration(seconds: 1), sizeDuration: const Duration(seconds: 1), child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if(tagProblems.isNotEmpty) ...[
                        Text('Problems', style: const TextStyle(fontWeight: FontWeight.w500)),
                        Gap(3),
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            children: tagProblems.map((info) => Container(
                              margin: EdgeInsets.symmetric(vertical: 2),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.error.withAlpha(30),
                                  border: Border.all(color: Theme.of(context).colorScheme.error.withAlpha(60), width: 1),
                                  borderRadius: const BorderRadius.all(Radius.circular(4))
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.warning_rounded, color: Theme.of(context).colorScheme.error, size: 14),
                                      Spacer(),
                                      Text(info.code, style: TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 10, color: Theme.of(context).colorScheme.onSecondary.withAlpha(100)))
                                    ],
                                  ),
                                  Text(info.message, style: TextStyle(color: Theme.of(context).colorScheme.onSecondary)),
                                  Gap(3),
                                  Wrap(
                                    runSpacing: 5,
                                    spacing: 5.0,
                                    children: info.involvedTags.map((el) => Container(
                                      decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.error.withAlpha(30),
                                          border: Border.all(color: Theme.of(context).colorScheme.error.withAlpha(60), width: 1),
                                          borderRadius: const BorderRadius.all(Radius.circular(4))
                                      ),
                                      padding: EdgeInsets.symmetric(vertical: 0, horizontal: 3),
                                      child: Text(el, style: TextStyle(fontSize: 10)),
                                    )).toList(),
                                  )
                                ],
                              ),
                            )).toList(),
                          ),
                        ),
                      ],
                      if(selected.isNotEmpty) ...[
                        Text('Merged tags', style: const TextStyle(fontWeight: FontWeight.w500)),
                        Gap(3),
                        SizedBox(
                          height: MediaQuery.of(context).size.height / 3,
                          child: Column(
                            children: [
                              TabBar(
                                controller: tabController,
                                tabs: const <Widget>[
                                  Tab(
                                      text: 'SD'
                                  ),
                                  Tab(
                                    text: 'E621',
                                  ),
                                ],
                              ),
                              Expanded(child: TabBarView(
                                controller: tabController,
                                children: <Widget>[
                                  Container(
                                      padding: const EdgeInsets.all(4.0),
                                      margin: const EdgeInsets.only(top: 8),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                                        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.5), width: 1),
                                        borderRadius: const BorderRadius.all(Radius.circular(5.0)),
                                      ),
                                      child: FractionallySizedBox(
                                          widthFactor: 1.0,
                                          child: SelectableText(selected.join(', '), style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400))
                                      )
                                  ),
                                  Container(
                                      padding: const EdgeInsets.all(4.0),
                                      margin: const EdgeInsets.only(top: 8),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                                        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.5), width: 1),
                                        borderRadius: const BorderRadius.all(Radius.circular(5.0)),
                                      ),
                                      child: FractionallySizedBox(
                                          widthFactor: 1.0,
                                          child: SelectableText(selected.map((e) => e.replaceAll(' ', '_')).join(','), style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400))
                                      )
                                  ),
                                ],
                              ))
                            ],
                          ),
                        )
                      ],
                      if(newList.isNotEmpty) ...[
                        Gap(8),
                        ShowUp(
                            delay: 0,
                            child: Text('New tags', style: const TextStyle(fontWeight: FontWeight.w500))
                        ),
                        Gap(3),
                        ShowUp(
                            delay: 200,
                            child: Container(
                              padding: const EdgeInsets.all(4.0),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.5), width: 1),
                                borderRadius: const BorderRadius.all(Radius.circular(5.0)),
                              ),
                              child: SelectableText(newList.join(', ')),
                            ),
                        ),
                      ]
                    ],
                  )),
                )),
              ],
            )
        )
    );
  }
}