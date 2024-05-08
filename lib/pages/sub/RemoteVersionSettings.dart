import 'package:cimagen/utils/ThemeManager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:settings_ui/settings_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/SQLite.dart';

class RemoteVersionSettings extends StatefulWidget{
  const RemoteVersionSettings({ Key? key }): super(key: key);

  @override
  _RemoteVersionSettingsState createState() => _RemoteVersionSettingsState();
}

class _RemoteVersionSettingsState extends State<RemoteVersionSettings>{
  bool _use_remote_version = false;

  String _sd_remote_webui_folder = '';
  String _sd_remote_webui_outputs_folder = '';

  late SharedPreferences prefs;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  _loadSettings() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {
      _use_remote_version = prefs.getBool('use_remote_version') ?? false;
      _sd_remote_webui_outputs_folder = prefs.getString('sd_remote_webui_outputs_folder') ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('Remote settings'),
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
                    title: const Text('Main'),
                    tiles: <SettingsTile>[
                      SettingsTile.switchTile(
                        leading: Icon(Icons.network_check_rounded, color: Theme.of(context).primaryColor),
                        title: Text('Use the remote version'),
                        description: Text('Specify the IP address to access the WebUI or select a network folder'),
                        onToggle: (v) {
                          setState(() {
                            _use_remote_version = v;
                          });
                          prefs.setBool('use_remote_version', v);
                        },
                        initialValue: _use_remote_version,
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: const Text('WebUI'),
                    tiles: <SettingsTile>[
                      SettingsTile.navigation(
                        leading: Icon(Icons.settings_system_daydream, color: Theme.of(context).primaryColor),
                        title: const Text('Root path'),
                        value: Text('The main folder is where they are .bat files, .json configs and more${_sd_remote_webui_folder.isNotEmpty ? '\n\nNow: '+_sd_remote_webui_folder : ''}'),
                        onPressed: (context) async {
                          String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
                          if (selectedDirectory != null) {
                            prefs.setString('sd_remote_webui_folder', selectedDirectory);
                            setState(() {
                              _sd_remote_webui_folder = selectedDirectory;
                            });
                          }
                        },
                      ),
                      SettingsTile.navigation(
                        leading: Icon(Icons.system_update_tv_rounded, color: Theme.of(context).primaryColor),
                        title: const Text('outputs folder'),
                        value: Text('If you do not have access to the root folder, specify the folder where the images are saved (extras-images, img2img-grids, img2img-images and more)${_sd_remote_webui_outputs_folder.isNotEmpty ? '\n\nNow: '+_sd_remote_webui_outputs_folder : ''}'),
                        onPressed: (context) async {
                          String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
                          if (selectedDirectory != null) {
                            prefs.setString('sd_remote_webui_outputs_folder', selectedDirectory);
                            setState(() {
                              _sd_remote_webui_outputs_folder = selectedDirectory;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            )
        )
    );
  }
}