import 'package:cimagen/Utils.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_charts/flutter_charts.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import '../modules/Animations.dart';
import '../utils/range.dart';

class PromtAnalyzer extends StatefulWidget{
  final GenerationParams generationParams;

  const PromtAnalyzer({ super.key, required this.generationParams});

  @override
  State<PromtAnalyzer> createState() => _PromtAnalyzerState();
}

class _PromtAnalyzerState extends State<PromtAnalyzer> {
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
    positiveController.text = widget.generationParams.positive;
    negativeController = TextEditingController();
    negativeController.text = widget.generationParams.negative;

    _posFocusNode = FocusNode();
    _negFocusNode = FocusNode();
    _posFocusNode.addListener(() {if(!_posFocusNode.hasFocus) analyzePromt(0);});
    _negFocusNode.addListener(() {if(!_negFocusNode.hasFocus) analyzePromt(1);});

    analyzePromt(0);
    analyzePromt(1);
  }

  Future<void> analyzePromt(int id) async {
    setState(() {
      loaded = false;
      if(id == 0){
        posMessages = [];
      } else {
        negMessages = [];
      }
    });

    var _tags = context.read<DataManager>().e621Tags;

    String _text = (id == 0 ? positiveController.text : negativeController.text).replaceAll('\n', ' ');

    Map<String, double> _tagsAndWeights = {};

    List<List<dynamic>> res = [];
    List<int> roundBrackets = [];
    var squareBrackets = [];

    double roundBracketMultiplier = 1.1;
    double squareBracketMultiplier = 1 / 1.1;

    void multiplyRange(int startPosition, double multiplier){
      for(var p in range(startPosition, res.length)){
        res[p][1] *= multiplier;
      }
    }

    RegExp reAttention = RegExp(r'\\\(|\\\)|\\\[|\\]|\\\\|\\|\(|\[|:\s*([+-]?[.\d]+)\s*\)|\)|]|[^\\()\[\]:]+|:');
    RegExp reBreak = RegExp(r'\s*\bBREAK\b\s*');

    RegExp reBracketTokens = RegExp(r'(?<!\\)\)\s*(,)\s*\S');
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
          (id == 0 ? posMessages : negMessages).add(HMessage(type: HMType.warn, text: 'Tag "$tag" has a duplicate'));
        }
        _tagsAndWeights[tag] = element[1];
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

    List<TagInfo> fi = _tagsAndWeights.keys.where((tag) => _tags.containsKey(tag) && _tags[tag]?.category == 1).map((e) => _tags[e]!).toList(growable: false);

    setState(() {
      loaded = true;
      if(id == 0) {
        posChart = [
        fi.map((e) => _tagsAndWeights[e.name]!).toList(),
        fi.map((e) => e.name).toList(),
        fi.map((e) => e.count.toDouble()).toList(),
        fi.map((e) => e.count * _tagsAndWeights[e.name]!).toList(),
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
      artistRawWeights = VerticalBarChart(
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
      );

      artistCount = VerticalBarChart(
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
      );

      artistWeights = VerticalBarChart(
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
      );
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
              child: Text('Promt analyzer', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600, fontFamily: 'Montserrat')),
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
                                color: Colors.green.withOpacity(0.1),
                                border: Border.all(color: Colors.green, width: 1),
                                borderRadius: const BorderRadius.all(Radius.circular(5.0)),
                              ),
                              child: TextField(
                                controller: positiveController,
                                focusNode: _posFocusNode,
                                keyboardType: TextInputType.multiline,
                                minLines: 1,
                                maxLines: null,
                                style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 13),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none, hintText: '',
                                ),
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
                              child: Text(
                                cleanUpSDPromt(positiveController.text),
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
                      MaterialButton(onPressed: () => analyzePromt(0), child: const Text('Analyze'))
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
                      MaterialButton(onPressed: () => analyzePromt(1), child: const Text('Analyze'))
                    ],
                  ),
                ],
              ),
            )
        )
    );
  }
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