import 'dart:ui' as ui;

import 'package:cimagen/Utils.dart';
import 'package:cimagen/components/ArtistDefaultStypeFinder.dart';
import 'package:cimagen/components/TagSearcher.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_charts/flutter_charts.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import '../../components/Animations.dart';
import '../../modules/DataManager.dart';
import '../../utils/range.dart';

class PromptAnalyzer extends StatefulWidget{
  final GenerationParams generationParams;

  const PromptAnalyzer({ super.key, required this.generationParams});

  @override
  State<PromptAnalyzer> createState() => _PromptAnalyzerState();
}

RegExp reAttention = RegExp(r'\\\(|\\\)|\\\[|\\]|\\\\|\\|\(|\[|:\s*([+-]?[.\d]+)\s*\)|\)|]|[^\\()\[\]:]+|:');
RegExp reBreak = RegExp(r'\s*\bBREAK\b\s*');
RegExp reBracketTokens = RegExp(r'(?<!\\)\)\s*(,)\s*\S');
Map<String, TagInfo> _tags = {};
Map<int, List<String>> _hasDubl = {
  0: [],
  1: []
};
Map<int, Map<String, double>> _tagsAndWeights = {
  0: {},
  1: {}
};

class _PromptAnalyzerState extends State<PromptAnalyzer> {
  bool loaded = false;

  late TextEditingController positiveController;
  late FocusNode _posFocusNode;

  late TextEditingController negativeController;
  late FocusNode _negFocusNode;

  List<HMessage> posMessages = [];
  List<HMessage> negMessages = [];

  var posChart = [];

  List<String> specialTags = ['score:0', 'score:1', 'score:2', 'score:3', 'score:4', 'score:5', 'score:6', 'score:7', 'score:8', 'score:9', 'rating:s', 'rating:q', 'rating:e'];


  @override
  void initState(){
    super.initState();

    _tags = context.read<DataManager>().e621Tags;

    positiveController = TextEditingController();
    positiveController.text = widget.generationParams.positive ?? '';
    negativeController = TextEditingController();
    negativeController.text = widget.generationParams.negative ?? '';

    _posFocusNode = FocusNode();
    _negFocusNode = FocusNode();
    _posFocusNode.addListener(() {if(!_posFocusNode.hasFocus) analyzePrompt(0);});
    _negFocusNode.addListener(() {if(!_negFocusNode.hasFocus) analyzePrompt(1);});

    analyzePrompt(0);
    analyzePrompt(1);
  }

  @override
  void dispose() {
    _tags = {};
    super.dispose();
  }

