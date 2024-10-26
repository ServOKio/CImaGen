import 'dart:convert';

import 'package:cimagen/components/Histogram.dart';
import 'package:cimagen/components/PromtAnalyzer.dart';
import 'package:collection/collection.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../Utils.dart';
import '../main.dart';
import '../modules/ICCProfiles.dart';

class MyImageInfo extends StatefulWidget {
  final ImageMeta data;
  const MyImageInfo(this.data, {super.key});

  @override
  State<MyImageInfo> createState() => _MyImageInfoState();
}


class _MyImageInfoState extends State<MyImageInfo> with TickerProviderStateMixin {

  @override
  Widget build(BuildContext context) {
    ImageMeta im = widget.data;
    GenerationParams? gp;
    bool isWebuiForge = false;
    String wForgeV = '';
    String wUIV = '';
    String parentVersion = '';
    bool byImageLib = im.fileTypeExtension != 'png';

    if(im.generationParams != null){
      gp = im.generationParams;
      if(gp?.version != null){
        RegExp ex = RegExp(r'(f[0-9]+\.[0-9]+\.[0-9]+)(v[0-9]+\.[0-9]+\.[0-9]+)(.*)');
        if(ex.hasMatch(gp!.version ?? '')){
          RegExpMatch match = ex.allMatches(gp.version ?? '').first;
          if(match[1] != null && match[1]!.startsWith('f')){
            isWebuiForge = true;
            List<String> pa = match[3]!.split('-');
            wForgeV = match[1]!;
            wUIV = '${match[2]}${pa[0]}';
            parentVersion = pa.getRange(1, pa.length).join('-');
          }
        }
      }
    }

    int bitsPerChannel = byImageLib ? (im.specific?['bitsPerChannel'] ?? 0) : im.specific?['bitDepth'] ?? 0;
    String? colorType = im.specific?['numChannels'] != null ? numChannelsToString(im.specific?['numChannels']) : im.specific?['colorType'] != null ? getColorType(im.specific?['colorType']) : null;
    NumberFormat f = NumberFormat("0.####");
    return SafeArea(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ExpansionTile(
              initiallyExpanded: gp == null && im.specific?['comfUINodes'] == null,
              tilePadding: EdgeInsets.zero,
              title:  Text('Image info', style: TextStyle(color: Colors.deepPurple.shade50, fontWeight: FontWeight.w600, fontSize: 18)),
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(aspectRatio: 16/9, child: Histogram(path: !im.isLocal && im.tempFilePath != null ? im.tempFilePath! : im.fullPath)),
                    InfoBox(one: 'Extension/mine', two: '${im.fileTypeExtension} (${im.mine})'),
                    InfoBox(one: 'Render engine', two: renderEngineToString(im.re)),
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
                                    im.dateModified != null ? InfoBox(one: 'Date modified', two: im.dateModified!.toIso8601String(), inner: true, withGap: false) : const SizedBox.shrink(),
                                    InfoBox(one: 'File size', two: readableFileSize(im.fileSize ?? 0), inner: true),
                                    InfoBox(one: 'File name', two: im.fileName ?? '', inner: true),
                                    im.size != null ? InfoBox(one: 'Size', two: '${im.size.toString()} (${aspectRatioFromSize(im.size!)})', inner: true) : const SizedBox.shrink(),
                                    im.fullPath != null ? InfoBox(one: 'Path', two: im.fullPath, inner: true) : const SizedBox.shrink(),
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
                                    InfoBox(one: 'Bit depth', two: byImageLib ? (im.specific?['bitsPerChannel'].toString() ?? 'None') : im.specific?['bitDepth'].toString() ?? 'None', inner: true),
                                    Row(
                                      children: List<Widget>.generate(bitsPerChannel * bitsPerChannel, (i){
                                        int c = (255 / (bitsPerChannel * bitsPerChannel)).round();
                                        return Expanded(child: Container(
                                            height: 4,
                                            color: Color.fromRGBO(c*i, c*i, c*i, 1)
                                        ));
                                      }),
                                    ),
                                    colorType != null ? InfoBox(one: 'Color type', two: Row(children: [
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
                                    ]), inner: true) : const SizedBox.shrink(),
                                    im.specific?['compression'] != null ? InfoBox(one: 'Compression', two: getCompression(im.specific?['compression']), inner: true) : const SizedBox.shrink(),
                                    im.specific?['filter'] != null ? InfoBox(one: 'Filter', two: getFilterType(im.specific?['filter']), inner: true) : const SizedBox.shrink(),
                                    im.specific?['colorMode'] != null ? InfoBox(one: 'Interlace method', two: getInterlaceMethod(im.specific?['colorMode']), inner: true) : const SizedBox.shrink(),
                                    im.specific?['profileName'] != null ? InfoBox(one: 'Profile Name', two: im.specific?['profileName'], inner: true) : const SizedBox.shrink(),
                                    im.specific?['pixelUnits'] != null ? InfoBox(one: 'Pixel units', two: im.specific?['pixelUnits'] == 1 ? 'Meters' : 'Not specified', inner: true) : const SizedBox.shrink(),
                                    im.specific?['pixelsPerUnitX'] != null ? InfoBox(one: 'Pixels per unit X/Y', two: '${im.specific?['pixelsPerUnitX']}x${im.specific?['pixelsPerUnitY']}', inner: true) : const SizedBox.shrink(),
                                  ],
                                )
                              ],
                            )
                        )
                    ),
                    im.specific?['hasIccProfile'] != null ? const Gap(4) : const SizedBox.shrink(),
                    im.specific?['hasIccProfile'] != null ? Container(
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
                                    const Text('ICC Profile', style: TextStyle(fontSize: 12, color: Colors.white70)),
                                    im.specific?['iccProfileName'] != null ? const Spacer() : const SizedBox.shrink(),
                                    im.specific?['iccProfileName'] != null && isHDR(im.specific?['iccProfileName']) ? Container(
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
                                    im.specific?['iccProfileName'] != null ? InfoBox(one: 'Raw Profile Name', two: im.specific?['iccProfileName'], inner: true) : const SizedBox.shrink(),
                                    im.specific?['iccCompressionMethod'] != null ? InfoBox(one: 'Compression method', two: im.specific?['iccCompressionMethod'].toString(), inner: true) : const SizedBox.shrink(),
                                    im.specific?['iccProfileSize'] != null ? InfoBox(one: 'Profile size', two: im.specific?['iccProfileSize'].toString(), inner: true) : const SizedBox.shrink(),
                                    im.specific?['iccCmmType'] != null ? InfoBox(one: 'CMM type', two: im.specific?['iccCmmType'], inner: true) : const SizedBox.shrink(),
                                    im.specific?['iccVersion'] != null ? InfoBox(one: 'Version', two: getProfileVersionDescription(im.specific?['iccVersion']), inner: true) : const SizedBox.shrink(),
                                    im.specific?['iccClass'] != null ? InfoBox(one: 'Profile Class', two: getProfileClass(im.specific?['iccClass']), inner: true) : const SizedBox.shrink(),
                                    im.specific?['iccColorSpace'] != null ? InfoBox(one: 'Color space', two: im.specific?['iccColorSpace'], inner: true) : const SizedBox.shrink(),
                                    im.specific?['iccConnectionSpace'] != null ? InfoBox(one: 'Connection space', two: im.specific?['iccConnectionSpace'], inner: true) : const SizedBox.shrink(),
                                    im.specific?['iccDateTime'] != null ? InfoBox(one: 'Date Time', two: im.specific?['iccDateTime'], inner: true) : const SizedBox.shrink(),
                                    im.specific?['iccSignature'] != null ? InfoBox(one: 'Signature', two: im.specific?['iccSignature'], inner: true) : const SizedBox.shrink(),
                                    im.specific?['iccPlatform'] != null ? InfoBox(one: 'Platform', two: getPlatform(im.specific?['iccPlatform']), inner: true) : const SizedBox.shrink(),
                                    im.specific?['iccFlags'] != null ? InfoBox(one: 'Flags', two: im.specific?['iccFlags'].toString(), inner: true) : const SizedBox.shrink(),
                                    im.specific?['iccDeviceMake'] != null ? InfoBox(one: 'Device make', two: im.specific?['iccDeviceMake'].toString(), inner: true) : const SizedBox.shrink(),
                                    im.specific?['iccRenderingIntent'] != null ? InfoBox(one: 'Rendering intent', two: getIndexedDescription(im.specific?['iccRenderingIntent']), inner: true) : const SizedBox.shrink(),
                                    im.specific?['iccXYZValues'] != null ? InfoBox(one: 'XYZ values', two: im.specific?['iccXYZValues'].map((e) => f.format(e)).toString(), inner: true) : const SizedBox.shrink(),
                                    im.specific?['iccTagCount'] != null ? InfoBox(one: 'Tag count', two: im.specific?['iccTagCount'].toString(), inner: true) : const SizedBox.shrink(),
                                    ...im.specific?['iccTagKeys'].map((el){
                                      int pa = int.parse(el.replaceFirst('iccTag', ''));
                                      String t = readTag(im.specific?[el]);
                                      return InfoBox(one: getTag(pa), two: pa == 1952801640 ? '$t (${getTechnologyDescription(t)})' : t, inner: true);
                                    }),
                                  ],
                                )
                              ],
                            )
                        )
                    ) : const SizedBox.shrink(),
                    im.specific?['xmpCreatorTool'] != null ? const Gap(4) : const SizedBox.shrink(),
                    im.specific?['xmpCreatorTool'] != null ? Container(
                        decoration: const BoxDecoration(
                            color: Color(0xff303030),
                            borderRadius: BorderRadius.all(Radius.circular(4))
                        ),
                        child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Editor', style: TextStyle(fontSize: 12, color: Colors.white70)),
                                const Gap(6),
                                Column(
                                  children: [
                                    // SelectableText(im.specific.toString()),
                                    InfoBox(one: 'Creator tool', two: im.specific?['xmpCreatorTool'], inner: true),
                                    im.specific?['xmpPhotoshopColorMode'] != null ? InfoBox(one: 'Photoshop colormode', two: xmpColorModeToString(im.specific?['xmpPhotoshopColorMode']), inner: true) : const SizedBox.shrink(),
                                    im.specific?['xmpCreateDate'] != null ? InfoBox(one: 'Create date', two: im.specific?['xmpCreateDate'], inner: true) : const SizedBox.shrink(),
                                    im.specific?['xmpModifyDate'] != null ? InfoBox(one: 'Modify date', two: im.specific?['xmpModifyDate'], inner: true) : const SizedBox.shrink(),
                                    im.specific?['xmpMetadataDate'] != null ? InfoBox(one: 'Metadata date', two: im.specific?['xmpMetadataDate'], inner: true) : const SizedBox.shrink(),
                                    im.specific?['xmpDcFormat'] != null ? InfoBox(one: 'DC format', two: im.specific?['xmpDcFormat'], inner: true) : const SizedBox.shrink(),
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
            if (gp != null) ExpansionTile(
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: true,
              title:  Text('Generation info', style: TextStyle(color: Colors.deepPurple.shade50, fontWeight: FontWeight.w600, fontSize: 18)),
              children: <Widget>[
                im.re != RenderEngine.unknown ? InfoBox(one: 'Render engine', two: renderEngineToString(im.re), withGap: false) : const SizedBox.shrink(),
                im.other?['softwareType'] != null ? InfoBox(one: 'Software', two: softwareToString(Software.values[im.other?['softwareType']])) : const SizedBox.shrink(),
                im.generationParams!.params?['internalbackendtype'] != null ? InfoBox(one: 'Internal Backend Type', two: im.generationParams!.params!['internalbackendtype']) : const SizedBox.shrink(),
                Container(
                    padding: const EdgeInsets.all(4.0),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      border: Border.all(color: Colors.green, width: 1),
                      borderRadius: const BorderRadius.all(Radius.circular(5.0)),
                    ),
                    child: FractionallySizedBox(
                        widthFactor: 1.0,
                        child: SelectableText(gp.positive ?? '', style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 10))
                    )
                ),
                Container(
                    padding: const EdgeInsets.all(4.0),
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
                    InfoBox(one: 'Checkpoint type', two: checkpointTypeToString(gp.checkpointType), withGap: false),
                    InfoBox(one: 'Checkpoint', two: '${gp.checkpoint}${gp.checkpointHash != null ? ' (${gp.checkpointHash})' : ''}', withGap: false),
                    gp.params?['vae'] != null ? InfoBox(one: 'VAE', two: gp.params?['vae']+(gp.params?['vae_hash'] != null ? ' (${gp.params?['vae_hash']})' : '')) : const SizedBox.shrink(),
                    gp.params?['loras'] != null ? Container(
                        margin: const EdgeInsets.only(top: 4),
                        clipBehavior: Clip.hardEdge,
                        decoration: const BoxDecoration(
                            color: Color(0xff1a1a1a),
                            borderRadius: BorderRadius.all(Radius.circular(4))
                        ),
                        child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ...(gp.params?['loras'] as List<dynamic>).mapIndexed((int index, dynamic item) {
                                  return Row(
                                    children: [
                                      const SelectableText('Lora', style: TextStyle(fontSize: 12, color: Colors.white70)),
                                      const Gap(6),
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: SelectableText("$item:${gp!.params?['loraweights'][index]}", style: const TextStyle(fontSize: 13)),
                                          ),
                                        ),
                                      )
                                    ],
                                  );
                                }).toList()
                              ],
                            )
                        )
                    ) : const SizedBox.shrink(),
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
                                    InfoBox(one: 'Sampler name', two: humanizeSamplerName(gp.sampler), inner: true, withGap: false),
                                    gp.params?['scheduler'] != null ? InfoBox(one: 'Scheduler', two: gp.params!['scheduler'], inner: true, withGap: true) : const SizedBox.shrink(),
                                    InfoBox(one: 'Steps', two: gp.steps.toString(), inner: true),
                                    gp.params?['initimagecreativity'] != null ? InfoBox(one: 'Init Image Creativity', two: gp.params!['initimagecreativity'].toString(), inner: true, withGap: true) : const SizedBox.shrink(),
                                    InfoBox(one: 'CFG Scale', two: gp.cfgScale.toString(), inner: true),
                                    gp.denoisingStrength != null && gp.hiresUpscale == null ? InfoBox(one: 'Denoising strength', two: gp.denoisingStrength.toString(), inner: true) : const SizedBox.shrink(),
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
                                    InfoBox(one: 'Denoising strength', two: gp.denoisingStrength.toString(), inner: true),
                                    InfoBox(one: 'Upscaler', two: gp.hiresUpscaler ?? 'None (Lanczos)', inner: true),
                                    InfoBox(one: 'Upscale', two: '${gp.hiresUpscale} (${gp.size.withMultiply(gp.hiresUpscale ?? 0)})' ?? '', inner: true),
                                  ],
                                )
                              ],
                            )
                        )
                    ) : const SizedBox.shrink(),
                    const Gap(6),
                    InfoBox(one: 'Seed', two: '${gp.seed}'),
                    const Gap(6),
                    InfoBox(one: 'Width and height', two: '${gp.size.width}x${gp.size.height}'),
                    const Gap(6),
                    isWebuiForge ? Container(
                        decoration: const BoxDecoration(
                            color: Color(0xff303030),
                            borderRadius: BorderRadius.all(Radius.circular(4))
                        ),
                        child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Version', style: TextStyle(fontSize: 12, color: Colors.white70)),
                                const Gap(6),
                                Column(
                                  children: [
                                    InfoBox(one: 'WebUI Forge', two: wForgeV, inner: true, withGap: false),
                                    InfoBox(one: 'Parent version', two: parentVersion, inner: true),
                                    InfoBox(one: 'WebUI', two: wUIV, inner: true),
                                    InfoBox(one: 'Raw', two: gp.version ?? '')
                                  ],
                                )
                              ],
                            )
                        )
                    ) : InfoBox(one: 'Version', two: gp.version ?? ''),
                  ],
                ),
                const Gap(6),
                Row(
                  children: [
                    ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size.zero, // Set this
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                        ),
                        onPressed: () async {
                          TabController tabController = TabController(length: 3, vsync: this);
                          showDialog<String>(
                            context: context,
                            builder: (BuildContext context) => AlertDialog(
                              title: const Text('Image info'),
                              content: SizedBox(
                                width: MediaQuery.of(context).size.width > 610 ? 610 : MediaQuery.of(context).size.width - 30,
                                height: MediaQuery.of(context).size.height > 700 ? 700 : MediaQuery.of(context).size.height - 30,
                                child: Column(
                                  children: [
                                    TabBar(
                                      controller: tabController,
                                      tabs: const <Widget>[
                                        Tab(
                                          text: 'Text'
                                        ),
                                        Tab(
                                          text: 'Discord',
                                        ),
                                        Tab(
                                          text: 'MD',
                                        ),
                                      ],
                                    ),
                                    Expanded(child: TabBarView(
                                      controller: tabController,
                                      children: <Widget>[
                                        Container(
                                            padding: const EdgeInsets.all(4.0),
                                            margin: const EdgeInsets.only(top: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.1),
                                              border: Border.all(color: Colors.black, width: 1),
                                              borderRadius: const BorderRadius.all(Radius.circular(5.0)),
                                            ),
                                            child: FractionallySizedBox(
                                                widthFactor: 1.0,
                                                child: SelectableText(im.toText(TextType.raw), style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400))
                                            )
                                        ),
                                        Container(
                                            padding: const EdgeInsets.all(4.0),
                                            margin: const EdgeInsets.only(top: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.1),
                                              border: Border.all(color: Colors.black, width: 1),
                                              borderRadius: const BorderRadius.all(Radius.circular(5.0)),
                                            ),
                                            child: FractionallySizedBox(
                                                widthFactor: 1.0,
                                                child: SelectableText(im.toText(TextType.discord), style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400))
                                            )
                                        ),
                                        Container(
                                            padding: const EdgeInsets.all(4.0),
                                            margin: const EdgeInsets.only(top: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.1),
                                              border: Border.all(color: Colors.black, width: 1),
                                              borderRadius: const BorderRadius.all(Radius.circular(5.0)),
                                            ),
                                            child: FractionallySizedBox(
                                                widthFactor: 1.0,
                                                child: SelectableText(im.toText(TextType.md), style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400))
                                            )
                                        ),
                                      ],
                                    ))
                                  ],
                                ),
                              ),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: (){
                                    Navigator.pop(context, 'ok');
                                  },
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: const Text("Copy G.P.", style: TextStyle(fontSize: 12))
                    ),
                    const Gap(8),
                    ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size.zero, // Set this
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                        ),
                        onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder: (context) => PromtAnalyzer(generationParams: gp!))),
                        child: const Text("Analyze promt", style: TextStyle(fontSize: 12))
                    ),
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
                    if(prefs!.getBool('debug') ?? false) ElevatedButton(child: const Text('Parse'), onPressed: (){
                      GenerationParams? gpP = parseSDParameters(gp?.rawData ?? '');
                      if(gpP != null){

                      } else {
                        showDialog<String>(
                          context: context,
                          builder: (BuildContext context) => AlertDialog(
                            content: Text('parseSDParameters returned null'),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () => Navigator.pop(context, 'ok'),
                                child: const Text('ok'),
                              ),
                            ],
                          ),
                        );
                      }
                    })
                  ],
                ) : const SizedBox.shrink(),
              ],
            ) else const SizedBox.shrink(),
            if (im.specific?['comfUINodes'] != null) ExpansionTile(
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: true,
              title:  Text('ComfUI render tree', style: TextStyle(color: Colors.deepPurple.shade50, fontWeight: FontWeight.w600, fontSize: 18)),
              subtitle: const Text('Direct connection of nodes for image generation', style: TextStyle(fontSize: 12, color: Colors.white70)),
              children: [
                ...withSpaceBetween(list: im.specific!['comfUINodes'].map<Widget>((el)=>ComfUINodePreview(data: el)).toList(), element: const Icon(Icons.arrow_downward)),
                im.other?['prompt'] != null ? ExpansionTile(
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
                            im.other?['prompt'] ?? '?',
                            style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 14, color: Colors.white70)
                        )
                    ),
                  ],
                ) : const SizedBox.shrink(),
              ]
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
      ),
    );
  }
}

