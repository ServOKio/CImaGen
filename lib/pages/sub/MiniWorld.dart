import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:image/image.dart' as img;

import '../../Utils.dart';

class MiniWorld extends StatefulWidget{
  final ImageMeta imageMeta;
  const MiniWorld({ super.key, required this.imageMeta });

  @override
  State<MiniWorld> createState() => _MiniWorldState();
}

class _MiniWorldState extends State<MiniWorld> {
  final TransformationController _transformationController =
  TransformationController();

  final List<NodeModel> nodes = [];
  final List<ConnectionModel> connections = [];

  final double canvasSize = 20000;

  final GlobalKey viewerKey = GlobalKey();
  final GlobalKey canvasKey = GlobalKey();
  final ValueNotifier<int> repaintNotifier = ValueNotifier(0);
  PaletteGenerator? paletteGenerator;
  Uint8List? readMe;

  Future<PaletteGenerator> genPalette() async {
    try {
      img.Image? data = await compute(img.decodeImage, readMe!);
      if(data != null) data = img.copyResize(data, width: 512);
      return await PaletteGenerator.fromImageProvider(
          maximumColorCount: 28,
          Image.memory(img.encodePng(data!)).image
      );
    } on PathNotFoundException catch (e){
      throw 'We\'ll fix it later.'; // TODO
    }
  }

  void measureAllPorts() {
    final canvasBox = canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (canvasBox == null) return;

    for (final node in nodes) {
      for (final port in [...node.inputs, ...node.outputs]) {
        final portBox = port.key.currentContext?.findRenderObject() as RenderBox?;
        if (portBox != null && portBox.hasSize) {
          final globalCenter = portBox.localToGlobal(portBox.size.center(Offset.zero));
          port.position = canvasBox.globalToLocal(globalCenter);
        }
      }
    }

    repaintNotifier.value++;
  }

  double minX = 0;
  double maxX = 0;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;

