import 'dart:async';

import 'package:cimagen/Utils.dart';
import 'package:cimagen/components/ArtistDefaultStypeFinder.dart';
import 'package:cimagen/components/TagSearcher.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_charts/flutter_charts.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import '../../components/Animations.dart';
import '../../constants.dart';
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
Map<int, List<String>> _hasDubl = {
  0: [],
  1: []
};
Map<int, Map<String, double>> _tagsAndWeights = {
  0: {},
  1: {}
};

const double roundBracketMultiplier = 1.1;
const double squareBracketMultiplier = 1.0 / 1.1;

List<List<dynamic>> parsePromptTagsAndWeights(String text) {
  final List<List<dynamic>> res = [];
  final List<int> roundBrackets = [];
  final List<int> squareBrackets = [];

  for (final m in reAttention.allMatches(text)) {
    final String token = m.group(0) ?? '';
    final String? weightStr = m.group(1);
    final double? explicitWeight = weightStr != null ? double.tryParse(weightStr) : null;

    if (token.startsWith('\\')) {
      res.add([token.substring(1), 1.0]);
    } else if (token == '(') {
      roundBrackets.add(res.length);
    } else if (token == '[') {
      squareBrackets.add(res.length);
    } else if (explicitWeight != null && roundBrackets.isNotEmpty) {
      _multiplyRange(res, roundBrackets.removeLast(), explicitWeight);
    } else if (token == ')' && roundBrackets.isNotEmpty) {
      _multiplyRange(res, roundBrackets.removeLast(), roundBracketMultiplier);
    } else if (token == ']' && squareBrackets.isNotEmpty) {
      _multiplyRange(res, squareBrackets.removeLast(), squareBracketMultiplier);
    } else if (token == ':') {
      // Lone :  usually ignored or error, but skip for now
      continue;
    } else {
      final parts = token.split(RegExp(r'\s*BREAK\s*', caseSensitive: false));
      for (int i = 0; i < parts.length; i++) {
        final part = parts[i].trim();
        if (i > 0) {
          res.add(['BREAK', -1.0]);
        }
        if (part.isNotEmpty) {
          res.add([part, 1.0]);
        }
      }
    }
  }

  for (final pos in roundBrackets) {
    _multiplyRange(res, pos, roundBracketMultiplier);
  }
  for (final pos in squareBrackets) {
    _multiplyRange(res, pos, squareBracketMultiplier);
  }

  int i = 0;
  while (i + 1 < res.length) {
    if (res[i][1] == res[i + 1][1] && res[i][0] is String && res[i + 1][0] is String) {
      res[i][0] = '${res[i][0]} ${res[i + 1][0]}'.trim();
      res.removeAt(i + 1);
    } else {
      i++;
    }
  }

  return res.isEmpty ? [['', 1.0]] : res;
}

void _multiplyRange(List<List<dynamic>> list, int start, double factor) {
  for (int j = start; j < list.length; j++) {
    if (list[j][1] is double) {
      list[j][1] = (list[j][1] as double) * factor;
    }
  }
}

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
    super.dispose();
    _hasDubl = {
      0: [],
      1: []
    };
    _tagsAndWeights = {
      0: {},
      1: {}
    };
  }

  Future<void> analyzePrompt(int id) async {
    Map<String, TagInfo> _tags = context.read<DataManager>().e621Tags;
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
                                showCursor: true,
                                strutStyle: const StrutStyle(),
                                specialTextSpanBuilder: PromptTextSpanBuilder(positiveController.text),
                                controller: positiveController,
                                minLines: 1,
                                maxLines: null,
                                style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 13),
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
  final String text;
  PromptTextSpanBuilder(this.text);

  @override
  List<RegExpSpecialText> get regExps => [
    RegExtraCommaText(),
    RegBreakText(),
    LoraSpecialText(),
    RegAttentionText(text),
  ];
}

class LoraSpecialText extends RegExpSpecialText {
  LoraSpecialText({TextStyle? textStyle}) : super();

  @override
  InlineSpan finishText(int start, Match match, {TextStyle? textStyle, SpecialTextGestureTapCallback? onTap}) {
    final fullText = match.group(0)!;

    final inner = fullText.substring(1, fullText.length - 1);
    final parts = inner.split(':');
    final type = parts[0].trim();
    final name = parts.length > 1 ? parts[1].trim() : '';
    final weightStr = parts.length > 2 ? parts[2].trim() : '1.0';
    final weight = double.tryParse(weightStr) ?? 1.0;

    final displayStyle = textStyle?.copyWith(
      color: Colors.cyanAccent,
      fontStyle: FontStyle.italic,
    );

    return SpecialTextSpan(
      text: fullText,
      actualText: fullText,
      style: displayStyle,
    );
  }

  @override
  RegExp get regExp => RegExp(
    r'<(?:lora|lyco|hypernet|embedding|ti):[^>:]+?(?::[^>]*)?>',
    caseSensitive: false,
  );
}

