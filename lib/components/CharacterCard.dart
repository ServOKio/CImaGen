import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:get/get.dart';

import 'dart:math' as math;

import '../Utils.dart';
import '../components/ImageInfo.dart';
import '../modules/Animations.dart';

class CharacterCardImageInfo extends StatefulWidget {
  final String base64;
  const CharacterCardImageInfo(this.base64, {super.key});

  @override
  State<CharacterCardImageInfo> createState() => _CharacterCardImageInfoState();
}

class _CharacterCardImageInfoState extends State<CharacterCardImageInfo> {
  bool loaded = false;
  var characterCard;

  @override
  void initState(){
    super.initState();
    main();
  }

  void main() async {
    String decoded = String.fromCharCodes(base64Decode(widget.base64));
    print(decoded);
    if(await isJson(decoded)){
      characterCard = jsonDecode(decoded);
    } else {

    }
    setState(() {
      loaded = true;
    });
  }

  // https://github.com/malfoyslastname/character-card-spec-v2/blob/main/spec_v2.md
  // https://github.com/kwaroran/character-card-spec-v3/blob/main/SPEC_V3.md

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      initiallyExpanded: true,
      title: Row(
        children: [
          Text('Character card', style: TextStyle(color: Colors.deepPurple.shade50, fontWeight: FontWeight.w600, fontSize: 18)),
          const Spacer(),
          if(!loaded) const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
        ],
      ),
      children: characterCard != null ? <Widget>[
        InfoBox(one: 'Name', two: characterCard['name']),
        if(characterCard['tags'] != null || characterCard['data']['tags'] != null) InfoBox(one: 'Tags', two: (characterCard['tags'] ?? characterCard['data']['tags']).join(', '), withGap: false),
        InfoBox(one: 'Spec/Version', two: characterCard['spec'] == null ? 'v1' : '${characterCard['spec']}, ${characterCard['spec_version']}', withGap: false),
        const Gap(6),
        Container(
            decoration: const BoxDecoration(
                color: Color(0xff303030),
                borderRadius: BorderRadius.all(Radius.circular(4))
            ),
            child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Main', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    if(characterCard['personality'] != null) const Gap(6),
                    if(characterCard['personality'] != null) TextBox(title: 'Personality', text: characterCard['personality']),
                    if(characterCard['scenario'] != null) const Gap(6),
                    if(characterCard['scenario'] != null) TextBox(title: 'Scenario', text: characterCard['scenario']),
                    if(characterCard['first_mes'] != null) const Gap(6),
                    if(characterCard['first_mes'] != null)  TextBox(title: 'First message', text: characterCard['first_mes']),
                    if(characterCard['mes_example'] != null) const Gap(6),
                    if(characterCard['mes_example'] != null) TextBox(title: 'Message example', text: characterCard['mes_example']),
                  ]
                )
            )
        ),
        ElevatedButton(child: const Text('View'), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) =>  CharacterCardFullView(jsonData: characterCard)))),
        const Gap(6)
      ] : []
    );
  }
}

class TextBox extends StatelessWidget {
  final String title;
  final String text;

  const TextBox({super.key, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
            padding: const EdgeInsets.all(4.0),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.all(Radius.circular(5.0)),
            ),
            child: FractionallySizedBox(
                widthFactor: 1.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w200, fontSize: 11, color: Colors.white70)),
                    SelectableText(text, style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 13))
                  ],
                )
            )
        ),
      ],
    );
  }
}

class CharacterCardFullView extends StatefulWidget{
  final dynamic jsonData;

  const CharacterCardFullView({ super.key, required this.jsonData});

  @override
  State<CharacterCardFullView> createState() => _CharacterCardFullViewState();
}

class _CharacterCardFullViewState extends State<CharacterCardFullView> {
  bool loaded = false;
  String? error;

  // General
  OperationMode opMode = OperationMode.unknown;

  // Main
  String? you;

  String? opponent;
  String? opponentAvatar;
  List<OpponentDescription> opponentDescription = [];

  List<String> actions = [];

