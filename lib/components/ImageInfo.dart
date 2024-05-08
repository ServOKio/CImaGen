import 'package:cimagen/components/Histogram.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../Utils.dart';
import '../modules/ICCProfiles.dart';

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

    int bitsPerChannel = im?.fileTypeExtension == 'jpg' ? (im?.specific?['bitsPerChannel'] ?? 0) : im?.specific?['bitDepth'] ?? 0;
    String colorType = im?.fileTypeExtension == 'jpg' ? numChannelsToString(im?.specific?['numChannels']) : getColorType(im?.specific?['colorType']);
    NumberFormat f = NumberFormat("0.####");
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
                                  InfoBox(one: 'Date modified', two: im?.dateModified.toIso8601String() ?? '', inner: true, withGap: false),
                                  InfoBox(one: 'File size', two: readableFileSize(im?.fileSize ?? 0), inner: true),
                                  InfoBox(one: 'File name', two: im?.fileName ?? '', inner: true),
                                  InfoBox(one: 'Size', two: '${im?.size.toString()} (${aspectRatioFromSize(im!.size)})', inner: true),
                                  InfoBox(one: 'Path', two: im.fullPath ?? '', inner: true),
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
                                  // SelectableText(im.specific.toString()),
                                  InfoBox(one: 'Bit depth', two: im.fileTypeExtension == 'jpg' ? (im.specific?['bitsPerChannel'].toString() ?? 'None') : im.specific?['bitDepth'].toString() ?? 'None', inner: true),
                                  Row(
                                    children: List<Widget>.generate(bitsPerChannel * bitsPerChannel, (i){
                                      int c = (255 / (bitsPerChannel * bitsPerChannel)).round();
                                      return Expanded(child: Container(
                                          height: 4,
                                          color: Color.fromRGBO(c*i, c*i, c*i, 1)
                                      ));
                                    }),
                                  ),
                                  InfoBox(one: 'Color type', two: Row(children: [
                                    SelectableText(colorType, style: const TextStyle(fontSize: 13)),
                                    const Gap(2),
                                    SizedBox(
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
                                  im.specific?['compression'] != null ? InfoBox(one: 'Compression', two: getCompression(im.specific?['compression']), inner: true) : const SizedBox.shrink(),
                                  im.specific?['filter'] != null ? InfoBox(one: 'Filter', two: getFilterType(im.specific?['filter']), inner: true) : const SizedBox.shrink(),
                                  im.specific?['colorMode'] != null ? InfoBox(one: 'Interlace method', two: getInterlaceMethod(im.specific?['colorMode']), inner: true) : const SizedBox.shrink(),
                                  im.specific?['profileName'] != null ? InfoBox(one: 'Profile Name', two: im.specific?['profileName'], inner: true) : const SizedBox.shrink(),
                                  im.specific?['pixelUnits'] != null ? InfoBox(one: 'Pixel units', two: im.specific?['pixelUnits'] == 1 ? 'Meters' : 'Not specified', inner: true) : const SizedBox.shrink(),
                                  im.specific?['pixelUnits'] != null ? InfoBox(one: 'Pixels per unit X/Y', two: '${im.specific?['pixelsPerUnitX']}x${im.specific?['pixelsPerUnitY']}', inner: true) : const SizedBox.shrink(),
                                ],
                              )
                            ],
                          )
                      )
                  ),
                  im.specific?['iccProfileName'] != null ? const Gap(4) : const SizedBox.shrink(),
                  im.specific?['iccProfileName'] != null ? Container(
                      decoration: const BoxDecoration(
                          color: Color(0xff303030),
                          borderRadius: BorderRadius.all(Radius.circular(4))
                      ),
                      child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('Icc Profile', style: TextStyle(fontSize: 12, color: Colors.white70)),
                                  const Spacer(),
                                  isHDR(im.specific?['iccProfileName']) ? Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      color: Colors.black38,
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: const Icon(Icons.hdr_on_rounded, color: Colors.white),
                                  ) : const SizedBox.shrink()
                                ],
                              ),
                              const Gap(6),
                              Column(
                                children: [
                                  // SelectableText(im.specific.toString()),
                                  InfoBox(one: 'Profile Name Raw', two: im.specific?['iccProfileName'], inner: true),
                                  im.specific?['iccCompressionMethod'] != null ? InfoBox(one: 'Compression method', two: im.specific?['iccCompressionMethod'].toString(), inner: true) : const SizedBox.shrink(),
                                  im.specific?['iccProfileSize'] != null ? InfoBox(one: 'Profile size', two: im.specific?['iccProfileSize'].toString(), inner: true) : const SizedBox.shrink(),
                                  im.specific?['iccCmmType'] != null ? InfoBox(one: 'CMM type', two: im.specific?['iccCmmType'], inner: true) : const SizedBox.shrink(),
                                  im.specific?['iccVersion'] != null ? InfoBox(one: 'Version', two: getProfileVersionDescription(im.specific?['iccVersion']), inner: true) : const SizedBox.shrink(),
                                  im.specific?['iccClass'] != null ? InfoBox(one: 'Class', two: im.specific?['iccClass'], inner: true) : const SizedBox.shrink(),
                                  im.specific?['iccColorSpace'] != null ? InfoBox(one: 'Color space', two: im.specific?['iccColorSpace'], inner: true) : const SizedBox.shrink(),
                                  im.specific?['iccConnectionSpace'] != null ? InfoBox(one: 'Connection space', two: im.specific?['iccConnectionSpace'], inner: true) : const SizedBox.shrink(),
                                  im.specific?['iccDateTime'] != null ? InfoBox(one: 'Date Time', two: im.specific?['iccDateTime'], inner: true) : const SizedBox.shrink(),
                                  im.specific?['iccSignature'] != null ? InfoBox(one: 'Signature', two: im.specific?['iccSignature'], inner: true) : const SizedBox.shrink(),
                                  im.specific?['iccPlatform'] != null ? InfoBox(one: 'Platform', two: im.specific?['iccPlatform'].toString(), inner: true) : const SizedBox.shrink(),
                                  im.specific?['iccFlags'] != null ? InfoBox(one: 'Flags', two: im.specific?['iccFlags'].toString(), inner: true) : const SizedBox.shrink(),
                                  im.specific?['iccDeviceMake'] != null ? InfoBox(one: 'Device make', two: im.specific?['iccDeviceMake'].toString(), inner: true) : const SizedBox.shrink(),
                                  im.specific?['iccRenderingIntent'] != null ? InfoBox(one: 'Rendering intent', two: getIndexedDescription(im.specific?['iccRenderingIntent']), inner: true) : const SizedBox.shrink(),
                                  im.specific?['iccXYZValues'] != null ? InfoBox(one: 'XYZ values', two: im.specific?['iccXYZValues'].map((e) => f.format(e)).toString(), inner: true) : const SizedBox.shrink(),
                                  im.specific?['iccTagCount'] != null ? InfoBox(one: 'Tag count', two: im.specific?['iccTagCount'].toString(), inner: true) : const SizedBox.shrink(),
                                  ...im.specific?['iccTagKeys'].map((el){
                                    int pa = int.parse(el.replaceFirst('iccTag', ''));
                                    String t = readTag(im?.specific?[el]);
                                    return InfoBox(one: getTag(pa), two: pa == 1952801640 ? '$t (${getTechnologyDescription(t)})' : t, inner: true);
                                  }),
                                ],
                              )
                            ],
                          )
                      )
                  ) : const SizedBox.shrink(),
                  const Gap(6),
                ],
              )
            ],
          ),
          if (!raw && im.re != RenderEngine.unknown) ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title:  Text('Generation info', style: TextStyle(color: Colors.deepPurple.shade50, fontWeight: FontWeight.w600, fontSize: 18)),
            children: <Widget>[
              InfoBox(one: 'Render engine', two: im.re.toString(), inner: true, withGap: false),
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
                      child: SelectableText(gp!.positive ?? '', style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 10))
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
                      child: SelectableText(gp.negative ?? '', style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 10))
                  )
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InfoBox(one: 'SD checkpoint type', two: '${gp.checkpointType}', withGap: false),
                  InfoBox(one: 'SD checkpoint', two: '${gp.checkpoint} (${gp.checkpointHash})', withGap: false),
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
                                  InfoBox(one: 'Method', two: gp.sampler ?? '', inner: true, withGap: false),
                                  InfoBox(one: 'Steps', two: gp.steps.toString() ?? '', inner: true),
                                  InfoBox(one: 'CFG Scale', two: gp.cfgScale.toString() ?? '', inner: true),
                                  gp.denoisingStrength != null && gp.hiresUpscale == null ? InfoBox(one: 'Denoising strength', two: gp.denoisingStrength.toString() ?? 'none', inner: true) : const SizedBox.shrink(),
                                ],
                              )
                            ],
                          )
                      )
                  ),
                  gp.hiresUpscale != null ? const Gap(4) : const SizedBox.shrink(),
                  gp.hiresUpscale != null ? Container(
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
                                  gp.hiresSampler != null ? InfoBox(one: 'Sampler', two: gp.hiresSampler ?? 'None', inner: true, withGap: false) : const SizedBox.shrink(),
                                  InfoBox(one: 'Denoising strength', two: gp.denoisingStrength.toString() ?? 'none', inner: true),
                                  InfoBox(one: 'Upscaler', two: gp.hiresUpscaler ?? 'None (Lanczos)', inner: true),
                                  InfoBox(one: 'Upscale', two: '${gp.hiresUpscale} (${gp.size.withMultiply(gp.hiresUpscale ?? 0)})' ?? '', inner: true),
                                ],
                              )
                            ],
                          )
                      )
                  ) : const SizedBox.shrink(),
                  const Gap(6),
                  InfoBox(one: 'Width and height', two:  '${gp.size.width}x${gp.size.height}'),
                  const Gap(6),
                  InfoBox(one: 'Version', two: gp.version ?? ''),
                ],
              ),
              gp.rawData != null ? ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 6),
                title: const Text('All parameters', style: TextStyle(fontSize: 13)),
                subtitle: const Text('View raw generation parameters without parsing', style: TextStyle(fontSize: 12, color: Colors.white70)),
                children: <Widget>[
                  Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: const BorderRadius.all(Radius.circular(4))
                      ),
                      child: SelectableText(
                          (gp.rawData ?? '').replaceFirst('parameters', ''),
                          style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 14, color: Colors.white70)
                      )
                  ),
                ],
              ) : const SizedBox.shrink(),
            ],
          ) else const SizedBox.shrink(),
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
  final bool withGap;

  const InfoBox({ Key? key, required this.one, required this.two, this.inner = false, this.withGap = true}): super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
        margin: withGap ? const EdgeInsets.only(top: 4) : null,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
            color: !inner ? Theme.of(context).scaffoldBackgroundColor : const Color(0xff1a1a1a),
            borderRadius: const BorderRadius.all(Radius.circular(4))
        ),
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            child: Row( // This shit killed four hours of my life.
              children: [
                SelectableText(one, style: const TextStyle(fontSize: 12, color: Colors.white70)),
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