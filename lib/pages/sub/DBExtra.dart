import 'package:cimagen/utils/ThemeManager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:settings_ui/settings_ui.dart';

import '../../modules/Animations.dart';
import '../../utils/ImageManager.dart';
import '../../utils/SQLite.dart';

class DBExtra extends StatefulWidget{
  const DBExtra({super.key});

  @override
  State<DBExtra> createState() => _DBExtraState();
}

class _DBExtraState extends State<DBExtra>{
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
            title: const ShowUp(
              delay: 100,
              child: Text('DB requests', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600, fontFamily: 'Montserrat')),
            ),
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
                  title: const Text('shit'),
                  tiles: <SettingsTile>[
                    SettingsTile(
                      leading: Icon(Icons.delete),
                      title: const Text('Delete only jpg'),
                      description: const Text('Delete from generation_params where keyup in (select keyup from images where fileTypeExtension = \'jpg\')\nDelete from images where fileTypeExtension = \'jpg\''),
                      onPressed: (context){
                        showDialog<String>(
                          context: context,
                          builder: (BuildContext context) => AlertDialog(
                            icon: const Icon(Icons.warning_amber_outlined),
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
                      leading: Icon(Icons.delete),
                      title: const Text('Delete only img2img'),
                      description: const Text('DELETE FROM images where type = 2\nDELETE FROM generation_params where type = 2'),
                      onPressed: (context){
                        showDialog<String>(
                          context: context,
                          builder: (BuildContext context) => AlertDialog(
                            icon: const Icon(Icons.warning_amber_outlined),
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
                      leading: Icon(Icons.delete),
                      title: const Text('Delete invalid thumbhail'),
                      description: const Text('DELETE FROM images WHERE thumbnail IS NULL'),
                      onPressed: (context){
                        showDialog<String>(
                          context: context,
                          builder: (BuildContext context) => AlertDialog(
                            icon: const Icon(Icons.warning_amber_outlined),
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
                    SettingsTile(
                      leading: const Icon(Icons.delete),
                      title: const Text('Delete network data'),
                      description: const Text('DELETE FROM images WHERE host NOT NULL\nDELETE FROM generation_params  WHERE host NOT NULL'),
                      onPressed: (context){
                        showDialog<String>(
                          context: context,
                          builder: (BuildContext context) => AlertDialog(
                            icon: const Icon(Icons.warning_amber_outlined),
                            title: const Text('Are you sure you want to delete this?'),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () => context.read<SQLite>().rawRun([
                                  'DELETE FROM images WHERE host NOT NULL',
                                  'DELETE FROM generation_params  WHERE host NOT NULL'
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
                      leading: const Icon(Icons.upgrade, color: Colors.yellow),
                      title: const Text('Update db to version 3'),
                      description: const Text('Parse rawData and put result to params column\nSELECT * FROM generation_params WHERE params IS NULL AND rawData IS NOT NULL;\n...\nUPDATE generation_params SET vae = ?, vaeHash = ?, params = ? WHERE keyup = ? and host = ?'),
                      onPressed: (context){
                        showDialog<String>(
                          barrierDismissible: false,
                          context: context,
                          builder: (BuildContext context) => const AlertDialog(
                            icon: Icon(Icons.warning_amber_outlined, color: Colors.orange),
                            title: Text('Don\'t touch anything. As soon as everything is completed, this window will close automatically.'),
                            content: LinearProgressIndicator(),
                          ),
                        );
                        context.read<SQLite>().fixDB().then((value) => Navigator.pop(context, 'ok'));
                      },
                    ),
                    SettingsTile(
                      leading: const Icon(Icons.delete, color: Colors.red),
                      title: const Text('Drop all tables for images'),
                      description: const Text('DROP TABLE images\nDROP TABLE generation_params'),
                      onPressed: (context){
                        showDialog<String>(
                          context: context,
                          builder: (BuildContext context) => AlertDialog(
                            icon: const Icon(Icons.warning_amber_outlined),
                            title: const Text('Are you sure you want to delete this?'),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () => context.read<SQLite>().rawRun([
                                  'DROP TABLE images',
                                  'DROP TABLE generation_params'
                                ]).then((value) => Navigator.pop(context, 'ok')),
                                child: const Text('Okay'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, 'cancel'),
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
                  title: const Text('const'),
                  tiles: [
                    SettingsTile(
                      leading: Icon(Icons.delete),
                      title: const Text('Drop saved_categories table'),
                      description: const Text('DROP TABLE saved_categories'),
                      onPressed: (context){
                        showDialog<String>(
                          context: context,
                          builder: (BuildContext context) => AlertDialog(
                            icon: const Icon(Icons.warning_amber_outlined),
                            title: const Text('Are you sure you want to delete this?'),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () => context.read<SQLite>().rawRunConst([
                                  'DROP TABLE saved_categories'
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
              ],
            ),
          )
        )
    );
  }
}