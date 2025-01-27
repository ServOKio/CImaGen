import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import '../utils/SQLite.dart';

class NotesSection extends StatefulWidget{
  const NotesSection({super.key});

  @override
  State<NotesSection> createState() => _NotesSectionState();
}

class _NotesSectionState extends State<NotesSection> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late FocusNode _titleFocusNode;
  late FocusNode _contentFocusNode;
  int _selectedIndex = -1;
  bool _contentHasChanges = false;
  bool _titleHasChanges = false;

  List<Note> _notes = [];

  @override
  void initState(){
    super.initState();
    _titleController = TextEditingController();
    _contentController = TextEditingController();
    _contentFocusNode = FocusNode();
    _titleFocusNode = FocusNode();
    _titleFocusNode.addListener(() {if(!_titleFocusNode.hasFocus) saveTitle();});
    _contentFocusNode.addListener(() {if(!_contentFocusNode.hasFocus) saveContent();});
    loadNotes();
  }

  void loadNotes() async{
    context.read<SQLite>().getNotes().then((notes){
      setState(() {
        _notes = notes;
      });
    });
  }

  void selectNote(int index) async {
    saveTitle();
    saveContent();
    _titleController.text = _notes[index].title;
    _contentController.text = _notes[index].content;
    setState(() {
      _selectedIndex = index;
    });
  }

  void saveTitle() async {
    if(_titleHasChanges){
      _notes[_selectedIndex].title = _titleController.text;
      await context.read<SQLite>().updateNoteTitle(_notes[_selectedIndex].id, _titleController.text);
      _titleHasChanges = false;
    }
  }

  void saveContent() async {
    if(_contentHasChanges){
      _notes[_selectedIndex].content = _contentController.text;
      await context.read<SQLite>().updateNoteContent(_notes[_selectedIndex].id, _contentController.text);
      _contentHasChanges = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Column(
            children: [
              const Gap(10),
              FloatingActionButton(
                elevation: 0,
                onPressed: () {
                  context.read<SQLite>().createNote().then((note){
                    _notes.add(note);
                    setState(() {
                      _selectedIndex = _notes.length-1;
                    });
                  });
                },
                child: const Icon(Icons.add),
              ),
              const Gap(10),
              Expanded(
                child: ListView.separated(
                  separatorBuilder: (BuildContext context, int index) => const Divider(height: 5),
                  itemCount: _notes.length,
                  itemBuilder: (BuildContext context, int index) {
                    Note element = _notes[index];
                    return GestureDetector(
                      onTap: () => selectNote(index),
                      child: Padding(
                          padding: EdgeInsets.all(7),
                          child: AspectRatio(
                            aspectRatio: 1/1,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Container(
                                padding: EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(color: Theme.of(context).dividerColor, blurRadius: 5)
                                  ]
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(element.icon, color: element.color),
                                    Text(element.title, style: TextStyle(), overflow: TextOverflow.ellipsis, maxLines: 1),
                                  ],
                                ),
                              ),
                            )
                          )
                      ),
                    );
                  },
                ),
              )
            ],
          ),
        ),
        const VerticalDivider(thickness: 1, width: 1),
        Expanded(
          child: _selectedIndex != -1 ? Column(
            children: [
              AppBar(
                title: TextField(
                  controller: _titleController,
                  focusNode: _titleFocusNode,
                  onChanged: (text){
                    if(!_titleHasChanges) _titleHasChanges = true;
                  },
                ),
                actions: <Widget>[
                  IconButton(
                    icon: const Icon(
                      Icons.delete,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      showDialog<String>(
                        context: context,
                        builder: (BuildContext context) => AlertDialog(
                          icon: const Icon(Icons.warning_amber_outlined),
                          title: const Text('Do you really want to delete this note?'),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.pop(context, 'Cancel'),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => context.read<SQLite>().deleteNote(_notes[_selectedIndex].id).then((f){
                                _notes.removeAt(_selectedIndex);
                                setState((){
                                  _selectedIndex = -1;
                                });
                                Navigator.pop(context, 'Ok');
                              }),
                              child: const Text('Okay'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              Expanded(child: Container(
                padding: const EdgeInsets.all(4),
                child: TextField(
                  focusNode: _contentFocusNode,
                  controller: _contentController,
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                  expands: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: null,
                  onChanged: (text){
                    if(!_contentHasChanges) _contentHasChanges = true;
                  },
                ),
              ))
            ],
          ) : const Padding(
            padding: EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sticky_note_2, size: 50, color: Colors.white),
                Gap(4),
                Text('Yeah, that\'s cool...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                Text('Your personal notes - leave as many as you want and write anything', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class Note{
  final int id;
  String title = 'New note';
  String content = '';
  Color color = Colors.indigoAccent;
  IconData icon = Icons.note_alt_outlined;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.color,
    required this.icon
  });
}