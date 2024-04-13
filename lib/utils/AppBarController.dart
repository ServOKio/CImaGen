import 'package:flutter/material.dart';

class AppBarController with ChangeNotifier{
  List<Widget> _actions = [];

  List<Widget> get actions => _actions;

  void setActions(List<Widget> actions) {
    _actions = actions;
    notifyListeners();
  }

  void resetActions(){
    _actions.clear();
    notifyListeners();
  }
}