  Future<void> analyzePrompt(int id) async {
    setState(() {
      loaded = false;
      if(id == 0){
        posMessages = [];
      } else {
        negMessages = [];
      }
    });

    String _text = (id == 0 ? positiveController.text : negativeController.text).replaceAll('\n', ' ');

    List<List<dynamic>> res = [];
    List<int> roundBrackets = [];
    List<int> squareBrackets = [];

    double roundBracketMultiplier = 1.1;
    double squareBracketMultiplier = 1 / 1.1;

    void multiplyRange(int startPosition, double multiplier){
      for(var p in range(startPosition, res.length)){
        res[p][1] *= multiplier;
      }
    }

    Iterable<RegExpMatch> f = reBracketTokens.allMatches(_text);
    if(f.isNotEmpty){
      (id == 0 ? posMessages : negMessages).add(HMessage(type: HMType.warn, text: '${f.length} extra commas after parentheses were found, which are unnecessary tokens and may affect the result'));
    }

    for(final m in reAttention.allMatches(_text)){
      String text = m.group(0) ?? '';
      double? weight = m.group(1) != null ? double.parse(m.group(1)!) : null;

      if(text.startsWith('\\')) {
        res.add([text.substring(1), 1.0]);
      } else if(text == '('){
        roundBrackets.add(res.length);
      } else if(text == '['){
        squareBrackets.add(res.length);
      } else if(weight != null && roundBrackets.isNotEmpty){
        multiplyRange(roundBrackets.removeLast(), weight);
      } else if(text == ')' && roundBrackets.isNotEmpty){
        multiplyRange(roundBrackets.removeLast(), roundBracketMultiplier);
      } else if(text == ']' && squareBrackets.isNotEmpty){
        multiplyRange(squareBrackets.removeLast(), squareBracketMultiplier);
      } else {
        var parts = text.split(reBreak);
        for (int i = 0; i < parts.length; i++){
          var part = parts[i];
          if(i > 0){
            res.add(['BREAK', -1]);
          }
          res.add([part.trim(), 1.0]);
        }
      }
    }

    for(var pos in roundBrackets){
      multiplyRange(pos, roundBracketMultiplier);
    }

    for(var pos in squareBrackets) {
      multiplyRange(pos, squareBracketMultiplier);
    }

    if(res.isEmpty){
      res = [['', 1.0]];
    }

    int i = 0;


    while(i + 1 < res.length) {
      if (res[i][1] == res[i + 1][1]) {
        res[i][0] += res[i + 1][0];
        res.removeAt(i + 1);
      } else {
        i += 1;
      }
    }

    // because fox ass
    List<String> dubl = [];
    _hasDubl[id]!.clear();
    _tagsAndWeights[id]!.clear();
    for (var element in res) {
      //print((element[0] as String).split(','));
      List<String> tags = (element[0] as String).split(',').map((e) => e.trim().toLowerCase().replaceAll(' ', '_'))
          .map((e) => e.replaceFirst('by_', '').replaceFirst('art_by_', ''))
          .where((e) => e != '')
          .where((e) => !specialTags.contains(e))
          .toList(growable: false);
      for(String tag in tags){
        if(!dubl.contains(tag)){
          dubl.add(tag);
        } else {
          _hasDubl[id]!.add(tag);
          (id == 0 ? posMessages : negMessages).add(HMessage(type: HMType.warn, text: 'Tag "$tag" has a duplicate'));
        }
        _tagsAndWeights[id]![tag] = element[1].toDouble();
        if(!(tag.startsWith('<') && tag.endsWith('>'))){
          if(!_tags.containsKey(tag)){
            (id == 0 ? posMessages : negMessages).add(HMessage(type: HMType.error, text: 'Tag "$tag" is invalid'));
          } else {
            int c = _tags[tag]!.count;
            if(_tags[tag]!.count < 50){
              (id == 0 ? posMessages : negMessages).add(c == 0 ? HMessage(type: HMType.dolbaeb, text: 'Tag "$tag" has no weight, remove this shit') : HMessage(type: HMType.warn, text: 'Tag "$tag" has too few assets ($c)'));
            }
          }
        }
      }
    }

    List<TagInfo> fi = _tagsAndWeights[0]!.keys.where((tag) => _tags.containsKey(tag) && _tags[tag]?.category == 1).map((e) => _tags[e]!).toList(growable: false);

    setState(() {
      loaded = true;
      if(id == 0) {
        posChart = [
          fi.map((e) => _tagsAndWeights[0]![e.name]!).toList(),
          fi.map((e) => e.name).toList(),
          fi.map((e) => e.count.toDouble()).toList(),
          fi.map((e) => e.count * _tagsAndWeights[0]![e.name]!).toList(),
        ];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget artistRawWeights;
    Widget artistCount;
    Widget artistWeights;

    if(posChart.isNotEmpty){
      artistRawWeights = posChart[0].isNotEmpty ? VerticalBarChart(
        painter: VerticalBarChartPainter(
          verticalBarChartContainer: VerticalBarChartTopContainer(
            chartData: ChartData(
              dataRowsColors: const [Colors.blue],
              dataRows: [posChart[0]],
              xUserLabels: posChart[1],
              dataRowsLegends: const ['User Weight',],
              chartOptions: const ChartOptions(
                  iterativeLayoutOptions: IterativeLayoutOptions(
                      multiplyLabelSkip: 1,
                      labelTiltRadians: -3.14 / 2
                  ),
                  dataContainerOptions: DataContainerOptions(startYAxisAtDataMinRequested: true)
              ),
            ),
          ),
        ),
      ) : Text('f');

      artistCount = posChart[2].isNotEmpty ? VerticalBarChart(
        painter: VerticalBarChartPainter(
          verticalBarChartContainer: VerticalBarChartTopContainer(
            chartData: ChartData(
              dataRowsColors: const [
                Colors.lightGreen
              ],
              dataRows: [
                posChart[2],
              ],
              xUserLabels: posChart[1],
              dataRowsLegends: const [
                'Number of artworks',
              ],
              chartOptions: const ChartOptions(
                  iterativeLayoutOptions: IterativeLayoutOptions(
                      multiplyLabelSkip: 1,
                      labelTiltRadians: -3.14 / 2
                  ),
                  dataContainerOptions: DataContainerOptions(
                    startYAxisAtDataMinRequested: true,
                  )
              ),
            ),
          ),
        ),
      ) : Text('f');

      artistWeights = posChart[3].isNotEmpty ? VerticalBarChart(
        painter: VerticalBarChartPainter(
          verticalBarChartContainer: VerticalBarChartTopContainer(
            chartData: ChartData(
              dataRows: [
                posChart[3],
              ],
              xUserLabels: posChart[1],
              dataRowsLegends: const [
                'Artists Token Weight',
              ],
              chartOptions: const ChartOptions(
                  iterativeLayoutOptions: IterativeLayoutOptions(
                      multiplyLabelSkip: 1,
                      labelTiltRadians: -3.14 / 2
                  ),
                  dataContainerOptions: DataContainerOptions(
                    startYAxisAtDataMinRequested: true,
                  )
              ),
            ),
          ),
        ),
      ) : Text('f');
    } else {
      artistRawWeights = const CircularProgressIndicator();
      artistCount = const CircularProgressIndicator();
      artistWeights = const CircularProgressIndicator();
    }

    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
            title: const ShowUp(
              delay: 100,
              child: Text('Prompt analyzer', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600, fontFamily: 'Montserrat')),
            ),
            backgroundColor: const Color(0xaa000000),
            elevation: 0,
            actions: []
        ),
        body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(7),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4.0),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.05),
                                border: Border.all(color: Colors.green, width: 1),
                                borderRadius: const BorderRadius.all(Radius.circular(5.0)),
                              ),
                              child:
                              ExtendedTextField(
                                focusNode: _posFocusNode,
                                // key: _key,
                                showCursor: true,
                                strutStyle: const StrutStyle(),
                                specialTextSpanBuilder: PromptTextSpanBuilder(),
                                controller: positiveController,
                                minLines: 1,
                                maxLines: null,
                                style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 13),
                                // selectionControls: _myExtendedMaterialTextSelectionControls,
                                // extendedContextMenuBuilder: MyTextSelectionControls.defaultContextMenuBuilder,
                                decoration: const InputDecoration(
                                   isDense: true,
                                   border: InputBorder.none, hintText: '',
                                 ),
                                //textDirection: TextDirection.rtl,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(4.0),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                border: Border.all(color: Colors.green, width: 1),
                                borderRadius: const BorderRadius.all(Radius.circular(5.0)),
                              ),
                              child: SelectableText(
                                cleanUpSDPrompt(positiveController.text),
                                style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 13),
                              ),
                            ),
                            Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.1),
                                ),
                                height: 500,
                                child: ListView.separated(
                                    itemBuilder: (BuildContext context, int index){
                                      var item = posMessages[index];
                                      return Container(
                                          color: Colors.black,
                                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                                          child: Row(
                                            children: [
                                              hMTypeToIcon(item.type),
                                              const Gap(4),
                                              SelectableText(item.text)
                                            ],
                                          )
                                      );
                                    },
                                    separatorBuilder: (BuildContext context, int index){
                                      return const Gap(3);
                                    },
                                    itemCount: posMessages.length
                                )
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          SizedBox(
                            height: 300,
                            width: 400,
                            child: artistRawWeights,
                          ),
                          SizedBox(
                            height: 300,
                            width: 400,
                            child: artistCount,
                          ),
                          SizedBox(
                            height: 300,
                            width: 400,
                            child: artistWeights,
                          )
                        ],
                      )
                    ],
                  ),
                  Row(
                    children: [
                      const Spacer(),
                      MaterialButton(onPressed: () => showDialog<String>(
                        context: context,
                        builder: (BuildContext context) => AlertDialog(
                          content: SizedBox(
                            width: 500,
                            height: 500,
                            child: ArtistDefaultStyleSearcher(),
                          ),
                          actions: <Widget>[
                            TextButton(
                              onPressed: (){
                                Navigator.pop(context, 'ok');
                              },
                              child: const Text('Okay'),
                            ),
                          ],
                        ),
                      ), child: const Text('Main artist finder')),
                      MaterialButton(onPressed: () => showDialog<String>(
                        context: context,
                        builder: (BuildContext context) => AlertDialog(
                          contentPadding: EdgeInsets.zero,
                          content: SizedBox(
                            width: 500,
                            height: 500,
                            child: TagSearcher(),
                          ),
                          actions: <Widget>[
                            IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close)),
                          ],
                        ),
                      ), child: const Text('Tag finder')),
                      MaterialButton(onPressed: () => analyzePrompt(0), child: const Text('Analyze'))
                    ],
                  ),
                  const Gap(8),
                  Container(
                    padding: const EdgeInsets.all(4.0),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      border: Border.all(color: Colors.red, width: 1,),
                      borderRadius: const BorderRadius.all(Radius.circular(5.0)),
                    ),
                    child: TextField(
                        controller: negativeController,
                        focusNode: _negFocusNode,
                        keyboardType: TextInputType.multiline,
                        minLines: 1,
                        maxLines: null,
                        style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 13),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none, hintText: '',
                        )
                    ),
                  ),
                  Container(
                      padding: const EdgeInsets.all(4.0),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.1),
                      ),
                      child: Column(
                        children: negMessages.map((item) => Container(
                          color: Colors.black,
                          child: Row(
                            children: [
                              hMTypeToIcon(item.type),
                              const Gap(7),
                              SelectableText(item.text)
                            ],
                          ),
                        )).toList(),
                      )
                  ),
                  Row(
                    children: [
                      const Spacer(),
                      MaterialButton(onPressed: () => analyzePrompt(1), child: const Text('Analyze'))
                    ],
                  ),
                ],
              ),
            )
        )
    );
  }
}

