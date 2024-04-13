import 'dart:io';

import 'package:cimagen/pages/sub/GitHubCommits.dart';
import 'package:cimagen/utils/ThemeManager.dart';
import 'package:external_path/external_path.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pie_chart/pie_chart.dart';
import 'package:provider/provider.dart';

import 'package:settings_ui/settings_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/SQLite.dart';

class DBExtra extends StatefulWidget{
  const DBExtra({ Key? key }): super(key: key);

  @override
  _DBExtraState createState() => _DBExtraState();
}

class _DBExtraState extends State<DBExtra>{
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
            title: const Text('db requests'),
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
                  title: Text('main.images'),
                  tiles: <SettingsTile>[
                    SettingsTile(
                      leading: Icon(Icons.delete, color: Theme.of(context).primaryColor),
                      title: Text('Delete only jpg'),
                      description: Text('Delete from generation_params where keyup in (select keyup from images where fileTypeExtension = \'jpg\')\nDelete from images where fileTypeExtension = \'jpg\''),
                      onPressed: (context){
                        showDialog<String>(
                          context: context,
                          builder: (BuildContext context) => AlertDialog(
                            icon: Icon(Icons.warning_amber_outlined),
                            title: const Text('Are you sure you want to delete this?'),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () => context.read<SQLite>().rawRun([
                                  'Delete from generation_params where keyup in (select keyup from images where fileTypeExtension = \'jpg\')',
                                  'Delete from images where fileTypeExtension = \'jpg\''
                                ]).then((value) => Navigator.pop(context, 'Ok')),
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
                      leading: Icon(Icons.delete, color: Theme.of(context).primaryColor),
                      title: Text('Delete only img2img'),
                      description: Text('DELETE FROM images where type = 2\nDELETE FROM generation_params where type = 2'),
                      onPressed: (context){
                        showDialog<String>(
                          context: context,
                          builder: (BuildContext context) => AlertDialog(
                            icon: Icon(Icons.warning_amber_outlined),
                            title: const Text('Are you sure you want to delete this?'),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () => context.read<SQLite>().rawRun([
                                  'DELETE FROM images where type = 2',
                                  'DELETE FROM generation_params where type = 2'
                                ]).then((value) => Navigator.pop(context, 'Ok')),
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
                      leading: Icon(Icons.delete, color: Theme.of(context).primaryColor),
                      title: Text('Delete invalid thumbhail'),
                      description: Text('DELETE FROM images WHERE thumbnail IS NULL'),
                      onPressed: (context){
                        showDialog<String>(
                          context: context,
                          builder: (BuildContext context) => AlertDialog(
                            icon: Icon(Icons.warning_amber_outlined),
                            title: const Text('Are you sure you want to delete this?'),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () => context.read<SQLite>().rawRun([
                                  'DELETE FROM images WHERE thumbnail IS NULL'
                                ]).then((value) => Navigator.pop(context, 'Ok')),
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
                  ],
                ),
                SettingsSection(
                  title: const Text('main.generation_params'),
                  tiles: [

                  ],
                ),
              ],
            ),
          )
        )
    );
  }
}