      _transformationController.value = Matrix4.identity()
        ..translate(
          size.width / 2 - canvasSize / 2,
          size.height / 2 - canvasSize / 2,
        );
      measureAllPorts();
    });

    if (widget.imageMeta.re == RenderEngine.comfUI &&
        widget.imageMeta.specific?['comfUINodes'] != null) {
      loadComfyJSON(widget.imageMeta.other?['prompt']);
    }
    initMain();
  }

  Future<void> initMain() async {
    if(widget.imageMeta.fullImage != null){
      readMe = widget.imageMeta.fullImage;
      PaletteGenerator t = await genPalette();
      setState(() {
        paletteGenerator = t;
      });
    } else {
      String path = widget.imageMeta.fullPath ?? widget.imageMeta.tempFilePath ?? widget.imageMeta.cacheFilePath ?? '';
      readAsBytesSync(path).then((v) async {
        readMe = v;
        PaletteGenerator t = await genPalette();
        setState(() {
          paletteGenerator = t;
        });
      });
    }
  }

  void loadComfyJSON(String jsonString) {
    final data = json.decode(jsonString) as Map<String, dynamic>;
    final Map<String, NodeModel> nodeMap = {};
    final List<ConnectionModel> connections = [];

    data.forEach((id, value) {
      final title = value['_meta']?['title'] ?? value['class_type'] ?? id;

      final inputs = <PortModel>[];
      final outputs = <PortModel>[];

      (value['inputs'] as Map<String, dynamic>).forEach((key, val) {
        if (val is List && val.length == 2 && val[0] is String) {
          final fromNode = val[0];
          connections.add(ConnectionModel(
            "${fromNode}_out_$key",
            "${id}_in_$key",
          ));
          inputs.add(PortModel(id: "${id}_in_$key", nodeId: id, isInput: true));
        } else {
          inputs.add(PortModel(
            id: "${id}_in_$key",
            nodeId: id,
            isInput: true,
            value: val,
          ));
        }
      });

      nodeMap[id] = NodeModel(
        id: id,
        position: const Offset(0, 0),
        inputs: inputs,
        outputs: outputs,
        title: title,
      );
    });

    for (var c in connections) {
      final fromId = c.fromPortId.split('_out_')[0];
      final fromPortIndex = c.fromPortId.split('_out_')[1];

      final toNodeId = c.toPortId.split('_in_')[0];
      final toPortName = c.toPortId.split('_in_')[1];

      final fromNode = nodeMap[fromId];
      if (fromNode != null) {
        final existing = fromNode.outputs.where((p) => p.id == "${fromId}_out_$fromPortIndex").toList();

        if (existing.isEmpty) {
          fromNode.outputs.add(
            PortModel(
              id: "${fromId}_out_$toPortName",
              nodeId: fromId,
              isInput: false,
            ),
          );
        }
      }
    }

    layoutNodes(nodeMap, connections);

    setState(() {
      nodes.clear();
      nodes.addAll(nodeMap.values);
      this.connections.clear();
      this.connections.addAll(connections);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      measureAllPorts();
    });
  }

  void layoutNodes(Map<String, NodeModel> nodeMap, List<ConnectionModel> connections) {
    final sortedNodes = topologicalSort(nodeMap, connections);

    final Map<String, int> nodeLayers = {};
    final Map<int, List<NodeModel>> layerGroups = {};

    for (var node in sortedNodes) {
      int layer = 0;

      for (var input in node.inputs) {
        final ref = connections.where((c) => c.toPortId == input.id).isNotEmpty
            ? connections.firstWhere((c) => c.toPortId == input.id)
            : null;
        if (ref != null) {
          final fromId = ref.fromPortId.split('_')[0];
          layer = (nodeLayers[fromId] ?? 0) + 1 > layer
              ? (nodeLayers[fromId] ?? 0) + 1
              : layer;
        }
      }

      nodeLayers[node.id] = layer;
      layerGroups.putIfAbsent(layer, () => []).add(node);
    }

    const double horizontalMargin = 150;
    const double verticalMargin = 100;
    const double nodeHeight = 250;

    // First pass: position nodes as before
    layerGroups.forEach((layer, nodesInLayer) {
      final totalHeight =
          nodesInLayer.length * nodeHeight + (nodesInLayer.length - 1) * verticalMargin;
      double startY = -totalHeight / 2;

      for (var i = 0; i < nodesInLayer.length; i++) {
        final node = nodesInLayer[i];
        final x = horizontalMargin + layer * (node.width + horizontalMargin);
        final y = startY + i * (nodeHeight + verticalMargin);
        node.position = Offset(x, y);
      }
    });

    // Calculate actual bounding box of the nodes
    minX = double.infinity;
    maxX = double.negativeInfinity;

    for (var node in nodeMap.values) {
      final nodeWidth = node.width; // make sure you have a width property
      minX = math.min(minX, node.position.dx);
      maxX = math.max(maxX, node.position.dx + nodeWidth);
    }

    for (var node in nodeMap.values) {
      node.position = node.position.translate(-((maxX - minX) / 2), 0);
    }
  }


  List<NodeModel> topologicalSort(Map<String, NodeModel> nodes, List<ConnectionModel> connections) {
    final Map<String, List<String>> graph = {};
    final Map<String, int> inDegree = {};

    nodes.forEach((id, node) {
      graph[id] = [];
      inDegree[id] = 0;
    });

    for (var c in connections) {
      final fromId = c.fromPortId.split('_')[0];
      final toId = c.toPortId.split('_')[0];
      graph[fromId]?.add(toId);
      inDegree[toId] = (inDegree[toId] ?? 0) + 1;
    }

    final queue = <String>[];
    inDegree.forEach((k, v) {
      if (v == 0) queue.add(k);
    });

    final sorted = <NodeModel>[];
    while (queue.isNotEmpty) {
      final id = queue.removeAt(0);
      sorted.add(nodes[id]!);

      for (var neighbor in graph[id]!) {
        inDegree[neighbor] = inDegree[neighbor]! - 1;
        if (inDegree[neighbor] == 0) queue.add(neighbor);
      }
    }

    return sorted;
  }



  @override
  Widget build(BuildContext context) {
    final double canvasHalf = canvasSize / 2;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          FixedDotGrid(
            controller: _transformationController,
            canvasSize: canvasSize,
          ),
          InteractiveViewer(
            transformationController: _transformationController,
            key: viewerKey,
            constrained: false,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            maxScale: 2.5,
            scaleFactor: 1000,
            minScale: 0.000001,
            clipBehavior: Clip.none,
            child: Container(
              //color: Colors.red,
              key: canvasKey,
              width: canvasSize,
              height: canvasSize,
              child: Stack(
                children: [
                  CustomPaint(
                    size: Size(canvasSize, canvasSize),
                    painter: ConnectionPainter(
                      nodes: nodes,
                      connections: connections,
                      canvasOffset: Offset(canvasHalf, canvasHalf),
                      viewerKey: viewerKey,
                      repaint: repaintNotifier,
                    ),
                  ),

                  ...nodes.map((node) => Positioned(
                    left: node.position.dx + canvasHalf,
                    top: node.position.dy + canvasHalf,
                    child: SizedBox(
                      width: node.width,
                      child: _buildNode(node),
                    ),
                  )),
                  // Positioned(
                  //   left: minX,
                  //   top: canvasHalf,
                  //   child: Container(color: Colors.greenAccent, width: 200, height: 200),
                  // ),
                  // Positioned(
                  //   left: maxX,
                  //   top: canvasHalf,
                  //   child: Container(color: Colors.yellow, width: 200, height: 200),
                  // )
                ],
              ),
            ),
          ),
          Positioned(
            top: 28,
            left: 28,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                      padding: const EdgeInsets.all(11),
                      decoration: ShapeDecoration(
                        color: Color(0xFF252525),
                        shape: SuperellipseRectangleBorder(
                          cornerRadius: 28,
                          exponent: 4,
                          side: const BorderSide(color: Color(0xcb3c3c3c), width: 1),
                        ),
                      ),
                      child: Icon(Icons.arrow_back_ios_rounded, color: Color(0xFFA6A6A6), size: 20)
                  ),
                ),
                Container(
                    padding: const EdgeInsets.all(11),
                    decoration: ShapeDecoration(
                      color: Color(0xFF252525),
                      shape: SuperellipseRectangleBorder(
                        cornerRadius: 28,
                        exponent: 4,
                        side: const BorderSide(color: Color(0xcb3c3c3c), width: 1),
                      ),
                    ),
                    child: Text('Workflow', style: TextStyle(fontFamily: 'Open Sans', color: Colors.white, fontSize: 13))
                ),
                Container(
                    padding: const EdgeInsets.all(11),
                    decoration: ShapeDecoration(
                      color: Color(0xFF252525),
                      shape: SuperellipseRectangleBorder(
                        cornerRadius: 28,
                        exponent: 4,
                        side: const BorderSide(color: Color(0xcb3c3c3c), width: 1),
                      ),
                    ),
                    child: Text('Edit', style: TextStyle(fontFamily: 'Open Sans', color: Colors.white, fontSize: 13))
                ),
                Container(
                    padding: const EdgeInsets.all(11),
                    decoration: ShapeDecoration(
                      color: Color(0xFF252525),
                      shape: SuperellipseRectangleBorder(
                        cornerRadius: 28,
                        exponent: 4,
                        side: const BorderSide(color: Color(0xcb3c3c3c), width: 1),
                      ),
                    ),
                    child: Text('Help', style: TextStyle(fontFamily: 'Open Sans', color: Colors.white, fontSize: 13))
                ),
              ].expand((x) => [const Gap(7), x]).skip(1).toList(),
            ),
          ),
          Positioned(
            top: 28,
            right: 28,
            child: Row(
              children: [
                GestureDetector(
                  child: Container(
                      padding: const EdgeInsets.all(11),
                      decoration: ShapeDecoration(
                        color: Color(0xFF252525),
                        shape: SuperellipseRectangleBorder(
                          cornerRadius: 28,
                          exponent: 4,
                          side: const BorderSide(color: Color(0xcb3c3c3c), width: 1),
                        ),
                      ),
                      child: Icon(Icons.more_vert, color: Color(0xFFA6A6A6), size: 20)
                  ),
                ),
                Container(
                    padding: const EdgeInsets.all(2),
                    decoration: ShapeDecoration(
                      color: Color(0xFF252525),
                      shape: SuperellipseRectangleBorder(
                        cornerRadius: 28,
                        exponent: 4,
                        side: const BorderSide(color: Color(0xcb3c3c3c), width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                            padding: const EdgeInsets.all(9),
                            decoration: ShapeDecoration(
                              color: Color(0xFF161616),
                              shape: SuperellipseRectangleBorder(
                                cornerRadius: 28,
                                exponent: 4
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.play_arrow_outlined, color: Color(0xFFA6A6A6), size: 20),
                                Gap(9),
                                Text('Queue', style: TextStyle(fontFamily: 'Open Sans', color: Colors.white, fontSize: 13)),
                                Gap(9),
                                Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFFA6A6A6), size: 20),
                              ],
                            )
                        ),
                        Gap(14),
                        Column(
                          children: [
                            Icon(Icons.keyboard_arrow_up_rounded, color: Color(0xFFA6A6A6), size: 20),
                            Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFFA6A6A6), size: 20),
                          ],
                        ),
                        Gap(7),
                      ],
                    )
                ),
                GestureDetector(
                  child: Container(
                      padding: const EdgeInsets.all(11),
                      decoration: ShapeDecoration(
                        color: Color(0xFF252525),
                        shape: SuperellipseRectangleBorder(
                          cornerRadius: 28,
                          exponent: 4,
                          side: const BorderSide(color: Color(0xcb3c3c3c), width: 1),
                        ),
                      ),
                      child: Icon(Icons.close, color: Color(0xFFA6A6A6), size: 20)
                  ),
                ),
                GestureDetector(
                  child: Container(
                      padding: const EdgeInsets.all(11),
                      decoration: ShapeDecoration(
                        color: Color(0xFF252525),
                        shape: SuperellipseRectangleBorder(
                          cornerRadius: 28,
                          exponent: 4,
                          side: const BorderSide(color: Color(0xcb3c3c3c), width: 1),
                        ),
                      ),
                      child: Icon(Icons.find_in_page_outlined, color: Color(0xFFA6A6A6), size: 20)
                  ),
                ),
                GestureDetector(
                  child: Container(
                      padding: const EdgeInsets.all(11),
                      decoration: ShapeDecoration(
                        color: Color(0xFF252525),
                        shape: SuperellipseRectangleBorder(
                          cornerRadius: 28,
                          exponent: 4,
                          side: const BorderSide(color: Color(0xcb3c3c3c), width: 1),
                        ),
                      ),
                      child: Icon(Icons.menu, color: Color(0xFFA6A6A6), size: 20)
                  ),
                ),
              ].expand((x) => [const Gap(7), x]).skip(1).toList(),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(right: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: ShapeDecoration(
                      color: Color(0xFF252525),
                      shape: SuperellipseRectangleBorder(
                        cornerRadius: 28,
                        exponent: 4,
                        side: const BorderSide(color: Color(0xcb3c3c3c), width: 1),
                      ),
                    ),
                    child: Icon(Icons.add, color: Color(0xFFA6A6A6))
                  ),
                  Container(
                      padding: const EdgeInsets.all(11),
                      decoration: ShapeDecoration(
                        color: Color(0xFF252525),
                        shape: SuperellipseRectangleBorder(
                          cornerRadius: 28,
                          exponent: 4,
                          side: const BorderSide(color: Color(0xcb3c3c3c), width: 1),
                        ),
                      ),
                      child: Icon(Icons.remove, color: Color(0xFFA6A6A6))
                  ),
                  Container(
                      padding: const EdgeInsets.all(11),
                      decoration: ShapeDecoration(
                        color: Color(0xFF252525),
                        shape: SuperellipseRectangleBorder(
                          cornerRadius: 28,
                          exponent: 4,
                          side: const BorderSide(color: Color(0xcb3c3c3c), width: 1),
                        ),
                      ),
                      child: Icon(Icons.fullscreen, color: Color(0xFFA6A6A6))
                  ),
                  Container(
                      padding: const EdgeInsets.all(11),
                      decoration: ShapeDecoration(
                        color: Color(0xFF252525),
                        shape: SuperellipseRectangleBorder(
                          cornerRadius: 28,
                          exponent: 4,
                          side: const BorderSide(color: Color(0xcb3c3c3c), width: 1),
                        ),
                      ),
                      child: Icon(Icons.remove_red_eye_outlined, color: Color(0xFFA6A6A6))
                  ),
                  Container(
                      padding: const EdgeInsets.all(11),
                      decoration: ShapeDecoration(
                        color: Color(0xFF252525),
                        shape: SuperellipseRectangleBorder(
                          cornerRadius: 28,
                          exponent: 4,
                          side: const BorderSide(color: Color(0xcb3c3c3c), width: 1),
                        ),
                      ),
                      child: Icon(Icons.explore_outlined, color: Color(0xFFA6A6A6))
                  )
                ].expand((x) => [const Gap(7), x]).skip(1).toList()
              )
            )
          ),
        ],
      ),
    );
  }

  Widget _buildNode(NodeModel node) {
    final accents = (["SaveImage", 'PreviewImage'].contains(node.title.replaceAll(' ', '')) && paletteGenerator != null) ? [
      (paletteGenerator!.vibrantColor ?? paletteGenerator!.dominantColor)!.color,
      (paletteGenerator!.lightVibrantColor ?? paletteGenerator!.lightMutedColor)!.color,
    ] : _getNodeAccentColors(node.title);
    final shift = (node.title.hashCode % 40).toDouble();

    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          node.position += details.delta;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => measureAllPorts());
      },
      child: Stack(
        children: [
          Container(
            width: node.width,
            constraints: BoxConstraints(
              minHeight: node.height,
            ),
            clipBehavior: Clip.antiAlias,
            decoration: ShapeDecoration(
              //color: Colors.red,
              shape: SuperellipseRectangleBorder(
                cornerRadius: 28,
                exponent: 4,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 7 + shift,
                  right: 50,
                  child: Container(width: 120, height: 100, color: accents[0]),
                ),
                Positioned(
                  top: 5,
                  right: 5 + shift,
                  child: Container(width: 80, height: 80, color: accents[1]),
                ),

                ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      width: node.width,
                      constraints: BoxConstraints(
                        minHeight: node.height,
                      ),
                      padding: const EdgeInsets.all(7),
                      decoration: ShapeDecoration(
                        shape: SuperellipseRectangleBorder(
                          cornerRadius: 28,
                          exponent: 4,
                          side: const BorderSide(color: Color(0xcb3c3c3c), width: 1),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.4),
                                        spreadRadius: 3,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(node.title,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      )),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),
                          (["SaveImage", 'PreviewImage'].contains(node.title.replaceAll(' ', '')) && (widget.imageMeta.fullPath ?? widget.imageMeta.tempFilePath) != null) ?
                          Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildInputPorts(node),
                                        _buildOutputPorts(node),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Padding(padding: EdgeInsetsGeometry.symmetric(horizontal: 14), child: _buildDynamicInputsTable(node)),
                              Gap(14),
                              Container(
                                clipBehavior: Clip.antiAlias,
                                decoration: ShapeDecoration(
                                  shape: SuperellipseRectangleBorder(
                                      cornerRadius: 24,
                                      exponent: 4
                                  ),
                                ),
                                child: Image.file(
                                  File(widget.imageMeta.fullPath ?? widget.imageMeta.tempFilePath!),
                                  fit: BoxFit.contain,
                                ),
                              )
                            ],
                          )
                              :
                          Container(
                            decoration: ShapeDecoration(
                              color: const Color(0xFF2d2d2d),
                              shape: SuperellipseRectangleBorder(
                                cornerRadius: 24,
                                exponent: 4,
                                side: const BorderSide(color: Color(0xcb3c3c3c), width: 1),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildInputPorts(node),
                                      _buildOutputPorts(node),
                                    ],
                                  ),

                                  if(node.inputs.where((p) => p.value != null && p.value is! List).isNotEmpty) const Gap(16),

                                  _buildDynamicInputsTable(node),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  node.width = (node.width + details.delta.dx).clamp(250, 1400);
                  node.height = (node.height + details.delta.dy).clamp(150, 2000);
                });

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  measureAllPorts();
                });
              },
              child: Container(
                color: Colors.transparent,
                width: 20,
                height: 20,
                alignment: Alignment.center,
              ),
            ),
          ),
        ]
      )
    );
  }

  Widget _buildInputPorts(NodeModel node) {
    final linkedInputs = node.inputs.where((p) => p.value == null).toList();
    if (linkedInputs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: linkedInputs.map((port) {
        final name = port.id.split('_in_')[1];
        final color = _getPortColor(name);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              _buildPortDot(port, color),
              const SizedBox(width: 10),
              Text(
                humanizeKey(name),
                style: const TextStyle(
                  color: Color(0xFFA6A6A6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOutputPorts(NodeModel node) {
    final linkedOutputs = node.outputs.where((p) => p.value == null).toList();
    if (linkedOutputs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: linkedOutputs.map((port) {
        final name = port.id.split('_out_')[1];
        final color = _getPortColor(name);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                humanizeKey(name),
                style: const TextStyle(
                  color: Color(0xFFA6A6A6),
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 10),
              _buildPortDot(port, color),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDynamicInputsTable(NodeModel node) {
    final dataInputs = node.inputs.where((p) => p.value != null && p.value is! List).toList();

    if (dataInputs.isEmpty) return const SizedBox.shrink();

    return Column(
      children: dataInputs.map((port) {
        final name = port.id.split('_in_')[1];
        final value = port.value ?? '';

        final isLargeText = value is String && value.length > 42;

        if (isLargeText) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                humanizeKey(name),
                style: const TextStyle(color: Color(0xFFA6A6A6), fontSize: 14),
              ),
              const SizedBox(height: 6),
              _buildTextField(
                value.toString(),
                multiline: true,
                hint: humanizeKey(name),
              ),
            ],
          );
        } else {
          return Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  humanizeKey(name),
                  style: const TextStyle(color: Color(0xFFA6A6A6), fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: _buildTextField(
                  value.toString(),
                  multiline: false,
                  hint: humanizeKey(name),
                ),
              ),
            ],
          );
        }
      }).expand((x) => [const Gap(7), x]).skip(1).toList(),
    );
  }

  Widget _buildTextField(String value, {bool multiline = false, String? hint}) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: const Color(0xFF171717),
        shape: SuperellipseRectangleBorder(
          cornerRadius: 28,
          exponent: 4,
          side: const BorderSide(
            color: Color(0xcb3c3c3c),
            width: 1,
          ),
        ),
      ),
      child: TextField(
        controller: TextEditingController(text: value),
        maxLines: multiline ? null : 1,
        minLines: multiline ? 3 : 1,
        keyboardType: multiline ? TextInputType.multiline : TextInputType.text,
        style: const TextStyle(color: Color(0xFFA6A6A6), fontSize: 14),
        decoration: InputDecoration(
          contentPadding: multiline ? EdgeInsets.symmetric(horizontal: 7, vertical: 14) : EdgeInsets.all(14),
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF787878), fontSize: 14),
          border: InputBorder.none,
          filled: true,
          fillColor: Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildPortDot(PortModel port, Color color) {
    return Container(
      key: port.key,
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.6),
            spreadRadius: 3,
            blurRadius: 0,
          ),
        ],
      ),
    );
  }
}