List<String> getRawTags(String prompt) {
  // Normalize whitespace
  prompt = prompt.replaceAll('\n', ' ');

  // Remove LoRA / embeddings
  prompt = prompt.replaceAll(RegExp(r'<[^>]+>'), '');

  // Unescape brackets
  prompt = prompt
      .replaceAll(r'\(', '(')
      .replaceAll(r'\)', ')')
      .replaceAll(r'\[', '[')
      .replaceAll(r'\]', ']');

  // Remove weights everywhere: :1.2
  prompt = prompt.replaceAll(RegExp(r':[+-]?[0-9.]+'), '');

  // Remove "by " prefixes
  prompt = prompt.replaceAll(RegExp(r'\bby\s+', caseSensitive: false), '');

  // Replace brackets with commas (NOT removal)
  prompt = prompt
      .replaceAll('(', ',')
      .replaceAll(')', ',')
      .replaceAll('[', ',')
      .replaceAll(']', ',');

  // Split by BREAK first
  final blocks = prompt.split(RegExp(r'\bBREAK\b'));

  final seen = <String>{};
  final result = <String>[];

  for (final block in blocks) {
    // Split by commas ONLY
    final tokens = block.split(',');

    for (var token in tokens) {
      token = token.trim();
      if (token.isEmpty) continue;

      // Normalize
      final normalized = token
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '');

      if (normalized.isEmpty) continue;

      if (seen.add(normalized)) {
        result.add(normalized);
      }
    }
  }

  return result;
}


