import 'dart:io';

import 'package:cimagen/utils/ThemeManager.dart';
import 'package:external_path/external_path.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'package:settings_ui/settings_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/SQLite.dart';

class Settings extends StatefulWidget{
  const Settings({ Key? key }): super(key: key);

  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings>{
  String _sd_webui_folter = '';
  bool _debug = false;

  String appDocumentsPath = '';
  String appTempPath = '';
  String? documentsPath = '';

  late SharedPreferences prefs;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // void setBo(key, bool val) {
  //   prefs.setBool(key.toString(), val);
  // }

  _loadSettings() async {
    prefs = await SharedPreferences.getInstance();
    Directory appDocumentsDir = await getApplicationDocumentsDirectory();
    Directory appTempDir = await getTemporaryDirectory();
    if(Platform.isAndroid){
      documentsPath = await ExternalPath.getExternalStoragePublicDirectory(ExternalPath.DIRECTORY_DOCUMENTS);
    }

    setState(() {
      _sd_webui_folter = (prefs.getString('sd_webui_folter') ?? 'none');
      _debug = (prefs.getBool('debug') ?? false);
      appDocumentsPath = appDocumentsDir.absolute.path;
      appTempPath = appTempDir.absolute.path;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
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
              title: Text('Common'),
              tiles: <SettingsTile>[
                SettingsTile.navigation(
                  leading: Icon(Icons.web, color: Theme.of(context).primaryColor),
                  title: const Text('Stable Diffusion web UI location'),
                  value: Text(_sd_webui_folter),
                  onPressed: (context) async {
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

                    if (selectedDirectory != null) {
                      prefs.setString('sd_webui_folter', selectedDirectory);
                      setState(() {
                        _sd_webui_folter = selectedDirectory;
                      });
                    }
                  },
                ),
                SettingsTile.switchTile(
                  onToggle: (v) {
                    setState(() {
                      _debug = v;
                    });
                    prefs.setBool('debug', v);
                  },
                  leading: Icon(Icons.bug_report, color: Theme.of(context).primaryColor),
                  title: Text('Enable debug'), initialValue: _debug,
                ),
              ],
            ),
            SettingsSection(
              title: const Text('Database'),
              tiles: <SettingsTile>[
                SettingsTile(
                  leading: Icon(Icons.delete, color: Theme.of(context).primaryColor),
                  title: Text('Clear image database'),
                  description: Text('Previews, image data. The list of favorites will remain untouched'),
                  onPressed: (context){
                    showDialog<String>(
                        context: context,
                        builder: (BuildContext context) => AlertDialog(
                          icon: Icon(Icons.warning_amber_outlined),
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
                )
              ],
            ),
            SettingsSection(
              title: const Text('Device info'),
              tiles: <SettingsTile>[
                SettingsTile(
                  leading: Icon(Platform.isAndroid ? Icons.phone_android : Icons.desktop_windows , color: Theme.of(context).primaryColor),
                  title: const Text('Device'),
                  description: Text('${123}'),
                ),
                SettingsTile(
                  leading: Icon(Icons.folder , color: Theme.of(context).primaryColor),
                  title: const Text('Paths'),
                  description: Text(''
                      'App Documents\n↳ $appDocumentsPath\n'
                      'App Temp\n↳ $appTempPath\n'
                      'Documents\n↳ $documentsPath\n'),
                )
              ],
            ),
          ],
        ),
    );
  }
}