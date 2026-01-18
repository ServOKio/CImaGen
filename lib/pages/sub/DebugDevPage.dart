import 'dart:io';

import 'package:cimagen/main.dart';
import 'package:cimagen/utils/Objectbox.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snowflake_dart/snowflake_dart.dart';

import '../../modules/libpuzzle/libPuzzle.dart';
import '../../utils/ImageManager.dart';
import '../../utils/SQLite.dart';
import '../../utils/Tokenizer.dart';

class DebugDevPage extends StatefulWidget {
  DebugDevPage({Key? key}) : super(key: key);

  @override
  _DebugDevPageState createState() => _DebugDevPageState();
}

class _DebugDevPageState extends State<DebugDevPage> {
  bool loaded = false;
  Snowflake snowflake = Snowflake(epoch: 1420070400000, nodeId: 0);
  TokenizerModule tokenizerModule = TokenizerModule();

  LibPuzzle puzzle = LibPuzzle();

  @override
  void initState() {
    super.initState();
    puzzle.puzzle_init_context();
    puzzle.puzzle_init_cvec();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
            title: const Text('Debug'),
            backgroundColor: const Color(0xaa000000),
            elevation: 0,
            actions: [
            ]
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextButton(
                  onPressed: (){
                    print(DateTime.fromMillisecondsSinceEpoch(snowflake.getTimeFromId(1332201808214364314)));
                  },
                  child: Text('Print epoch'),
                ),
                TextButton(
                  onPressed: (){
                    context.read<ImageManager>().changeGetter(2);
                  },
                  child: Text('Change getter to OnWeb'),
                ),
                TextButton(
                  onPressed: (){
                    sqLite.testDB().then((value) {

                    }, onError: (error) {
                      print(error);
                    });
                  },
                  child: Text('Test db'),
                ),
                TextButton(
                  onPressed: (){
                    objectbox.fixDB(DBErrorsForFix.image_size_missmatch);
                  },
                  child: Text('Fix db: broken cached image size'),
                ),
                TextButton(
                  onPressed: () async {
                    int res = await puzzle.puzzle_fill_cvec_from_file(File('W:/00906-3163105554.png'));
                    print(res);
                  },
                  child: Text('Test libpuzzle'),
                ),
                TextButton(
                  onPressed: () async {
                    List<Map<String, dynamic>> res = await tokenizerModule.tokenize('runwayml/stable-diffusion-v1-5', 'by blotch, by (darkgem:1.3), by mystikfox61, by strange-fox, by (nawka:0.7), (by rayliicious:0.8)');
                    print(res);
                  },
                  child: Text('Test tokenizerModule'),
                ),
                TextButton(
                  onPressed: () async {
                    objectbox.getBiggestAss();
                  },
                  child: Text('get big ass'),
                ),
                Text("Jobs"),
                Column(
                  children: context.read<ImageManager>().getter.getJobs.keys.map((key){
                    ParseJob j = context.read<ImageManager>().getter.getJobs[key]!;
                    return Container(
                      margin: EdgeInsets.all(7),
                      color: Colors.blueGrey,
                      child: Column(
                        children: [
                          SelectableText('JobID: ${j.jobID}'),
                          SelectableText('controller.isClosed: ${j.controller.isClosed}'),
                          SelectableText('host: ${j.host}'),
                          SelectableText('isDone: ${j.isDone}'),
                          TextButton(
                            onPressed: () => j.forceStop(),
                            child: Text('Force stop'),
                          ),
                        ],
                      ),
                    );
                  }).toList(growable: false),
                )
              ],
            ),
          )
        )
    );
  }
}