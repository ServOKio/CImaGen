import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LottieJsonPreview extends StatelessWidget {
  final String directoryPath;

  const LottieJsonPreview({super.key, required this.directoryPath});

  List<File> _loadLottieFiles() {
    final dir = Directory(directoryPath);
    if (!dir.existsSync()) return [];

    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final lottieFiles = _loadLottieFiles();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Lottie File Viewer')),
      body: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: (MediaQuery.sizeOf(context).width / 74).toInt(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: lottieFiles.length,
        itemBuilder: (context, index) {
          return ColorFiltered(
            colorFilter: const ColorFilter.mode(
              Colors.white,
              BlendMode.srcIn,
            ),
            child: GestureDetector(
              onTap: (){
                print('Selected: ${lottieFiles[index].path}');
              },
              child: Lottie.file(
                lottieFiles[index],
                width: 64,
                height: 64,
                fit: BoxFit.fill,
              )
            ),
          );
        },
      ),
    );
  }
}