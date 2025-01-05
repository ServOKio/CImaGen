import 'package:flutter/material.dart';

class CustomActionButton extends StatefulWidget{
  final Function onPress;
  final Function isActive;
  final Function getIcon;
  final String tooltip;

  const CustomActionButton({super.key, required this.onPress, required this.isActive, required this.getIcon, required this.tooltip});

  @override
  State<CustomActionButton> createState() => _CustomActionButtonState();
}

class _CustomActionButtonState extends State<CustomActionButton>{
  IconData icon = Icons.add;
  bool active = false;

  @override
  void initState(){
    active = widget.isActive();
    icon = widget.getIcon();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: active ? Colors.white : Colors.grey[700]),
      tooltip: widget.tooltip,
      onPressed: () {
        widget.onPress();
        setState(() {
          active = widget.isActive();
          icon = widget.getIcon();
        });
      },
    );
  }
}