import 'package:flutter/material.dart';
import 'package:infinite_canvas/infinite_canvas.dart';
import 'package:node_editor/node_editor.dart';

import 'nodes.dart';

class MiniWorld extends StatefulWidget{
  const MiniWorld({ super.key });

  @override
  State<MiniWorld> createState() => _MiniWorldState();
}

class _MiniWorldState extends State<MiniWorld> {
  final NodeEditorController controller = NodeEditorController();
  final FocusNode _focusNode = FocusNode();
  final FocusNode _focusNode2 = FocusNode();
  final TextEditingController _controller = TextEditingController();
  @override
  void initState() {
    controller.addSelectListener((Connection conn) {
      debugPrint("ON SELECT inNode: ${conn.inNode}, inPort: ${conn.inPort}");
    });

    controller.addNode(
      componentNode('node_1_1'),
      NodePosition.afterLast,
    );
    controller.addNode(
      componentNode('node_1_2'),
      NodePosition.afterLast,
    );
    controller.addNode(
      componentNode('node_1_3'),
      NodePosition.afterLast,
    );
    controller.addNode(
      receiverNode('node_2_1', _focusNode2, _controller),
      NodePosition.afterLast,
    );
    controller.addNode(
      binaryNode('node_3_1'),
      NodePosition.afterLast,
    );
    controller.addNode(
      sinkNode('node_4_1'),
      NodePosition.afterLast,
    );
    super.initState();
  }

  void _addNewNode() {
    controller.addNode(
      componentNode("new_node"),
      NodePosition.afterLast,
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
          title: const Text('Mini World'),
          backgroundColor: const Color(0xaa000000),
          elevation: 0,
          actions: []
      ),
      body: SafeArea(
        child: NodeEditor(
          focusNode: _focusNode,
          controller: controller,
          background: const GridBackground(
            backgroundColor: const Color(0xff141218),
            lineColor: const Color(0xff29272e)
          ),
          infiniteCanvasSize: 5000,
        )
      )
    );
  }
}