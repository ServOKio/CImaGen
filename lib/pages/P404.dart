import 'dart:math';

import 'package:cimagen/Utils.dart';
import 'package:flutter/material.dart';

class P404 extends StatefulWidget {
  @override
  State<P404> createState() => _P404State();
}

class _P404State extends State<P404> {
  final _random = new Random();
  int next(int min, int max) => min + _random.nextInt(max - min);
  List<D> ci = [];
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  void load() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (var i = 0; i < 100; i++) {
        double size = next(30, 60).toDouble();
        ci.add(D(x: next(0, MediaQuery.of(context).size.width.round()).toDouble(), y: next(0, MediaQuery.of(context).size.height.round()).toDouble(), c: getColor(i), s: size));
      }
      setState(() {
        loaded = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Stack(children: loaded ? ci.map<Positioned>((ent){
          return Positioned(
              left: ent.x,
              top: ent.y,
              child: Container(width: 50, height: 50, decoration:
              BoxDecoration(
                color: ent.c,
                shape: BoxShape.circle,
                backgroundBlendMode: BlendMode.screen
              ))
          );
        }).toList() : []),
        Positioned.fill(
            child: Align(
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ClipRRect(
                    //   borderRadius: BorderRadius.circular(18),
                    //   child: Container(
                    //     padding: EdgeInsets.all(10),
                    //     color: Color(0xffff0000),
                    //     child: Container(
                    //       height: 100,
                    //       width: 100,
                    //       decoration: BoxDecoration(
                    //         shape: BoxShape.circle,
                    //         color: Colors.white,
                    //       ),
                    //       padding: EdgeInsets.all(10),
                    //       child: SvgPicture.asset('assets/discord-white.svg', color: Colors.black),
                    //     ),
                    //   ),
                    // ),
                    // Container(
                    //   height: 100,
                    //   width: 100,
                    //   child: SvgPicture.asset('assets/discord-white.svg', color: Colors.white),
                    // ),
                    Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Column(children: [
                      Text('404', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                      // Row(
                      //   mainAxisAlignment: MainAxisAlignment.center,
                      //   children: [
                      //     Text('Adult only ', style: TextStyle(color: theme.newsBlockTitleSub)),
                      //     Icon(Icons.warning, size: 16),
                      //     Text(' click on logo to join', style: TextStyle(color: theme.newsBlockTitleSub)),
                      //   ],
                      // )
                    ])),
                  ],
                )
            )
        )
      ],
    );
  }
}

class D {
  final double x;
  final double y;
  final Color c;
  final double s;

  D({
    required this.x,
    required this.y,
    required this.c,
    required this.s
  });
}