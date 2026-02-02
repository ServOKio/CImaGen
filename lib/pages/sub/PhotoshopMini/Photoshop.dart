import 'dart:async';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';

class PhotoshopMini extends StatefulWidget{
  dynamic fileData;
  PhotoshopMini({ super.key, this.fileData});

  @override
  State<PhotoshopMini> createState() => _PhotoshopMiniState();
}

class _PhotoshopMiniState extends State<PhotoshopMini> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        extendBodyBehindAppBar: true,
        body: Theme(
            data: ThemeData.dark().copyWith(
              scaffoldBackgroundColor: const Color(0xFF1D1D1D), // workspace gray
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blueGrey,
                brightness: Brightness.dark,
                primary: const Color(0xFF90CAF9),
                surface: const Color(0xFF2B2B2B),
                surfaceContainerHighest: const Color(0xFF333333),
              ),
              dividerColor: const Color(0xFF444444),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF252526), // almost black
                foregroundColor: Colors.white70,
                elevation: 0,
                toolbarHeight: 32,
              ),
            ),
            child: Column(
              children: [
                Container(
                  height: 32,
                  color: const Color(0xFF252526),
                  child: WindowTitleBarBox(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(width: 8),
                        const Icon(Icons.image, color: Colors.white70, size: 16),
                        const SizedBox(width: 8),

                        Expanded(
                          child: MoveWindow(
                            child: Row(
                              children: [
                                const Text(
                                  'Без имени-1 @ 52.9% (Слой 1, RGB/8*)',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 48),

                                // ── Real Photoshop-style menu items ───────────────────────────────
                                _PsMenuItem(
                                  title: 'Файл',
                                  items: [
                                    _PsMenuEntry('Создать...', shortcut: 'Ctrl+N'),
                                    _PsMenuEntry('Открыть...', shortcut: 'Ctrl+O'),
                                    _PsMenuEntry('Обзор в Bridge...', shortcut: 'Alt+Ctrl+O'),
                                    _PsMenuEntry('Открыть как...', shortcut: 'Alt+Shift+Ctrl+O'),
                                    _PsMenuEntry('Открыть как смарт-объект...'),
                                    const _PsMenuDivider(),
                                    _PsMenuEntry('Последние документы', hasSubmenu: true),
                                    const _PsMenuDivider(),
                                    _PsMenuEntry('Закрыть'),
                                    _PsMenuEntry('Закрыть все', shortcut: 'Alt+Ctrl+W'),
                                    // ... add the rest from your list
                                    const _PsMenuDivider(),
                                    _PsMenuEntry('Выход', shortcut: 'Ctrl+Q'),
                                  ],
                                ),

                                _PsMenuItem(title: 'Редактирование'),
                                _PsMenuItem(title: 'Изображение'),
                                _PsMenuItem(title: 'Слои'),
                                _PsMenuItem(title: 'Текст'),
                                // Add more: Select, Filter, etc.
                              ],
                            ),
                          ),
                        ),

                        const WindowButtons(),
                      ],
                    ),
                  ),
                ),

                Container(
                  height: 48,
                  color: const Color(0xFF333333),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Text("Инструмент: Кисть", style: TextStyle(color: Colors.white70)),
                      const Spacer(),
                      _OptionChip("Режим: Нормальный"),
                      _OptionChip("Непрозр.: 100%"),
                      _OptionChip("Нажатие: 100%"),
                      _OptionChip("Сглаживание: 26%"),
                    ],
                  ),
                ),

                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        color: const Color(0xFF2B2B2B),
                        child: Column(
                          children: List.generate(20, (i) => _ToolIcon(i)),
                        ),
                      ),

                      // Central canvas area
                      Expanded(
                        child: Container(
                          color: const Color(0xFF1E1E1E), // dark workspace
                          child: Stack(
                            children: [
                              // Checkerboard background
                              // Container(
                              //   decoration: const BoxDecoration(
                              //     image: DecorationImage(
                              //       image: AssetImage('assets/checkerboard.png'), // you need to add 32×32 checker png
                              //       repeat: ImageRepeat.repeat,
                              //     ),
                              //   ),
                              // ),
                              const Center(
                                child: Text(
                                  "holst",
                                  style: TextStyle(color: Colors.white24, fontSize: 48),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(
                        width: 320,
                        child: Column(
                          children: [
                            Expanded(
                              child: DefaultTabController(
                                length: 3,
                                child: Column(
                                  children: [
                                    TabBar(
                                      tabs: const [
                                        Tab(text: "Слои"),
                                        Tab(text: "Свойства"),
                                        Tab(text: "Библиотеки"),
                                      ],
                                      labelColor: Colors.white,
                                      unselectedLabelColor: Colors.white54,
                                      indicatorColor: Colors.blueAccent,
                                    ),
                                    Expanded(
                                      child: TabBarView(
                                        children: [
                                          Container(
                                            color: const Color(0xFF252526),
                                            child: ListView(
                                              children: const [
                                                ListTile(
                                                  leading: Icon(Icons.image, size: 18, color: Colors.white70),
                                                  title: Text("Слой 1", style: TextStyle(fontSize: 13)),
                                                  trailing: Icon(Icons.visibility, size: 16),
                                                ),
                                                Divider(height: 1, color: Color(0xFF444)),
                                              ],
                                            ),
                                          ),
                                          const Center(child: Text("Свойства слоя")),
                                          const Center(child: Text("Библиотеки")),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  height: 24,
                  color: const Color(0xFF252526),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: const [
                      Text("2560×1440 px (72 ppi)", style: TextStyle(color: Colors.white54, fontSize: 11)),
                      Spacer(),
                      Text("52.89%", style: TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            )
        )
    );
  }

  Widget _MenuItem(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.white70)),
  );

  Widget _OptionChip(String text) => Padding(
    padding: const EdgeInsets.only(right: 12),
    child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.white70)),
  );

  Widget _ToolIcon(int index) {
    final icons = [
      Icons.crop_square, Icons.brush, Icons.text_fields, Icons.crop, Icons.zoom_in,
    ];
    return Container(
      height: 48,
      color: index == 1 ? const Color(0xFF454545) : null,
      child: Center(child: Icon(icons[index % icons.length], color: Colors.white70)),
    );
  }
}

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MinimizeWindowButton(colors: _buttonColors),
        MaximizeWindowButton(colors: _buttonColors),
        CloseWindowButton(colors: closeColors),
      ],
    );
  }
}

final _buttonColors = WindowButtonColors(
  iconNormal: Colors.white70,
  mouseOver: Colors.white,
  mouseDown: Colors.grey[800],
  iconMouseOver: Colors.black,
  iconMouseDown: Colors.black,
);

final closeColors = WindowButtonColors(
  mouseOver: const Color(0xFFD32F2F),
  mouseDown: const Color(0xFFB71C1C),
  iconNormal: Colors.white70,
  iconMouseOver: Colors.white,
);

class _PsMenuItem extends StatefulWidget {
  final String title;
  final List<PopupMenuEntry<dynamic>>? items;

  const _PsMenuItem({required this.title, this.items});

  @override
  State<_PsMenuItem> createState() => _PsMenuItemState();
}

class _PsMenuItemState extends State<_PsMenuItem> {
  bool _isHovered = false;

  Timer? _hoverTimer;

  @override
  void dispose() {
    _hoverTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasMenu = widget.items != null && widget.items!.isNotEmpty;

    return MouseRegion(
      onEnter: (_) {
        if (!hasMenu) return;
        _hoverTimer?.cancel();
        _hoverTimer = Timer(const Duration(milliseconds: 180), () {
          if (!mounted) return;
          _showPsMenu(context);
        });
      },
      onExit: (_) {
        _hoverTimer?.cancel();
      },
      cursor: hasMenu ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: !hasMenu ? null : () => _showPsMenu(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          color: _isHovered ? const Color(0xFF454545) : null,
          child: Text(
            widget.title,
            style: TextStyle(
              fontSize: 12,
              color: _isHovered ? Colors.white : const Color(0xFFD4D4D4),
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  void _showPsMenu(BuildContext context) {
    if (widget.items == null || widget.items!.isEmpty) return;

    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu(
      context: context,
      position: position,
      color: const Color(0xFF282828),
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),
        side: const BorderSide(color: Color(0xFF454545), width: 1),
      ),
      constraints: const BoxConstraints(minWidth: 220),
      items: widget.items!,
      popUpAnimationStyle: null,
    );
  }
}

class _PsMenuEntry extends PopupMenuItem {
  final String text;
  final String? shortcut;
  final bool hasSubmenu;
  final bool enabled;

  _PsMenuEntry(
      this.text, {
        this.shortcut,
        this.hasSubmenu = false,
        this.enabled = true,
      }) : super(
    enabled: enabled,
    height: 28,
    padding: EdgeInsets.zero,
    child: _PsMenuRow(
      text: text,
      shortcut: shortcut,
      hasSubmenu: hasSubmenu,
    ),
  );
}

class _PsMenuRow extends StatefulWidget {
  final String text;
  final String? shortcut;
  final bool hasSubmenu;

  const _PsMenuRow({
    required this.text,
    this.shortcut,
    this.hasSubmenu = false,
  });

  @override
  State<_PsMenuRow> createState() => __PsMenuRowState();
}

class __PsMenuRowState extends State<_PsMenuRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        height: 28,
        color: _hovered ? const Color(0xFF3E5F9B) : null,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.text,
                style: TextStyle(
                  fontSize: 12,
                  color: _hovered ? Colors.white : const Color(0xFFE0E0E0),
                ),
              ),
            ),
            if (widget.shortcut != null)
              Text(
                widget.shortcut!,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFAAAAAA),
                ),
              ),
            if (widget.hasSubmenu)
              const Padding(
                padding: EdgeInsets.only(left: 16),
                child: Icon(Icons.arrow_right, size: 16, color: Color(0xFFAAAAAA)),
              ),
          ],
        ),
      ),
    );
  }
}

class _PsMenuDivider extends PopupMenuDivider {
  const _PsMenuDivider() : super(height: 9);

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 9,
      thickness: 1,
      color: Color(0xFF3C3C3C),
      indent: 12,
      endIndent: 12,
    );
  }
}