import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'SQLite.dart';

class SaveManager extends ChangeNotifier {
  Map<int, Category> categories = {};

  void addCategory(Category category){
    categories[category.id] = category;
    notifyListeners();
  }

  void removeCategory(int id){
    categories.remove(id);
    notifyListeners();
  }

  Future<void> init(BuildContext context) async {
    context.read<SQLite>().getCategories().then((v){
      for (var element in v) {categories[element.id] = element;}
    });
  }
}

class Category {
  // 'id INTEGER PRIMARY KEY AUTOINCREMENT,'
  // 'title VARCHAR(256),'
  // 'description TEXT,'
  // 'color VARCHAR(16),'
  // 'icon VARCHAR(128),'
  // 'thumbnail TEXT'

  final int id;
  String title;
  String? description = '';
  Color? color = Colors.redAccent;
  IconData? icon = Icons.category;
  Image? thumbnail;

  Category({
    required this.id,
    required this.title,
    this.description,
    this.color,
    this.icon,
    this.thumbnail
  });
}