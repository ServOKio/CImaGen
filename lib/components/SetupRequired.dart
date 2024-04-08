import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class SetupRequired extends StatelessWidget {
  final bool webui;
  final bool comfyui;

  const SetupRequired({Key? key, required this.webui, required this.comfyui}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.settings_suggest_outlined, size: 50, color: Colors.white),
          const Gap(4),
          const Text('Configuration required', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const Text('To continue working, you need to configure:', style: TextStyle(color: Colors.grey)),
          webui ? const Text('WebUI folder', style: TextStyle(color: Colors.grey)) : const SizedBox.shrink(),
          comfyui ? const Text('ComfyUI folder') : const SizedBox.shrink(),
        ],
      )
    );
  }
}