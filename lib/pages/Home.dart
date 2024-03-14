import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'package:desktop_drop/desktop_drop.dart';
import 'dart:io';
import 'package:cross_file/cross_file.dart';

import '../Utils.dart';

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool _dragging = false;

  Future<void> readDraged(List<XFile> files) async {
    XFile f = files.first;
    if(isImage(f)){

    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          color: Theme.of(context).colorScheme.background,
          width: 350,
          child: Column(
            children: [
              const Spacer(),
              Container(
                height: 1,
                color: const Color(0xFF2d2f32),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: DropTarget(
                  onDragDone: (detail) {
                    readDraged(detail.files);
                  },
                  onDragEntered: (detail) {
                    setState(() {
                      _dragging = true;
                    });
                  },
                  onDragExited: (detail) {
                    setState(() {
                      _dragging = false;
                    });
                  },
                  child: DottedBorder(
                    dashPattern: const [6, 6],
                    color: const Color(0xFF2d2f32),
                    borderType: BorderType.RRect,
                    strokeWidth: 2,
                    radius: const Radius.circular(12),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          color: _dragging ? Colors.blue.withOpacity(0.4) : Theme.of(context).scaffoldBackgroundColor,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.file_open_outlined, color: Color(0xFF0068ff), size: 36),
                                Gap(6),
                                Text('Drag-n-Drop to unload', style: TextStyle(fontWeight: FontWeight.w500)),
                                Text('or'),
                                Text('Enter URL', style: TextStyle(fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ),
                      )
                    ),
                  ),
                )
              )
            ],
          )
        )
      ]
    );
  }
}