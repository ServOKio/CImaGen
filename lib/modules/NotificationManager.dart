import 'package:flutter/material.dart';

import '../utils/NavigationService.dart';

class NotificationManager{
  List<NotificationObject> _notifications = [];

  List<NotificationObject> get notifications => _notifications;

  void init(){

  }

  void show({required String title, String? description, Color color = Colors.red}){
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
  }


}

class NotificationObject {
  final int width;
  final int height;

  const NotificationObject({
    required this.width,
    required this.height
  });

  @override
  String toString(){
    return '${width}x$height';
  }

  int totalPixels(){
    return width*height;
  }

  double aspectRatio(){
    return width / height;
  }

  String withMultiply(double hiresUpscale) {
    return '${(width * hiresUpscale).round()}x${(height * hiresUpscale).round()}';
  }
}