  void initState(){
    try{
      // character-card-spec ?
      dynamic d = widget.jsonData;
      if(d['spec'] != null){
        // yes, character
        if(d['spec_version'] == '2.0'){
          dynamic data = d['data'];
          opponent = data['name'];
          RegExp bbRegex = RegExp(r'\[([\w\W]*?)\]([\w\W]*?)\[\/[\w\W]*?\]');
          if(data['description'] != null){
            String opponentDescriptionRaw = (data['description'] as String).replaceAll('{{char}}', opponent ?? 'They');
            Iterable<RegExpMatch> matches = bbRegex.allMatches(opponentDescriptionRaw);
            for(RegExpMatch match in matches){
              String key = match.group(1) ?? 'nullKey';
              String value = match.group(2) ?? 'nullValue';
              opponentDescription.add(OpponentDescription(keyRaw: key.toLowerCase(), title: key, content: value.trim().split('\n')));
            }
          }

        } else if(d['spec_version'] == '3.0'){

        }
      } else {
        // spec v1 ?
        if(d['name'] != null && d['first_mes'] != null){
          // yes
        } else {
          // kobold ?
          if(d['savedsettings'] != null){
            // yes
            dynamic settings = d['savedsettings'];
            opMode = opToOP(settings['opmode'].runtimeType == int ? settings['opmode'] : int.parse(settings['opmode']));

            // Main
            you = settings['chatname'];
            opponent = settings['chatopponent'];
            actions = List<String>.from(d['actions']);
          }
          if(d['savedaestheticsettings'] != null){
            dynamic saes = d['savedaestheticsettings'];
            if(saes['AI_portrait'] != null) opponentAvatar = saes['AI_portrait'];
          }
        }

      }
      setState(() {
        loaded = true;
      });
    } catch(e, stack){
      setState(() {
        error = e.toString()+stack.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    AppBar appBar = AppBar(
        title: ShowUp(
          delay: 100,
          child: Text('Character Card ${opMode.toString()}', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600, fontFamily: 'Montserrat')),
        ),
    );

    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: appBar,
        backgroundColor: Color(0xff141517),
        body: SafeArea(
            child: error == null ? Row(
              children: [
                Left(),
                Expanded(child: opMode == OperationMode.chat ? ListView.separated(
                    itemBuilder: (context, index){
                      String raw = actions[index].trim();
                      String nickname = raw.startsWith(opponent ?? 'They') ? opponent ?? 'They' : you ?? 'You';
                      String text = (RegExp(r':.*').firstMatch(raw)!.group(0) ?? '').replaceFirst(':', '').trim();
                      return Row(
                        children: [
                          raw.startsWith(opponent ?? '') ? opponentAvatar != null ? CircleAvatar(
                            backgroundImage: MemoryImage(Base64Decoder().convert(opponentAvatar!.split('base64,')[1])),
                          ) : Icon(Icons.account_box_rounded) : Icon(Icons.account_box_rounded),
                          Gap(4),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nickname, style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(text),
                            ],
                          )
                        ],
                      );
                    },
                    separatorBuilder: (context, index) => Gap(6),
                    itemCount: actions.length
                  ) : Text('')
                ),
                Right()
              ],
            ) : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 50, color: Colors.redAccent),
                  Gap(4),
                  Text('Oops, looks like there was an error...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  Text('E: $error', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
        )
    );
  }

  Widget Left(){
    return Container(
      color: Color(0xff1b1c20),
      width: 300,
      child: SingleChildScrollView(
        child: Text('Opponent'),

      ),
    );
  }

  Color getColor(int index){
    List<Color> c = [
      const Color(0xffea4b49),
      const Color(0xfff88749),
      const Color(0xfff8be46),
      const Color(0xff89c54d),
      const Color(0xff48bff9),
      const Color(0xff5b93fd),
      const Color(0xff9c6efb)
    ];
    return c[index % c.length];
  }

  Widget Right(){
    return Container(
      color: Color(0xff1b1c20),
      width: 300,
      child: SingleChildScrollView(
        child: Column(
          children: [
            Text('Opponent'),
            ExpansionTile(
            title: Text('Description'),
            children: opponentDescription.asMap().map((index, desc) => MapEntry(index, Container(
                margin: EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Color(0xff111214),
                  borderRadius: BorderRadius.all(Radius.circular(4))
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: getColor(index),
                          ),
                        ),
                        Gap(4),
                        Text(desc.title)
                      ],
                    ),
                    Gap(4),
                    SelectableText(desc.content.join('\n'))
                  ],
                ),
              ))).values.toList(),
            )
          ],
        ),
      ),
    );
  }
}

class OpponentDescription{
  final String keyRaw;
  final String title;
  final List<String> content;

  OpponentDescription({
    required this.keyRaw,
    required this.title,
    required this.content,
  });
}

enum OperationMode{
  unknown,
  chat
}

OperationMode opToOP(int op){
  return {
    3: OperationMode.chat
  }[op] ?? OperationMode.unknown;
}