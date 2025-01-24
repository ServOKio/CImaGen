import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snowflake_dart/snowflake_dart.dart';

import '../../utils/ImageManager.dart';

class DebugDevPage extends StatefulWidget {
  DebugDevPage({Key? key}) : super(key: key);

  @override
  _DebugDevPageState createState() => _DebugDevPageState();
}

class _DebugDevPageState extends State<DebugDevPage> {
  bool loaded = false;
  Snowflake snowflake = Snowflake(epoch: 1420070400000, nodeId: 0);

  @override
  void initState() {
    super.initState();
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
                  context.read<ImageManager>().changeGetter(3);
                },
                child: Text('Change getter to OnWeb'),
              ),
            ],
          )
        )
    );
  }
}