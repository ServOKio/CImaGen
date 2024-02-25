import 'package:cimagen/utils/ThemeManager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:settings_ui/settings_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings extends StatefulWidget{
  const Settings({ Key? key }): super(key: key);

  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings>{
  String _sd_webui_folter = '';
  bool _debug = false;

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
    setState(() {
      _sd_webui_folter = (prefs.getString('sd_webui_folter') ?? 'none');
      _debug = (prefs.getBool('debug') ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
        child: SettingsList(
          brightness: context.read<ThemeManager>().isDark ? Brightness.dark : Brightness.light,
          shrinkWrap: true,
          platform: DevicePlatform.fuchsia,
          sections: [
            SettingsSection(
              title: const Text('Common'),
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
          ],
        ),
    );
  }
}