Color _getPortColor(String name) {
  final hash = name.toLowerCase().hashCode;

  const goldenRatioConjugate = 0.61803398875;
  double hueFraction = ((hash * goldenRatioConjugate) % 1.0);
  double hue = hueFraction * 360.0; // convert to degrees

  const saturation = 0.65;
  const value = 0.85;

  return HSVColor.fromAHSV(1.0, hue, saturation, value).toColor();
}

List<Color> _getNodeAccentColors(String title) {
  final hash = title.hashCode;

  final color1 = Color((hash & 0x00FFFFFF) | 0xFF000000);
  final color2 = Color(((hash * 31) & 0x00FFFFFF) | 0xFF000000);

  return [
    color1.withOpacity(0.4),
    color2.withOpacity(0.4),
  ];
}

class NodeLayerPainter extends CustomPainter {
  final List<NodeModel> nodes;

  NodeLayerPainter(this.nodes);

  @override
  void paint(Canvas canvas, Size size) {
    for (var node in nodes) {
      final rect = Rect.fromLTWH(node.position.dx, node.position.dy, 220, 120);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
      final paint = Paint()..color = const Color(0xFF2A2A2A);
      canvas.drawRRect(rrect, paint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: 'Node ${node.id}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(maxWidth: 220);
      textPainter.paint(canvas, node.position + const Offset(12, 12));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ConnectionPainter extends CustomPainter {
  final List<NodeModel> nodes;
  final List<ConnectionModel> connections;
  final Offset canvasOffset;
  final GlobalKey viewerKey;

  ConnectionPainter({
    required this.nodes,
    required this.connections,
    required this.canvasOffset,
    required this.viewerKey,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    for (var connection in connections) {
      final from = _getPortPosition(connection.fromPortId);
      final to = _getPortPosition(connection.toPortId);

      if (from == null || to == null) continue;

      final fromPort = _getPort(connection.fromPortId);
      final portColor = fromPort != null
          ? _getPortColor(fromPort.id.split('_out_')[1])
          : Colors.white;

      final color = Color.lerp(Colors.white, portColor, 0.5)!.withOpacity(0.8);

      final paint = Paint()
        ..color = color.withOpacity(0.7)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(from.dx+30, from.dy);

      const double curveStrength = 120;
      final controlPoint1 = Offset(from.dx+30 + curveStrength, from.dy);
      final controlPoint2 = Offset(to.dx-30 - curveStrength, to.dy);

      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        to.dx-30,
        to.dy,
      );

      canvas.drawPath(path, paint);
    }
  }

  PortModel? _getPort(String portId) {
    for (var node in nodes) {
      for (var p in [...node.inputs, ...node.outputs]) {
        if (p.id == portId) return p;
      }
    }
    return null;
  }

  Offset? _getPortPosition(String portId) {
    final port = _getPort(portId);
    return port?.position;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class FixedDotGrid extends StatelessWidget {
  final TransformationController controller;
  final double spacing;
  final double dotRadius;
  final double canvasSize;

  const FixedDotGrid({
    required this.controller,
    required this.canvasSize,
    this.spacing = 30,
    this.dotRadius = 2,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(canvasSize, canvasSize),
      painter: _FixedDotGridPainter(
        controller: controller,
        spacing: spacing,
        dotRadius: dotRadius,
        canvasOffset: Offset(canvasSize / 2, canvasSize / 2),
      ),
    );
  }
}

class _FixedDotGridPainter extends CustomPainter {
  final TransformationController controller;
  final double spacing;
  final double dotRadius;
  final double minVisibleSpacing;
  final Offset canvasOffset;

  _FixedDotGridPainter({
    required this.controller,
    required this.spacing,
    required this.dotRadius,
    required this.canvasOffset,
    this.minVisibleSpacing = 6,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF272727);

    final matrix = controller.value;
    final scale = matrix.getMaxScaleOnAxis();
    final offset = matrix.getTranslation();

    final scaledRadius = dotRadius * scale;
    final scaledSpacing = spacing * scale;

    if (scaledSpacing < minVisibleSpacing) return;

    final startX = -offset.x / scale - canvasOffset.dx;
    final startY = -offset.y / scale - canvasOffset.dy;

    for (double x = startX - (startX % spacing);
    x < startX + size.width / scale;
    x += spacing) {
      for (double y = startY - (startY % spacing);
      y < startY + size.height / scale;
      y += spacing) {
        final screenX = (x + canvasOffset.dx) * scale + offset.x;
        final screenY = (y + canvasOffset.dy) * scale + offset.y;
        canvas.drawCircle(Offset(screenX, screenY), scaledRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class NodeModel {
  String id;
  Offset position;

  double width;
  double height;

  List<PortModel> inputs;
  List<PortModel> outputs;

  String title;

  NodeModel({
    required this.id,
    required this.position,
    required this.inputs,
    required this.outputs,
    required this.title,
    this.width = 350,
    this.height = 10,
  });
}

class PortModel {
  final String id;
  final String nodeId;
  final bool isInput;
  Offset? position;
  final GlobalKey key = GlobalKey();
  dynamic value;

  PortModel({
    required this.id,
    required this.nodeId,
    required this.isInput,
    this.value,
  });
}

class ConnectionModel {
  final String fromPortId;
  final String toPortId;

  ConnectionModel(this.fromPortId, this.toPortId);
}

class SuperellipseRectangleBorder extends OutlinedBorder {
  final double cornerRadius;
  final double exponent;

  const SuperellipseRectangleBorder({
    required this.cornerRadius,
    this.exponent = 4,
    super.side = BorderSide.none,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  SuperellipseRectangleBorder copyWith({
    BorderSide? side,
  }) {
    return SuperellipseRectangleBorder(
      cornerRadius: cornerRadius,
      exponent: exponent,
      side: side ?? this.side,
    );
  }


  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return _buildPath(rect);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return _buildPath(rect.deflate(side.width));
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side == BorderSide.none) return;

    final path = getOuterPath(rect);

    final paint = side.toPaint();
    canvas.drawPath(path, paint);
  }

  Path _buildPath(Rect rect) {
    final r = cornerRadius.clamp(
      0.0,
      math.min(rect.width, rect.height) / 2,
    );

    final n = exponent;

    final left = rect.left;
    final right = rect.right;
    final top = rect.top;
    final bottom = rect.bottom;

    final path = Path();

    path.moveTo(left + r, top);
    path.lineTo(right - r, top);

    _addCorner(path, Offset(right - r, top + r), r, n, -math.pi / 2);

    path.lineTo(right, bottom - r);

    _addCorner(path, Offset(right - r, bottom - r), r, n, 0);

    path.lineTo(left + r, bottom);

    _addCorner(path, Offset(left + r, bottom - r), r, n, math.pi / 2);

    path.lineTo(left, top + r);

    _addCorner(path, Offset(left + r, top + r), r, n, math.pi);

    path.close();

    return path;
  }

  void _addCorner(
      Path path,
      Offset center,
      double radius,
      double exponent,
      double startAngle,
      ) {
    const steps = 24;

    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final angle = startAngle + t * (math.pi / 2);

      final cosT = math.cos(angle);
      final sinT = math.sin(angle);

      final x = radius *
          math.pow(cosT.abs(), 2 / exponent) *
          (cosT >= 0 ? 1 : -1);

      final y = radius *
          math.pow(sinT.abs(), 2 / exponent) *
          (sinT >= 0 ? 1 : -1);

      path.lineTo(center.dx + x, center.dy + y);
    }
  }

  @override
  ShapeBorder scale(double t) {
    return SuperellipseRectangleBorder(
      cornerRadius: cornerRadius * t,
      exponent: exponent,
      side: side.scale(t),
    );
  }
}