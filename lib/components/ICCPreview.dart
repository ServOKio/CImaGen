import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:settings_ui/settings_ui.dart';
import '../Utils.dart';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../utils/ImageManager.dart';

class ICCPreview extends StatefulWidget{
  final ImageMeta imageMeta;
  const ICCPreview(this.imageMeta, { super.key });

  @override
  State<ICCPreview> createState() => _ICCPreviewState();
}

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

class _ICCPreviewState extends State<ICCPreview> {
  bool loaded = false;

  String selectedProfile = '-';
  int renderingIntent = 0;
  bool gamutWarning = true;

  late Uint8List lotsOfData;
  Uint8List? rendered;

  final TransformationController _transformationController = TransformationController();

  List<String> iccProfiles = [];
  String path = 'F:\\PC2\\РабСто\\тестировать\\58146c24217971.57455a52e5971.png';
  String icc_path = 'C:\\Windows\\System32\\spool\\drivers\\color\\Canon PRO-1000 series_Brauberg260Sat.icm';
  String icc_path2 = 'W:\\sRGB_v4_ICC_preference.icc';

  @override
  void initState(){
    super.initState();
    init();
  }

  Future<void> init() async {
    _readImageFile(widget.imageMeta).then((data) async {
      lotsOfData = data!;
      iccProfiles = (await dirContents(Directory("C:\\Windows\\System32\\spool\\drivers\\color"))).whereType<File>().toList().where((element) => ['.icc', '.icm'].contains(p.extension(element.path))).map((ent) => p.basename(ent.path)).toList();
      rebuild();
    });
  }

