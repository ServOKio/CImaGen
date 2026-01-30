import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../modules/DataManager.dart';

import 'package:path/path.dart' as p;

class Networktest extends StatefulWidget{

  const Networktest({ super.key });

  @override
  State<Networktest> createState() => _NetworktestState();
}

class _NetworktestState extends State<Networktest> {

  bool loaded = false;

  @override
  void initState(){
    super.initState();
  }

  Future<void> test() async {
    setState(() {
      loaded = false;
    });


    setState(() {
      loaded = true;

    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Text('fdf'),
    );
  }
}