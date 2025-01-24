import 'dart:io';
import 'dart:math';

import 'package:cimagen/pages/sub/DBExtra.dart';
import 'package:cimagen/pages/sub/GitHubCommits.dart';
import 'package:cimagen/pages/sub/RemoteVersionSettings.dart';
import 'package:cimagen/utils/ThemeManager.dart';
import 'package:external_path/external_path.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pie_chart/pie_chart.dart';
import 'package:provider/provider.dart';

import 'package:settings_ui/settings_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_theme/system_theme.dart';
import 'package:path/path.dart' as p;

import '../Utils.dart';
import '../main.dart';
import '../modules/webUI/OnLocal.dart';
import '../utils/SQLite.dart';

class Settings extends StatefulWidget{
  const Settings({ super.key });

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings>{
  // Settings
  String _webui_folder = '';
  bool _use_remote_version = false;

  bool _debug = false;
  bool _imageview_use_fullscreen = false;
  bool _gallery_display_id = false;

  String _custom_cache_dir = '-';
  double _maxCacheSize = 5;
  int _currentCacheSize = 0;

  String appDocumentsPath = '';
  String appTempPath = '';
  String? documentsPath = '';
  String? downloadsPath = '';
  String appVersion = '-';

  String _deviceInfo = '-';

  Map<String, double> dataMap = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  _loadSettings() async {
    Directory appDocumentsDir = await getApplicationDocumentsDirectory();
    Directory appTempDir = await getTemporaryDirectory();
    if(Platform.isAndroid){
      documentsPath = await ExternalPath.getExternalStoragePublicDirectory(ExternalPath.DIRECTORY_DOCUMENTS);
    } else if(Platform.isWindows){
      documentsPath = appDocumentsDir.path;
    }
    Directory? dP = await getDownloadsDirectory();
    if(dP != null) downloadsPath = dP.absolute.path;
    PackageInfo packageInfo = await PackageInfo.fromPlatform();

    String deviceInfo = await getDeviceInfo();

    setState(() {
      _webui_folder = prefs!.getString('webui_folder') ?? 'none';
      _use_remote_version = prefs!.getBool('use_remote_version') ?? false;
      _debug = prefs!.getBool('debug') ?? false;
      _imageview_use_fullscreen = (prefs!.getBool('imageview_use_fullscreen') ?? false);
      _gallery_display_id = (prefs!.getBool('gallery_display_id') ?? false);
      appDocumentsPath = appDocumentsDir.absolute.path;
      appTempPath = appTempDir.absolute.path;
      appVersion = packageInfo.version;
      _deviceInfo = deviceInfo;
      _custom_cache_dir = context.read<ConfigManager>().tempDir;
      _maxCacheSize = (prefs!.getDouble('max_cache_size') ?? 5);
    });

    getDirSize(Directory(_custom_cache_dir)).then((value) => setState(() {
      _currentCacheSize = value;
    }));

    context.read<SQLite>().getTablesInfo().then((value) => {
      if(mounted)setState(() {
        dataMap = {
          'txt2img (${readableFileSize(value['txt2imgSumSize'] as int)})': (value['txt2imgCount'] as int).toDouble(),
          'img2img (${readableFileSize(value['img2imgSumSize'] as int)})': (value['img2imgCount'] as int).toDouble(),
          'inpaint (${readableFileSize(value['inpaintSumSize'] as int)})': (value['inpaintCount'] as int).toDouble(),
          'comfui (${readableFileSize(value['comfuiSumSize'] as int)})': (value['comfuiCount'] as int).toDouble(),
          'Without meta': (value['totalImages'] as int) - (value['totalImagesWithMetadata'] as int).toDouble()
        };
      })
    }).onError((error, stackTrace) => {
      if(mounted) setState(() {
        dataMap = {
          'all': 0
        };
      })
    });
  }

  @override
  Widget build(BuildContext context) {
    Color f = SystemTheme.accentColor.accent;
    return Center(
        child: SettingsList(
          lightTheme: SettingsThemeData(
            leadingIconsColor: Theme.of(context).colorScheme.primary,
            settingsListBackground: Theme.of(context).scaffoldBackgroundColor,
            titleTextColor: Theme.of(context).primaryColor,
            tileDescriptionTextColor: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
            settingsTileTextColor: Theme.of(context).textTheme.bodyMedium?.color
          ),
          darkTheme: SettingsThemeData(
              leadingIconsColor: Theme.of(context).colorScheme.primary,
              settingsListBackground: Theme.of(context).scaffoldBackgroundColor,
              titleTextColor: Theme.of(context).colorScheme.primary,
              tileDescriptionTextColor: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
              settingsTileTextColor: Theme.of(context).textTheme.bodyMedium?.color
          ),
          brightness: context.read<ThemeManager>().isDark ? Brightness.dark : Brightness.light,
          shrinkWrap: true,
          platform: DevicePlatform.fuchsia,
          sections: [
            SettingsSection(
              title: const Text('Common'),
              tiles: <SettingsTile>[
                SettingsTile.navigation(
                  enabled: _use_remote_version == false,
                  leading: const Icon(Icons.web),
                  title: const Text('WebUI location'),
                  value: Text(_use_remote_version ? 'Turn off the remote version to use the local version' : _webui_folder),
                  onPressed: (context) async {
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
                    if (selectedDirectory != null) {
                      prefs.setString('webui_folder', selectedDirectory);
                      setState(() {
                        _webui_folder = selectedDirectory;
                      });
                      prefs.getKeys().forEach((element) {
                        print(prefs.get(element));
                      });
                    }
                  },
                ),
                SettingsTile.navigation(
                  leading: const Icon(Icons.cached),
                  title: const Text('Cache Location'),
                  value: Text('The place where the cache will be located (temporary shit that can be deleted after a while)\nNow: $_custom_cache_dir'),
                  onPressed: (context) async {
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
                    if (selectedDirectory != null) {
                      List<FileSystemEntity> fe = await dirContents(Directory(selectedDirectory));
                      if(fe.isNotEmpty){
                        Directory tDir = Directory(p.join(selectedDirectory, 'cImagen'));
                        tDir.create(recursive: true).then((va){
                          setState(() {
                            _custom_cache_dir = va.path;
                          });
                          prefs.setString('custom_cache_dir', va.path);
                          context.read<ConfigManager>().updateCacheLocation();
                        });
                      } else {
                        prefs.setString('custom_cache_dir', selectedDirectory);
                        context.read<ConfigManager>().updateCacheLocation();
                      }
                    }
                  },
                ),
                SettingsTile(
                  leading: Icon(Icons.restart_alt),
                  title: Text('Restore the default cache location'),
                  onPressed: (context) async {
                    showDialog<String>(
                      context: context,
                      builder: (BuildContext context) => AlertDialog(
                        icon: const Icon(Icons.warning_amber_outlined),
                        title: const Text('Are you serious?'),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () async {
                              SharedPreferences prefs = await SharedPreferences.getInstance();
                              prefs.remove('custom_cache_dir');
                              context.read<ConfigManager>().updateCacheLocation().then((value){
                                setState(() {
                                  _custom_cache_dir = value;
                                });
                              });
                            },
                            child: const Text('Okay'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, 'Cancel'),
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                SettingsTile(
                  leading: Icon(Icons.delete_sweep),
                  title: Text('Maximum cache size'),
                  description: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Limit: ${_maxCacheSize.round()}GB Current: ${readableFileSize(_currentCacheSize)}'),
                      Slider(
                        value: _maxCacheSize,
                        min: 5,
                        max: 50,
                        divisions: 5,
                        label: '${_maxCacheSize.round()}GB',
                        onChanged: (double v) {
                          prefs!.setDouble('max_cache_size', v);
                          setState(() {
                            _maxCacheSize = v;
                          });
                        },
                      )
                    ],
                  ),
                ),
                SettingsTile.navigation(
                  leading: const Icon(Icons.network_check_rounded),
                  title: Text('Remote version settings'),
                  description: Text('Specify the IP address to access the WebUI or select a network folder'),
                  onPressed: (context){
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const RemoteVersionSettings()));
                  },
                ),
                SettingsTile.switchTile(
                  onToggle: (v) {
                    setState(() {
                      _debug = v;
                    });
                    prefs!.setBool('debug', v);
                  },
                  leading: Icon(Icons.bug_report),
                  title: Text('Enable debug'), initialValue: _debug,
                ),
              ],
            ),
            SettingsSection(
              title: Text('UI & UX'),
              tiles:[
                AppTheme(),
                SettingsTile.switchTile(
                  leading: const Icon(Icons.fullscreen),
                  title: const Text('Full-screen mode when viewing images'),
                  description: Text('When viewing images, the upper control frame will be completely removed'),
                  onToggle: (v) {
                    setState(() {
                      _imageview_use_fullscreen = v;
                    });
                    prefs!.setBool('imageview_use_fullscreen', v);
                  }, initialValue: _imageview_use_fullscreen,
                ),
                SettingsTile.switchTile(
                  leading: const Icon(Icons.numbers),
                  title: Text('Display image ID in gallery'),
                  description: Text('This will help determine the sequence of images if they are all the same size'),
                  onToggle: (v) {
                    setState(() {
                      _gallery_display_id = v;
                    });
                    prefs!.setBool('gallery_display_id', v);
                  }, initialValue: _gallery_display_id,
                ),
              ],
            ),
            SettingsSection(
              title: const Text('Database'),
              tiles: [
                DBChart(dataMap: dataMap),
                SettingsTile(
                  leading: const Icon(Icons.delete),
                  title: Text('Clear image database'),
                  description: Text('Previews, image data. The list of favorites will remain untouched'),
                  onPressed: (context){
                    showDialog<String>(
                        context: context,
                        builder: (BuildContext context) => AlertDialog(
                          icon: const Icon(Icons.warning_amber_outlined),
                          title: const Text('Are you sure you want to delete the cache?'),
                          content: const Text('The application will take some time to read all the images again'),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => context.read<SQLite>().clearMeta().then((value) => Navigator.pop(context, 'Ok')),
                              child: const Text('Okay'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, 'Cancel'),
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                    );
                  },
                ),
                SettingsTile(
                  leading: Icon(Icons.warning),
                  title: Text('Extra'),
                  description: Text('Not recommended for noobs'),
                  onPressed: (context){
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const DBExtra()));
                  },
                )
              ],
            ),
            SettingsSection(
              title: const Text('Device info'),
              tiles: <SettingsTile>[
                SettingsTile(
                  leading: Icon(Platform.isAndroid ? Icons.phone_android : Icons.desktop_windows , color: f),
                  title: const Text('Device'),
                  description: SelectableText(_deviceInfo),
                ),
                SettingsTile(
                  leading: const Icon(Icons.folder ),
                  title: const Text('Paths'),
                  description: Text(''
                      'App Documents\n↳ $appDocumentsPath\n'
                      'App Temp\n↳ $appTempPath\n'
                      'Documents\n↳ $documentsPath\n'
                      'Downloads\n↳ $downloadsPath\n'),
                )
              ],
            ),
            SettingsSection(
              title: const Text('CImaGen'),
              tiles: <SettingsTile>[
                SettingsTile(
                  leading: Icon(Platform.isAndroid ? Icons.phone_android : Icons.desktop_windows ),
                  title: const Text('App'),
                  description: Text(appVersion),
                ),
                SettingsTile(
                  leading: Icon(Icons.system_update_alt),
                  title: Text('Updates'),
                  description: Text('View the list of changes'),
                  onPressed: (context){
                    Navigator.push(context, MaterialPageRoute(builder: (context) => GitHubCommits()));
                  },
                )
              ],
            ),
          ],
        ),
    );
  }
}

