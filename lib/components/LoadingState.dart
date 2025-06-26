import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import '../modules/DataManager.dart';

class LoadingState extends StatefulWidget{
  final bool loaded;
  final String? error;

  const LoadingState({
    super.key,
    required this.loaded,
    this.error
  });

  @override
  State<LoadingState> createState() => _LoadingStateState();
}

class _LoadingStateState extends State<LoadingState> with TickerProviderStateMixin{
  late final AnimationController _repeatController;
  late final Animation<double> _animation;

  int test = 0;

  @override
  void initState() {
    super.initState();
    _repeatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(); // set the animation to repeat

    _animation = Tween<double>(begin: 0, end: 1).animate(_repeatController);
  }

  @override
  void dispose(){
    _repeatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            RotationTransition(
              turns: _animation,
              child: const Icon(Icons.settings_outlined, size: 50, color: Colors.white),
            ),
            const Positioned(
              right: -6,
              top: 0,
              child: Icon(Icons.star, size: 13, color: Colors.white),
            ),
            const Positioned(
              right: -6,
              top: 14,
              child: Icon(Icons.star, size: 10, color: Colors.white),
            )
          ],
        ),
        const Gap(4),
        Text(widget.error != null ? 'Oops, there seems to be a error' : 'Configuration required', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        SelectableText(widget.error != null ? widget.error! : 'To continue working, you need to configure:', style: TextStyle(color: Colors.grey)),
        // widget.webui ? const Text('WebUI folder', style: TextStyle(color: Colors.grey)) : const SizedBox.shrink(),
        // widget.comfyui ? const Text('ComfyUI folder') : const SizedBox.shrink(),
        const Gap(7),
        MaterialButton(onPressed: (){
          setState(() {
            test = test + 1;
          });
          print(context.read<DataManager>().error);
        }, child: Text('Retry'))
      ],
    );
  }
}