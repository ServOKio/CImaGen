import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void setBo(key, bool val) {
    //prefs.setBool(key.toString(), val);
    print(val);
    setState(() {
      key = val;
    });
    print(_debug);
  }

  _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _sd_webui_folter = (prefs.getString('sd_webui_folter') ?? 'none');
      _debug = (prefs.getBool('debug') ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
        child: SettingsList(
          shrinkWrap: true,
          platform: DevicePlatform.fuchsia,
          sections: [
            SettingsSection(
              title: Text('Common'),
              tiles: <SettingsTile>[
                SettingsTile.navigation(
                  leading: Icon(Icons.web),
                  title: Text('Stable Diffusion web UI location'),
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
                  onToggle: (value) async {
                    setBo(_debug, value);
                  },
                  initialValue: _debug,
                  leading: Icon(Icons.bug_report),
                  title: Text('Enable debug'),
                ),
              ],
            ),
          ],
        ),
    );
  }
}