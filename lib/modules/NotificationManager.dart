import 'package:animated_size_and_fade/animated_size_and_fade.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cimagen/Utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../utils/NavigationService.dart';

class NotificationManager with ChangeNotifier {
  int active = 0;
  Map<int, NotificationObject> _notifications= {};
    // NotificationObject(id: 12312, title: 'Test', content: Container(
    //   margin: EdgeInsets.only(top: 7),
    //   width: 100,
    //   child: LinearProgressIndicator(),
    // ))

  Map<int, NotificationObject> get notifications => _notifications;

  void init(){

  }

  int show({required String title, Widget? thumbnail, String? description, Color color = Colors.red, Widget? content}){
    int id = getRandomInt(10000, 50000);
    _notifications[id] = NotificationObject(id: id, thumbnail: thumbnail, title: title, description: description, content: content);
    notifyListeners();
    audioController!.player.play(AssetSource('audio/open.wav'));
    if (kDebugMode) {
      print('show with id:$id: $title');
    }
    active++;
    return id;
  }

  void update(int id, String key, dynamic value) {
    NotificationObject? object = _notifications[id];
    if(object != null){
      object.update(key, value);
    }
  }

  void close(int id){
    print('close $id');
    NotificationObject? object = _notifications[id];
    if(object != null){
      object.close();
    }
  }

  void remove(int id){
    active--;
    audioController!.player.play(AssetSource('audio/okay.wav'));
    if(active <= 0){
      _notifications.clear();
      notifyListeners();
      print('clean');
    }
  }
}

class NotificationWidget extends StatefulWidget{
  final NotificationObject notificationObject;
  final NotificationManager manager;
  final BuildContext context;
  const NotificationWidget(this.context, this.manager, this.notificationObject, { super.key });

  @override
  State<NotificationWidget> createState() => _NotificationWidgetState();
}

class _NotificationWidgetState extends State<NotificationWidget> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  bool shown = false;

  @override
  void initState() {
    super.initState();
    widget.notificationObject.setClose(close);
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.fastLinearToSlowEaseIn,
    );
    _controller.forward().then((v){
      shown = true;
      if(widget.notificationObject.closed) close();
    });
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  void close() {
    if (shown && _animation.status == AnimationStatus.completed) {
      _controller.animateBack(0, duration: const Duration(seconds: 1)).then((onValue){
        widget.manager.remove(widget.notificationObject.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => widget.notificationObject,
      child:  Consumer<NotificationObject>(builder: (context, notiData, child) => SizeTransition(
        sizeFactor: _animation,
        axis: Axis.vertical,
        child: Container(
          clipBehavior: Clip.none,
          margin: const EdgeInsets.only(top: 7),
          padding: const EdgeInsets.all(28),
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(7)),
            color: Colors.black,
            // boxShadow: [
            //   BoxShadow(
            //     color: Colors.grey.withOpacity(0.5),
            //     spreadRadius: 5,
            //     blurRadius: 7,
            //     offset: const Offset(0, 3), // changes position of shadow
            //   ),
            // ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(notiData.title, style: const TextStyle(fontWeight: FontWeight.w500)),
                      if(notiData.description != null) SelectableText(notiData.description!, style: const TextStyle(color: Colors.grey)),
                      if(notiData.content != null) notiData.content!,
                      // const Gap(21),
                      // Row(
                      //   children: [
                      //     ElevatedButton(
                      //         style: ButtonStyle(
                      //             foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
                      //             backgroundColor: MaterialStateProperty.all<Color>(Theme.of(context).primaryColor),
                      //             shape: MaterialStateProperty.all<RoundedRectangleBorder>(const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))))
                      //         ),
                      //         onPressed: () async {
                      //         },
                      //         child: Text('hfgh', style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal))
                      //     ),
                      //     const Gap(8),
                      //     ElevatedButton(
                      //         style: ButtonStyle(
                      //             foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
                      //             backgroundColor: MaterialStateProperty.all<Color>(Theme.of(context).primaryColor),
                      //             shape: MaterialStateProperty.all<RoundedRectangleBorder>(const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))))
                      //         ),
                      //         onPressed: () async {
                      //         },
                      //         child: Text('fsfd', style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal))
                      //     )
                      //   ],
                      // )
                    ],
                  ),
                  IconButton(
                    onPressed: (){
                      close();
                    },
                    icon: const Icon(Icons.close, size: 21, color: Colors.grey),
                  )
                ],
              )
            ],
          ),
        ),
      ))
    );
  }
}

class NotificationObject with ChangeNotifier{
  final int id;
  Widget? thumbnail;
  String title;
  String? description;
  Widget? content;

  Function? _closeFunction;
  Function? changeFunction;
  bool closed = false;

  NotificationObject({
    required this.id,
    this.thumbnail,
    required this.title,
    this.description,
    this.content
  });

  void update(String key, dynamic value){
    switch (key) {
      case 'thumbnail':
        thumbnail = value;
        notifyListeners();
      case 'title':
        title = value;
        notifyListeners();
      case 'description':
        description = value;
        notifyListeners();
      case 'content':
        content = value;
        notifyListeners();
    }
  }

  void setClose(void Function() f) => _closeFunction = f;
  void close(){
    closed = true;
    if(_closeFunction != null) _closeFunction!();
  }
}