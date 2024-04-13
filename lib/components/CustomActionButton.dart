import 'package:flutter/material.dart';

class CustomActionButton extends StatefulWidget{
  final IconData icon;
  final Function onPress;
  final Function getter;
  final String tooltip;

  const CustomActionButton({super.key, required this.icon, required this.onPress, required this.getter, required this.tooltip});

  @override
  _CustomActionButtonState createState() => _CustomActionButtonState();
}

class _CustomActionButtonState extends State<CustomActionButton>{
  bool active = false;

  @override
  void initState(){
    //blyat
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(widget.icon, color: active ? Colors.white : Colors.grey),
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