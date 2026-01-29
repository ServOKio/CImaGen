
import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';

class SimpleWindowBar extends StatelessWidget implements PreferredSizeWidget {

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Window menu
          Positioned(
              top: 0,
              child: Container(
                // color: const Color(0xff0c0c0e),
                  height: 32, width: MediaQuery.of(context).size.width,
                  child: MoveWindow()
              )
          ),
          Positioned(
              top: 0,
              left: Platform.isMacOS ? 0 : null,
              right: !Platform.isMacOS ? 0 : null,
              child: Row(children: Platform.isMacOS ? [
                CloseWindowButton(),
                MinimizeWindowButton(),
                MaximizeWindowButton()
              ] : [
                MinimizeWindowButton(colors: WindowButtonColors(iconNormal: Theme.of(context).colorScheme.primary)),
                MaximizeWindowButton(colors: WindowButtonColors(iconNormal: Theme.of(context).colorScheme.primary)),
                CloseWindowButton(colors: WindowButtonColors(iconNormal: Theme.of(context).colorScheme.primary))
              ]
            )
          )
        ],
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(32.0);
}