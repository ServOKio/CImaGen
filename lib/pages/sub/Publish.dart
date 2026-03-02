import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cimagen/modules/AudioController.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:photo_view/photo_view.dart';
import 'package:flutter/foundation.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:settings_ui/settings_ui.dart';

import '../../Utils.dart';

import 'package:image/image.dart' as img;

import '../../components/Animations.dart';
import '../../main.dart';

Future<Uint8List?> _readImageFile(ImageMeta imageMeta) async {
  Uint8List? fi;
  if(imageMeta.mine?.split('/')[1] == 'vnd.adobe.photoshop'){
    fi = imageMeta.fullImage;
  } else {
    try {
      String? pathToImage = imageMeta.fullPath ?? imageMeta.tempFilePath ?? imageMeta.cacheFilePath;
      if(pathToImage == null) return null;
      final Uint8List bytes = await compute(readAsBytesSync, pathToImage);
      img.Image? image = await compute(img.decodeImage, bytes);
      if(image != null){
        return img.encodePng(image);
      }
    } on PathNotFoundException catch (e){
      throw 'We\'ll fix it later.'; // TODO
    }
  }
  return fi;
}

class Publish extends StatefulWidget{
  final ImageMeta? imageMeta;
  const Publish({ super.key, this.imageMeta});

  @override
  _PublishState createState() => _PublishState();
}

class _PublishState extends State<Publish> {

  // Settings
  bool keepData = prefs.getBool('publish_keep_data') ?? false;
  bool encryptData = prefs.getBool('publish_encrypt_data') ?? false;
  bool fuckParsingBots = prefs.getBool('publish_fuck_parsing_bots') ?? true;
  String? password = 'Syka';
  String authorNotes = '''
Copyright: Brack
Social: @BadassFreakingHound
''';

  bool authorship = prefs.getBool('publish_insert_authorship') ?? true;
  bool resizeImage = prefs.getBool('publish_resize_image') ?? true;


  final TransformationController _transformationController = TransformationController();

  bool showOriginalSize = true;
  PhotoViewScaleStateController scaleStateController = PhotoViewScaleStateController();

