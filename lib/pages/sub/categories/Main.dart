import 'package:cimagen/pages/Home.dart';
import 'package:cimagen/pages/sub/categories/UtilsList.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class MainContent extends StatelessWidget{
  final double breakpoint = 600.0;
  void Function(CategoryMini category) appendCategory;

  MainContent(this.appendCategory, {super.key});
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: screenWidth <= breakpoint ? screenWidth * 70 / 100 : 500,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('👋', style: TextStyle(fontSize: 50)),
              const Gap(4),
              Text('Hello, how are you?', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              Text('What are we going to do today?', style: const TextStyle(color: Colors.grey)),
              const Gap(22),
              Container(
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
                      children: [
                        iconPreview(Icons.auto_graph, Color(0xff7371fc))
                      ],
                    ),
                    Gap(16),
                    Text('Utils', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600)),
                    Text('Various tools for working with images and more', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              )
            ],
          ),
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