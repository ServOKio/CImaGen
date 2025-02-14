import 'dart:io';

import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import '../modules/Animations.dart';

class DevicePreview extends StatefulWidget{
  final ImageMeta imageMeta;

  const DevicePreview({ super.key, required this.imageMeta});

  @override
  State<DevicePreview> createState() => _DevicePreviewState();
}

class _DevicePreviewState extends State<DevicePreview> {
  bool loaded = false;

  @override
  Widget build(BuildContext context) {
    AppBar appBar = AppBar(
        title: ShowUp(
          delay: 100,
          child: Text('Device Preview', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600, fontFamily: 'Montserrat')),
        ),
        backgroundColor: const Color(0xaa000000),
        elevation: 0,
        actions: []
    );

    ImageProvider provider;
    if(!widget.imageMeta.isLocal){
      String net = widget.imageMeta.fullNetworkPath ?? context.read<ImageManager>().getter.getFullUrlImage(widget.imageMeta);
      provider = net == '' ? FileImage(File(widget.imageMeta.tempFilePath ?? widget.imageMeta.cacheFilePath ?? 'e.png')) : NetworkImage(widget.imageMeta.fullNetworkPath ?? context.read<ImageManager>().getter.getFullUrlImage(widget.imageMeta));
    } else {
      provider = FileImage(File(widget.imageMeta.fullPath ?? widget.imageMeta.tempFilePath ?? widget.imageMeta.cacheFilePath ?? 'e.png'));
    }

    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: appBar,
        backgroundColor: Color(0xFFecebe9),
        body: SafeArea(
            child: SingleChildScrollView(
              child: Wrap(
                children: [
                  IMac(provider),
                  Samsung(provider),
                  ViewSonic(provider),
                  LG(provider),
                  RedMagic8SPro(provider),
                  SamsungS20Plus(provider),
                  WatchFit(provider),
                  Qin(provider),
                  SteamDesk(provider)
                ],
              ),
            )
        )
    );
  }

  Widget IMac(ImageProvider provider){
    return Container(
        padding: EdgeInsets.all(18),
        decoration: BoxDecoration(
          border: Border.all(
            color: Color(0xffd8d8d8)
          )
        ),
        width: 350,
        child: Column(
          children: [
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Color(0xffc3c3c3),
                borderRadius: BorderRadius.circular(5)
              ),
              padding: EdgeInsets.only(bottom: 20),
              child: Container(
                  color: Color(0xff22212a),
                  padding: EdgeInsets.all(10),
                  child: AspectRatio(
                    aspectRatio: 16/10,
                    child: Image(
                      fit: BoxFit.cover,
                      image: provider,
                    ),
                  )
              ),
            ),
            Column(
              children: [
                Text('IMac', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600, fontFamily: 'Montserrat', color: Color(0xff424242))),
                Text('16/10 5120x2880', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w400, fontFamily: 'Montserrat', color: Color(0xff5b5b5b)))
              ],
            )
          ],
        )
    );
  }

  Widget ViewSonic(ImageProvider provider){
    return Container(
        padding: EdgeInsets.all(18),
        decoration: BoxDecoration(
            border: Border.all(
                color: Color(0xffd8d8d8)
            )
        ),
        width: 350,
        child: Column(
          children: [
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                  color: Color(0xff353a3c),
                  borderRadius: BorderRadius.circular(2)
              ),
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  AspectRatio(aspectRatio: 4/3, child: Image(
                    fit: BoxFit.cover,
                    image: provider,
                  )),
                  Gap(18),
                  Container(color: Color(0xff282b2d), height: 2)
                ],
              ),
            ),
            Column(
              children: [
                Text('ViewSonic', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600, fontFamily: 'Montserrat', color: Color(0xff424242))),
                Text('4/3 1024x768', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w400, fontFamily: 'Montserrat', color: Color(0xff5b5b5b)))
              ],
            )
          ],
        )
    );
  }

  Widget Samsung(ImageProvider provider){
    return Container(
        padding: EdgeInsets.all(18),
        decoration: BoxDecoration(
            border: Border.all(
                color: Color(0xffd8d8d8)
            )
        ),
        width: 350,
        child: Column(
          children: [
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                  color: Color(0xff7f858a),
                  borderRadius: BorderRadius.circular(2)
              ),
              padding: EdgeInsets.only(bottom: 10),
              child: Container(
                  color: Color(0xff222020),
                  padding: EdgeInsets.all(3),
                  child: Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 16/10,
                        child: Image(
                          fit: BoxFit.cover,
                          image: provider,
                        ),
                      ),
                      Positioned.fill(child: Container(color: Colors.black.withAlpha(50))),
                      Positioned(
                        bottom: 10,
                        left: 10,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('7:39', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w400)),
                            Text('Monday, January 8', style: const TextStyle(fontWeight: FontWeight.w200)),
                          ],
                        ),
                      )
                    ],
                  )
              ),
            ),
            Column(
              children: [
                Text('Samsung', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600, fontFamily: 'Montserrat', color: Color(0xff424242))),
                Text('16/9 1920x1080', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w400, fontFamily: 'Montserrat', color: Color(0xff5b5b5b)))
              ],
            )
          ],
        )
    );
  }

  Widget LG(ImageProvider provider){
    return Container(
        padding: EdgeInsets.all(18),
        decoration: BoxDecoration(
            border: Border.all(
                color: Color(0xffd8d8d8)
            )
        ),
        width: 500,
        child: Column(
          children: [
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                  color: Color(0xff2c2c2c),
                  borderRadius: BorderRadius.circular(2)
              ),
              padding: EdgeInsets.only(bottom: 10),
              child: Container(
                  color: Color(0xff222020),
                  padding: EdgeInsets.all(3),
                  child: Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 21/9,
                        child: Image(
                          fit: BoxFit.cover,
                          image: provider,
                        ),
                      ),
                      Positioned.fill(child: Container(color: Colors.black.withAlpha(50))),
                      Positioned(
                        bottom: 10,
                        left: 10,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('7:39', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w400)),
                            Text('Monday, January 8', style: const TextStyle(fontWeight: FontWeight.w200)),
                          ],
                        ),
                      )
                    ],
                  )
              ),
            ),
            Column(
              children: [
                Text('LG', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600, fontFamily: 'Montserrat', color: Color(0xff424242))),
                Text('21:9 3440x1440', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w400, fontFamily: 'Montserrat', color: Color(0xff5b5b5b)))
              ],
            )
          ],
        )
    );
  }

  Widget RedMagic8SPro(ImageProvider provider) {
    return Container(
        padding: EdgeInsets.all(18),
        decoration: BoxDecoration(
            border: Border.all(
                color: Color(0xffd8d8d8)
            )
        ),
        child: Column(
          children: [
            Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                    color: Color(0xff383a3c),
                    borderRadius: BorderRadius.circular(2)
                ),
                padding: EdgeInsets.all(3),
                child: Stack(
                  children: [
                    SizedBox(
                      height: 350,
                      child: AspectRatio(
                        aspectRatio: 9/20,
                        child: Image(
                          fit: BoxFit.cover,
                          image: provider,
                        ),
                      ),
                    ),
                    Positioned.fill(child: Container(color: Colors.black.withAlpha(50))),
                    Positioned.fill(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('12\n00', style: const TextStyle(fontSize: 80, fontWeight: FontWeight.w400, height: 0.8)),
                        ],
                      )
                    )
                  ],
                )
            ),
            Column(
              children: [
                Text('RedMagic 8S', style: const TextStyle(fontSize: 21,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Montserrat',
                    color: Color(0xff424242))),
                Text('20/9 2480x1116', style: const TextStyle(fontSize: 10,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Montserrat',
                    color: Color(0xff5b5b5b)))
              ],
            )
          ],
        )
    );
  }

  Widget SamsungS20Plus(ImageProvider provider) {
    return Container(
        padding: EdgeInsets.all(18),
        decoration: BoxDecoration(
            border: Border.all(
                color: Color(0xffd8d8d8)
            )
        ),
        child: Column(
          children: [
            Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                    color: Color(0xff383a3c),
                    borderRadius: BorderRadius.circular(17)
                ),
                padding: EdgeInsets.symmetric(horizontal: 5, vertical: 7),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(17)
                  ),
                  child: Stack(
                    children: [
                      SizedBox(
                        height: 350,
                        child: AspectRatio(
                          aspectRatio: 9/20,
                          child: Image(
                            fit: BoxFit.cover,
                            image: provider,
                          ),
                        ),
                      ),
                      Positioned.fill(child: Container(color: Colors.black.withAlpha(50))),
                      Positioned.fill(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('12\n00', style: const TextStyle(fontSize: 80, fontWeight: FontWeight.w400, height: 0.8)),
                            ],
                          )
                      )
                    ],
                  ),
                )
            ),
            Column(
              children: [
                Text('Samsung S20+', style: const TextStyle(fontSize: 21,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Montserrat',
                    color: Color(0xff424242))),
                Text('20/9 3200x1440', style: const TextStyle(fontSize: 10,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Montserrat',
                    color: Color(0xff5b5b5b)))
              ],
            )
          ],
        )
    );
  }

  Widget WatchFit(ImageProvider provider) {
    return Container(
        padding: EdgeInsets.all(18),
        decoration: BoxDecoration(
            border: Border.all(
                color: Color(0xffd8d8d8)
            )
        ),
        child: Column(
          children: [
            Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                    color: Color(0xff808080),
                    borderRadius: BorderRadius.circular(40)
                ),
                padding: EdgeInsets.all(5),
                child:  Container(
                    clipBehavior: Clip.antiAlias,
                    width: 200,
                    decoration: BoxDecoration(
                        color: Color(0xff121313),
                        border: Border.all(
                            width: 10,
                            color: Color(0xff181816)
                        ),
                        borderRadius: BorderRadius.circular(40),
                    ),
                    child: AspectRatio(
                      aspectRatio: 17/20,
                      child: Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: Image(
                            fit: BoxFit.cover,
                            image: provider,
                          ),
                      ),
                    )
                ),
            ),
            Column(
              children: [
                Text('Watch Fit 3', style: const TextStyle(fontSize: 21,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Montserrat',
                    color: Color(0xff424242))),
                Text('20/17 480х408', style: const TextStyle(fontSize: 10,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Montserrat',
                    color: Color(0xff5b5b5b)))
              ],
            )
          ],
        )
    );
  }

  Widget Qin(ImageProvider provider) {
    return Container(
        padding: EdgeInsets.all(18),
        decoration: BoxDecoration(
            border: Border.all(
                color: Color(0xffd8d8d8)
            )
        ),
        child: Column(
          children: [
            SizedBox(
              width: 150,
              child: AspectRatio(
                aspectRatio: 58/147,
                child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                        color: Color(0xff353743),
                        borderRadius: BorderRadius.circular(5)
                    ),
                    padding: EdgeInsets.all(3),
                    child: Column(
                      children: [
                        Container(
                          color: Colors.black,
                          padding: EdgeInsets.only(
                              top: 10,
                              bottom: 8,
                              left: 5,
                              right: 5
                          ),
                          child: Stack(
                            children: [
                              Container(
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(7)
                                ),
                                child: AspectRatio(
                                  aspectRatio: 2/3,
                                  child: Image(
                                    fit: BoxFit.cover,
                                    image: provider,
                                  ),
                                ),
                              ),
                              Positioned.fill(child: Container(color: Colors.black.withAlpha(50))),
                              Positioned.fill(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('12\n00', style: const TextStyle(fontSize: 80, fontWeight: FontWeight.w400, height: 0.8)),
                                    ],
                                  )
                              )
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            Container(
                              margin: EdgeInsets.only(top: 4),
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Color(0xff272935)
                                  ),// border color
                                  shape: BoxShape.circle,
                                )
                            ),
                            Align(alignment: Alignment.bottomRight, child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Color(0xff14171e), // border color
                                  shape: BoxShape.circle,
                                )
                            ))
                          ],
                        )
                      ],
                    )
                ),
              ),
            ),
            Column(
              children: [
                Text('Qin F22', style: const TextStyle(fontSize: 21,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Montserrat',
                    color: Color(0xff424242))),
                Text('3/2 640x960', style: const TextStyle(fontSize: 10,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Montserrat',
                    color: Color(0xff5b5b5b)))
              ],
            )
          ],
        )
    );
  }

  Widget SteamDesk(ImageProvider provider){
    return Container(
        padding: EdgeInsets.all(18),
        decoration: BoxDecoration(
            border: Border.all(
                color: Color(0xffd8d8d8)
            )
        ),
        width: 350,
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 298/117,
              child: Container(
                decoration: BoxDecoration(
                  color: Color(0xff2a2a2a),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20),
                    bottom: Radius.circular(30)
                  ),
                ),
                padding: EdgeInsets.all(3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Color(0xff000000),
                        borderRadius: BorderRadius.all(Radius.circular(3))
                      ),
                      padding: EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                      child: AspectRatio(
                        aspectRatio: 16/10,
                        child: Image(
                          fit: BoxFit.cover,
                          image: provider,
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
            Column(
              children: [
                Text('Steam Deck', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600, fontFamily: 'Montserrat', color: Color(0xff424242))),
                Text('16/10 1280x800', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w400, fontFamily: 'Montserrat', color: Color(0xff5b5b5b)))
              ],
            )
          ],
        )
    );
  }
}