import 'dart:convert';
import 'dart:io';

import 'package:cimagen/components/PromtAnalyzer.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Utils.dart';
import '../modules/Animations.dart';
import 'package:path/path.dart' as p;

import '../utils/ImageManager.dart';

class TagsClassification extends StatefulWidget{

  const TagsClassification({ super.key });

  @override
  State<TagsClassification> createState() => _TagsClassificationState();
}

class _TagsClassificationState extends State<TagsClassification> {
  bool loaded = false;

  int gogogo = 0;

  Map<String, TagInfo> allTags = {};
  List<String> done = [];

  Map<String, List<String>> current = {
    "G": [],
    "PG": [],
    "PG_13": [],
    "R": [],
    "NC_17": [],
    "X": [],
    "XXX": []
  };

  @override
  void initState(){
    super.initState();
    allTags = Map<String, TagInfo>.from(context.read<DataManager>().e621Tags);
    load();
  }

  Future<void> load() async {
    setState(() {
      loaded = false;
      done = [];
    });
    Directory dD = await getApplicationDocumentsDirectory();
    dynamic jsonPath = Directory(p.join(dD.path, 'CImaGen', 'json'));
    if (!jsonPath.existsSync()) {
      await jsonPath.create(recursive: true);
    }
    jsonPath = File(p.join(dD.path, 'CImaGen', 'json', 'content-rating.json'));
    if (jsonPath.existsSync()) {
      print('ok');
      File(jsonPath.path).readAsString().then((v) async {
        var data = await json.decode(v);
        current['G'] = List<String>.from(data['G']);
        current['PG'] = List<String>.from(data['PG']);
        current['PG_13'] = List<String>.from(data['PG_13']);
        current['R'] = List<String>.from(data['R']);
        current['NC_17'] = List<String>.from(data['NC_17']);
        current['X'] = List<String>.from(data['X']);
        current['XXX'] = List<String>.from(data['XXX']);
        //cleanup
        for (var key in current.keys) {
          done.addAll(current[key]!);
        }
        for(String tag in done){
          allTags.remove(tag);
        }

        for(String key in allTags.keys){
          TagInfo t = allTags[key]!;
          if([1,3,4,5].contains(t.category)){
            current['G']!.add(t.name);
            // allTags.remove(key);
          }
          for (var e in ['sex', 'cum', 'vaginal', 'masturbation', 'penetration', 'anus', 'penis']) {
            if(t.name.startsWith('${e}_') || t.name.endsWith('_${e}')){
              current['X']!.add(t.name);
            }
          }
        }

        jsonPath.writeAsStringSync(json.encode(current));

        setState(() {
          loaded = true;
        });
      });
    } else {
      jsonPath.writeAsStringSync(json.encode(current));
      //{
      //     "G": [],
      //     "PG": [],
      //     "PG_13": [],
      //     "R": [],
      //     "NC_17": [],
      //     "X": [],
      //     "XXX": []
      // }
    }
  }

  Future<void> rate(ContentRating rating) async {
    TagInfo c = allTags[allTags.keys.first]!;
    current[rating.name]!.add(c.name);
    allTags.remove(allTags.keys.first);

    //save
    Directory dD = await getApplicationDocumentsDirectory();
    File jsonPath  = File(p.join(dD.path, 'CImaGen', 'json', 'content-rating.json'));
    jsonPath.writeAsStringSync(json.encode(current));

    setState(() {
      gogogo++;
    });
  }

  @override
  Widget build(BuildContext context) {
    TagInfo? c = allTags.keys.isNotEmpty ? allTags[allTags.keys.first] : null;
    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
            title: const ShowUp(
              delay: 100,
              child: Text('Manual Tags Classification', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600, fontFamily: 'Montserrat')),
            ),
            backgroundColor: const Color(0xaa000000),
            elevation: 0,
            actions: []
        ),
        body: SafeArea(
            child: c != null ? Column(
              children: [
                Row(
                  children: [
                    Column(
                      children: [
                        loaded ? const Icon(Icons.check, color: Colors.greenAccent) : const CircularProgressIndicator(),
                        Text('Total: ${allTags.keys.length + done.length}'),
                        Text('Rated: ${done.length}'),
                        Text('Not rated: ${allTags.keys.length}'),
                      ],
                    )
                  ],
                ),
                TextButton(
                  onPressed: () async {
                    final Uri _url = Uri(
                        scheme: 'https',
                        host: 'e621.net',
                        path: '/posts',
                        queryParameters: {'tags': c.name}
                    );
                    if (!await launchUrl(_url)) {
                      throw Exception('Could not launch $_url');
                    }
                  },
                  child: Text(c.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500)),
                ),
                Text(c.id.toString()),
                Text('usage: ${c.count.toString()}'),
                Text(categoryToString(c.category)),
                const Gap(28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: ([1,3,4,5].contains(c.category) ? [ContentRating.G] : [
                    ContentRating.G,
                    ContentRating.PG,
                    ContentRating.PG_13,
                    ContentRating.R,
                    ContentRating.NC_17,
                    ContentRating.X,
                    ContentRating.XXX,
                  ]).map((r) => ElevatedButton.icon(
                    icon: Container(
                      width: 18,
                      height: 18,
                      padding: const EdgeInsets.only(left: 2, right: 2, bottom: 1),
                      decoration: BoxDecoration(
                          borderRadius: const BorderRadius.all(Radius.circular(2)),
                          color: Color(r == ContentRating.X || r == ContentRating.XXX ? 0xff000000 : 0xffffffff)
                      ),
                      child: Text(r.name, textAlign: TextAlign.center, style: TextStyle(color: Color([
                        0xff006835,
                        0xfff15a24,
                        0xff803d99,
                        0xffd8121a,
                        0xff1b3e9b,
                        0xffffffff,
                        0xffffffff
                      ][r.index]), fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    label: Text(r.name),
                    onPressed: () => rate(r),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32.0),
                      ),
                    ),
                  )).toList(growable: false)
                )
              ],
            ) : const Text('tags db not found')
        )
    );
  }
}