class AppTheme extends AbstractSettingsTile{
  @override
  Widget build(BuildContext context) {
    double size = 200;
    double aspectRatio = 16/9;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Column(
            children: [
              Container(
                  width: size,
                  child: AspectRatio(
                    aspectRatio: aspectRatio,
                    child: Container(
                      decoration: const BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(7)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 14
                            )
                          ],
                          color: Color(0xFF131517)
                      ),
                    ),
                  ),
                ),
                const Gap(8),
                const Text('Dark')
            ],
          ),
          const Gap(14),
          Column(
            children: [
              Container(
                  width: size,
                  child: AspectRatio(
                    aspectRatio: aspectRatio,
                    child: Container(
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(7)),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black12,
                              blurRadius: 14
                          )
                        ],
                        color: Color(0xFFf5f5f5)
                      ),
                    ),
                  ),
                ),
                const Gap(8),
                const Text('Light')
            ],
          ),
          const Gap(14),
          Column(
            children: [
              Container(
                width: size,
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  child: Container(
                    decoration: const BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(7)),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black12,
                              blurRadius: 14
                          )
                        ],
                        color: Color(0xFFf5f5f5)
                    ),
                  ),
                ),
              ),
              const Gap(8),
              const Text('System')
            ],
          )
        ],
      ),
    );
  }
}