String categoryToString(int category){
  return {
    0: 'general',
    1: 'artist',
    3: 'copyright',
    4: 'character',
    5: 'species',
    6: 'invalid',
    7: 'meta',
    8: 'lore'
  }[category] ?? '?';
}

class HMessage {
  final HMType type;
  final String text;

  const HMessage({
    required this.type,
    required this.text,
  });
}

enum HMType {
  info,
  warn,
  error,
  dolbaeb
}

Widget hMTypeToIcon(HMType type){
  return [
    const Icon(Icons.info_outline, color: Colors.blueAccent),
    const Icon(Icons.warning, color: Colors.yellow),
    const Icon(Icons.error, color: Colors.redAccent),
    const Text('🤡', style: TextStyle(fontSize: 18)),
  ][type.index];
}

class PromptTextSpanBuilder extends RegExpSpecialTextSpanBuilder {
  @override
  List<RegExpSpecialText> get regExps => [
    RegExtraCommaText(),
    RegBreakText(),
    RegAttentionText(),
  ];
}

class RegExtraCommaText extends RegExpSpecialText {
  @override
  InlineSpan finishText(int s, Match m, {TextStyle? textStyle, SpecialTextGestureTapCallback? onTap}) => SpecialTextSpan(
    text: m.group(0)!,
    style: textStyle?.copyWith(color: Colors.pinkAccent, background: Paint()..color = Colors.pink.withAlpha(25)),
  );
  @override
  RegExp get regExp => RegExp(r'(?<!\\)\)\s*(,)\s*\S|,,');
}

