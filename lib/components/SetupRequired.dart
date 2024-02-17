import 'package:flutter/material.dart';

class SetupRequired extends StatelessWidget {
  final bool webui;
  final bool comfyui;

  const SetupRequired({Key? key, required this.webui, required this.comfyui}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: [
          Text('Configuration required'),
          Text('To continue working, you need to configure:'),
          webui ? Text('WebUI folder') : SizedBox.shrink(),
          comfyui ? Text('ComfyUI folder') : SizedBox.shrink(),
        ],
      )
    );
  }
}