  late final lotsOfData = _readImageFile(widget.imageMeta!);

  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_){
      showDialog<String>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: ShowUp(
            delay: 100,
            child: Text('Be careful', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600, fontFamily: 'Montserrat')),
          ),
          icon: Icon(Icons.star),
          iconColor: Colors.yellow,
          content: Container(
            constraints: BoxConstraints(maxWidth: 300),
            child: const Text('Be sure to check carefully for any defects and artifacts before publishing - remember that once published to third-party resources, you will not be able to remove it from the users\' minds if they find it', style: TextStyle(fontFamily: 'Montserrat')),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Okay'),
            ),
          ],
        ),
      );
      audioController!.play(NtSound.open);
    });
  }

  Future<void> buildExport() async {
    // 1. Get image and remove all data
    Uint8List? data;
    if(widget.imageMeta!.mine?.split('/')[1] == 'vnd.adobe.photoshop'){
      data = widget.imageMeta!.fullImage;
    } else {
      try {
        String pathToImage = widget.imageMeta!.fullPath ?? widget.imageMeta!.tempFilePath ?? widget.imageMeta!.cacheFilePath ?? '';
        data = await compute(readAsBytesSync, pathToImage);
      } on PathNotFoundException catch (e) {
        throw 'We\'ll fix it later.'; // TODO
      }
    }

    img.Image newImage = img.decodeImage(await stripExif(data!))!;
    if(resizeImage) newImage = img.resize(newImage, width: newImage.height > newImage.width ? 920 : null, height: newImage.width > newImage.height ? 920 : null);
    String finalTextData = '';

    if(keepData){
      if(widget.imageMeta?.generationParams != null && widget.imageMeta!.generationParams?.rawData != null){

        String textData = widget.imageMeta!.generationParams!.rawData!;
        if(encryptData){
          final key = encrypt.Key.fromUtf8('32 xyina');
          final iv = encrypt.IV.fromLength(16);
          final encrypter = encrypt.Encrypter(encrypt.AES(key));
          String encrypted = encrypter.encrypt(textData, iv: iv).base64;

          if(fuckParsingBots){
            finalTextData = '''\n#${authorNotes.split('\n').join('\n#')}
# Encrypted by CImaGen
# $encrypted
white circle, gradient, glass,
BREAK simple background, black background
Negative prompt: red background
Steps: 25, Sampler: Euler a, Schedule type: Automatic, CFG scale: 7, Seed: 88005553535, Size: ${newImage.width}x${newImage.height}, Model hash: 210549a28c, Model: CImaGen_ServOKio, Denoising strength: 0.5, RNG: NV, Hires CFG Scale: 7, Hires upscale: 1.5, Hires upscaler: None, Version: 0.0.4
''';
          } else {
            finalTextData = 'Encrypted by CImaGen. $encrypted';
          }
        }
      } else {
        if(fuckParsingBots){
          finalTextData = '''\n#${authorNotes.split('\n').join('\n#')}
# Encrypted by CImaGen
white circle, gradient, glass,
BREAK simple background, black background
Negative prompt: red background
Steps: 25, Sampler: Euler a, Schedule type: Automatic, CFG scale: 7, Seed: 88005553535, Size: ${newImage.width}x${newImage.height}, Model hash: 210549a28c, Model: CImaGen_ServOKio, Denoising strength: 0.5, RNG: NV, Hires CFG Scale: 7, Hires upscale: 1.5, Hires upscaler: None, Version: 0.0.4
''';
        } else {
          finalTextData = 'Encrypted by CImaGen';
        }
      }

      newImage.textData = {
        'parameters': finalTextData
      };
    }

    File f = File('W:\\${getRandomString(32)}.png');
    await f.writeAsBytes(img.encodePng(newImage));
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const breakpoint = 600.0;
    return Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          backgroundColor: const Color(0xaa000000),
          elevation: 0,
        ),
        endDrawer: screenWidth >= breakpoint ? null : _buildMenu(),
        drawerEdgeDragWidth: screenWidth >= breakpoint ? null : MediaQuery.of(context).size.width / 2,
        body: SafeArea(
            child: screenWidth >= breakpoint ? Row(
              children: [
                Expanded(
                    child: _buildMain()
                ),
                _buildMenu()
              ],
            ) : _buildMain()
        )
    );
  }

  Widget _buildMain(){

    double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    return InteractiveViewer(
      transformationController: _transformationController,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      panEnabled: true,
      scaleFactor: 1000,
      minScale: 0.000001,
      maxScale: double.infinity,
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: Center(
            child: Stack(
              children: [
                ['png', 'jpeg', 'jpg', 'gif', 'webp', 'bmp', 'bmp'].contains(widget.imageMeta!.fileTypeExtension) ? Hero(
                  tag: widget.imageMeta!.fileName,
                  child: Image.file(
                    File(widget.imageMeta!.fullPath ?? widget.imageMeta!.tempFilePath ?? widget.imageMeta!.cacheFilePath ?? 'e.png'),
                    width: widget.imageMeta!.size!.width / devicePixelRatio,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.none,
                    errorBuilder: (context, exception, stack) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 60,
                          ),
                          Text('Error: $exception')
                        ],
                      ),
                    ),
                    frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                      if (wasSynchronouslyLoaded) {
                        return child;
                      } else {
                        return AnimatedOpacity(
                          opacity: frame == null ? 0 : 1,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          child: child,
                        );
                      }
                    },
                  ),
                ) : FutureBuilder(
                    future: lotsOfData,
                    builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
                      Widget children;
                      if (snapshot.hasData) {
                        children = Image.memory(snapshot.data, gaplessPlayback: true);
                      } else if (snapshot.hasError) {
                        children = Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 60,
                              ),
                              Text('Error: ${snapshot.error}')
                            ],
                          ),
                        );
                      } else {
                        children = const CircularProgressIndicator();
                      }
                      return children;
                    }
                ),
                Positioned(
                  bottom: 14,
                  right: 14,
                  width: 120,
                  child: Opacity(opacity: 0.5, child: Image.file(File('F:\\PC2\\documents\\React\\github\\ServOKio-App\\public\\assets\\icons\\1920.png'))),
                )
              ],
            )
        ),
      ),
    );
  }

  Widget _buildMenu(){
    return Container(
      padding: const EdgeInsets.all(6),
      width: 420,
      child: SingleChildScrollView(
        child: Column(
            children: [
              ExpansionTile(
                initiallyExpanded: true,
                tilePadding: EdgeInsets.zero,
                title:  Text('Watermark', style: TextStyle(color: Colors.deepPurple.shade50, fontWeight: FontWeight.w600, fontSize: 18)),
                children: <Widget>[

                ],
              ),
              ExpansionTile(
                initiallyExpanded: true,
                tilePadding: EdgeInsets.zero,
                title:  Text('Data', style: TextStyle(color: Colors.deepPurple.shade50, fontWeight: FontWeight.w600, fontSize: 18)),
                children: <Widget>[
                  SettingsList(
                    darkTheme: SettingsThemeData(
                        leadingIconsColor: Theme.of(context).colorScheme.primary,
                        settingsListBackground: Colors.transparent,
                        titleTextColor: Theme.of(context).colorScheme.primary,
                        tileDescriptionTextColor: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                        settingsTileTextColor: Theme.of(context).textTheme.bodyMedium?.color
                    ),
                    shrinkWrap: true,
                    platform: DevicePlatform.fuchsia,
                    sections: [
                      SettingsSection(
                        title: Text('Encryption'),
                        tiles:[
                          SettingsTile.switchTile(
                            title: const Text('Keep image data'),
                            description: Text('Don\'t remove EXIF metadata which may contain generation parameters'),
                            onToggle: (v) {
                              setState(() {
                                keepData = v;
                              });
                              prefs.setBool('publish_keep_data', v);
                            }, initialValue: keepData,
                          ),
                          SettingsTile.switchTile(
                            enabled: keepData,
                            title: const Text('Encrypt the original data'),
                            description: Text('EXIF metadata (including UserComment and Parameters) which may contain generation parameters'),
                            onToggle: (v) {
                              setState(() {
                                encryptData = v;
                              });
                              prefs.setBool('publish_encrypt_data', v);
                            }, initialValue: encryptData,
                          ),
                          SettingsTile.switchTile(
                            enabled: encryptData && keepData,
                            title: const Text('Fuck bots for parsing'),
                            description: Text('Replace the content of the generation with encrypted data, which will allow bots to parse it'),
                            onToggle: (v) {
                              setState(() {
                                fuckParsingBots = v;
                              });
                              prefs.setBool('publish_fuck_parsing_bots', v);
                            }, initialValue: fuckParsingBots,
                          ),
                        ],
                      ),
                      SettingsSection(
                        title: Text('Custom'),
                        tiles:[
                          SettingsTile.switchTile(
                            title: const Text('Attribution'),
                            description: Text('Indicate authorship, your social networks or something else in the image code'),
                            onToggle: (v) {
                              setState(() {
                                authorship = v;
                              });
                              prefs.setBool('publish_insert_authorship', v);
                            }, initialValue: authorship,
                          ),
                        ],
                      ),
                      SettingsSection(
                        title: Text('Quality'),
                        tiles:[
                          SettingsTile.switchTile(
                            title: const Text('Resize image to 1080px'),
                            description: Text('To avoid revealing the original'),
                            onToggle: (v) {
                              setState(() {
                                resizeImage = v;
                              });
                              prefs.setBool('publish_resize_image', v);
                            }, initialValue: resizeImage,
                          ),
                        ],
                      ),
                    ],
                  )
                ],
              ),
              const Gap(7),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    InfoBox(one: 'Width x Height', two: widget.imageMeta!.size.toString(), withGap: false),
                    InfoBox(one: 'Size', two: readableFileSize(widget.imageMeta!.fileSize ?? 0), withGap: false),
                  ],
                ),
              ),
              const Gap(7),
              ElevatedButton(
                  style: ButtonStyle(
                      foregroundColor: WidgetStateProperty.all<Color>(Theme.of(context).colorScheme.onPrimary),
                      backgroundColor: WidgetStateProperty.all<Color>(Theme.of(context).colorScheme.primary),
                      shape: WidgetStateProperty.all<RoundedRectangleBorder>(const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))))
                  ),
                  onPressed: () => buildExport(),
                  child: Text('Export', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Montserrat'))
              )
            ]
        ),
      ),
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