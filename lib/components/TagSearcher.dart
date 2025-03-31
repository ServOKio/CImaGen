import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../modules/DataManager.dart';

import 'package:path/path.dart' as p;
import 'package:fast_csv/fast_csv_ex.dart' as fast_csv_ex;

class TagSearcher extends StatefulWidget{

  const TagSearcher({ super.key });

  @override
  State<TagSearcher> createState() => _TagSearcherState();
}

class _TagSearcherState extends State<TagSearcher> {

  bool loaded = false;
  String title = 'Select .csv file';

  List<String> tags = [];
  String? search;

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
    List<String> fTags = search != null ? tags.where((t) => t.contains(search!)).toList() : tags;
    return CustomScrollView(
      slivers: <Widget>[
        SliverAppBar(
          title: loaded ? TextField(
            onSubmitted: (value) async {
              value = value.trim();
              setState(() {
                search = value == '' ? null : value.toLowerCase();
              });
            },
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Enter a search term',
            ),
          ) : Text(title),
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
                  prefs.setString('last_tag_search_file', result.files.single.path!);
                  file.readAsString().then((value) async {
                    final data = await compute(fast_csv_ex.parse, value.replaceAll('"', "'"));
                    setState(() {
                      tags = (data as List<dynamic>).map((e) => e[0] as String).toList();
                      loaded = true;
                    });
                  });
                } else {
                  // User canceled the picker
                }
              },
            ),
          ],
        ),
        SliverFixedExtentList(
          itemExtent: 50.0,
          delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
              return Container(
                color: [Colors.indigo, Colors.blueAccent][index % 2],
                child: SelectableText(fTags[index]),
              );
            },
            childCount: fTags.length
          ),
        ),
      ],
    );
  }
}