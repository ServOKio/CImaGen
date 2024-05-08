import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class SetupRequired extends StatefulWidget{
  final bool webui;
  final bool comfyui;

  const SetupRequired({Key? key, required this.webui, required this.comfyui}) : super(key: key);

  @override
  State<SetupRequired> createState() => _SetupRequiredState();
}

class _SetupRequiredState extends State<SetupRequired> with TickerProviderStateMixin{
  late final AnimationController _repeatController;
  late final Animation<double> _animation;

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
        const Text('Configuration required', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const Text('To continue working, you need to configure:', style: TextStyle(color: Colors.grey)),
        widget.webui ? const Text('WebUI folder', style: TextStyle(color: Colors.grey)) : const SizedBox.shrink(),
        widget.comfyui ? const Text('ComfyUI folder') : const SizedBox.shrink(),
      ],
    );
  }
}