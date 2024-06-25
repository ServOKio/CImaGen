import 'package:flutter/material.dart';

class CustomActionButton extends StatefulWidget{
  final IconData icon;
  final Function onPress;
  final Function getter;
  final String tooltip;

  const CustomActionButton({super.key, required this.icon, required this.onPress, required this.getter, required this.tooltip});

  @override
  State<CustomActionButton> createState() => _CustomActionButtonState();
}

class _CustomActionButtonState extends State<CustomActionButton>{
  bool active = false;

  @override
  void initState(){
    active = widget.getter();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(widget.icon, color: active ? Colors.white : Colors.grey[700]),
      tooltip: widget.tooltip,
      onPressed: () {
        widget.onPress();
        setState(() {
          active = widget.getter();
        });
      },
    );
  }
}