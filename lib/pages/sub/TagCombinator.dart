import 'dart:ui';

import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/material.dart';

import '../../components/Animations.dart';

class TagCombinator extends StatefulWidget{
  final ImageMeta? oneImageMeta;
  final ImageMeta? twoImageMeta;

  const TagCombinator({ super.key, this.oneImageMeta, this.twoImageMeta});

  @override
  State<TagCombinator> createState() => _TagCombinatorState();
}

class _TagCombinatorState extends State<TagCombinator>{
  bool loaded = false;

  @override
  void initState(){
    super.initState();
    initClient();
  }

  @override
  void dispose() {
    super.dispose();
    //
  }

  Future<void> initClient() async {
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
            title: const ShowUp(
              delay: 100,
              child: Text('Tag Combinator', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600, fontFamily: 'Montserrat')),
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
                  child: Text('1')
                )),
                Flexible(flex: 1, child: Column(
                  children: [
                    Expanded(
                        child: Text('2')
                    ),
                  ],
                )),
                Flexible(flex: 1, child: SingleChildScrollView(
                  padding: EdgeInsets.all(7),
                  child: Text('3')
                )),
              ],
            )
        )
    );
  }
}