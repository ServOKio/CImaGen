import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../modules/DataManager.dart';

class TagSearcher extends StatefulWidget{

  const TagSearcher({ super.key });

  @override
  State<TagSearcher> createState() => _TagSearcherState();
}

class _TagSearcherState extends State<TagSearcher> {

  bool loaded = false;

  @override
  void initState(){
    super.initState();
  }

  Future<void> analyze() async {
    setState(() {
      loaded = false;
    });

    var _tags = context.read<DataManager>().e621Tags;

    setState(() {
      loaded = true;

    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: <Widget>[
        SliverAppBar(
          title: Text("Title"),
          snap: true,
          floating: true,
        ),
        SliverFixedExtentList(
          itemExtent: 50.0,
          delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
              return new Container(
                alignment: Alignment.center,
                color: Colors.lightBlue[100 * (index % 9)],
                child: new Text('list item $index'),
              );
            },
          ),
        ),
      ],
    );
  }
}