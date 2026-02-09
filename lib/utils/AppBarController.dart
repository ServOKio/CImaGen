import 'package:flutter/material.dart';

class AppBarController with ChangeNotifier{
  List<Widget> _actions = [];
  Widget _windowBar = SizedBox.shrink();

  List<Widget> get actions => _actions;
  Widget get windowBar => _windowBar;

  void setActions(List<Widget> actions) {
    _actions = actions;
    notifyListeners();
  }

  void setWindowBar(Widget widget){
    _windowBar = widget;
    notifyListeners();
  }

  void resetActions(){
    _actions.clear();
    notifyListeners();
  }

  void resetWindowBar(){
    _windowBar = SizedBox.shrink();
    notifyListeners();
  }
}