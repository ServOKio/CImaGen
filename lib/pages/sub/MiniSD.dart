import 'dart:convert';
import 'dart:io';

import 'package:cimagen/Utils.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../main.dart';

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
  
  @override
  void initState(){
    sessionHash = getRandomString(11);
    networkAccess = Uri.parse(prefs.getString('sd_remote_webui_address') ?? '');
    init();
  }

  Future<void> init() async {
    File('D:\\PC\\Downloads\\gradio.json').readAsString().then((source){
      setState(() {
        config = jsonDecode(source);
        loaded = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
            title: const Text('SD'),
            backgroundColor: const Color(0xaa000000),
            elevation: 0,
            actions: []
        ),
        // floatingActionButton: FloatingActionButton(
        //   onPressed: () {
        //     debugDumpSemanticsTree();
        //   },
        //   child: const Icon(Icons.account_tree_rounded),
        // ),
        body: SafeArea(
          child: loaded ? buildAll() : CircularProgressIndicator()
        )
    );
  }

  Widget buildAll(){
    List<dynamic> compJson = config['components'] as List<dynamic>;
    var treeResult = buildTree(compJson, 0);
    List<Component> tree = treeResult.item1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildWidget(tree[0]),
        //buildWidget(tree[1]),
        Expanded(
          child: buildWidget(tree[1]),
        ),
      ],
    );
  }
}

class Component {
  int id;
  String type;
  Map<String, dynamic> props;
  List<Component> children;

  Component({
    required this.id,
    required this.type,
    required this.props,
    required this.children,
  });

  factory Component.fromJson(Map<String, dynamic> json) {
    return Component(
      id: json['id'] as int,
      type: json['type'] as String,
      props: json['props'] as Map<String, dynamic>? ?? {},
      children: [],
    );
  }
}

class Tuple<T1, T2> {
  T1 item1;
  T2 item2;

  Tuple(this.item1, this.item2);
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
  ].contains(type);
}

Tuple<List<Component>, int> buildTree(
    List<dynamic> compJson, int start) {
  List<Component> tree = [];
  int index = start;
  while (index < compJson.length) {
    Map<String, dynamic> json = compJson[index];
    if (json['props']?['elem_id'] == 'tabs' && start > 0) {
      return Tuple(tree, index);
    }
    Component comp = Component.fromJson(json);
    tree.add(comp);
    index += 1;
    if (isContainer(comp.type)) {
      var result = buildTree(compJson, index);
      comp.children = result.item1;
      index = result.item2;
    }
  }
  return Tuple(tree, index);
}