class RegExtraCommaText extends RegExpSpecialText {
  @override
  InlineSpan finishText(int s, Match m, {TextStyle? textStyle, SpecialTextGestureTapCallback? onTap}) => SpecialTextSpan(
    text: m.group(0)!,
    style: textStyle?.copyWith(color: Colors.pinkAccent, background: Paint()..color = Colors.pink.withAlpha(25)),
  );
  @override
  RegExp get regExp => RegExp(
    r'(?<!\\)\)\s*,|,,|\(\s*,',
  );
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

class PromptSelectableWithHover extends StatefulWidget {
  final String text;
  final TextStyle baseStyle;

  const PromptSelectableWithHover({
    Key? key,
    required this.text,
    required this.baseStyle,
  }) : super(key: key);

  @override
  _PromptSelectableWithHoverState createState() => _PromptSelectableWithHoverState();
}

class RegAttentionText extends RegExpSpecialText {
  final Map<String, TagInfo> _tags = kBaseNavigatorKey.currentContext!.read<DataManager>().e621Tags;
  final Map<String, Map<String, dynamic>> _tagStats;
  RegAttentionText(String fullText) : _tagStats = parsePromptTagStats(fullText), super();

  static Map<String, Map<String, dynamic>> parsePromptTagStats(String text) {
    final parsed = parsePromptTagsAndWeights(text);
    final stats = <String, Map<String, dynamic>>{};
    for (final entry in parsed) {
      final raw = entry[0] as String;
      final weight = entry[1] as double;
      if (raw == 'BREAK' || weight < 0) continue;
      String norm = raw
          .replaceAll('by ', '')
          .trim()
          .replaceAll(' ', '_')
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9_]'), '_');
      if (norm.isEmpty) continue;
      stats.putIfAbsent(norm, () => {'weight': 0.0, 'count': 0});
      stats[norm]!['weight'] = stats[norm]!['weight'] + weight;
      stats[norm]!['count'] = stats[norm]!['count'] + 1;
    }
    return stats;
  }

  @override
  InlineSpan finishText(int s, Match m, {TextStyle? textStyle, SpecialTextGestureTapCallback? onTap}) {
    final raw = m.group(0)!;
    final normTag = raw
        .replaceAll('by ', '')
        .trim()
        .replaceAll(' ', '_')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_');

    final stats = _tagStats[normTag];
    final promptWeight = stats?['weight'] as double? ?? 1.0;
    final occurrenceCount = stats?['count'] as int? ?? 1;
    final tagInfo = _tags[normTag];
    final bool hasInfo = tagInfo != null;
    final bool popular = hasInfo && tagInfo.count >= 50;
    final bool isDuplicate = occurrenceCount > 1;

    Color? textColor;
    Paint? bgPaint;
    if (isDuplicate) {
      textColor = Colors.purple;
      bgPaint = Paint()..color = Colors.purple.withAlpha(50);
    } else if (!hasInfo) {
      textColor = Colors.red;
      bgPaint = Paint()..color = Colors.red.withAlpha(40);
    } else if (!popular) {
      textColor = Colors.yellow;
      bgPaint = Paint()..color = Colors.yellow.withAlpha(35);
    }
    if (bgPaint != null) {
      final factor = (promptWeight.clamp(0.6, 2.5) - 0.6) / 1.9;
      final alpha = (bgPaint.color.alpha * (0.5 + factor * 0.5)).round();
      bgPaint.color = bgPaint.color.withAlpha(alpha);
    }

    return SpecialTextSpan(
      text: raw,
      actualText: raw,
      style: textStyle?.copyWith(
        color: textColor,
        background: bgPaint,
        fontWeight: promptWeight > 1.25 || isDuplicate ? FontWeight.w600 : null,
      ),
    );
  }

  @override
  RegExp get regExp => RegExp(
    r'(?<!<[^>]*:)(?![0-9:.+-]+\b)[^\s,\\\[\](){}: ]+(?:\s+[^\s,\\\[\](){}: ]+)*(?=[,\s:()]|$)',
    caseSensitive: false,
  );
}

class _PromptSelectableWithHoverState extends State<PromptSelectableWithHover> {
  final GlobalKey _textKey = GlobalKey();
  OverlayEntry? _overlay;
  Timer? _hideTimer;
  final Duration _tooltipShowDelay = Duration(milliseconds: 100);
  final Duration _tooltipHideDelay = Duration(milliseconds: 150);
  TextSpan? _builtSpan;
  List<_TokenRange> _tokens = [];

  @override
  void initState() {
    super.initState();
    _buildSpanAndTokens();
  }

