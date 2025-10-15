import 'package:cimagen/pages/sub/categories/LoraMakerList.dart';
import 'package:flutter/material.dart';

import '../../../components/CustomMasonryView.dart';
import '../../Home.dart';

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
        )
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
            gradient: RadialGradient(
              colors: [ii.item.color, Colors.black],
              stops: const [0, 1],
              center: Alignment.topCenter,
              focalRadius: 2,
            ),
            boxShadow: const [
              BoxShadow(color: Colors.black, spreadRadius: 3),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                bottom: 0,
                right: 0,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Icon(ii.item.icon, color: ii.item.color, size: 205),
                    Icon(ii.item.icon, color: Colors.black, size: 200),
                  ],
                ),
              ),
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
                          boxShadow: const [
                            BoxShadow(color: Colors.black, spreadRadius: 3),
                          ]
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Center(child: Icon(ii.item.icon, color: ii.item.color, size: 21),)
                      ),
                      const Spacer(),
                      Text(ii.item.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 21)),
                      ii.item.description != null ? Text(ii.item.description, style: const TextStyle(color: Colors.grey, fontSize: 14)) : const SizedBox.shrink(),
                      const Spacer(),
                      Row(
                        children: [
                          TextButton(
                            onPressed: ii.item.onClick != null ? () => ii.item.onClick() : null,
                            child: Text('Open'),
                          )
                        ]
                      )
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