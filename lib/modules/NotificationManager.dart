import 'package:animated_size_and_fade/animated_size_and_fade.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cimagen/Utils.dart';
import 'package:flutter/cupertino.dart';
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

  int show({required String title, String? description, Color color = Colors.red, Widget? content}){
    int id = getRandomInt(10000, 50000);
    _notifications[id] = NotificationObject(id: id, title: title, description: description, content: content);
    notifyListeners();
    audioController!.player.play(AssetSource('audio/open.wav'));
    print('show with id:$id: $title');
    if(NavigationService.navigatorKey.currentContext != null){
      // BuildContext context = NavigationService.navigatorKey.currentContext!;
      //
      // bool isRTL = Directionality.of(context) == TextDirection.rtl;
      //
      // final size = MediaQuery.of(context).size;
      //
      // // screen dimensions
      // bool isMobile = size.width <= 768;
      // bool isTablet = size.width > 768 && size.width <= 992;
      //
      // final hsl = HSLColor.fromColor(color);
      // final hslDark = hsl.withLightness((hsl.lightness - 0.1).clamp(0.0, 1.0));
      //
      // double horizontalPadding = 0.0;
      // double leftSpace = size.width * 0.12;
      // double rightSpace = size.width * 0.12;
      //
      // if (isMobile) {
      //   horizontalPadding = size.width * 0.01;
      // } else if (isTablet) {
      //   leftSpace = size.width * 0.05;
      //   horizontalPadding = size.width * 0.2;
      // } else {
      //   leftSpace = size.width * 0.05;
      //   horizontalPadding = size.width * 0.3;
      // }
      // // ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      // //   behavior: SnackBarBehavior.floating,
      // //   content: const Text('Awesome Snackbar!'),
      // //   action: SnackBarAction(
      // //     label: 'Action',
      // //     onPressed: () {
      // //       // Code to execute.
      // //     },
      // //   ),
      // // ));
      // // return;
      // ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      //     backgroundColor: Colors.transparent,
      //     behavior: SnackBarBehavior.floating,
      //     elevation: 0.0,
      //     content: Container(
      //       margin: EdgeInsets.symmetric(
      //         horizontal: horizontalPadding,
      //       ),
      //       height: size.height * 0.125,
      //       child: Stack(
      //         clipBehavior: Clip.none,
      //         alignment: Alignment.topCenter,
      //         children: [
      //           /// background container
      //           Container(
      //             width: size.width,
      //             decoration: BoxDecoration(
      //               color: color,
      //               borderRadius: BorderRadius.circular(20),
      //             ),
      //           ),
      //
      //           /// Splash SVG asset
      //           Positioned(
      //             bottom: 0,
      //             left: 0,
      //             child: ClipRRect(
      //               borderRadius: const BorderRadius.only(
      //                 bottomLeft: Radius.circular(20),
      //               ),
      //               child: Icon(Icons.ac_unit, size: size.width * 0.05)
      //             ),
      //           ),
      //
      //           // Bubble Icon
      //           // Positioned(
      //           //   top: -size.height * 0.02,
      //           //   left: !isRTL
      //           //       ? leftSpace -
      //           //       8 -
      //           //       (isMobile ? size.width * 0.075 : size.width * 0.035)
      //           //       : null,
      //           //   right: isRTL
      //           //       ? rightSpace -
      //           //       8 -
      //           //       (isMobile ? size.width * 0.075 : size.width * 0.035)
      //           //       : null,
      //           //   child: Stack(
      //           //     alignment: Alignment.center,
      //           //     children: [
      //           //       Positioned(
      //           //         top: size.height * 0.015,
      //           //         child: Icon(Icons.access_time_filled_outlined, size: size.height * 0.022)
      //           //       )
      //           //     ],
      //           //   ),
      //           // ),
      //
      //           /// content
      //           Positioned.fill(
      //             left: isRTL ? size.width * 0.03 : leftSpace,
      //             right: isRTL ? rightSpace : size.width * 0.03,
      //             child: Column(
      //               mainAxisSize: MainAxisSize.min,
      //               crossAxisAlignment: CrossAxisAlignment.start,
      //               children: [
      //                 SizedBox(
      //                   height: size.height * 0.02,
      //                 ),
      //                 Row(
      //                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
      //                   children: [
      //                     /// `title` parameter
      //                     Expanded(
      //                       flex: 3,
      //                       child: Text(
      //                         title,
      //                         style: TextStyle(
      //                           fontSize: !isMobile
      //                                   ? size.height * 0.03
      //                                   : size.height * 0.025,
      //                           fontWeight: FontWeight.w600,
      //                           color: Colors.white,
      //                         ),
      //                       ),
      //                     ),
      //
      //                     InkWell(
      //                       onTap: () {
      //                         ScaffoldMessenger.of(context).hideCurrentSnackBar();
      //                       },
      //                       child: Icon(Icons.close, size: size.height * 0.022)
      //                     ),
      //                   ],
      //                 ),
      //                 SizedBox(
      //                   height: size.height * 0.005,
      //                 ),
      //                 /// `message` body text parameter
      //                 Expanded(
      //                   child: Text(
      //                     description ?? 'none',
      //                     style: TextStyle(
      //                       fontSize: size.height * 0.016,
      //                       color: Colors.white,
      //                     ),
      //                   ),
      //                 ),
      //                 SizedBox(
      //                   height: size.height * 0.015,
      //                 ),
      //               ],
      //             ),
      //           )
      //         ],
      //       ),
      //     )
      // ));
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
              Positioned(
                  top: -21,
                  right: -21,
                  child: IconButton(
                    onPressed: (){
                      close();
                    },
                    icon: const Icon(Icons.close, size: 21, color: Colors.grey),
                  )
              ),
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
                      if(notiData.description != null) Text(notiData.description!, style: const TextStyle(color: Colors.grey)),
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