  @override
  void didUpdateWidget(covariant PromptSelectableWithHover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.baseStyle != widget.baseStyle) {
      _buildSpanAndTokens();
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _buildSpanAndTokens() {
    _builtSpan = PromptTextSpanBuilder(widget.text).build(widget.text, textStyle: widget.baseStyle);

    final attentionReg = RegAttentionText('').regExp;
    final loraReg = RegExp(r'<(?:lora|lyco|hypernet|embedding|ti):[^>:]+?(?::[^>]*)?>', caseSensitive: false);

    final matches = <Match>[];
    matches.addAll(attentionReg.allMatches(widget.text));
    matches.addAll(loraReg.allMatches(widget.text));

    matches.sort((a, b) => a.start.compareTo(b.start));

    _tokens = matches.map((m) {
      final raw = m.group(0)!;
      final token = _TokenRange(start: m.start, end: m.end, raw: raw);
      token.tooltip = _createTooltipFor(raw, widget.text);
      return token;
    }).toList();
  }


  Map<String, String> _createTooltipFor(String raw, String fullText) {
    if (raw.startsWith('<') && raw.contains(':')) {
      final inner = raw.substring(1, raw.length - 1);
      final parts = inner.split(':');
      final type = parts.isNotEmpty ? parts[0].trim() : '';
      final name = parts.length > 1 ? parts[1].trim() : '';
      final weightStr = parts.length > 2 ? parts[2].trim() : '1.0';
      final weight = double.tryParse(weightStr) ?? 1.0;

      return {
        'tag': raw,
        'type': type,
        'name': name,
        'weight': weight.toStringAsFixed(2),

        'count': '-',
        'countWeight': '-',
        'occurrences': '1',
      };
    }

    final normTag = raw
        .replaceAll('by ', '')
        .trim()
        .replaceAll(' ', '_')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_');

    final parsedStats = RegAttentionText.parsePromptTagStats(fullText);
    final stats = parsedStats[normTag];
    final promptWeight = stats?['weight'] as double? ?? 1.0;
    final occurrenceCount = stats?['count'] as int? ?? 1;
    final tagInfo = kBaseNavigatorKey.currentContext!.read<DataManager>().e621Tags[normTag];

    final countStr = tagInfo?.count.toString() ?? '-';
    final countWeightStr = tagInfo != null ? (tagInfo.count * promptWeight).toStringAsFixed(2) : '-';

    return {
      'tag': raw,
      'count': countStr,
      'weight': promptWeight.toStringAsFixed(2),
      'countWeight': countWeightStr,
      'occurrences': occurrenceCount.toString(),
    };
  }

  void _showOverlayAt(Offset globalPosition, Map<String, String> tooltipData) {
    _hideTimer?.cancel();
    _removeOverlay();
    final overlay = Overlay.of(context);

    final overlayEntry = OverlayEntry(
      builder: (ctx) {
        final p = globalPosition + const Offset(12, -10);
        return Positioned(
          left: p.dx,
          top: p.dy,
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 300),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.white, fontSize: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tooltipData['tag'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('Tag count: ${tooltipData['count']}'),
                    Text('Prompt weight: ${tooltipData['weight']}'),
                    Text('Count*weight: ${tooltipData['countWeight']}'),
                    if ((tooltipData['occurrences'] ?? '1') != '1') Text('Appears: ${tooltipData['occurrences']}×'),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(overlayEntry);
    _overlay = overlayEntry;
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _onHover(PointerHoverEvent event) {
    final box = _textKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || _builtSpan == null) {
      _removeOverlay();
      return;
    }
    final local = box.globalToLocal(event.position);

    final tp = TextPainter(
      text: _builtSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
      textScaleFactor: MediaQuery.of(context).textScaleFactor,
      maxLines: null,
    );

    tp.layout(maxWidth: box.size.width);

    if (local.dy < 0 || local.dy > tp.height || local.dx < 0 || local.dx > box.size.width) {
      _hideTimer?.cancel();
      _hideTimer = Timer(_tooltipHideDelay, () => _removeOverlay());
      return;
    }

    final textPos = tp.getPositionForOffset(local);
    final idx = textPos.offset;

    final token = _tokens.firstWhere(
          (t) => idx >= t.start && idx <= t.end,
      orElse: () => _TokenRange.none(),
    );

    if (token.isNone) {
      _hideTimer?.cancel();
      _hideTimer = Timer(_tooltipHideDelay, () => _removeOverlay());
      return;
    }

    _hideTimer?.cancel();
    _hideTimer = Timer(_tooltipShowDelay, () {
      _showOverlayAt(event.position, token.tooltip ?? {});
    });
  }

  void _onExit(PointerExitEvent event) {
    _hideTimer?.cancel();
    _hideTimer = Timer(_tooltipHideDelay, () => _removeOverlay());
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth ? constraints.maxWidth : MediaQuery.of(context).size.width;
        final span = _builtSpan ?? PromptTextSpanBuilder(widget.text).build(widget.text, textStyle: widget.baseStyle);

        return MouseRegion(
          onHover: _onHover,
          onExit: _onExit,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width),
            child: Container(
              key: _textKey,
              width: width,
              child: ExtendedSelectableText.rich(
                span,
                showCursor: true,
                minLines: 1,
                maxLines: null,
                style: widget.baseStyle,
                textAlign: TextAlign.left,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TokenRange {
  final int start;
  final int end;
  final String raw;
  Map<String, String>? tooltip;
  final bool isNoneToken;

  _TokenRange({required this.start, required this.end, required this.raw, this.tooltip}) : isNoneToken = false;
  _TokenRange.none() : start = -1, end = -1, raw = '', isNoneToken = true;
  bool get isNone => isNoneToken;
}