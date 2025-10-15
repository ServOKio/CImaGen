import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:settings_ui/settings_ui.dart';

import '../../../main.dart';
import '../../../utils/ThemeManager.dart';

class SauceNAOSettings extends StatefulWidget{
  const SauceNAOSettings({ super.key });

  @override
  State<SauceNAOSettings> createState() => _SauceNAOSettingsState();
}

class _SauceNAOSettingsState extends State<SauceNAOSettings>{
  // https://saucenao.com/tools/examples/api/index_details.txt
  List<int> indexes = [
    5,  // pixiv
    6,  // pixivhistorical
    29, // e621
    40, // FurAffinity
    41, // Twitter (X)
    42, // Furry Network
  ];

  bool testMode = false;
  String? apiKey;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  _loadSettings() async {

    if(prefs.containsKey('saucenao_indexes')){
      indexes = prefs.getStringList('saucenao_indexes')!.map((e) => int.parse(e)).toList();
    }
    testMode = prefs.getBool('saucenao_testmode') ?? false;
    apiKey = prefs.getString('saucenao_apikey');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('SauceNAO settings'),
          backgroundColor: const Color(0xaa000000),
          elevation: 0,
        ),
        body: SafeArea(
            child:Center(
              child: SettingsList(
                lightTheme: SettingsThemeData(
                    settingsListBackground: Theme.of(context).scaffoldBackgroundColor,
                    titleTextColor: Theme.of(context).primaryColor,
                    tileDescriptionTextColor: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                    settingsTileTextColor: Theme.of(context).textTheme.bodyMedium?.color
                ),
                brightness: context.read<ThemeManager>().isDark ? Brightness.dark : Brightness.light,
                shrinkWrap: true,
                platform: DevicePlatform.fuchsia,
                sections: [
                  SettingsSection(
                    title: const Text('Index Details'),
                    tiles: [
                      SauceNAOIndexes(indexes: indexes, onChange: (list) {

                      })
                    ]
                  ),
                  SettingsSection(
                      title: const Text('Main'),
                      tiles: [
                        SettingsTile.navigation(
                          leading: Icon(Icons.token, color: apiKey != null ? Colors.lightGreen : null),
                          title: const Text('Api Key'),
                          value: Text('Allows using the API from anywhere regardless of whether the client is logged in, or supports cookies'),
                          onPressed: (context) async {
                            var addressController = TextEditingController();
                            addressController.text = apiKey ?? '';
                            final _formKey = GlobalKey<FormState>();
                            await showDialog<void>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  content: Form(
                                    key: _formKey,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        TextFormField(
                                          controller: addressController,
                                          validator: (text) {
                                            return null;
                                          },
                                          decoration: const InputDecoration(
                                            hintStyle: TextStyle(color: Colors.grey),
                                            hintText: 'xxxxxxxxxxxooooooooooooooooooooooooooooo',
                                            labelText: 'Api Key',
                                          ),
                                        ),
                                        const Gap(12),
                                        ElevatedButton(
                                          child: const Text('Set'),
                                          onPressed: () {
                                            if (_formKey.currentState!.validate()) {
                                              String f = addressController.text.trim();
                                              if(f.isEmpty){
                                                prefs.remove('saucenao_apikey');
                                                setState(() {
                                                  apiKey = null;
                                                });
                                              } else {

                                              }
                                              prefs.setString('saucenao_apikey', f);
                                              setState(() {
                                                apiKey = f;
                                              });
                                              Navigator.pop(context);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                            );
                          },
                        ),
                        SettingsTile.switchTile(
                          leading: const Icon(Icons.developer_board_outlined),
                          title: const Text('Test mode'),
                          description: Text('Causes each index which has a match to output at most 1 for testing. Works best with a numres greater than the number of indexes searched.'),
                          onToggle: (v) {
                            setState(() {
                              prefs.setBool('saucenao_testmode', v);
                              testMode = v;
                            });
                          },
                          initialValue: testMode,
                        ),
                      ]
                  ),
                ],
              ),
            )
        )
    );
  }
}

class SauceNAOIndexes extends AbstractSettingsTile{

  List<int> indexes = [
    5,  // pixiv
    6,  // pixivhistorical
    29, // e621
    40, // FurAffinity
    41, // Twitter (X)
    42, // Furry Network
  ];

  SauceNAOIndexes({
    super.key,
    required this.indexes, required Null Function(dynamic list) onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      runSpacing: 5,
      spacing: 5.0,
      children: [
        'h-mags',
        'h-anime',
        'hcg',
        'ddb-objects',
        'ddb-samples',
        'pixiv',
        'pixivhistorical',
        'anime',
        'seiga_illust - nico nico seiga',
        'danbooru',
        'drawr',
        'nijie',
        'yande.re',
        'animeop',
        'IMDb',
        'Shutterstock',
        'FAKKU',
        '!!!RESERVED!!!', // TODO
        'H-MISC (nhentai)',
        '2d_market',
        'medibang',
        'Anime',
        'H-Anime',
        'Movies',
        'Shows',
        'gelbooru',
        'konachan',
        'sankaku',
        'anime-pictures',
        'e621',
        'idol complex',
        'bcy illust',
        'bcy cosplay',
        'portalgraphics',
        'dA',
        'pawoo',
        'madokami',
        'mangadex',
        'H-Misc (ehentai)',
        'ArtStation',
        'FurAffinity',
        'Twitter',
        'Furry Network',
        'Kemono',
        'Skeb'
      ].mapIndexed((index, el) => ChoiceChip(
        labelPadding: EdgeInsetsGeometry.zero,
        label: Text(el, style: TextStyle(fontSize: 12)),
        selected: indexes.contains(index),
        onSelected: (bool sel) {
          if(sel){
            indexes.add(index);
          } else {
            indexes.remove(index);
          }
        },
      )).toList(),
    );
  }
}