class RegAttentionText extends RegExpSpecialText {
  @override
  InlineSpan finishText(int s, Match m, {TextStyle? textStyle, SpecialTextGestureTapCallback? onTap}){
    String tag = m.group(0)!.replaceAll('by ', '').trim().replaceAll(' ', '_').toLowerCase();
    bool ok = !_hasDubl[0]!.contains(tag) && _tags.containsKey(tag) && _tags[tag]!.count >= 50;
    bool calculated = _tagsAndWeights[0]![tag] != null;
    return ok ? ExtendedWidgetSpan(
        actualText: m.group(0)!,
        child: Tooltip(
          padding: EdgeInsets.all(7),
          showDuration: Duration(seconds: 10),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
          textStyle: TextStyle(color: Colors.white),
          preferBelow: true,
          richMessage: TextSpan(
            text: 'Count: ',
            children: <TextSpan>[
              TextSpan(text: '${_tags[tag]!.count}\n', style: TextStyle(color: Colors.amberAccent)),
              if(calculated) TextSpan(text: 'User weight: '),
              if(calculated) TextSpan(text: '${_tagsAndWeights[0]![tag]!.toStringAsFixed(2)}\n', style: TextStyle(color: Colors.blue)),
              if(calculated) TextSpan(text: 'Count*weight: '),
              if(calculated) TextSpan(text: '${(_tags[tag]!.count * _tagsAndWeights[0]![tag]!).toStringAsFixed(2)}\n', style: TextStyle(color: Colors.lightBlueAccent)),
            ],
          ),
          child: Text(m.group(0)!, style: textStyle),
        )
    ) : SpecialTextSpan(
      text: m.group(0)!,
      style: _hasDubl[0]!.contains(tag) ? textStyle?.copyWith(color: Colors.purple, background: Paint()..color = Colors.purple.withAlpha(25)) :
      _tags.containsKey(tag) ?
        _tags[tag]!.count < 50 ?
          textStyle?.copyWith(color: Colors.yellow, background: Paint()..color = Colors.yellow.withAlpha(25)) :
          textStyle :
        textStyle?.copyWith(color: Colors.red, background: Paint()..color = Colors.red.withAlpha(25))
    );
  }
  @override
  RegExp get regExp => RegExp(r'(\b[^,\\\[\]():|]+)');
}

class RegBreakText extends RegExpSpecialText {
  @override
  InlineSpan finishText(int s, Match m, {TextStyle? textStyle, SpecialTextGestureTapCallback? onTap}) {
    return SpecialTextSpan(
      text: m.group(0)!,
      deleteAll: true,
      style: textStyle?.copyWith(color: Colors.blueGrey),
    );
  }
  @override
  RegExp get regExp => reBreak;
}