Widget buildWidget(Component comp, {int level = 0}) {
  if (comp.props['visible'] == false) {
    return const SizedBox.shrink();
  }

  Widget widget;

  switch (comp.type) {
    case 'row':
      // widget = Row(
      //   mainAxisAlignment: MainAxisAlignment.start,
      //   crossAxisAlignment: CrossAxisAlignment.stretch,
      //   children: comp.children.map((c) => buildWidget(c, level: level + 1)).toList(),
      // );
      // if (comp.props['elem_id'] == 'quicksettings') {
      //   widget = SingleChildScrollView(
      //     scrollDirection: Axis.horizontal,
      //     child: row,
      //   );
      // } else {
      //   widget = row;
      // }
      widget = Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: comp.children.map((c) => buildWidget(c, level: level + 1)).toList(),
      );
      // widget = SelectableText('row ${comp.id}');
      break;
    // case 'column':
    //   widget = Column(
    //     mainAxisAlignment: MainAxisAlignment.start,
    //     crossAxisAlignment: CrossAxisAlignment.stretch,
    //     children: comp.children.map((c) => buildWidget(c, level: level + 1)).toList(),
    //   );
    //   break;
    case 'tabs':
      // widget = DefaultTabController(
      //   length: comp.children.length,
      //   child: Column(
      //     children: [
      //       TabBar(
      //         tabs: comp.children.map((c) => Tab(
      //           text: c.props['label']?.toString() ?? 'Tab',
      //         )).toList(),
      //       ),
      //       Expanded(
      //         child: TabBarView(
      //           children: comp.children.map((c) => buildWidget(c, level: level + 1)).toList(),
      //         ),
      //       ),
      //     ],
      //   ),
      // );
      // break;
    // case 'tabitem':
    //   widget = SingleChildScrollView(
    //     child: Column(
    //       crossAxisAlignment: CrossAxisAlignment.stretch,
    //       children: comp.children.map((c) => buildWidget(c, level: level + 1)).toList(),
    //     ),
    //   );
    //   break;
    // case 'accordion':
    //   widget = ExpansionTile(
    //     title: Text(comp.props['label']?.toString() ?? 'Accordion'),
    //     initiallyExpanded: comp.props['open'] ?? false,
    //     children: comp.children.map((c) => buildWidget(c, level: level + 1)).toList(),
    //   );
    //   break;
    // case 'group':
    //   widget = Container(
    //     padding: const EdgeInsets.all(8.0),
    //     child: Column(
    //       crossAxisAlignment: CrossAxisAlignment.stretch,
    //       children: comp.children.map((c) => buildWidget(c, level: level + 1)).toList(),
    //     ),
    //   );
    //   break;
    // case 'form':
    //   widget = Form(
    //     child: Column(
    //       crossAxisAlignment: CrossAxisAlignment.stretch,
    //       children: comp.children.map((c) => buildWidget(c, level: level + 1)).toList(),
    //     ),
    //   );
    //   break;
    // case 'box':
    //   widget = Container(
    //     decoration: BoxDecoration(
    //       border: Border.all(color: Colors.grey),
    //       borderRadius: BorderRadius.circular(4),
    //     ),
    //     padding: const EdgeInsets.all(8.0),
    //     child: Column(
    //       crossAxisAlignment: CrossAxisAlignment.stretch,
    //       children: comp.children.map((c) => buildWidget(c, level: level + 1)).toList(),
    //     ),
    //   );
    //   break;
    // case 'textbox':
    //   widget = TextField(
    //     controller: TextEditingController(text: comp.props['value']?.toString() ?? ''),
    //     maxLines: comp.props['max_lines'] ?? comp.props['lines'] ?? 1,
    //     minLines: comp.props['lines'] ?? 1,
    //     decoration: InputDecoration(
    //       labelText: comp.props['show_label'] == true ? comp.props['label']?.toString() : null,
    //       hintText: comp.props['placeholder']?.toString(),
    //     ),
    //   );
    //   break;
    // case 'dropdown':
    //   var choices = comp.props['choices'] as List<dynamic>? ?? [];
    //   var value = comp.props['value'];
    //   widget = DropdownButton<dynamic>(
    //     value: value,
    //     items: choices.map((e) => DropdownMenuItem<dynamic>(
    //       value: e,
    //       child: Text(e.toString()),
    //     )).toList(),
    //     onChanged: (v) {},
    //     hint: Text(comp.props['label']?.toString() ?? 'Select'),
    //     isExpanded: true,
    //   );
    //   break;
    // case 'button':
    //   widget = ElevatedButton(
    //     onPressed: () {}, // Add functionality later
    //     child: Text(comp.props['value']?.toString() ?? 'Button'),
    //   );
    //   break;
    // case 'slider':
    //   double value = (comp.props['value'] as num?)?.toDouble() ?? 0.0;
    //   double min = (comp.props['minimum'] as num?)?.toDouble() ?? 0.0;
    //   double max = (comp.props['maximum'] as num?)?.toDouble() ?? 100.0;
    //   widget = Slider(
    //     value: value,
    //     min: min,
    //     max: max,
    //     onChanged: (v) {},
    //     label: comp.props['label']?.toString(),
    //   );
    //   break;
    // case 'checkbox':
    //   widget = CheckboxListTile(
    //     title: Text(comp.props['label']?.toString() ?? ''),
    //     value: comp.props['value'] as bool? ?? false,
    //     onChanged: (v) {},
    //   );
    //   break;
    // case 'html':
    //   widget = Text(comp.props['value']?.toString() ?? ''); // Simplified, use flutter_html for real HTML
    //   break;
    // case 'image':
    //   var src = comp.props['value'] as String? ?? '';
    //   widget = src.isNotEmpty ? Image.network(src) : const Placeholder(fallbackHeight: 200);
    //   break;
    // case 'gallery':
    //   widget = const Placeholder(fallbackHeight: 200); // Implement gallery later
    //   break;
    // case 'file':
    //   widget = ElevatedButton(
    //     onPressed: () {}, // Add file picker
    //     child: const Text('Upload File'),
    //   );
    //   break;
    // case 'label':
    //   widget = Text(comp.props['value']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold));
    //   break;
    default:
      widget = SelectableText('Unsupported: ${comp.type} ${comp.id}\n${comp.children.length}');
  }

  // Handle scale and min_width if present
  int scale = comp.props['scale'] ?? 1;
  double? minWidth = comp.props['min_width']?.toDouble();

  // if (scale > 0 || minWidth != null) {
  //   widget = Flexible(
  //     flex: scale,
  //     child: SizedBox(
  //       width: minWidth,
  //       child: widget,
  //     ),
  //   );
  // }

  return widget;
}