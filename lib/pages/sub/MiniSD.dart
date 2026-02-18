import 'dart:convert';
import 'dart:io';

import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/material.dart';


class MiniSD extends StatefulWidget{
  final ImageMeta? imageMeta;
  const MiniSD({ super.key, this.imageMeta});

  @override
  State<MiniSD> createState() => _MiniSDState();
}

class _MiniSDState extends State<MiniSD> {
  bool loaded = false;

  late String sessionHash;
  late Uri networkAccess;

  Map<String, dynamic> config = {};
  late Map<int, Map<String, dynamic>> componentMap;

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    final source = await File('W:/gradio.json').readAsString();

    setState(() {
      config = jsonDecode(source);
      buildComponentIndex();
      loaded = true;
    });
  }

  void buildComponentIndex() {
    componentMap = {};
    for (var comp in config['components']) {
      componentMap[comp['id']] = Map<String, dynamic>.from(comp);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gradio → Flutter")),
      body: SafeArea(
        child: loaded
            ? SingleChildScrollView(child: buildFromRoot())
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget buildFromRoot() {
    final root = config['layout'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildNode(root['children'][0]),
        buildNode(root['children'][1])
      ]
        //root['children'] as List<dynamic>).map((child) => buildNode(child)).toList(),
    );
  }

  Widget buildNode(
      Map<String, dynamic> layoutNode, {
        bool insideRow = false,
      }) {
    final int id = layoutNode['id'];
    final component = componentMap[id];
    if (component == null) return const SizedBox();

    final type = component['type'];
    final props = Map<String, dynamic>.from(component['props'] ?? {});
    final visible = props['visible'] ?? true;
    if (!visible) return const SizedBox();

    final children = (layoutNode['children'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    Widget widget;

    if (isContainer(type)) {
      widget = buildContainer(
        type,
        props,
        children,
        insideRow: insideRow,
      );
    } else {
      widget = buildLeaf(type, props);
    }

    final int? scale = props['scale'];
    final int? minWidth = props['min_width'];

    if (minWidth != null && minWidth > 0) {
      widget = ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth.toDouble()),
        child: widget,
      );
    }

    if (insideRow && type != 'button') {
      if (scale != null && scale > 0) {
        widget = Expanded(flex: scale, child: widget);
      } else {
        widget = Flexible(
          fit: FlexFit.loose,
          child: IntrinsicWidth(child: widget),
        );
      }
    }

    return widget;
  }

  Widget buildContainer(
      String type,
      Map<String, dynamic> props,
      List<Map<String, dynamic>> childrenLayout, {
        bool insideRow = false,
      }) {
    final bool isRowContainer = type == 'row' || type == 'group';
    final childrenWidgets = childrenLayout.map((child) => buildNode(child, insideRow: isRowContainer)).toList();

    switch (type) {
      case 'row':
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: childrenWidgets,
        );

      case 'column':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: childrenWidgets,
        );

      case 'group':
        return Card(
          margin: const EdgeInsets.all(8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: childrenWidgets),
          ),
        );

      case 'box':
        return Text('hi');
        return Card(
          margin: const EdgeInsets.all(8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(children: childrenWidgets),
          ),
        );
      case 'form':
        return Wrap(
          children: childrenWidgets,
        );

      case 'accordion':
        return ExpansionTile(
          title: Text(props['label'] ?? ''),
          initiallyExpanded: props['open'] ?? false,
          children: childrenWidgets,
        );

      case 'tabs':
        return DefaultTabController(
          length: childrenLayout.length,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TabBar(
                isScrollable: true,
                tabs: childrenLayout.map((child) {
                  final comp = componentMap[child['id']];
                  final label =
                      comp?['props']?['label'] ?? 'Tab';
                  return Tab(text: label);
                }).toList(),
              ),
              SizedBox(
                height: 700,
                child: TabBarView(
                  children: childrenWidgets,
                ),
              ),
            ],
          ),
        );

      case 'tabitem':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: childrenWidgets,
        );

      default:
        return Text('unknown $type');//Column(children: childrenWidgets);
    }
  }

  Widget buildLeaf(String type, Map<String, dynamic> props) {
    final visible = props['visible'] ?? true;
    if (!visible) return const SizedBox();

    switch (type) {
      case 'textbox':
        return Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller:
            TextEditingController(text: props['value']?.toString() ?? ''),
            maxLines: props['lines'] ?? 1,
            decoration: InputDecoration(
              labelText:
              props['show_label'] == true ? props['label'] : null,
              hintText: props['placeholder'],
              border: const OutlineInputBorder(),
            ),
          ),
        );

      case 'dropdown':
        final choices = (props['choices'] ?? []) as List<dynamic>;
        final value = props['value'];

        // return Container(
        //   height: 32,
        //   color: Colors.red,
        // );

        return DropdownButtonFormField<dynamic>(
          value: choices.contains(value) ? value : null,
          items: choices.map((c) => DropdownMenuItem(value: c, child: Text(c.toString()))).toList(),
          onChanged: (_) {},
          isExpanded: true,
          decoration: InputDecoration(
            // isDense: true,
            labelText: props['show_label'] == true ? props['label'] : null,
            border: const OutlineInputBorder(),
          ),
        );

      case 'slider':
        // return Container(
        //   height: 32,
        //   color: Colors.green,
        // );
        return StatefulBuilder(
          builder: (context, setState) {
            double val = (props['value'] as num?)?.toDouble() ?? (props['minimum'] as num).toDouble();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (props['show_label'] == true) Padding(padding: const EdgeInsets.only(left: 8.0), child: Text("${props['label']} (${val.toStringAsFixed(2)})")),
                Slider(
                  min: (props['minimum'] as num).toDouble(),
                  max: (props['maximum'] as num).toDouble(),
                  divisions: null,
                  value: val,
                  onChanged: (v) {
                    setState(() => val = v);
                  },
                ),
              ],
            );
          },
        );

      case 'button':
        final variant = props['variant'];

        return Padding(
          padding: const EdgeInsets.all(6),
          child: variant == 'primary'
              ? ElevatedButton(
            onPressed: () {},
            child: Text(props['value'] ?? 'Button'),
          )
              : OutlinedButton(
            onPressed: () {},
            child: Text(props['value'] ?? 'Button'),
          ),
        );

      case 'checkbox':
        return StatefulBuilder(builder: (context, setState) {
          bool value = props['value'] ?? false;

          return CheckboxListTile(
            value: value,
            onChanged: (v) => setState(() => value = v ?? false),
            title: Text(props['label'] ?? ''),
          );
        });

      case 'html':
        return Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            props['value'] ?? '',
            style: const TextStyle(color: Colors.grey),
          ),
        );

      case 'label':
        return Padding(
          padding: const EdgeInsets.all(8),
          child: Text(props['value']?.toString() ?? ''),
        );

      default:
        return const SizedBox();
    }
  }
}

bool isContainer(String type) {
  return [
    'row',
    'column',
    'group',
    'box',
    'tabs',
    'tabitem',
    'accordion',
    'form',
  ].contains(type);
}