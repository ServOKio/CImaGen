import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AnimatedText extends StatefulWidget {
  const AnimatedText(
      this.text, {
        super.key,
        this.style,
        this.textAlign,
        this.duration = const Duration(milliseconds: 420),
        this.curve = Curves.easeInOutCubicEmphasized,
        this.slideDistance = 32.0,
        this.useMonospaceDuringTransition = true,
      });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final Duration duration;
  final Curve curve;
  final double slideDistance;
  final bool useMonospaceDuringTransition;

  @override
  State<AnimatedText> createState() => _AnimatedTextState();
}

class _AnimatedTextState extends State<AnimatedText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String _currentText = '';
  String _previousText = '';

  @override
  void initState() {
    super.initState();
    _currentText = widget.text;
    _previousText = widget.text;

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
  }

  @override
  void didUpdateWidget(covariant AnimatedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      setState(() {
        _previousText = oldWidget.text;
        _currentText = widget.text;
      });
      _controller
        ..value = 0.0
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  TextStyle _getEffectiveStyle(bool isTransitioning) {
    final base = widget.style ?? Theme.of(context).textTheme.bodyMedium!;
    if (!widget.useMonospaceDuringTransition || !isTransitioning) {
      return base;
    }
    return base.copyWith(
      fontFamily: 'Roboto Mono'
      // letterSpacing: 0.5,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAnimating = _controller.isAnimating;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = widget.curve.transform(_controller.value);
        final style = _getEffectiveStyle(isAnimating);

        return IntrinsicWidth(
          child: Stack(
            alignment: Alignment.centerLeft,
            textDirection: TextDirection.ltr,
            children: [
              Opacity(
                opacity: 1.0 - t,
                child: Transform.translate(
                  offset: Offset(0, t * widget.slideDistance),
                  child: Text(
                    _previousText,
                    style: style,
                    textAlign: widget.textAlign,
                    softWrap: true,
                    maxLines: null,
                  ),
                ),
              ),

              Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, -widget.slideDistance * (1 - t)),
                  child: Text(
                    _currentText,
                    style: style,
                    textAlign: widget.textAlign,
                    softWrap: true,
                    maxLines: null,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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