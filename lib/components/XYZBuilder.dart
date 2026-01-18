import 'dart:io';

import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/material.dart';

import '../pages/sub/ImageView.dart';

class XYZBuilder extends StatefulWidget {
  final List<ImageMeta> images;

  const XYZBuilder({super.key, required this.images});

  @override
  State<XYZBuilder> createState() => _XYZBuilderState();
}

class _XYZBuilderState extends State<XYZBuilder> {
  String xKey = 'seed';
  String yKey = 'sampler';

  late XYZGrid grid;

  @override
  void initState() {
    super.initState();
    _rebuild();
  }

  void _rebuild() {
    grid = buildXYZGrid(
      images: widget.images,
      xKey: xKey,
      yKey: yKey,
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('XYZ plot ($xKey × $yKey)'),
      ),
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(child: _buildGrid()),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    const keys = [
      'seed',
      'sampler',
      'steps',
      'cfgScale',
      'checkpoint',
    ];

    return SizedBox(
      width: 220,
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          const Text('X axis', style: TextStyle(fontWeight: FontWeight.bold)),
          ...keys.map((k) => RadioListTile(
            value: k,
            groupValue: xKey,
            onChanged: (v) {
              xKey = v!;
              _rebuild();
            },
            title: Text(k),
          )),
          const Divider(),
          const Text('Y axis', style: TextStyle(fontWeight: FontWeight.bold)),
          ...keys.map((k) => RadioListTile(
            value: k,
            groupValue: yKey,
            onChanged: (v) {
              yKey = v!;
              _rebuild();
            },
            title: Text(k),
          )),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    if (grid.xValues.isEmpty || grid.yValues.isEmpty) {
      return const Center(child: Text('Not enough data'));
    }

    return InteractiveViewer(
      minScale: 0.2,
      maxScale: 5,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(color: Colors.grey),
        children: [
          _buildHeaderRow(),
          ...grid.yValues.map(_buildRow),
        ],
      ),
    );
  }

  TableRow _buildHeaderRow() {
    return TableRow(
      children: [
        const SizedBox(),
        ...grid.xValues.map(
              (x) => Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              '$xKey = $x',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  TableRow _buildRow(String yValue) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            '$yKey = $yValue',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        ...grid.xValues.map((xValue) {
          final im = grid.cells[(xValue, yValue)];
          if (im == null) {
            return const SizedBox(width: 128, height: 128);
          }

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ImageView(imageMeta: im),
                ),
              );
            },
            child: AspectRatio(
              aspectRatio: im.size?.aspectRatio() ?? 1.0,
              child: Image.file(
                File(im.fullPath!),
                fit: BoxFit.contain,
              ),
            ),
          );

        }),
      ],
    );
  }

}

XYZGrid buildXYZGrid({
  required List<ImageMeta> images,
  required String xKey,
  required String yKey,
}) {
  final xSet = <String>{};
  final ySet = <String>{};
  final cells = <(String, String), ImageMeta>{};

  for (final im in images) {
    final gp = im.generationParams;
    if (gp == null) continue;

    final map = gp.toMap();
    final xVal = map[xKey]?.toString();
    final yVal = map[yKey]?.toString();

    if (xVal == null || yVal == null) continue;

    xSet.add(xVal);
    ySet.add(yVal);
    cells[(xVal, yVal)] = im;
  }

  final xValues = xSet.toList()..sort();
  final yValues = ySet.toList()..sort();

  return XYZGrid(
    xKey: xKey,
    yKey: yKey,
    xValues: xValues,
    yValues: yValues,
    cells: cells,
  );
}

class XYZGrid {
  final String xKey;
  final String yKey;
  final List<String> xValues;
  final List<String> yValues;
  final Map<(String, String), ImageMeta> cells;

  XYZGrid({
    required this.xKey,
    required this.yKey,
    required this.xValues,
    required this.yValues,
    required this.cells,
  });
}