class DBChart extends AbstractSettingsTile{
  final Map<String, double> dataMap;

  DBChart({
    super.key,
    required this.dataMap,
  });

  final List<List<List<Color>>> colorList = [
    [],                       // 0
    [
      [
        const Color(0xffffffff),
        increaseColorLightness(const Color(0xffffffff), 0.2)
      ]
    ], // 1
    [
      [
        const Color(0xffe20000),
        increaseColorLightness(const Color(0xffe20000), 0.2)
      ],
      [
        const Color(0xff03ce6c),
        increaseColorLightness(const Color(0xff03ce6c), 0.2)
      ]
    ], // 2
    [
      [
        const Color(0xff6407f6),
        increaseColorLightness(const Color(0xff6407f6), 0.2)
      ],
      [
        const Color(0xff01e5fc),
        increaseColorLightness(const Color(0xff01e5fc), 0.2)
      ],
      [
        const Color(0xff1df400),
        increaseColorLightness(const Color(0xff1df400), 0.2)
      ]
    ], // 3
    [
      [
        const Color(0xff197bf7),
        increaseColorLightness(const Color(0xff197bf7), 0.2),
      ],
      [
        const Color(0xff000146),
        increaseColorLightness(const Color(0xff000146), 0.2)
      ],
      [
        const Color(0xffe00081),
        increaseColorLightness(const Color(0xffe00081), 0.2)
      ],
      [
        const Color(0xfff8e71a),
        increaseColorLightness(const Color(0xfff8e71a), 0.2)
      ]
    ], // 4
    [
      [
        const Color(0xff26f8b8),
        increaseColorHue(const Color(0xff26f8b8), -15)
      ],
      [
        const Color(0xffcbc20a),
        increaseColorHue(const Color(0xffcbc20a), -15)
      ],
      [
        const Color(0xfffc8c0e),
        increaseColorHue(const Color(0xfffc8c0e), -15)
      ],
      [
        const Color(0xffd63d50),
        increaseColorHue(const Color(0xffd63d50), -15)
      ],
      [
        const Color(0xff2800ff),
        increaseColorHue(const Color(0xff2800ff), -15)
      ]
    ], // 5
    // [ // TODO
    //   const Color(0xff26f8b8),
    //   const Color(0xffcbc20a),
    //   const Color(0xfffc8c0e),
    //   const Color(0xffd63d50),
    //   const Color(0xff2800ff),
    //   const Color(0xffd63d50),
    //   const Color(0xff2800ff)
    // ], // 6
    // [ // TODO
    //   const Color(0xff26f8b8),
    //   const Color(0xffcbc20a),
    //   const Color(0xfffc8c0e),
    //   const Color(0xffd63d50),
    //   const Color(0xff2800ff),
    //   const Color(0xffd63d50),
    //   const Color(0xff2800ff)
    // ], // 7
    // [
    //   const Color(0xffe56a02),
    //   const Color(0xfffedf00),
    //   const Color(0xff54fca6),
    //   const Color(0xff13e4e8),
    //   const Color(0xff0271fc),
    //   const Color(0xff5f0073),
    //   const Color(0xff8c0241),
    //   const Color(0xffba301f),
    // ] // 8
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return dataMap.isNotEmpty ? PieChart(
      dataMap: dataMap,
      animationDuration: const Duration(milliseconds: 1000),
      chartLegendSpacing: screenWidth > 1280 ? 80 : 60,
      chartRadius: screenWidth > 1280 ? 200 : 140,
      gradientList: colorList[dataMap.keys.length],
      initialAngleInDegree: 0,
      chartType: ChartType.ring,
      ringStrokeWidth: 18,
      centerText: dataMap.values.reduce((a, b) => a + b).round().toString(),
      legendOptions: const LegendOptions(
        showLegendsInRow: false,
        legendPosition: LegendPosition.right,
        showLegends: true,
        legendShape: BoxShape.circle,
        legendTextStyle: TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      chartValuesOptions: const ChartValuesOptions(
        showChartValueBackground: true,
        showChartValues: true,
        showChartValuesInPercentage: false,
        showChartValuesOutside: true,
        decimalPlaces: 0,
      ),
    ) : const LinearProgressIndicator();
  }
}

Color changeColorLightness(Color color, double lightness) => HSLColor.fromColor(color).withLightness(lightness).toColor();
Color changeColorHue(Color color, double hue) => HSLColor.fromColor(color).withHue(hue).toColor();
Color increaseColorHue(Color color, double increment) {
  var hslColor = HSLColor.fromColor(color);
  var newValue = min(max(hslColor.hue + increment, 0.0), 360.0);
  return hslColor.withHue(newValue).toColor();
}
Color increaseColorLightness(Color color, double increment) {
  var hslColor = HSLColor.fromColor(color);
  var newValue = min(max(hslColor.lightness + increment, 0.0), 1.0);
  return hslColor.withLightness(newValue).toColor();
}