import 'package:animated_size_and_fade/animated_size_and_fade.dart';
import 'package:cimagen/main.dart';
import 'package:cimagen/modules/AudioController.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:get/get_navigation/src/root/parse_route.dart';
import 'package:provider/provider.dart';

class NotificationManager with ChangeNotifier {
  final List<NotificationObject> _notifications = [];
  int _nextId = 0;

  List<NotificationObject> get notifications => List.unmodifiable(_notifications);

  int get active => _notifications.length;

  void init() {
  }

  int show({
    required String title,
    Widget? thumbnail,
    String? description,
    Color color = Colors.red,
    Widget? content,
    Duration? autoCloseDuration,
    NtSound? sound,
  }) {
    final id = _nextId++;
    final obj = NotificationObject(
      id: id,
      thumbnail: thumbnail,
      title: title,
      description: description,
      content: content,
    );
    _notifications.add(obj);
    notifyListeners();
    if(sound != null){
      audioController.play(sound);
    }
    if (autoCloseDuration != null) {
      Future.delayed(autoCloseDuration, () => close(id));
    }
    return id;
  }

  void update(int id, void Function(NotificationObject obj) updater) {
    final obj = _notifications.firstWhereOrNull((n) => n.id == id);
    if (obj != null) {
      updater(obj);
      obj.notifyListeners();
    }
  }

  void close(int id) {
    final obj = _notifications.firstWhereOrNull((n) => n.id == id);
    if (obj != null) {
      obj.close();
    }
  }

  void closeAll() {
    for (final obj in _notifications) {
      obj.close();
    }
  }

  void _remove(int id) {
    _notifications.removeWhere((n) => n.id == id);
    audioController.play(NtSound.okay);
    if (_notifications.isEmpty) {
      // Optional: SoLoud.instance.disposeAllSources(); for cleanup
    }
    notifyListeners();
  }
}

class NotificationObject with ChangeNotifier {
  final int id;
  Widget? thumbnail;
  String title;
  String? description;
  Widget? content;

  VoidCallback? _closeCallback;
  bool closed = false;

  NotificationObject({
    required this.id,
    this.thumbnail,
    required this.title,
    this.description,
    this.content,
  });

  void setThumbnail(Widget? newThumbnail) {
    thumbnail = newThumbnail;
    // No notify here - handled by manager.update()
  }

  void setTitle(String newTitle) {
    title = newTitle;
    // No notify here
  }

  void setDescription(String? newDescription) {
    description = newDescription;
    // No notify here
  }

  void setContent(Widget? newContent) {
    content = newContent;
    // No notify here
  }

  void setCloseCallback(VoidCallback callback) {
    _closeCallback = callback;
  }

  void close() {
    if (closed) return;
    closed = true;
    _closeCallback?.call();
  }
}

class NotificationWidget extends StatefulWidget {
  final NotificationObject notificationObject;
  final NotificationManager manager;

  const NotificationWidget({
    super.key,
    required this.notificationObject,
    required this.manager,
  });

  @override
  State<NotificationWidget> createState() => _NotificationWidgetState();
}

class _NotificationWidgetState extends State<NotificationWidget> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    widget.notificationObject.setCloseCallback(_close);
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.fastLinearToSlowEaseIn,
    );
    _controller.forward().then((v){
      _shown = true;
      if(widget.notificationObject.closed) _close();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() {
    if (_shown && _controller.status == AnimationStatus.completed) {
      _controller.animateBack(0, duration: const Duration(seconds: 1)).then((_) => widget.manager._remove(widget.notificationObject.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
        value: widget.notificationObject,
        child:  Consumer<NotificationObject>(builder: (context, notiData, child) => SizeTransition(
          sizeFactor: _animation,
          axis: Axis.vertical,
          child: Container(
            // clipBehavior: Clip.none,
            margin: const EdgeInsets.only(top: 7),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12), // Softer corners
              color: Colors.black.withAlpha(240), // Semi-transparent for modern look
            ),
            child: Row(
              children: [
                AnimatedSizeAndFade(
                  child: notiData.thumbnail != null ? Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(7)
                        ),
                        width: 64,
                        height: 64,
                        child: notiData.thumbnail!,
                      ),
                      const Gap(21),
                    ],
                  ) : const SizedBox.shrink(),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(notiData.title, style: const TextStyle(fontWeight: FontWeight.w500)),
                      if(notiData.description != null) SelectableText(notiData.description!, style: const TextStyle(color: Colors.grey)),
                      if(notiData.content != null) notiData.content!,
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _close,
                  icon: const Icon(Icons.close, size: 21, color: Colors.grey),
                )
              ],
            ),
          ),
        ))
    );
  }
}