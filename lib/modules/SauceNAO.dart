import 'dart:io';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cimagen/modules/saucenao/Result.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:get/get_connect/http/src/request/request.dart';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

import '../../Utils.dart';
import '../main.dart';
import '../pages/Home.dart';
import 'DataManager.dart';

class SauceNAO extends StatefulWidget{
  final ImageMeta imageMeta;
  const SauceNAO({ super.key, required this.imageMeta});

  @override
  State<SauceNAO> createState() => _SauceNAOState();
}

class _SauceNAOState extends State<SauceNAO> {
  int state = 0;
  int states = 4;

  double minimumSimilarity = 0;

  List<Result> results = [];

  @override
  void initState(){
    super.initState();
    runSauceNAO();
  }

  Future<void> runSauceNAO() async {

    final Uint8List bytes = await compute(readAsBytesSync, widget.imageMeta.fullPath!);
    img.Image? image = await compute(img.decodeImage, bytes);
    image = image!.width == image.height ? img.resize(image, width: 250, maintainAspect: true) : img.resize(image, width: image.width > image.height ? 250 : null, height: image.height > image.width ? 250 : null, maintainAspect: true);
    Uint8List fi = img.encodeJpg(image);

    setState(() {state = 1;});

    // Unload this shit
    Map<String, String> params = {
      'output_type': '2', // json
      'db': '999',
      'numres': '16'
    };
    if(prefs.containsKey('saucenao_apikey')) params['api_key'] = prefs.getString('saucenao_apikey')!;
    if(prefs.getBool('saucenao_testmode') ?? false) params['saucenao_testmode'] = '1';

    final Uri uri = Uri(
        scheme: 'https',
        host: 'saucenao.com',
        path: '/search.php',
        queryParameters: params
    );

    var request = http.MultipartRequest('POST', uri);
    request.files.add(
        http.MultipartFile(
            'file',
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

      dynamic data = await json.decode(response.body);
      minimumSimilarity = data['header']['minimum_similarity'] as double;
      results = List<Result>.from(data['results'].map((e) => Result.fromJson(e as Map<String, dynamic>)));
      setState(() {state = 4;});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
            title: const Text('SauceNAO'),
            backgroundColor: const Color(0xaa000000),
            elevation: 0,
            actions: []
        ),
        body: SafeArea(
            child: Row(
              children: [
                Container(
                  width: 312,
                  child: Column(
                    children: [
                    Hero(
                      tag: widget.imageMeta.fileName,
                      child: !widget.imageMeta.isLocal ?
                        CachedNetworkImage(imageUrl: widget.imageMeta.fullNetworkPath ?? context.read<ImageManager>().getter.getFullUrlImage(widget.imageMeta)) :
                        Image.file(File(widget.imageMeta.fullPath ?? widget.imageMeta.tempFilePath ?? widget.imageMeta.cacheFilePath ?? 'e.png')),
                      ),
                      LinearProgressIndicator(value: state/states),
                    ],
                  ),
                ),
                Flexible(flex: 1, child: Container(
                  color: Theme.of(context).colorScheme.background,
                  child: ListView.separated(
                    separatorBuilder: (BuildContext context, int index) => const Divider(height: 14),
                    itemCount: results.length,
                    padding: EdgeInsets.all(7),
                    itemBuilder: (BuildContext context, int index) {
                      Result el = results[index];
                      double sim = double.parse(el.header.similarity);
                      return Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: Theme.of(context).scaffoldBackgroundColor
                          ),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(7.0),
                                  child: Stack(
                                    children: [
                                      CachedNetworkImage(imageUrl: el.header.thumbnail),
                                      Container(
                                        margin: const EdgeInsets.only(top: 3, left: 3),
                                        height: 18,
                                        padding: const EdgeInsets.only(left: 2, right: 2, bottom: 1),
                                        decoration: BoxDecoration(
                                            borderRadius: const BorderRadius.all(Radius.circular(2)),
                                            color: (sim >= minimumSimilarity ? Colors.green : Colors.red).withOpacity(0.7)
                                        ),
                                        child: Text(el.header.similarity, textAlign: TextAlign.center, style: TextStyle(color: (sim >= minimumSimilarity ? Colors.greenAccent : Colors.redAccent), fontSize: 12, fontWeight: FontWeight.bold)),
                                      )
                                    ],
                                  ),
                                ),
                                Gap(7),
                                Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if(el.data.title != null) InfoBox(one: 'Title', two: el.data.title),
                                        if(el.data.eng_name != null) InfoBox(one: 'English Name', two: el.data.eng_name),
                                        if(el.data.jp_name != null) InfoBox(one: 'Japan Name', two: el.data.jp_name),

                                        if(el.data.artist != null) InfoBox(one: 'Artist', two: el.data.artist),
                                        if(el.data.creator != null) InfoBox(one: 'Creator', two: el.data.creator.runtimeType == String ? el.data.creator : el.data.creator.join(',\n')),
                                        if(el.data.author != null) InfoBox(one: 'Author', two: el.data.author),
                                        if(el.data.author_name != null) InfoBox(one: 'Author Name', two: el.data.author_name),

                                        if(el.data.fa_id != null) InfoBox(one: 'FurAffinity ID', two: el.data.fa_id.toString()),
                                        if(el.data.e621_id != null) InfoBox(one: 'E621 ID', two: el.data.e621_id.toString()),
                                        const Gap(7),
                                        if(el.data.e621_id != null) ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              minimumSize: Size.zero, // Set this
                                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                                            ),
                                            onPressed: () async {
                                              int notID = 0;
                                              notID = notificationManager!.show(
                                                  thumbnail: const Icon(Icons.change_circle, color: Colors.blueAccent, size: 32),
                                                  title: 'Let\'s try to find...',
                                                  description: 'It shouldn\'t take long',
                                              );
                                              audioController!.player.play(AssetSource('audio/open.wav'));

                                              context.read<DataManager>().getE621Post(el.data.e621_id!).then((e) => Future.delayed(const Duration(seconds: 2), () => notificationManager!.close(notID)));
                                              //downloadToDownloadFolder('test123.png', el.data.)
                                            },
                                            child: const Text("Try download original", style: TextStyle(fontSize: 12))
                                        )
                                      ],
                                    )
                                )
                              ]
                          )
                      );
                    },
                  ),
                  ),
                ),
                Flexible(flex: 1, child: SingleChildScrollView(
                  padding: EdgeInsets.all(7),
                  child: Text('Later...')
                )),
              ],
            )
        )
    );
  }
}
