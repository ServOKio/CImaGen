import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

class CustomMasonryView extends StatelessWidget {
  final List<dynamic> listOfItem;
  final int numberOfColumn;
  final double itemPadding;
  final double itemRadius;
  final Widget Function(IndexedItem) itemBuilder;

  const CustomMasonryView({
    Key? key,
    required this.listOfItem,
    required this.numberOfColumn,
    this.itemPadding = 8.0,
    this.itemRadius = 10,
    required this.itemBuilder,
  }) : super(key: key);

  List<dynamic> _items(int start) {
    List<dynamic> items = [];
    for (var i = start; i < listOfItem.length; i = i + numberOfColumn) {
      dynamic item = listOfItem.elementAt(i);
      items.add(IndexedItem(index: i, item: item));
    }
    return items;
  }

  List<Widget> _columns() {
    List<Widget> column = [];
    for (var i = 0; i < numberOfColumn; i++) {
      column.add(_column(_items(i)));
    }
    return column;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _columns(),
    );
  }

  Widget _column(List<dynamic> items) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: items.map((item) {
          return Padding(
            padding: EdgeInsets.all(itemPadding),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(itemRadius),
              child: itemBuilder(item),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class IndexedItem {
  final int index;
  final dynamic item;

  IndexedItem({
    required this.index,
    required this.item
  });
}