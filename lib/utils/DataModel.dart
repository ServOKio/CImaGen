import 'package:flutter/material.dart';

class DataModel with ChangeNotifier {
  TimelineBlock timelineBlock = TimelineBlock();
}

class TimelineBlock {
  dynamic firstSelected;
  dynamic secondSelected;

  bool get bothSelected => firstSelected != null && secondSelected != null;

  void changeSelected(int type, dynamic data){
    if(type == 0){
      firstSelected = data;
    } else if(type == 1){
      secondSelected = data;
    }
  }
}