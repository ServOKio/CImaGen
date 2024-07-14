import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ShowUp extends StatefulWidget {
  final Widget child;
  final int? delay;

  const ShowUp({super.key, required this.child, this.delay});

  @override
  State<ShowUp> createState() => _ShowUpState();
}

class _ShowUpState extends State<ShowUp> with TickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _animOffset;

  @override
  void initState() {
    super.initState();

    if(mounted){
      _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
      final curve = CurvedAnimation(curve: Curves.decelerate, parent: _animController);
      _animOffset = Tween<Offset>(begin: const Offset(0.0, 0.35), end: Offset.zero).animate(curve);

      if (widget.delay == null) {
        _animController.forward();
      } else {
        Timer(Duration(milliseconds: widget.delay!), () {
          _animController.forward();
        });
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
    _animController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animController,
      child: SlideTransition(
        position: _animOffset,
        child: widget.child,
      ),
    );
  }
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Animation<Offset>>('_animOffset', _animOffset));
  }
}