import 'package:cimagen/modules/pawchive/pawchiveUI.dart';
import 'package:cimagen/pages/sub/InkJetUnclog.dart';
import 'package:cimagen/pages/sub/categories/Utils/LoraMakerList.dart';
import 'package:flutter/material.dart';

import '../../../../components/CustomMasonryView.dart';
import '../../../../main.dart';
import '../../../Home.dart';
import '../../AudioAnalyzer.dart';
import '../../LottieJsonPreview.dart';
import '../../PSDRecover.dart';

class UtilsList extends StatelessWidget {
  final double breakpoint = 600.0;
  void Function(CategoryMini category) appendCategory;

  UtilsList(this.appendCategory, {super.key});

  @override
  Widget build(BuildContext context) {
    return CustomMasonryView(
      itemRadius: 14,
      itemPadding: 4,
      listOfItem: [
        Util(
          title: 'Lora helper',
          description: 'Data collection and training utility',
          color: Color(0xffeabe5c),
          icon: Icons.auto_graph,
          onClick: () async => appendCategory(CategoryMini(name: 'Lora Maker', color: Color(0xffeabe5c), widget: LoraMakerList()))
        ),
        Util(
          title: 'MiniSD',
          description: 'Minimal panel for generating images',
          color: Color(0xff8acee0),
          icon: Icons.web_rounded,
        ),
        Util(
          title: 'Tag combinator',
          description: 'A utility for quickly, for example, transferring tags from one character to another',
          color: Color(0xffd38ae0),
          icon: Icons.tag,
        ),
        Util(
            title: 'InkJet Unclog',
            description: 'Printing a pattern for cleaning the printer',
            color: Color(0xff9270c9),
            icon: Icons.print,
            onClick: () => Navigator.push(context, MaterialPageRoute(builder: (context) => InkJetUnclog()))
        ),
        if(prefs.getBool('debug') ?? false) Util(
            title: 'Lottie JSON bath preview',
            description: 'Select folder and preview all icons',
            color: Color(0xffc2e35f),
            icon: Icons.find_in_page,
            onClick: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LottieJsonPreview(directoryPath: 'W:\\icons',)))
        ),
        if(prefs.getBool('debug') ?? false) Util(
            title: 'Audio Analyzer',
            description: '-',
            color: Color(0xffe08ba9),
            icon: Icons.audiotrack,
            onClick: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AudioAnalyzer()))
        ),
        Util(
            title: 'Pixel Art Rebuilder',
            description: 'Mesh overlay and pixel art restoration',
            color: Color(0xff827eb9),
            icon: Icons.grid_on_sharp,
            onClick: () => Navigator.push(context, MaterialPageRoute(builder: (context) => InkJetUnclog()))
        ),
        Util(
            title: 'PSD recover',
            description: 'If you have the final merged image and the source layers, we can try to restore it.',
            color: Color(0xff5181da),
            icon: Icons.layers,
            onClick: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PSDRecover()))
        ),
        Util(
            title: 'DotSearch search',
            description: '-',
            color: Color(0xff51b5da),
            icon: Icons.scatter_plot,
            onClick: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DotSearch()))
        ),
      ],
      numberOfColumn: (MediaQuery.of(context).size.width / 500).round(),
      itemBuilder: (ii) {
        return AspectRatio(aspectRatio: 16/9, child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF2d2f32),
              width: 2,
            ),
            color: Colors.black.withAlpha(120)
          ),
          child: Stack(
            children: [
              // Positioned(
              //   bottom: 0,
              //   right: 0,
              //   child: Stack(
              //     alignment: Alignment.bottomRight,
              //     children: [
              //       Icon(ii.item.icon, color: ii.item.color, size: 205),
              //       Icon(ii.item.icon, color: Colors.black.withAlpha(120), size: 200),
              //     ],
              //   ),
              // ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.all(21),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: ii.item.color.withOpacity(0.3),
                          // boxShadow: const [
                          //   BoxShadow(color: Colors.black, spreadRadius: 3),
                          // ]
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Center(child: Icon(ii.item.icon, color: ii.item.color, size: 21),)
                      ),
                      const Spacer(),
                      Text(ii.item.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 21)),
                      ii.item.description != null ? Text(ii.item.description, style: const TextStyle(color: Colors.grey, fontSize: 14)) : const SizedBox.shrink(),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed:
                        ii.item.onClick != null ? () => ii.item.onClick() : null,
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text("Open"),
                        style: FilledButton.styleFrom(
                          backgroundColor: ii.item.color,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        ));
      },
    );
  }
}

class Util {
  String title;
  String? description = '';
  Color? color = Colors.redAccent;
  IconData? icon = Icons.category;
  Image? thumbnail;
  Future Function()? onClick;

  Util({
    required this.title,
    this.description,
    this.color,
    this.icon,
    this.thumbnail,
    this.onClick
  });
}