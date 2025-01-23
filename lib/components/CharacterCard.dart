import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../Utils.dart';
import '../components/ImageInfo.dart';

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
                    const Gap(6),
                    TextBox(title: 'Personality', text: characterCard['personality']),
                    const Gap(6),
                    TextBox(title: 'Scenario', text: characterCard['scenario']),
                    const Gap(6),
                    TextBox(title: 'First message', text: characterCard['first_mes']),
                    const Gap(6),
                    TextBox(title: 'Message example', text: characterCard['mes_example']),
                  ],
                )
            )
        ),
        const Gap(6)
      ] : [],
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