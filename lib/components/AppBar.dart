import 'package:flutter/material.dart';

class CAppBar extends StatefulWidget implements PreferredSizeWidget {
  CAppBar({ Key? key }) : preferredSize = const Size.fromHeight(kToolbarHeight), super(key: key);

  @override
  final Size preferredSize;

  @override
  _CustomAppBarState createState() => _CustomAppBarState();
}

class _CustomAppBarState extends State<CAppBar>{
  final debug = true;

  @override
  Widget build(BuildContext context) {
    return debug ? Padding(
        padding: const EdgeInsets.all(6),
        child: AppBar(
            surfaceTintColor: Colors.transparent,
            title: const Text('Hello'),
            centerTitle: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(9)),
          ),
        ),
    ) : Container(
      height: 56,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xff262626),
        borderRadius: const BorderRadius.all(Radius.circular(9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff262626).withOpacity(0.3),
            offset: const Offset(0, 20),
            blurRadius: 20
          )
        ]
      ),
      child: Center(
        child: Text('Hello'),
      ),
    );
  }
}