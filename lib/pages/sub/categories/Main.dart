import 'package:cimagen/pages/Home.dart';
import 'package:cimagen/pages/sub/categories/Utils/UtilsList.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../components/CustomMasonryView.dart';

class MainContent extends StatelessWidget{
  final double breakpoint = 600.0;
  void Function(CategoryMini category) appendCategory;

  MainContent(this.appendCategory, {super.key});
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: screenWidth <= breakpoint ? screenWidth * 70 / 100 : 500,
              ),
              child: Column(
                children: [
                  Text('👋', style: TextStyle(fontSize: 50)),
                  const Gap(4),
                  Text('Hello, how are you?', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  Text('What are we going to do today?', style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            const Gap(22),
            CustomMasonryView(
              itemRadius: 14,
              itemPadding: 4,
              listOfItem: [
                BlockData(
                  title: 'Utils',
                  description: 'Various tools for working with images and more',
                  color: Color(0xff8acee0),
                  icon: Icons.web_rounded,
                  miniIcons: [
                    MiniIcon(color: Color(0xff7371fc), icon: Icons.auto_graph)
                  ]
                ),
                // BlockData(
                //     title: 'Utils',
                //     description: 'Various tools for working with images and more',
                //     color: Color(0xff8acee0),
                //     icon: Icons.web_rounded,
                //     miniIcons: [
                //       MiniIcon(color: Color(0xff7371fc), icon: Icons.auto_graph)
                //     ]
                // ),
              ],
              numberOfColumn: (MediaQuery.of(context).size.width / 600).round(),
              itemBuilder: (ii) {
                return AspectRatio(aspectRatio: 16/9, child: Container(
                  padding: EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                        radius: 2,
                        center: Alignment(0.5, 2),
                        colors: [Colors.blue, Colors.black]
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.grey[850]!,
                      width: 2,
                    ),
                    boxShadow: [
                      //BoxShadow(color: Colors.grey, spreadRadius: 3)
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: <Color>[Colors.black, Colors.blue]
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.grey[850]!,
                                width: 1,
                              ),
                              boxShadow: [
                                //BoxShadow(color: Colors.grey, spreadRadius: 3)
                              ],
                            ),
                            child: Icon(Icons.apps, color: Colors.white, size: 32),
                          ),
                          Spacer(),
                          ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                minimumSize: Size.zero, // Set this
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                              ),
                              onPressed: () => appendCategory(CategoryMini(name: 'Utils', color: Color(0xff93cb76), widget: UtilsList(appendCategory))),
                              child: const Text("View", style: TextStyle(fontSize: 14))
                          )
                        ],
                      ),
                      Gap(6),
                      Wrap(
                        children: (ii.item.miniIcons as List<MiniIcon>).map((el) => iconPreview(el.icon, el.color)).toList(),
                      ),
                      Gap(16),
                      Text('Utils', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600)),
                      Text('', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ));
              },
            )
          ],
        )
    );
  }
}

Widget iconPreview(IconData icon, Color color){
  return Container(
    padding: EdgeInsets.all(3),
    decoration: BoxDecoration(
      gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Colors.black, color]
      ),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(
        color: Colors.grey[850]!,
        width: 1,
      ),
      boxShadow: [
        //BoxShadow(color: Colors.grey, spreadRadius: 3)
      ],
    ),
    child: Icon(icon, color: Colors.white, size: 16),
  );
}

class BlockData {
  String title;
  String? description = '';
  Color? color = Colors.redAccent;
  IconData? icon = Icons.category;
  Future Function()? onClick;
  String? buttonText = 'default';
  List<MiniIcon> miniIcons;

  BlockData({
    required this.title,
    this.description,
    this.color,
    this.icon,
    this.onClick,
    this.buttonText,
    this.miniIcons = const []
  });
}

class MiniIcon {
  Color color = Colors.redAccent;
  IconData icon = Icons.category;

  MiniIcon({
    required this.color,
    required this.icon,
  });
}