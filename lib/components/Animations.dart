import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AnimatedLetter extends StatefulWidget {
  const AnimatedLetter({super.key, this.letter});

  final String? letter;

  @override
  State<AnimatedLetter> createState() => _AnimatedLetterState();
}

class _AnimatedLetterState extends State<AnimatedLetter>
    with SingleTickerProviderStateMixin {
  AnimationController? controller;

  String? currentLetter;
  String? prevLetter;

  @override
  void initState() {
    controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    currentLetter = widget.letter;
    prevLetter = widget.letter;
    super.initState();
  }

  @override
  void didUpdateWidget(AnimatedLetter oldWidget) {
    if (widget.letter != oldWidget.letter) {
      setState(() {
        prevLetter = oldWidget.letter;
        currentLetter = widget.letter;
        controller!..reset()..forward();
      });
    }

    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    const TextStyle style = TextStyle(fontSize: 42, fontWeight: FontWeight.w600, fontFamily: 'Montserrat');
    return AnimatedBuilder(
        animation: controller!,
        builder: (_, __) {
          return Stack(
            alignment: Alignment.centerRight,
            children: [
              Transform.translate(
                offset: Offset(0, controller!.value * 20),
                child: Opacity(
                  opacity: 1 - controller!.value,
                  child: Text(
                    prevLetter!,
                    style: style,
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(0, -20 + controller!.value * 20),
                child: Opacity(
                  opacity: controller!.value,
                  child: Text(
                    currentLetter!,
                    style: style,
                  ),
                ),
              ),
            ],
          );
        });
  }
}

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
    _animController.dispose();
    super.dispose();
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