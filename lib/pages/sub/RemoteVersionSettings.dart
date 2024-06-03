import 'dart:convert';

import 'package:cimagen/utils/ImageManager.dart';
import 'package:cimagen/utils/ThemeManager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class RemoteVersionSettings extends StatefulWidget{
  const RemoteVersionSettings({ Key? key }): super(key: key);

  @override
  _RemoteVersionSettingsState createState() => _RemoteVersionSettingsState();
}

class _RemoteVersionSettingsState extends State<RemoteVersionSettings>{
  bool _use_remote_version = false;

  String _sd_remote_webui_folder = '';
  String _sd_remote_webui_outputs_folder = '';

  String _sd_remote_webui_address = '';

  // temp
  String remoteInfo = '';
  bool _has_infinite_image_browsing_extension = false;
  bool _has_connection = false;
  bool _has_200_code = false;

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

      _sd_remote_webui_address = prefs.getString('sd_remote_webui_address') ?? '';
    });
    if(_use_remote_version && _sd_remote_webui_address.isNotEmpty) checkRemoteStatus();
  }

  void checkRemoteStatus(){
    setState(() {
      remoteInfo = 'Checking...';
      _has_connection = false;
      _has_infinite_image_browsing_extension = false;
      _has_200_code = false;
    });

    Uri parse = Uri.parse(_sd_remote_webui_address);

    //TODO: Ping sosat with port
    // Uri pingUri = Uri(
    //     host: parse.host
    // );
    // print(pingUri.toString().replaceFirst('//', ''));
    // final ping = Ping(pingUri.toString().replaceFirst('//', ''), count: 10);
    //
    // // Begin ping process and listen for output
    // ping.stream.listen((event) {
    //   print(event);
    // });

    Uri base = Uri(
        scheme: parse.scheme,
        host: parse.host,
        port: parse.port,
        path: '/internal/sysinfo',
        queryParameters: {'attachment': 'false'}
    );
    http.Client().get(base).timeout(const Duration(seconds: 5)).then((res) async {
      _has_connection = true;
      if(res.statusCode == 200){
        //print(res.body);
        _has_200_code = true;
        var data = await json.decode(res.body);
        var exNames = data['Extensions'].map((ex) => ex['name'] as String).toList();
        _has_infinite_image_browsing_extension = exNames.contains('sd-webui-infinite-image-browsing');
        String fin = 'System\nPlatform: ${data['Platform']}\n'
            'Python: ${data['Python']}\n'
            'Torch version: ${data['Torch env info']['torch_version']}\n'
            'Cuda compiled version: ${data['Torch env info']['cuda_compiled_version']}\n'
            'CMake version: ${data['Torch env info']['cmake_version']}\n'
            'Nvidia gpu models: ${data['Torch env info']['nvidia_gpu_models']}\n'
            'CPU:\n   ${data['Torch env info']['cpu_info'].join('\n   ')}\n'
            'RAM: ${data['RAM']['total']}\n'
            '\nSD\n'
            'Version: ${data['Version']}\n'
            'Environment commandline args: ${data['Environment']['COMMANDLINE_ARGS']}\n';
        setState(() {
          remoteInfo = fin;
        });
      } else {
        setState(() {
          remoteInfo = 'Error: Code is not 200';
        });
      }
    }).catchError((e){
      setState(() {
        remoteInfo = 'Error: $e';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    bool allOkay = _has_infinite_image_browsing_extension && _has_connection && _has_200_code;
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
                        enabled: _sd_remote_webui_address.isNotEmpty,
                        leading: Icon(Icons.network_check_rounded),
                        title: Text('Use the remote version'),
                        description: Text('${_sd_remote_webui_address.isNotEmpty ? '✓' : '✗'} - Specify the address of the panel'),
                        onToggle: (v) {
                          setState(() {
                            _use_remote_version = v;
                          });
                          prefs.setBool('use_remote_version', v);
                          context.read<ImageManager>().changeGetter(v ? 1 : 0);
                        },
                        initialValue: _use_remote_version,
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: const Text('WebUI'),
                    tiles: <SettingsTile>[
                      SettingsTile.navigation(
                        leading: Icon(Icons.settings_system_daydream),
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
                        leading: Icon(Icons.system_update_tv_rounded),
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
                  SettingsSection(
                    title: const Text('WebUI via IP:port'),
                    tiles: <SettingsTile>[
                      SettingsTile(
                        leading: Icon(allOkay ? Icons.check : Icons.error_outline, color: allOkay ? Colors.greenAccent : Colors.redAccent),
                        title: Text(allOkay ? 'All okay' : 'There are problems'),
                        description: Text('${_has_connection ? '✓' : '✗'} - have a connection\n'
                            '${_has_200_code ? '✓' : '✗'} - the host returned the correct answer'
                            '${_has_200_code ? '\n${_has_infinite_image_browsing_extension ? '✓' : '✗'} - sd-webui-infinite-image-browsing extension\n' : ''}'
                        ),
                      ),
                      SettingsTile.navigation(
                        leading: Icon(Icons.web),
                        title: const Text('Web panel address'),
                        value: Text('The address that you use in the browser, for example: http://192.168.1.5:7860${_sd_remote_webui_address.isNotEmpty ? '\n\nNow: '+_sd_remote_webui_address : ''}'),
                        onPressed: (context) async {
                          var addressController = TextEditingController();
                          addressController.text = _sd_remote_webui_address;
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
                                          if(text != null && text.isNotEmpty){
                                            if(!Uri.parse(text.trim()).host.isNotEmpty){
                                              return 'This is not a link';
                                            }
                                          }
                                          return null;
                                        },
                                        decoration: const InputDecoration(
                                          hintStyle: TextStyle(color: Colors.grey),
                                          hintText: 'http://192.168.1.5:7860',
                                          labelText: 'Address *',
                                        ),
                                      ),
                                      const Gap(12),
                                      ElevatedButton(
                                        child: const Text('Change'),
                                        onPressed: () {
                                          if (_formKey.currentState!.validate()) {
                                            String f = addressController.text.trim();
                                            prefs.setString('sd_remote_webui_address', f);
                                            setState(() {
                                              _sd_remote_webui_address = f;
                                            });
                                            checkRemoteStatus();
                                            Navigator.pop(context, 'Ok');
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
                    ],
                  ),
                  SettingsSection(
                    title: const Text('Utils'),
                    tiles: <SettingsTile>[
                      SettingsTile.navigation(
                        leading: Icon(Icons.checklist),
                        title: const Text('Check the status'),
                        value: Text(remoteInfo.isNotEmpty ? remoteInfo : 'Get information about the remote interface'),
                        onPressed: (context) async {
                          checkRemoteStatus();
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