  Future<void> rebuild() async {
    try {
      Uint8List finalData = lotsOfData;

      if(selectedProfile != '-'){
        String iccProfilePath = p.join("C:\\Windows\\System32\\spool\\drivers\\color", selectedProfile);
        if(renderingIntent == 1){
          finalData = printProofSimulation(lotsOfData, iccProfilePath);
        } else if(renderingIntent == 2){
          finalData = gamutWarningAbsoluteColorimetric(lotsOfData, iccProfilePath);
        }
      }

      setState(() {
        rendered = finalData;
      });
      // setState(() {
      //   loaded = true;
      //   bytes = printProofSimulation(bytes1, icc_path); //relative
      //   bytes2 = gamutWarningAbsoluteColorimetric(bytes1, icc_path); // a c
      // });
    } on PathNotFoundException catch (e){
      throw 'We\'ll fix it later.'; // TODO
    }
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
                Hero(
                  tag: widget.imageMeta.fileName,
                  child: rendered == null ? CircularProgressIndicator() : Image.memory(rendered!,
                    width: widget.imageMeta.size!.width / devicePixelRatio,
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
        child: SettingsList(
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
              title: Text('Color proof'),
              tiles:[
                SettingsTile.navigation(
                  leading: const Icon(Icons.print),
                  title: const Text('Printer Profile'),
                  value: DropdownButton(
                    focusColor: Colors.transparent,
                    underline: const SizedBox.shrink(),
                    value: selectedProfile,
                    items: [
                      DropdownMenuItem<String>(
                        value: '-',
                        child: Text('none', style: TextStyle(fontSize: 12)),
                      ),
                      ...iccProfiles.map((el) => DropdownMenuItem<String>(
                        value: el,
                        child: Text(el, style: TextStyle(fontSize: 12)),
                      ))
                    ],
                    onChanged: (String? value) {
                      if(value != null){
                        setState(() {
                          selectedProfile = value;
                        });
                        rebuild();
                      }
                    },
                  ),
                ),
                SettingsTile.navigation(
                  leading: const Icon(Icons.location_searching ),
                  title: const Text('Rendering Intent'),
                  value: DropdownButton(
                    focusColor: Colors.transparent,
                    underline: const SizedBox.shrink(),
                    value: renderingIntent,
                    items: [
                      DropdownMenuItem<int>(
                        value: 0,
                        child: Text('Default profile', style: TextStyle(fontSize: 12)),
                      ),
                      DropdownMenuItem<int>(
                        value: 1,
                        child: Text('Relative Colorimetric', style: TextStyle(fontSize: 12)),
                      ),
                      DropdownMenuItem<int>(
                        value: 2,
                        child: Text('Absolute Colorimetric', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                    onChanged: (int? value) {
                      if(value != null){
                        setState(() {
                          renderingIntent = value;
                        });
                        rebuild();
                      }
                    },
                  ),
                ),
                SettingsTile.switchTile(
                  leading: const Icon(Icons.contrast),
                  title: const Text('Gamut Warning'),
                  onToggle: (v) {
                    setState(() {
                      gamutWarning = v;
                    });
                    rebuild();
                  },
                  initialValue: gamutWarning,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class IccProfile {
  final List<double> rXYZ, gXYZ, bXYZ;
  final List<double> rTRC, gTRC, bTRC;

  IccProfile(this.rXYZ, this.gXYZ, this.bXYZ,
      this.rTRC, this.gTRC, this.bTRC);
}

IccProfile loadIccProfile(Uint8List icc) {
  double s15Fixed16(int o) =>
      ((icc[o] << 24) | (icc[o+1] << 16) | (icc[o+2] << 8) | icc[o+3]) /
          65536.0;

  List<double> readXYZ(String tag) {
    final off = _findTag(icc, tag);
    return [
      s15Fixed16(off + 8),
      s15Fixed16(off + 12),
      s15Fixed16(off + 16),
    ];
  }

  List<double> readTRC(String tag) {
    final off = _findTag(icc, tag);
    final count = (icc[off + 8] << 8) | icc[off + 9];
    final out = <double>[];
    for (int i = 0; i < count; i++) {
      out.add(
        ((icc[off + 10 + i * 2] << 8) | icc[off + 11 + i * 2]) / 65535.0,
      );
    }
    return out;
  }

  return IccProfile(
    readXYZ('rXYZ'),
    readXYZ('gXYZ'),
    readXYZ('bXYZ'),
    readTRC('rTRC'),
    readTRC('gTRC'),
    readTRC('bTRC'),
  );
}

List<int> applyProofPixel(
    int r, int g, int b,
    IccProfile p,
    ) {
  double lin(int v) =>
      v <= 10 ? v / 3294.6 : math.pow((v / 255.0 + 0.055) / 1.055, 2.4).toDouble();

  final lr = lin(r);
  final lg = lin(g);
  final lb = lin(b);

  final x = lr * p.rXYZ[0] + lg * p.gXYZ[0] + lb * p.bXYZ[0];
  final y = lr * p.rXYZ[1] + lg * p.gXYZ[1] + lb * p.bXYZ[1];
  final z = lr * p.rXYZ[2] + lg * p.gXYZ[2] + lb * p.bXYZ[2];

  double comp(double v) =>
      (v <= 0.0031308) ? v * 12.92 : 1.055 * math.pow(v, 1 / 2.4) - 0.055;

  return [
    (comp(x) * 255).clamp(0, 255).toInt(),
    (comp(y) * 255).clamp(0, 255).toInt(),
    (comp(z) * 255).clamp(0, 255).toInt(),
  ];
}

Uint8List printProofSimulation(
    Uint8List fileContent,
    String iccProfilePath,
    ) {
  final image = img.decodeImage(fileContent);
  if (image == null) {
    throw ArgumentError('Unsupported image format');
  }

  final iccBytes = File(iccProfilePath).readAsBytesSync();

  final bool isMatrixProfile = _hasTag(iccBytes, 'rXYZ');
  final bool isLutProfile =
      _hasTag(iccBytes, 'A2B0') || _hasTag(iccBytes, 'B2A0');

  if (isMatrixProfile) {
    final profile = _loadMatrixProfile(iccBytes);
    _applyMatrixProof(image, profile);
  } else if (isLutProfile) {
    print('lut');
    _applyLutApproximation(image);
  } else {
    // Unknown profile → no-op (sRGB)
  }

  return Uint8List.fromList(img.encodePng(image));
}

class IccMatrixProfile {
  final List<double> rXYZ, gXYZ, bXYZ;
  IccMatrixProfile(this.rXYZ, this.gXYZ, this.bXYZ);
}

IccMatrixProfile _loadMatrixProfile(Uint8List icc) {
  List<double> xyz(String tag) {
    final o = _findTag(icc, tag);
    double f(int i) =>
        ((icc[i] << 24) |
        (icc[i + 1] << 16) |
        (icc[i + 2] << 8) |
        icc[i + 3]) / 65536.0;
    return [f(o + 8), f(o + 12), f(o + 16)];
  }

  return IccMatrixProfile(
    xyz('rXYZ'),
    xyz('gXYZ'),
    xyz('bXYZ'),
  );
}

void _applyMatrixProof(img.Image image, IccMatrixProfile p) {
  for (final pixel in image) {
    double lin(int v) {
      final x = v / 255.0;
      return x <= 0.04045
          ? x / 12.92
          : math.pow((x + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = lin(pixel.r.toInt());
    final g = lin(pixel.g.toInt());
    final b = lin(pixel.b.toInt());

    final x = r * p.rXYZ[0] + g * p.gXYZ[0] + b * p.bXYZ[0];
    final y = r * p.rXYZ[1] + g * p.gXYZ[1] + b * p.bXYZ[1];
    final z = r * p.rXYZ[2] + g * p.gXYZ[2] + b * p.bXYZ[2];

    double comp(double v) =>
        v <= 0.0031308
            ? 12.92 * v
            : 1.055 * math.pow(v, 1 / 2.4) - 0.055;

    pixel
      ..r = (comp(x) * 255).clamp(0, 255).toInt()
      ..g = (comp(y) * 255).clamp(0, 255).toInt()
      ..b = (comp(z) * 255).clamp(0, 255).toInt();
  }
}

void _applyLutApproximation(img.Image image) {
  for (final pixel in image) {
    // Convert to linear
    double lin(int v) =>
        math.pow(v / 255.0, 2.2).toDouble();

    double r = lin(pixel.r.toInt());
    double g = lin(pixel.g.toInt());
    double b = lin(pixel.b.toInt());

    // Simulate ink limit & paper contrast
    r = r * 0.90 + 0.02;
    g = g * 0.90 + 0.02;
    b = b * 0.90 + 0.02;

    // Gamut compression
    final maxC = math.max(r, math.max(g, b));
    if (maxC > 0.85) {
      final scale = 0.85 / maxC;
      r *= scale;
      g *= scale;
      b *= scale;
    }

    int comp(double v) =>
        (math.pow(v.clamp(0.0, 1.0), 1 / 2.2) * 255).toInt();

    pixel
      ..r = comp(r)
      ..g = comp(g)
      ..b = comp(b);
  }
}

bool _hasTag(Uint8List icc, String tag) {
  final count =
  (icc[128] << 24) |
  (icc[129] << 16) |
  (icc[130] << 8) |
  icc[131];

  for (int i = 0; i < count; i++) {
    final o = 132 + i * 12;
    final sig = ascii.decode(icc.sublist(o, o + 4));
    if (sig == tag) return true;
  }
  return false;
}

int _findTag(Uint8List icc, String tag) {
  final count =
  (icc[128] << 24) |
  (icc[129] << 16) |
  (icc[130] << 8) |
  icc[131];

  for (int i = 0; i < count; i++) {
    final o = 132 + i * 12;
    final sig = ascii.decode(icc.sublist(o, o + 4));
    if (sig == tag) {
      return (icc[o + 4] << 24) |
      (icc[o + 5] << 16) |
      (icc[o + 6] << 8) |
      icc[o + 7];
    }
  }
  throw StateError('ICC tag $tag not found');
}

Uint8List gamutWarningAbsoluteColorimetric(
    Uint8List fileContent,
    String iccProfilePath,
    ) {
  final image = img.decodeImage(fileContent);
  if (image == null) {
    throw ArgumentError('Unsupported image format');
  }

  final icc = File(iccProfilePath).readAsBytesSync();

  final isMatrix = _hasTag(icc, 'rXYZ');
  final isLut = _hasTag(icc, 'A2B0') || _hasTag(icc, 'B2A0');

  if (isMatrix) {
    final profile = _loadMatrixProfile(icc);
    _applyMatrixGamutWarning(image, profile);
  } else if (isLut) {
    _applyLutGamutWarningApprox(image);
  }

  return Uint8List.fromList(img.encodePng(image));
}

void _applyMatrixGamutWarning(
    img.Image image,
    IccMatrixProfile p,
    ) {
  for (final pixel in image) {
    final r = _lin(pixel.r.toInt());
    final g = _lin(pixel.g.toInt());
    final b = _lin(pixel.b.toInt());

    final x = r * p.rXYZ[0] + g * p.gXYZ[0] + b * p.bXYZ[0];
    final y = r * p.rXYZ[1] + g * p.gXYZ[1] + b * p.bXYZ[1];
    final z = r * p.rXYZ[2] + g * p.gXYZ[2] + b * p.bXYZ[2];

    final outOfGamut =
        x < 0 || y < 0 || z < 0 ||
            x > 1.0 || y > 1.0 || z > 1.0;

    if (outOfGamut) {
      // Neutral gray warning (Photoshop-like)
      pixel
        ..r = 160
        ..g = 160
        ..b = 160;
    }
  }
}

double _lin(int v) {
  final x = v / 255.0;
  return x <= 0.04045
      ? x / 12.92
      : math.pow((x + 0.055) / 1.055, 2.4).toDouble();
}

void _applyLutGamutWarningApprox(img.Image image) {
  for (final pixel in image) {
    final r = pixel.r / 255.0;
    final g = pixel.g / 255.0;
    final b = pixel.b / 255.0;

    final maxC = math.max(r, math.max(g, b));
    final minC = math.min(r, math.min(g, b));
    final chroma = maxC - minC;

    final outOfGamut = chroma > 0.45 || maxC > 0.92 || minC < 0.02;

    if (outOfGamut) {
      pixel
        ..r = 160
        ..g = 160
        ..b = 160;
    }
  }
}


