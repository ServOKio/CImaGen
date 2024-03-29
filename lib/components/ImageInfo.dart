import 'dart:math';

import 'package:cimagen/components/Histogram.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../Utils.dart';

class MyImageInfo extends StatelessWidget {
  dynamic data;
  MyImageInfo(this.data);

  @override
  Widget build(BuildContext context) {
    bool raw = true;
    ImageMeta? im;
    GenerationParams? gp;
    if(data.runtimeType == ImageMeta){
      raw = false;
      im = data as ImageMeta;
      if(im.generationParams != null) gp = im.generationParams;
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ExpansionTile(
            initiallyExpanded: true,
            tilePadding: EdgeInsets.zero,
            title:  Text('Image info', style: TextStyle(color: Colors.deepPurple.shade50, fontWeight: FontWeight.w600, fontSize: 18)),
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(aspectRatio: 16/9, child: Histogram(path: raw ? data as String : im!.fullPath)),
                  InfoBox(one: 'Extension/mine', two: '${im?.fileTypeExtension} (${im?.mine})'),
                  const Gap(6),
                  Container(
                      decoration: const BoxDecoration(
                          color: Color(0xff303030),
                          borderRadius: BorderRadius.all(Radius.circular(4))
                      ),
                      child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Main', style: TextStyle(fontSize: 12, color: Colors.white70)),
                              const Gap(6),
                              Column(
                                children: [
                                  InfoBox(one: 'Date modified', two: im?.dateModified.toIso8601String() ?? '', inner: true),
                                  const Gap(4),
                                  InfoBox(one: 'File size', two: readableFileSize(im?.fileSize ?? 0), inner: true),
                                  const Gap(4),
                                  InfoBox(one: 'File name', two: im?.fileName ?? '', inner: true),
                                  const Gap(4),
                                  InfoBox(one: 'Size', two: '${im?.size.toString()} (${aspectRatioFromSize(im!.size)})', inner: true),
                                  const Gap(4),
                                  InfoBox(one: 'Path', two: im?.fullPath ?? '', inner: true),
                                ],
                              )
                            ],
                          )
                      )
                  ),
                  const Gap(4),
                  Container(
                      decoration: const BoxDecoration(
                          color: Color(0xff303030),
                          borderRadius: BorderRadius.all(Radius.circular(4))
                      ),
                      child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Raw', style: TextStyle(fontSize: 12, color: Colors.white70)),
                              const Gap(6),
                              Column(
                                children: [
                                  InfoBox(one: 'Bit depth', two: im?.bitDepth.toString() ?? '', inner: true),
                                  Row(
                                    children: List<Widget>.generate(im!.bitDepth * im.bitDepth, (i){
                                      int c = (255 / (im!.bitDepth * im.bitDepth)).round();
                                      return Expanded(child: Container(
                                          height: 4,
                                          color: Color.fromRGBO(c*i, c*i, c*i, 1)
                                      ));
                                    }),
                                  ),
                                  const Gap(4),
                                  InfoBox(one: 'Color type', two: Row(children: [
                                    SelectableText(getColorType(im.colorType), style: const TextStyle(fontSize: 13)),
                                    const Gap(2),
                                    Container(
                                      width: 15,
                                      height: 15,
                                      child: Stack(
                                        children: [
                                          Align(alignment: Alignment.topCenter, child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, borderRadius: BorderRadius.all(Radius.circular(6)), backgroundBlendMode: BlendMode.screen))),
                                          Align(alignment: Alignment.bottomLeft, child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.green, borderRadius: BorderRadius.all(Radius.circular(6)), backgroundBlendMode: BlendMode.screen))),
                                          Align(alignment: Alignment.bottomRight, child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.all(Radius.circular(6)), backgroundBlendMode: BlendMode.screen))),
                                        ],
                                      ),
                                    )
                                  ]), inner: true),
                                  const Gap(4),
                                  InfoBox(one: 'Compression', two: getCompression(im.compression), inner: true),
                                  const Gap(4),
                                  InfoBox(one: 'Filter', two: getFilterType(im.filter), inner: true),
                                  const Gap(4),
                                  InfoBox(one: 'Interlace method', two: getInterlaceMethod(im.colorMode), inner: true),
                                ],
                              )
                            ],
                          )
                      )
                  ),
                  const Gap(6),
                ],
              )
            ],
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title:  Text('Generation info', style: TextStyle(color: Colors.deepPurple.shade50, fontWeight: FontWeight.w600, fontSize: 18)),
            children: <Widget>[
              Container(
                  padding: const EdgeInsets.all(4.0),
                  margin: const EdgeInsets.only(bottom: 8),
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    border: Border.all(color: Colors.green, width: 1),
                    borderRadius: const BorderRadius.all(Radius.circular(5.0)),
                  ),
                  child: FractionallySizedBox(
                      widthFactor: 1.0,
                      child: SelectableText(gp?.positive ?? '', style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 10))
                  )
              ),
              Container(
                  padding: const EdgeInsets.all(4.0),
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    border: Border.all(color: Colors.red, width: 1,),
                    borderRadius: const BorderRadius.all(Radius.circular(5.0)),
                  ),
                  child: FractionallySizedBox(
                      widthFactor: 1.0,
                      child: SelectableText(gp?.negative ?? '', style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 10))
                  )
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InfoBox(one: 'SD checkpoint', two: '${gp?.model} (${gp?.modelHash})'),
                  const Gap(6),
                  Container(
                      decoration: const BoxDecoration(
                          color: Color(0xff303030),
                          borderRadius: BorderRadius.all(Radius.circular(4))
                      ),
                      child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Sampling', style: TextStyle(fontSize: 12, color: Colors.white70)),
                              const Gap(6),
                              Column(
                                children: [
                                  InfoBox(one: 'Method', two: gp?.sampler ?? '', inner: true),
                                  const Gap(4),
                                  InfoBox(one: 'Steps', two: gp?.steps.toString() ?? '', inner: true),
                                  const Gap(4),
                                  InfoBox(one: 'CFG Scale', two: gp?.cfgScale.toString() ?? '', inner: true),
                                ],
                              )
                            ],
                          )
                      )
                  ),
                  gp?.hiresUpscale != null ? const Gap(4) : const SizedBox.shrink(),
                  gp?.hiresUpscale != null ? Container(
                      decoration: const BoxDecoration(
                          color: Color(0xff303030),
                          borderRadius: BorderRadius.all(Radius.circular(4))
                      ),
                      child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Hi-res', style: TextStyle(fontSize: 12, color: Colors.white70)),
                              const Gap(6),
                              Column(
                                children: [
                                  gp?.hiresSampler != null ? InfoBox(one: 'Sampler', two: gp?.hiresSampler ?? 'None', inner: true) : const SizedBox.shrink(),
                                  gp?.hiresSampler != null ? const Gap(4) : const SizedBox.shrink(),
                                  InfoBox(one: 'Denoising strength', two: gp?.denoisingStrength.toString() ?? 'none', inner: true),
                                  const Gap(4),
                                  InfoBox(one: 'Upscaler', two: gp?.hiresUpscaler ?? 'None (Lanczos)', inner: true),
                                  const Gap(4),
                                  InfoBox(one: 'Upscale', two: '${gp?.hiresUpscale} (${gp?.size.withMultiply(gp.hiresUpscale ?? 0)})' ?? '', inner: true),
                                ],
                              )
                            ],
                          )
                      )
                  ) : const SizedBox.shrink(),
                  const Gap(6),
                  InfoBox(one: 'Width and height', two:  '${gp?.size.width}x${gp?.size.height}'),
                  const Gap(6),
                  InfoBox(one: 'Version', two: gp?.version ?? ''),
                ],
              ),
              gp?.rawData != null ? ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('All parameters', style: TextStyle(fontSize: 14)),
                subtitle: const Text('View raw generation parameters without parsing'),
                children: <Widget>[
                  Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: const BorderRadius.all(Radius.circular(4))
                      ),
                      child: SelectableText(
                          (gp?.rawData ?? '').replaceFirst('parameters', ''),
                          style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 14, color: Colors.white70)
                      )
                  ),
                ],
              ) : const SizedBox.shrink(),
            ],
          ),
          BottomNavigationBar(
            backgroundColor: Colors.transparent,
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.thumb_up),
                label: 'Like',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.undo),
                label: 'Reset',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.thumb_down_alt_outlined),
                activeIcon: Icon(Icons.thumb_down_alt),
                label: 'Dislike',
              ),
            ],
            currentIndex: 1,
            selectedItemColor: Theme.of(context).primaryColor,
            unselectedItemColor: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            onTap: (index){

            },
          )
        ]
    );
  }

}

class InfoBox extends StatelessWidget{
  final String one;
  final dynamic two;
  final bool inner;

  const InfoBox({ Key? key, required this.one, required this.two, this.inner = false}): super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
            color: !inner ? Theme.of(context).scaffoldBackgroundColor : const Color(0xff1a1a1a),
            borderRadius: const BorderRadius.all(Radius.circular(4))
        ),
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            child: Row( // This shit killed four hours of my life.
              children: [
                Text(one, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                const Gap(6),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: two.runtimeType == String ? SelectableText(two, style: const TextStyle(fontSize: 13)) : two,
                    ),
                  ),
                )
              ],
            )
        )
    );
  }
}