class ComfUINodePreview extends StatelessWidget{
  final dynamic data;

  const ComfUINodePreview({ Key? key, required this.data}): super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: Color(0xff303030),
          borderRadius: BorderRadius.all(Radius.circular(4))
      ),
      padding: EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data['type'], style: TextStyle(fontSize: 12, color: Colors.white70)),
          const Gap(6),
          Column(
            children: getForType(data)
            // [
            //   InfoBox(one: 'Bit depth', two: 'None', inner: true),
            // ],
          )
        ],
      ),
    );
  }
}

List<Widget> getForType(dynamic data){
  switch (data['type']) {
    case 'EmptyLatentImage':
      return [
        InfoBox(one: 'Width and height', two: '${data['width']}x${data['height']}', inner: true),
        InfoBox(one: 'Batch size', two: data['batchSize'].toString(), inner: true)
      ];
    case 'SDXL Quick Empty Latent (WLSH)':
      return [
        InfoBox(one: 'Resolution', two: data['resolution'], inner: true),
        InfoBox(one: 'Direction', two: data['direction'].toString(), inner: true),
        InfoBox(one: 'Batch size', two: data['batchSize'].toString(), inner: true)
      ];
    case 'LoadImage':
      return [
        InfoBox(one: 'Image', two: data['image'], inner: true),
      ];
    case 'VHS_LoadVideo':
      return [
        InfoBox(one: 'Video', two: data['video'], inner: true),
        InfoBox(one: 'Force rate', two: data['forceRate'].toString(), inner: true),
        InfoBox(one: 'Force size', two: data['forceSize'], inner: true),
        InfoBox(one: 'Frame load cap', two: data['frameLoadCap'].toString(), inner: true),
        InfoBox(one: 'Skip first frames', two: data['skipFirstFrames'].toString(), inner: true),
        InfoBox(one: 'Select Every Nth', two: data['selectEveryNth'].toString(), inner: true),
      ];
    case 'SamplerCustom':
      return [
        InfoBox(one: 'Add noise', two: data['addNoise'] ? 'True' : 'False', inner: true),
        InfoBox(one: 'Noise seed', two: data['noiseSeed'].toString(), inner: true),
        InfoBox(one: 'CFG Scale', two: data['cfg'].toString(), inner: true),
        InfoBox(one: 'Model', two: data['model'], inner: true),
        InfoBox(one: 'Sampler name', two: data['sampler'], inner: true), // TODO normalize
        InfoBox(one: 'Sigmas', two: data['sigmas'], inner: true), // TODO normalize
        Container(
            padding: const EdgeInsets.all(4.0),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              border: Border.all(color: Colors.green, width: 1),
              borderRadius: const BorderRadius.all(Radius.circular(5.0)),
            ),
            child: FractionallySizedBox(
                widthFactor: 1.0,
                child: SelectableText(data['positive'], style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 10))
            )
        ),
        data['negative'].trim() != '' ? Container(
            padding: const EdgeInsets.all(4.0),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              border: Border.all(color: Colors.red, width: 1,),
              borderRadius: const BorderRadius.all(Radius.circular(5.0)),
            ),
            child: FractionallySizedBox(
                widthFactor: 1.0,
                child: SelectableText(data['negative'], style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 10))
            )
        ) : const SizedBox.shrink(),
      ];
    case 'KSampler':
      return [
        InfoBox(one: 'Seed', two: data['seed'].toString(), inner: true),
        InfoBox(one: 'Steps', two: data['steps'].toString(), inner: true),
        InfoBox(one: 'CFG Scale', two: data['cfg'].toString(), inner: true),
        InfoBox(one: 'Sampler name', two: humanizeSamplerName(data['samplerName']), inner: true),
        InfoBox(one: 'Scheduler', two: humanizeSchedulerName(data['scheduler']), inner: true),
        Container(
            margin: const EdgeInsets.only(top: 4),
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(
                color: Color(0xff1a1a1a),
                borderRadius: BorderRadius.all(Radius.circular(4))
            ),
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row( // This shit killed four hours of my life.
                      children: [
                        const SelectableText('Model', style: TextStyle(fontSize: 12, color: Colors.white70)),
                        const Gap(6),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SelectableText(data['model'].runtimeType == String ? data['model'] : data['model'].first, style: const TextStyle(fontSize: 13)),
                            ),
                          ),
                        )
                      ],
                    ),
                    ...data['model'].runtimeType == String ? [] : data['model'].sublist(1).map<Widget>((el)=>Row(
                      children: [
                        const SelectableText('Lora', style: TextStyle(fontSize: 12, color: Colors.white70)),
                        const Gap(6),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SelectableText(el, style: const TextStyle(fontSize: 13)),
                            ),
                          ),
                        )
                      ],
                    )).toList()
                  ],
                )
            )
        ),
        Container(
            padding: const EdgeInsets.all(4.0),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              border: Border.all(color: Colors.green, width: 1),
              borderRadius: const BorderRadius.all(Radius.circular(5.0)),
            ),
            child: FractionallySizedBox(
                widthFactor: 1.0,
                child: SelectableText(data['positive'], style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 10))
            )
        ),
        data['negative'].trim() != '' ? Container(
            padding: const EdgeInsets.all(4.0),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              border: Border.all(color: Colors.red, width: 1,),
              borderRadius: const BorderRadius.all(Radius.circular(5.0)),
            ),
            child: FractionallySizedBox(
                widthFactor: 1.0,
                child: SelectableText(data['negative'], style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 10))
            )
        ) : const SizedBox.shrink(),
      ];
    case 'KSamplerAdvanced':
      return [
        InfoBox(one: 'Add noise', two: data['addNoise'], inner: true),
        InfoBox(one: 'Noise seed', two: data['noiseSeed'].toString(), inner: true),
        InfoBox(one: 'Steps', two: data['steps'].toString(), inner: true),
        InfoBox(one: 'CFG Scale', two: data['cfg'].toString(), inner: true),
        InfoBox(one: 'Sampler name', two: humanizeSamplerName(data['samplerName']), inner: true),
        InfoBox(one: 'Scheduler', two: humanizeSchedulerName(data['scheduler']), inner: true),
        InfoBox(one: 'Start At Step', two: data['startAtStep'].toString(), inner: true),
        InfoBox(one: 'End At Step', two: data['endAtStep'].toString(), inner: true),
        InfoBox(one: 'Return with left over noise', two: data['returnWithLeftoverNoise'], inner: true),
        Container(
            margin: const EdgeInsets.only(top: 4),
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(
                color: Color(0xff1a1a1a),
                borderRadius: BorderRadius.all(Radius.circular(4))
            ),
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row( // This shit killed four hours of my life.
                      children: [
                        const SelectableText('Model', style: TextStyle(fontSize: 12, color: Colors.white70)),
                        const Gap(6),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SelectableText(data['model'].runtimeType == String ? data['model'] : data['model'].first, style: const TextStyle(fontSize: 13)),
                            ),
                          ),
                        )
                      ],
                    ),
                    ...data['model'].runtimeType == String ? [] : data['model'].sublist(1).map<Widget>((el)=>Row(
                      children: [
                        const SelectableText('Lora', style: TextStyle(fontSize: 12, color: Colors.white70)),
                        const Gap(6),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SelectableText(el, style: const TextStyle(fontSize: 13)),
                            ),
                          ),
                        )
                      ],
                    )).toList()
                  ],
                )
            )
        ),
        Container(
            padding: const EdgeInsets.all(4.0),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              border: Border.all(color: Colors.green, width: 1),
              borderRadius: const BorderRadius.all(Radius.circular(5.0)),
            ),
            child: FractionallySizedBox(
                widthFactor: 1.0,
                child: SelectableText(data['positive'], style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 10))
            )
        ),
        data['negative'].trim() != '' ? Container(
            padding: const EdgeInsets.all(4.0),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              border: Border.all(color: Colors.red, width: 1,),
              borderRadius: const BorderRadius.all(Radius.circular(5.0)),
            ),
            child: FractionallySizedBox(
                widthFactor: 1.0,
                child: SelectableText(data['negative'], style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 10))
            )
        ) : const SizedBox.shrink(),
      ];
    case 'KSampler_A1111':
      return [
        InfoBox(one: 'Seed', two: data['seed'].toString(), inner: true),
        InfoBox(one: 'Steps', two: data['steps'].toString(), inner: true),
        InfoBox(one: 'CFG', two: data['cfg'].toString(), inner: true),
        InfoBox(one: 'CFG Scale', two: data['cfgScale'].toString(), inner: true), // wtf
        InfoBox(one: 'Denoise', two: data['denoise'].toString(), inner: true),
        InfoBox(one: 'Sampler name', two: humanizeSamplerName(data['samplerName']), inner: true),
        InfoBox(one: 'Scheduler', two: humanizeSchedulerName(data['scheduler']), inner: true),
        InfoBox(one: 'Start percent', two: data['startPercent'].toString(), inner: true),
        InfoBox(one: 'RM Nearest', two: data['rmNearest'].toString(), inner: true),
        InfoBox(one: 'RM Background', two: data['rmBackground'].toString(), inner: true),
        InfoBox(one: 'Seed mode', two: data['seedMode'], inner: true),
        InfoBox(one: 'ensd', two: data['ensd'].toString(), inner: true),
        InfoBox(one: 'BBox Threshold', two: data['bboxThreshold'].toString(), inner: true),
        InfoBox(one: 'Feather', two: data['feather'].toString(), inner: true),
        InfoBox(one: 'Force Inpaint', two: data['forceInpaint'].toString(), inner: true),
        InfoBox(one: 'Guide size for', two: data['guideSizeFor'].toString(), inner: true),
        InfoBox(one: 'Inpaint model', two: data['inpaintModel'].toString(), inner: true),
        InfoBox(one: 'Noise mask', two: data['noiseMask'].toString(), inner: true),
        InfoBox(one: 'Sam BBox Expansion', two: data['samBboxExpansion'].toString(), inner: true),
        InfoBox(one: 'Sam dilation', two: data['samDilation'].toString(), inner: true),
        InfoBox(one: 'Max length', two: data['maxLength'].toString(), inner: true),
        Container(
            margin: const EdgeInsets.only(top: 4),
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(
                color: Color(0xff1a1a1a),
                borderRadius: BorderRadius.all(Radius.circular(4))
            ),
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row( // This shit killed four hours of my life.
                      children: [
                        const SelectableText('Model', style: TextStyle(fontSize: 12, color: Colors.white70)),
                        const Gap(6),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SelectableText(data['model'].runtimeType == String ? data['model'] : data['model'].first, style: const TextStyle(fontSize: 13)),
                            ),
                          ),
                        )
                      ],
                    ),
                    ...data['model'].runtimeType == String ? [] : data['model'].sublist(1).map<Widget>((el)=>Row(
                      children: [
                        const SelectableText('Lora', style: TextStyle(fontSize: 12, color: Colors.white70)),
                        const Gap(6),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SelectableText(el, style: const TextStyle(fontSize: 13)),
                            ),
                          ),
                        )
                      ],
                    )).toList()
                  ],
                )
            )
        ),
        Container(
            padding: const EdgeInsets.all(4.0),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              border: Border.all(color: Colors.green, width: 1),
              borderRadius: const BorderRadius.all(Radius.circular(5.0)),
            ),
            child: FractionallySizedBox(
                widthFactor: 1.0,
                child: SelectableText(data['positive'], style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 10))
            )
        ),
        data['negative'].trim() != '' ? Container(
            padding: const EdgeInsets.all(4.0),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              border: Border.all(color: Colors.red, width: 1,),
              borderRadius: const BorderRadius.all(Radius.circular(5.0)),
            ),
            child: FractionallySizedBox(
                widthFactor: 1.0,
                child: SelectableText(data['negative'], style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 10))
            )
        ) : const SizedBox.shrink(),
      ];
    case 'VAEDecodeTiled':
      return [
        InfoBox(one: 'Tile size', two: data['tileSize'].toString(), inner: true),
        InfoBox(one: 'VAE', two: data['vae'], inner: true)
      ];
    case 'VAEDecode':
      return [
        InfoBox(one: 'VAE', two: data['vae'], inner: true)
      ];
    case 'VAEEncodeTiled':
      return [
        InfoBox(one: 'Tile size', two: data['tileSize'].toString(), inner: true),
        InfoBox(one: 'VAE', two: data['vae'], inner: true)
      ];
    case 'VAEEncode':
      return [
        InfoBox(one: 'VAE', two: data['vae'], inner: true)
      ];
    case 'ImageScale':
      return [
        InfoBox(one: 'Upscale method', two: data['upscaleMethod'], inner: true),
        InfoBox(one: 'Width and height', two: '${data['width']}x${data['height']}', inner: true),
        InfoBox(one: 'Crop', two: data['crop'].toString(), inner: true),
      ];
    case 'ImageUpscaleWithModel':
      return [
        InfoBox(one: 'Upscale model', two: data['upscaleModel'], inner: true)
      ];
    case 'UltimateSDUpscale':
      return [
        InfoBox(one: 'Upscale by', two: data['upscaleBy'].toString(), inner: true),
        InfoBox(one: 'Seed', two: data['seed'].toString(), inner: true),
        InfoBox(one: 'Steps', two: data['steps'].toString(), inner: true),
        InfoBox(one: 'CFG Scale', two: data['cfg'].toString(), inner: true),
        InfoBox(one: 'Sampler name', two: humanizeSamplerName(data['samplerName']), inner: true),
        InfoBox(one: 'Scheduler', two: humanizeSchedulerName(data['scheduler']), inner: true),
        InfoBox(one: 'Denoise', two: data['denoise'].toString(), inner: true),
        InfoBox(one: 'Mode type', two: data['modeType'], inner: true),
        InfoBox(one: 'Tile width and height', two: '${data['tileWidth']}x${data['tileHeight']}', inner: true),
        InfoBox(one: 'Mask blur', two: data['maskBlur'].toString(), inner: true),
        InfoBox(one: 'Tile padding', two: data['tilePadding'].toString(), inner: true),
        InfoBox(one: 'Seam fix mode', two: data['seamFixMode'], inner: true),
        InfoBox(one: 'Seam fix denoise', two: data['seamFixDenoise'].toString(), inner: true),
        InfoBox(one: 'Seam fix width', two: data['seamFixWidth'].toString(), inner: true),
        InfoBox(one: 'Seam fix mask blur', two: data['seamFixMaskBlur'].toString(), inner: true),
        InfoBox(one: 'Seam fix padding', two: data['seamFixPadding'].toString(), inner: true),
        InfoBox(one: 'Force uniform tiles', two: data['seamFixPadding'].toString(), inner: true),
        Container(
            margin: const EdgeInsets.only(top: 4),
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(
                color: Color(0xff1a1a1a),
                borderRadius: BorderRadius.all(Radius.circular(4))
            ),
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row( // This shit killed four hours of my life.
                      children: [
                        const SelectableText('Model', style: TextStyle(fontSize: 12, color: Colors.white70)),
                        const Gap(6),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SelectableText(data['model'].first, style: const TextStyle(fontSize: 13)),
                            ),
                          ),
                        )
                      ],
                    ),
                    ...data['model'].sublist(1, data['model'].length - 2).map<Widget>((el)=>Row( // This shit killed four hours of my life.
                      children: [
                        const SelectableText('Lora', style: TextStyle(fontSize: 12, color: Colors.white70)),
                        const Gap(6),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SelectableText(el, style: const TextStyle(fontSize: 13)),
                            ),
                          ),
                        )
                      ],
                    )).toList()
                  ],
                )
            )
        ),
        Container(
            padding: const EdgeInsets.all(4.0),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              border: Border.all(color: Colors.green, width: 1),
              borderRadius: const BorderRadius.all(Radius.circular(5.0)),
            ),
            child: FractionallySizedBox(
                widthFactor: 1.0,
                child: SelectableText(data['positive'], style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 10))
            )
        ),
        data['negative'].trim() != '' ? Container(
            padding: const EdgeInsets.all(4.0),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              border: Border.all(color: Colors.red, width: 1,),
              borderRadius: const BorderRadius.all(Radius.circular(5.0)),
            ),
            child: FractionallySizedBox(
                widthFactor: 1.0,
                child: SelectableText(data['negative'], style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 10))
            )
        ) : const SizedBox.shrink(),
        InfoBox(one: 'VAE', two: data['vae'], inner: true),
        InfoBox(one: 'Upscale model', two: data['upscaleModel'], inner: true),
      ];
    case 'NNLatentUpscale':
      return [
        InfoBox(one: 'Version', two: data['version'], inner: true),
        InfoBox(one: 'Upscale', two: data['upscale'].toString(), inner: true),
      ];
    case 'SamplerCustomAdvanced':
      return [
        InfoBox(one: 'Noise', two: data['noise'], inner: true),
        InfoBox(one: 'Guider', two: data['guider'], inner: true),
        InfoBox(one: 'Sampler', two: data['sampler'], inner: true),
        InfoBox(one: 'Sigmas', two: data['sigmas'], inner: true),
      ];
    case 'FaceDetailer':
      return [
        InfoBox(one: 'Guide size', two: data['guideSize'].toString(), inner: true),
        InfoBox(one: 'Guide size for', two: data['guideSizeFor'] ? 'True' : 'False', inner: true),
        InfoBox(one: 'Max size', two: data['maxSize'].toString(), inner: true),
        InfoBox(one: 'Guide size', two: data['guideSize'].toString(), inner: true),
        InfoBox(one: 'Seed', two: data['seed'].toString(), inner: true),
        InfoBox(one: 'Steps', two: data['steps'].toString(), inner: true),
        InfoBox(one: 'CFG Scale', two: data['cfg'].toString(), inner: true),
        InfoBox(one: 'Sampler name', two: humanizeSamplerName(data['samplerName']), inner: true),
        InfoBox(one: 'Scheduler', two: humanizeSchedulerName(data['scheduler']), inner: true),
        InfoBox(one: 'Denoise', two: data['denoise'].toString(), inner: true),
        InfoBox(one: 'Noise mask', two: data['noiseMask'] ? 'True' : 'False', inner: true),
        InfoBox(one: 'Force inpaint', two: data['forceInpaint'] ? 'True' : 'False', inner: true),
        InfoBox(one: 'BBox threshold', two: data['bboxThreshold'].toString(), inner: true),
        InfoBox(one: 'BBox dilation', two: data['bboxDilation'].toString(), inner: true),
        InfoBox(one: 'BBox crop factor', two: data['bboxCropFactor'].toString(), inner: true),
        InfoBox(one: 'Sam detection hint', two: data['samDetectionHint'], inner: true),
        InfoBox(one: 'Sam dilation', two: data['samDilation'].toString(), inner: true),
        InfoBox(one: 'Sam threshold', two: data['samThreshold'].toString(), inner: true),
        InfoBox(one: 'Sam BBox expansion', two: data['samBboxExpansion'].toString(), inner: true),
        InfoBox(one: 'Sam mask hint threshold', two: data['samMaskHintThreshold'].toString(), inner: true),
        InfoBox(one: 'Sam mask hint use negative', two: data['samMaskHintUseNegative'], inner: true), // dolbaeb
        InfoBox(one: 'Drop size', two: data['dropSize'].toString(), inner: true),
        InfoBox(one: 'Wildcard', two: data['wildcard'], inner: true),
        InfoBox(one: 'Cycle', two: data['cycle'].toString(), inner: true),
        InfoBox(one: 'Inpaint model', two: data['inpaintModel'] ? 'True' : 'False', inner: true),
        InfoBox(one: 'Noise mask feather', two: data['noiseMaskFeather'].toString(), inner: true),
        // InfoBox(one: 'Image', two: data['image'].toString(), inner: true),
        Container(
            margin: const EdgeInsets.only(top: 4),
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(
                color: Color(0xff1a1a1a),
                borderRadius: BorderRadius.all(Radius.circular(4))
            ),
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row( // This shit killed four hours of my life.
                      children: [
                        const SelectableText('Model', style: TextStyle(fontSize: 12, color: Colors.white70)),
                        if(data['model'].runtimeType != String) const Gap(6),
                        if(data['model'].runtimeType != String) Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SelectableText(data['model'].first, style: const TextStyle(fontSize: 13)),
                            ),
                          ),
                        )
                      ],
                    ),
                    const SelectableText('Lora', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SelectableText(data['model'].runtimeType != String ? data['model'].sublist(1).join('\n') : data['model'], style: const TextStyle(fontSize: 13)),
                    )
                  ],
                )
            )
        ),
        Container(
            margin: const EdgeInsets.only(top: 4),
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(
                color: Color(0xff1a1a1a),
                borderRadius: BorderRadius.all(Radius.circular(4))
            ),
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SelectableText('Clip', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SelectableText(data['clip'].runtimeType != String ? data['clip'].join('\n') : data['clip'], style: const TextStyle(fontSize: 13)),
                    )
                  ],
                )
            )
        ),
        Container(
            padding: const EdgeInsets.all(4.0),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              border: Border.all(color: Colors.green, width: 1),
              borderRadius: const BorderRadius.all(Radius.circular(5.0)),
            ),
            child: FractionallySizedBox(
                widthFactor: 1.0,
                child: SelectableText(data['positive'], style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 10))
            )
        ),
        data['negative'].trim() != '' ? Container(
            padding: const EdgeInsets.all(4.0),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              border: Border.all(color: Colors.red, width: 1,),
              borderRadius: const BorderRadius.all(Radius.circular(5.0)),
            ),
            child: FractionallySizedBox(
                widthFactor: 1.0,
                child: SelectableText(data['negative'], style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 10))
            )
        ) : const SizedBox.shrink(),
        InfoBox(one: 'VAE', two: data['vae'], inner: true),
        InfoBox(one: 'BBox detector', two: data['bboxDetector'], inner: true),
        if(data['samModelOpt'] != null) InfoBox(one: 'Sam model name', two: data['samModelOpt']['modelName'], inner: true),
        if(data['samModelOpt'] != null) InfoBox(one: 'Sam model device mode', two: data['samModelOpt']['deviceMode'], inner: true),
        InfoBox(one: 'Segm detector opt', two: data['segmDetectorOpt'], inner: true),
      ];
    case 'SaveImage':
      return [
        InfoBox(one: 'Prefix', two: data['path'], inner: true),
      ];
    default:
      return [
        Column(
          children: [
            SelectableText('Error: ${data['type']}'),
            SelectableText(jsonEncode(data))
          ],
        )
      ];
  }
}

List<Widget> withSpaceBetween({required List<Widget> list, required Widget element}) => [
  for (int i = 0; i < list.length; i++)
    ...[
      if (i > 0)
        element,
      list[i],
    ],
];

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