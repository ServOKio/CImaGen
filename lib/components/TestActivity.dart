import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../Utils.dart';

import 'package:image/image.dart' as img;

import 'Animations.dart';

class TestActity extends StatefulWidget{
  const TestActity({ super.key });

  @override
  State<TestActity> createState() => _TestActityState();
}

class _TestActityState extends State<TestActity> {
  bool loaded = false;
  Uint8List? bytes;
  Uint8List? bytes2;
  String path = 'F:\\PC2\\РабСто\\тестировать\\58146c24217971.57455a52e5971.png';
  String icc_path = 'C:\\Windows\\System32\\spool\\drivers\\color\\Canon PRO-1000 series_Brauberg260Sat.icm';
  String icc_path2 = 'W:\\sRGB_v4_ICC_preference.icc';

  Future<void> rebuild() async {
    setState(() {
      loaded = false;
      bytes = null;
      bytes2 = null;
    });

    try {
      final Uint8List bytes1 = await compute(readAsBytesSync, path);
      setState(() {
        loaded = true;
        bytes = printProofSimulation(bytes1, icc_path); //relative
        bytes2 = gamutWarningAbsoluteColorimetric(bytes1, icc_path);
      });
    } on PathNotFoundException catch (e){
      throw 'We\'ll fix it later.'; // TODO
    }
  }

  @override
  Widget build(BuildContext context) {
    AppBar appBar = AppBar(
        title: ShowUp(
          delay: 100,
          child: Text('TestActity', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600, fontFamily: 'Montserrat')),
        ),
        backgroundColor: const Color(0xaa000000),
        elevation: 0,
        actions: []
    );

    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: appBar,
        backgroundColor: Color(0xFFecebe9),
        body: SafeArea(
            child: Row(
              children: [
                SizedBox(
                  width: 700,
                  child: Row(
                    children: [
                      Image.file(File(path), height: 512),
                      if(bytes != null) Image.memory(bytes!, height: 512),
                      if(bytes2 != null) Image.memory(bytes2!, height: 512),
                    ],
                  ),
                ),
                IconButton(onPressed: () => rebuild(), icon: Icon(Icons.edit_road))
              ],
            )
        )
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


