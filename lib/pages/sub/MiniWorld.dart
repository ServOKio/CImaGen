import 'package:flutter/material.dart';
import 'package:infinite_canvas/infinite_canvas.dart';

class MiniWorld extends StatefulWidget{
  const MiniWorld({ super.key });

  @override
  State<MiniWorld> createState() => _MiniWorldState();
}

class _MiniWorldState extends State<MiniWorld> {
  late InfiniteCanvasController controller;

  @override
  void initState() {
    super.initState();

    final rectangleNode = InfiniteCanvasNode(
      key: UniqueKey(),
      label: 'Rectangle',
      offset: const Offset(400, 300),
      size: const Size(200, 200),
      child: Builder(
        builder: (context) {
          return Container(
            width: 10,
            height: 20,
            color: Colors.red,
          );
        },
      ),
    );
    final triangleNode = InfiniteCanvasNode(
      key: UniqueKey(),
      label: 'Triangle',
      offset: const Offset(550, 300),
      size: const Size(200, 200),
      child: Builder(
        builder: (context) {
          return Container(
            width: 10,
            height: 20,
            color: Colors.green,
          );
        },
      ),
    );
    final circleNode = InfiniteCanvasNode(
      key: UniqueKey(),
      label: 'Circle',
      offset: const Offset(500, 450),
      size: const Size(200, 200),
      child: Builder(
        builder: (context) {
          return Container(
            width: 10,
            height: 20,
            color: Colors.blueAccent,
          );
        },
      ),
    );
    final nodes = [
      rectangleNode,
      triangleNode,
      circleNode,
    ];
    controller = InfiniteCanvasController(nodes: nodes);
  }

  @override
  Widget build(BuildContext context) {
    return InfiniteCanvas(
      controller: controller,
    );
  }
}