import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../modules/DataManager.dart';

import 'package:path/path.dart' as p;
import 'package:fast_csv/fast_csv_ex.dart' as fast_csv_ex;

class ArtistDefaultStyleSearcher extends StatefulWidget{

  const ArtistDefaultStyleSearcher({ super.key });

  @override
  State<ArtistDefaultStyleSearcher> createState() => _ArtistDefaultStyleSearcherState();
}

class _ArtistDefaultStyleSearcherState extends State<ArtistDefaultStyleSearcher> {

  bool loaded = false;
  String title = 'Select .csv file';

  List<String> endsWith = [];
  List<String> artists = [];

  @override
  void initState(){
    super.initState();
  }

  Future<void> analyze() async {
    setState(() {
      loaded = false;
    });

    var _tags = context.read<DataManager>().e621Tags;

    setState(() {
      loaded = true;

    });
  }

  @override
  Widget build(BuildContext context) {
    List<String> ar = artists.where((a) => (a.toLowerCase().startsWith('r') && a.toLowerCase().endsWith('y') || a.toLowerCase().startsWith('a') && a.toLowerCase().endsWith('y'))).toList();
    return CustomScrollView(
      slivers: <Widget>[
        SliverAppBar(
          title: Text(title+(artists.isNotEmpty ? ' ${artists.length}' : '')),
          snap: true,
          floating: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.file_open),
              onPressed: () async {
                FilePickerResult? result = await FilePicker.platform.pickFiles(
                  dialogTitle: 'Select .csv file with model tags',
                  allowedExtensions: ['.csv']
                );

                if (result != null) {
                  File file = File(result.files.single.path!);
                  final String e = p.extension(file.path);
                  if(!e.endsWith('.csv')) return;
                  setState(() {
                    title = p.basename(file.path);
                  });
                  file.readAsString().then((value) async {
                    final data = await compute(fast_csv_ex.parse, value.replaceAll('"', "'"));
                    List<String> _artists = (data as List<dynamic>).where((test) => (test[0] as String).startsWith('by ')).map((e) => (e[0] as String).replaceFirst('by ', '')).toList();
                    setState(() {
                      artists = _artists;
                    });
                  });
                } else {
                  // User canceled the picker
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.filter_alt),
              onPressed: () async {
                showDialog<String>(
                  context: context,
                  builder: (BuildContext context) => AlertDialog(
                    content: SizedBox(
                      width: 500,
                      height: 500,
                      child: Text('fsdf'),
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: (){
                          Navigator.pop(context, 'ok');
                        },
                        child: const Text('Okay'),
                      ),
                    ],
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.textsms),
              onPressed: () async {
                showDialog<String>(
                  context: context,
                  builder: (BuildContext context) => AlertDialog(
                    content: SizedBox(
                      width: 500,
                      height: 500,
                      child: SingleChildScrollView(
                        child: SelectableText(ar.join(', ')),
                      ),
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: (){
                          Navigator.pop(context, 'ok');
                        },
                        child: const Text('Okay'),
                      ),
                    ],
                  ),
                );
              },
            )
          ],
        ),
        SliverFixedExtentList(
          itemExtent: 50.0,
          delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
              return Container(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: () async {
                    final Uri _url = Uri(
                        scheme: 'https',
                        host: 'e621.net',
                        path: '/posts',
                        queryParameters: {'tags': ar[index]}
                    );
                    if (!await launchUrl(_url)) {
                      throw Exception('Could not launch $_url');
                    }
                  },
                  child: Text(ar[index]+(context.read<DataManager>().e621Tags.containsKey(ar[index]) ? ' ${context.read<DataManager>().e621Tags[ar[index]]!.count}' : ''), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500)),
                ),
              );
            },
            childCount: ar.length
          ),
        ),
      ],
    );
  }
}