import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';

import '../main.dart';

class NotesSection extends StatefulWidget {
  const NotesSection({super.key});

  @override
  State<NotesSection> createState() => _SectionState();
}

class _SectionState extends State<NotesSection> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late FocusNode _titleFocusNode;
  late FocusNode _contentFocusNode;
  int _selectedIndex = -1;
  String _searchQuery = '';
  List<Note> _notes = [];
  Timer? _debounceTimer;

  final List<Color> _availableColors = [
    Colors.indigoAccent,
    Colors.redAccent,
    Colors.greenAccent,
    Colors.yellowAccent.shade700,
    Colors.blueAccent,
    Colors.purpleAccent,
    Colors.orangeAccent,
    Colors.tealAccent,
  ];

  final List<IconData> _availableIcons = [
    Icons.note_alt_outlined,
    Icons.star_outline,
    Icons.lightbulb_outline,
    Icons.checklist,
    Icons.music_note,
    Icons.image_outlined,
    Icons.favorite_border,
    Icons.bookmark_border,
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _contentController = TextEditingController();
    _titleFocusNode = FocusNode();
    _contentFocusNode = FocusNode();
    loadNotes();
  }

  void loadNotes() async {
    final notes = await sqLite.getNotes();
    setState(() {
      _notes = notes;
    });
  }

  List<Note> get _filteredNotes {
    if (_searchQuery.isEmpty) return _notes;
    final lowerQuery = _searchQuery.toLowerCase();
    return _notes.where((note) =>
    note.title.toLowerCase().contains(lowerQuery) ||
        note.content.toLowerCase().contains(lowerQuery)).toList();
  }

  void selectNote(int filteredIndex) {
    _saveChanges();
    final note = _filteredNotes[filteredIndex];
    final realIndex = _notes.indexOf(note);
    setState(() {
      _selectedIndex = realIndex;
    });
    _titleController.text = note.title;
    _contentController.text = note.content;
  }

  void _debounceSave(VoidCallback saveFunc) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), saveFunc);
  }

  Future<void> _saveTitle() async {
    if (_selectedIndex == -1) return;
    _notes[_selectedIndex].title = _titleController.text.trim();
    await sqLite.updateNoteTitle(_notes[_selectedIndex].id, _notes[_selectedIndex].title);
  }

  Future<void> _saveContent() async {
    if (_selectedIndex == -1) return;
    _notes[_selectedIndex].content = _contentController.text;
    await sqLite.updateNoteContent(_notes[_selectedIndex].id, _notes[_selectedIndex].content);
  }

  void _saveChanges() {
    _debounceTimer?.cancel();
    _saveTitle();
    _saveContent();
  }

  void _createNewNote() {
    String newTitle = 'New Note';
    Color selectedColor = _availableColors[0];
    IconData selectedIcon = _availableIcons[0];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('New Note', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (val) => newTitle = val.trim().isEmpty ? 'New Note' : val.trim(),
                  ),
                  const SizedBox(height: 24),
                  const Text('Color', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _availableColors.map((color) {
                      final isSelected = color == selectedColor;
                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => setModalState(() => selectedColor = color),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 3)
                                  : Border.all(color: Colors.transparent, width: 3),
                              boxShadow: isSelected
                                  ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 12, spreadRadius: 2)]
                                  : null,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  const Text('Icon', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: _availableIcons.map((icon) {
                      final isSelected = icon == selectedIcon;
                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => setModalState(() => selectedIcon = icon),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected ? selectedColor.withOpacity(0.15) : null,
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected
                                  ? Border.all(color: selectedColor, width: 2)
                                  : null,
                            ),
                            child: Icon(icon, size: 32, color: isSelected ? selectedColor : Colors.grey[700]),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () async {
                        final note = await sqLite.createNote(
                          title: newTitle,
                          color: selectedColor,
                          icon: selectedIcon,
                        );
                        setState(() {
                          _notes.add(note);
                          _selectedIndex = _notes.length - 1;
                          _titleController.text = note.title;
                          _contentController.text = '';
                        });
                        Navigator.pop(context);
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      ),
                      child: const Text('Create Note'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _updateColor(Color newColor) async {
    if (_selectedIndex == -1) return;
    setState(() {
      _notes[_selectedIndex].color = newColor;
    });
    await sqLite.updateNoteColor(_notes[_selectedIndex].id, newColor);
  }

  void _updateIcon(IconData newIcon) async {
    if (_selectedIndex == -1) return;
    setState(() {
      _notes[_selectedIndex].icon = newIcon;
    });
    await sqLite.updateNoteIcon(_notes[_selectedIndex].id, newIcon);
  }

  void _deleteNote() {
    if (_selectedIndex == -1) return;
    final deletedNote = _notes[_selectedIndex];
    final deletedIndex = _selectedIndex;
    setState(() {
      _notes.removeAt(_selectedIndex);
      _selectedIndex = -1;
    });
    sqLite.deleteNote(deletedNote.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Note deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              _notes.insert(deletedIndex, deletedNote);
              _selectedIndex = deletedIndex;
            });
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredNotes;

    return Row(
      children: [
        Container(
          width: 280,
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search notes…',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (q) => setState(() => _searchQuery = q),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: FilledButton.icon(
                  onPressed: _createNewNote,
                  icon: const Icon(Icons.add),
                  label: const Text('New Note'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final note = filtered[i];
                    final isSelected = _notes.indexOf(note) == _selectedIndex;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      elevation: isSelected ? 4 : 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
                      child: ListTile(
                        leading: Icon(note.icon, color: note.color, size: 28),
                        title: Text(
                          note.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: isSelected ? FontWeight.bold : null),
                        ),
                        subtitle: Text(
                          note.content.isEmpty ? 'No content' : note.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => selectNote(i),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: _selectedIndex == -1
              ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                    child: Lottie.asset(
                      'assets/icons/lottie/archive-book-two.json',
                      width: 120,
                      height: 120,
                      fit: BoxFit.fill,
                    )
                ),
                const SizedBox(height: 24),
                const Text(
                  "No note selected",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  "Create a new note or select one from the list",
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          )
              : Column(
            children: [
              AppBar(
                title: TextField(
                  controller: _titleController,
                  focusNode: _titleFocusNode,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Note title…',
                  ),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  onChanged: (_) => _debounceSave(_saveTitle),
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.palette_outlined, color: _notes[_selectedIndex].color),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => SimpleDialog(
                          title: const Text('Choose color'),
                          children: _availableColors.map((c) => SimpleDialogOption(
                            onPressed: () {
                              _updateColor(c);
                              Navigator.pop(ctx);
                            },
                            child: Row(
                              children: [
                                CircleAvatar(backgroundColor: c, radius: 16),
                                const SizedBox(width: 16),
                                Text(c.toString().split('(0x')[0]),
                              ],
                            ),
                          )).toList(),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(_notes[_selectedIndex].icon),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => SimpleDialog(
                          title: const Text('Choose icon'),
                          children: _availableIcons.map((ic) => SimpleDialogOption(
                            onPressed: () {
                              _updateIcon(ic);
                              Navigator.pop(ctx);
                            },
                            child: Icon(ic, color: _notes[_selectedIndex].color),
                          )).toList(),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _deleteNote,
                  ),
                ],
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: _contentController,
                          focusNode: _contentFocusNode,
                          maxLines: null,
                          expands: true,
                          decoration: const InputDecoration(
                            hintText: 'Start writing...',
                            border: InputBorder.none,
                          ),
                          onChanged: (text) {
                            _debounceSave(_saveContent);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Updated Note class (if needed)
class Note {
  final int id;
  String title;
  String content;
  Color color;
  IconData icon;

  Note({
    required this.id,
    required this.title,
    this.content = '',
    required this.color,
    required this.icon,
  });
}