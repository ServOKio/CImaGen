import 'package:flutter/material.dart';

class NotesSection extends StatefulWidget{
  const NotesSection({ Key? key }): super(key: key);

  @override
  _NotesSectionState createState() => _NotesSectionState();
}

class _NotesSectionState extends State<NotesSection> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        NavigationRail(
          labelType: NavigationRailLabelType.all,
          selectedIndex: _selectedIndex,
          onDestinationSelected: (int index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          leading: FloatingActionButton(
            elevation: 0,
            onPressed: () {
            },
            child: const Icon(Icons.add),
          ),
          destinations: const <NavigationRailDestination>[
            NavigationRailDestination(
              icon: Icon(Icons.favorite_border),
              selectedIcon: Icon(Icons.favorite),
              label: Text('First'),
            ),
            NavigationRailDestination(
              icon: Badge(child: Icon(Icons.bookmark_border)),
              selectedIcon: Badge(child: Icon(Icons.book)),
              label: Text('Second'),
            ),
            NavigationRailDestination(
              icon: Badge(
                label: Text('4'),
                child: Icon(Icons.star_border),
              ),
              selectedIcon: Badge(
                label: Text('4'),
                child: Icon(Icons.star),
              ),
              label: Text('Third'),
            ),
          ],
        ),
        const VerticalDivider(thickness: 1, width: 1),
        Expanded(
          child: TextField(
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: null,
          ),
        ),
      ],
    );
  }
}