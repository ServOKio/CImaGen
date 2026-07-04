import 'dart:io';

import 'package:animated_size_and_fade/animated_size_and_fade.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../Utils.dart';
import '../../utils/ImageManager.dart';

class FloatPreview extends StatefulWidget{
  final void Function(Function(PointerHoverEvent event, ImageMeta im)) initializer;

  const FloatPreview({ super.key, required this.initializer });

  @override
  State<FloatPreview> createState() => _FloatPreviewState();
}

class _FloatPreviewState extends State<FloatPreview> {

  ImageMeta? display;
  bool top = true;
  bool left = true;

  void changePos(PointerHoverEvent event, ImageMeta im){
    if(mounted) {
      setState(() {
        display = im;
        top = event.position.dy > MediaQuery.of(context).size.height / 2;
        left = event.position.dx > MediaQuery.of(context).size.width / 2;
      });
    }
  }

  @override
  void initState(){
    super.initState();
    widget.initializer(changePos);
  }

  @override
  Widget build(BuildContext context) {
    String pa = display == null ? '' : display!.fullNetworkPath ?? context
        .read<ImageManager>()
        .getter
        .getFullUrlImage(display!);
    Widget child;
    if (display != null) {
      if (display!.isLocal) {
        child = Image.file(File(display!.fullPath!), gaplessPlayback: true);
      } else {
        if (pa == '') {
          child = Image.file(File(display!.cacheFilePath!));
        } else {
          child = CachedNetworkImage(
              imageUrl: display!.fullNetworkPath ?? context
                  .read<ImageManager>()
                  .getter
                  .getFullUrlImage(display!),
              progressIndicatorBuilder: (context, url, downloadProgress) =>
                  Stack(
                      children: [
                        Center(
                          child: Stack(
                            children: [
                              display!.thumbnail != null ? Image.memory(
                                display!.thumbnail!,
                                filterQuality: FilterQuality.low,
                                gaplessPlayback: true,
                              ) : Icon(Icons.error),
                              if(display!.thumbnail != null) Shimmer.fromColors(
                                  baseColor: Colors.transparent,
                                  highlightColor: Colors.white.withAlpha(90),
                                  child: Image.memory(
                                    display!.thumbnail!,
                                    filterQuality: FilterQuality.low,
                                    gaplessPlayback: true,
                                  )
                              ),
                            ],
                          ),
                        ),
                        Padding(padding: EdgeInsets.all(14),
                            child: LinearProgressIndicator(
                                value: downloadProgress.progress,
                                color: Colors.white))
                      ]
                  )
          );
        }
      }
    } else {
      child = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
                child:  Lottie.asset(
                  'assets/icons/lottie/image-two.json',
                  width: 64,
                  height: 64,
                  fit: BoxFit.fill,
                )
            ),
            const Gap(4),
            const Text('Well well well...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const Text('Just hover over the image to see it', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return AnimatedAlign(
        alignment: top && left ? Alignment.bottomLeft : top && !left ? Alignment.bottomRight : !top && left ? Alignment.topLeft : Alignment.topRight,
        duration: const Duration(milliseconds: 50),
        curve: Curves.ease,
        child: AnimatedSizeAndFade(
            sizeDuration: const Duration(milliseconds: 50),
            sizeCurve: Curves.linear,
            child: Container(
                margin: const EdgeInsets.all(18),
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 80 / 100,
                    maxWidth: MediaQuery.of(context).size.width / 3
                ),
                decoration: BoxDecoration(
                  color: Colors.black,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      spreadRadius: 5,
                      blurRadius: 7,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: child
            )
        )
    );
  }
}

class SidePreview extends StatefulWidget{
  final void Function(Function(PointerHoverEvent event, ImageMeta im)) initializer;

  const SidePreview({ super.key, required this.initializer });

  @override
  State<SidePreview> createState() => _SidePreviewState();
}

class _SidePreviewState extends State<SidePreview> {

  ImageMeta? display;

  void changeImage(PointerHoverEvent event, ImageMeta im){
    if(mounted) {
      setState(() {
        display = im;
      });
    }
  }

  @override
  void initState(){
    super.initState();
    widget.initializer(changeImage);
  }

  @override
  Widget build(BuildContext context) {
    String pa = display == null ? '' : display!.fullNetworkPath ?? context.read<ImageManager>().getter.getFullUrlImage(display!);
    Widget child;
    // return Column(
    //   children: [
    //     SelectableText('isLocal ${display!.isLocal ? 'true' : 'false'}\nfullPath ${display!.fullPath}\ncacheFilePath ${display!.cacheFilePath}\nfullNetworkPath ${display!.fullNetworkPath}\ngetFullUrlImage ${context.read<ImageManager>().getter.getFullUrlImage(display!)}')
    //   ],
    // );
    if (display != null) {
      if (display!.isLocal) {
        child = Image.file(
            File(display!.fullPath!),
            gaplessPlayback: true,
            errorBuilder: (BuildContext context, Object obj, StackTrace? st) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                        child:  Lottie.asset(
                          'assets/icons/lottie/gallery slash-two.json',
                          width: 64,
                          height: 64,
                          fit: BoxFit.fill,
                        )
                    ),
                    const Gap(4),
                    const Text('There seems to be a problem', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    SelectableText(humanizeError(obj) ?? 'Unknown error\n$obj', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }
        );
      } else {
        if (pa == '') {
          child = Image.file(File(display!.cacheFilePath!));
        } else {
          child = CachedNetworkImage(
            imageUrl: display!.fullNetworkPath ?? context.read<ImageManager>().getter.getFullUrlImage(display!),
            progressIndicatorBuilder: (context, url, downloadProgress) => Stack(
                children: [
                  Center(
                    child: Stack(
                      children: [
                        display!.thumbnail != null ? Image.memory(
                          display!.thumbnail!,
                          filterQuality: FilterQuality.low,
                          gaplessPlayback: true,
                        ) : Icon(Icons.error),
                        if(display!.thumbnail != null) Shimmer.fromColors(
                            baseColor: Colors.transparent,
                            highlightColor: Colors.white.withAlpha(90),
                            child: Image.memory(
                              display!.thumbnail!,
                              filterQuality: FilterQuality.low,
                              gaplessPlayback: true,
                            )
                        ),
                      ],
                    ),
                  ),
                  Padding(padding: EdgeInsets.all(14), child: LinearProgressIndicator(value: downloadProgress.progress, color: Colors.white))
                ]
            ),
            errorWidget: (context, url, error) => Stack(
                children: [
                  Center(
                    child: Stack(
                      children: [
                        display!.thumbnail != null ? Image.memory(
                          display!.thumbnail!,
                          filterQuality: FilterQuality.low,
                          gaplessPlayback: true,
                        ) : Icon(Icons.error),
                        if(display!.thumbnail != null) Image.memory(
                          display!.thumbnail!,
                          filterQuality: FilterQuality.low,
                          gaplessPlayback: true,
                        )
                      ],
                    ),
                  ),
                  Padding(padding: EdgeInsets.all(14), child: SelectableText('Error: $error'))
                ]
            ),
          );
        }
      }
    } else {
      child = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
                child:  Lottie.asset(
                  'assets/icons/lottie/image-two.json',
                  width: 64,
                  height: 64,
                  fit: BoxFit.fill,
                )
            ),
            const Gap(4),
            const Text('Well well well...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const Text('Just hover over the image to see it', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return child;
  }
}