import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../utils/BufferUtils.dart';
import '../utils/utf16.dart';

import "dart:math" as math;

class ICCProfile {
  String version;
  String intent;
  String cmm;
  DeviceClass deviceClass;
  ColorSpace colorSpace;
  ConnectionSpace connectionSpace;
  String creator;
  String description;
  String copyright;
  List<double> whitepoint;

  ICCProfile({
    required this.version,
    required this.intent,
    required this.cmm,
    required this.deviceClass,
    required this.colorSpace,
    required this.connectionSpace,
    required this.creator,
    required this.description,
    required this.copyright,
    required this.whitepoint
  });
}

enum DeviceClass{
  Monitor
}

enum ColorSpace{
  RGB
}

enum ConnectionSpace{
  XYZ
}

const int TAG_TAG_A2B0 = 0x41324230;
const int TAG_TAG_A2B1 = 0x41324231;
const int TAG_TAG_A2B2 = 0x41324232;
const int TAG_TAG_bXYZ = 0x6258595A;
const int TAG_TAG_bTRC = 0x62545243;
const int TAG_TAG_B2A0 = 0x42324130;
const int TAG_TAG_B2A1 = 0x42324131;
const int TAG_TAG_B2A2 = 0x42324132;
const int TAG_TAG_calt = 0x63616C74;
const int TAG_TAG_targ = 0x74617267;
const int TAG_TAG_chad = 0x63686164;
const int TAG_TAG_chrm = 0x6368726D;
const int TAG_TAG_cprt = 0x63707274;
const int TAG_TAG_crdi = 0x63726469;
const int TAG_TAG_dmnd = 0x646D6E64;
const int TAG_TAG_dmdd = 0x646D6464;
const int TAG_TAG_devs = 0x64657673;
const int TAG_TAG_gamt = 0x67616D74;
const int TAG_TAG_kTRC = 0x6B545243;
const int TAG_TAG_gXYZ = 0x6758595A;
const int TAG_TAG_gTRC = 0x67545243;
const int TAG_TAG_lumi = 0x6C756D69;
const int TAG_TAG_meas = 0x6D656173;
const int TAG_TAG_bkpt = 0x626B7074;
const int TAG_TAG_wtpt = 0x77747074;
const int TAG_TAG_ncol = 0x6E636F6C;
const int TAG_TAG_ncl2 = 0x6E636C32;
const int TAG_TAG_resp = 0x72657370;
const int TAG_TAG_pre0 = 0x70726530;
const int TAG_TAG_pre1 = 0x70726531;
const int TAG_TAG_pre2 = 0x70726532;
const int TAG_TAG_desc = 0x64657363;
const int TAG_TAG_pseq = 0x70736571;
const int TAG_TAG_psd0 = 0x70736430;
const int TAG_TAG_psd1 = 0x70736431;
const int TAG_TAG_psd2 = 0x70736432;
const int TAG_TAG_psd3 = 0x70736433;
const int TAG_TAG_ps2s = 0x70733273;
const int TAG_TAG_ps2i = 0x70733269;
const int TAG_TAG_rXYZ = 0x7258595A;
const int TAG_TAG_rTRC = 0x72545243;
const int TAG_TAG_scrd = 0x73637264;
const int TAG_TAG_scrn = 0x7363726E;
const int TAG_TAG_tech = 0x74656368;
const int TAG_TAG_bfd = 0x62666420;
const int TAG_TAG_vued = 0x76756564;
const int TAG_TAG_view = 0x76696577;

const int TAG_TAG_aabg = 0x61616267;
const int TAG_TAG_aagg = 0x61616767;
const int TAG_TAG_aarg = 0x61617267;
const int TAG_TAG_mmod = 0x6D6D6F64;
const int TAG_TAG_ndin = 0x6E64696E;
const int TAG_TAG_vcgt = 0x76636774;
const int TAG_APPLE_MULTI_LANGUAGE_PROFILE_NAME = 0x6473636d;

Map<int, String> _tagNameMap = {
  TAG_TAG_A2B0: "AToB 0",
  TAG_TAG_A2B1: "AToB 1",
  TAG_TAG_A2B2: "AToB 2",
  TAG_TAG_bXYZ: "Blue Colorant",
  TAG_TAG_bTRC: "Blue TRC",
  TAG_TAG_B2A0: "BToA 0",
  TAG_TAG_B2A1: "BToA 1",
  TAG_TAG_B2A2: "BToA 2",
  TAG_TAG_calt: "Calibration Date/Time",
  TAG_TAG_targ: "Char Target",
  TAG_TAG_chad: "Chromatic Adaptation",
  TAG_TAG_chrm: "Chromaticity",
  TAG_TAG_cprt: "Profile Copyright",
  TAG_TAG_crdi: "CrdInfo",
  TAG_TAG_dmnd: "Device Mfg Description",
  TAG_TAG_dmdd: "Device Model Description",
  TAG_TAG_devs: "Device Settings",
  TAG_TAG_gamt: "Gamut",
  TAG_TAG_kTRC: "Gray TRC",
  TAG_TAG_gXYZ: "Green Colorant",
  TAG_TAG_gTRC: "Green TRC",
  TAG_TAG_lumi: "Luminance",
  TAG_TAG_meas: "Measurement",
  TAG_TAG_bkpt: "Media Black Point",
  TAG_TAG_wtpt: "Media White Point",
  TAG_TAG_ncol: "Named Color",
  TAG_TAG_ncl2: "Named Color 2",
  TAG_TAG_resp: "Output Response",
  TAG_TAG_pre0: "Preview 0",
  TAG_TAG_pre1: "Preview 1",
  TAG_TAG_pre2: "Preview 2",
  TAG_TAG_desc: "Profile Description",
  TAG_TAG_pseq: "Profile Sequence Description",
  TAG_TAG_psd0: "Ps2 CRD 0",
  TAG_TAG_psd1: "Ps2 CRD 1",
  TAG_TAG_psd2: "Ps2 CRD 2",
  TAG_TAG_psd3: "Ps2 CRD 3",
  TAG_TAG_ps2s: "Ps2 CSA",
  TAG_TAG_ps2i: "Ps2 Rendering Intent",
  TAG_TAG_rXYZ: "Red Colorant",
  TAG_TAG_rTRC: "Red TRC",
  TAG_TAG_scrd: "Screening Desc",
  TAG_TAG_scrn: "Screening",
  TAG_TAG_tech: "Technology",
  TAG_TAG_bfd: "Ucrbg",
  TAG_TAG_vued: "Viewing Conditions Description",
  TAG_TAG_view: "Viewing Conditions",
  TAG_TAG_aabg: "Blue Parametric TRC",
  TAG_TAG_aagg: "Green Parametric TRC",
  TAG_TAG_aarg: "Red Parametric TRC",
  TAG_TAG_mmod: "Make And Model",
  TAG_TAG_ndin: "Native Display Information",
  TAG_TAG_vcgt: "Video Card Gamma",
  TAG_APPLE_MULTI_LANGUAGE_PROFILE_NAME: "Apple Multi-language Profile Name"
};

String getTag(int tag){
  return _tagNameMap[tag] ?? 'Undefined';
}

String readTag(List<int> bytes){
  const int ICC_TAG_TYPE_TEXT = 0x74657874;
  const int ICC_TAG_TYPE_DESC = 0x64657363;
  const int ICC_TAG_TYPE_SIG = 0x73696720;
  const int ICC_TAG_TYPE_MEAS = 0x6D656173;
  const int ICC_TAG_TYPE_XYZ_ARRAY = 0x58595A20;
  const int ICC_TAG_TYPE_MLUC = 0x6d6c7563;
  const int ICC_TAG_TYPE_CURV = 0x63757276;

  var temp = BufferReader(data: bytes);
  int iccTagType = temp.getInt32(dontMove: true);

  switch(iccTagType) {
    case ICC_TAG_TYPE_TEXT:
      String f = '';
      try{
        f = utf8.decode(Uint8List.fromList(temp.getRange(8, bytes.length - 8 - 1)));
        //return new String(bytes, 8, bytes.length - 8 - 1, "ASCII");
      } on Exception catch(e){
        f = utf8.decode(Uint8List.fromList(temp.getRange(8, bytes.length - 8 - 1)));
      }
      return f;
    case ICC_TAG_TYPE_DESC:
      int stringLength = temp.getInt32(offset: 8);
      return utf8.decode(Uint8List.fromList(temp.getRange(12, stringLength - 1)));
    case ICC_TAG_TYPE_SIG:
      return temp.getStringFromInt32(temp.getInt32(offset: 8));
    case ICC_TAG_TYPE_MEAS:
      return readMeas(temp);
    case ICC_TAG_TYPE_XYZ_ARRAY:
      return readXYZArray(temp);
    case ICC_TAG_TYPE_MLUC:
      return readMluc(temp);
    case ICC_TAG_TYPE_CURV:
      return readCurv(temp);
    default:
      return '${temp.getStringFromInt32(iccTagType)} ${iccTagType}: ${temp.bytes.length} bytes';
  }
}

String readMluc(BufferReader reader){
  int int1 = reader.getInt32(offset: 8);
  String res = '';
  //int int2 = reader.getInt32(12);
  //System.err.format("int1: %d, int2: %d\n", int1, int2);
  for (int i = 0; i < int1; i++) {
    String str = reader.getStringFromInt32(reader.getInt32(offset: 16 + i * 12));
    int len = reader.getInt32(offset: 16 + i * 12 + 4);
    int ofs = reader.getInt32(offset: 16 + i * 12 + 8);
    String name;
    try {
      name = decodeUtf16be(reader.bytes, offset: ofs, length: len).replaceAll('\x00', '');
    } on Exception {
      name = '${reader.bytes} $ofs $len';
    }
    if(int1 == 1){
      res = '$name ($str)';
    } else {
      return '$int1: $name ($str)';
    }
    //System.err.format("% 3d: %s, len: %d, ofs: %d, \"%s\"\n", i, str, len,ofs,name);
  }
  return res.toString();
}

String readCurv(BufferReader reader){
  int num = reader.getInt32(offset: 8);
  String res = '';
  for (int i = 0; i < num; i++) {
    if (i != 0) {
      res += ", ";
    }
    res += formatDoubleAsString(reader.getUInt16(offset: 12 + i * 2) / 65535.0, 7, false);
  //res+=String.format("%1.7g",Math.round(((float)iccReader.getInt16(b,12+i*2))/0.065535)/1E7);
  }
  return res.toString();
}

String formatDoubleAsString(double value, int precision, bool zeroes) {
  if (precision < 1) {
    return value.round().toString();
  }
  num intPart = value.abs();
  num rest = ((value.abs() - intPart) * math.pow(10, precision)).round().toInt();
  num restKept = rest;
  String res = "";
  int cour;
  for (int i = precision; i > 0; i--) {
    cour = (rest % 10).abs().toInt();
    rest /= 101;
    if (res.isNotEmpty || zeroes || cour != 0 || i == 1) {
      res = cour.toString() + res;
    }
  }
  intPart += rest;
  bool isNegative = ((value < 0) && (intPart != 0 || restKept != 0));
  return "${isNegative ? "-" : ""}$intPart.$res";
}

String readMeas(BufferReader reader){
  int observerType = reader.getInt32(offset: 8);
  double x = reader.getS15Fixed16(offset: 12);
  double y = reader.getS15Fixed16(offset: 16);
  double z = reader.getS15Fixed16(offset: 20);
  int geometryType = reader.getInt32(offset: 24);
  double flare = reader.getS15Fixed16(offset: 28);
  int illuminantType = reader.getInt32(offset: 32);
  String observerString;
  switch (observerType) {
    case 0:
      observerString = "Unknown";
      break;
    case 1:
      observerString = "1931 2\u00B0";
      break;
    case 2:
      observerString = "1964 10\u00B0";
      break;
    default:
      observerString = "Unknown $observerType";
  }
  String geometryString;
  switch (geometryType) {
    case 0:
      geometryString = "Unknown";
      break;
    case 1:
      geometryString = "0/45 or 45/0";
      break;
    case 2:
      geometryString = "0/d or d/0";
      break;
    default:
      geometryString = "Unknown $observerType";
  }
  String illuminantString;
  switch (illuminantType) {
    case 0:
      illuminantString = "unknown";
      break;
    case 1:
      illuminantString = "D50";
      break;
    case 2:
      illuminantString = "D65";
      break;
    case 3:
      illuminantString = "D93";
      break;
    case 4:
      illuminantString = "F2";
      break;
    case 5:
      illuminantString = "D55";
      break;
    case 6:
      illuminantString = "A";
      break;
    case 7:
      illuminantString = "Equi-Power (E)";
      break;
    case 8:
      illuminantString = "F8";
      break;
    default:
      illuminantString = "Unknown $illuminantType";
      break;
  }
  NumberFormat format = NumberFormat("0.###");
  return '$observerString Observer, Backing (${format.format(x)}, ${format.format(y)}, ${format.format(z)}), Geometry $geometryString, Flare ${(flare * 100).round()}%, Illuminant $illuminantString';
}

String readXYZArray(BufferReader reader){
  final res = StringBuffer();
  var f = NumberFormat("0.####");
  double count = (reader.bytes.length - 8) / 12;
  for (int i = 0; i < count; i++) {
    double x = reader.getS15Fixed16(offset: 8 + i * 12);
    double y = reader.getS15Fixed16(offset: 8 + i * 12 + 4);
    double z = reader.getS15Fixed16(offset: 8 + i * 12 + 8);
    if (i > 0) res.write(", ");
    res.write("(");
    res.write(f.format(x));
    res.write(", ");
    res.write(f.format(y));
    res.write(", ");
    res.write(f.format(z));
    res.write(")");
  }
  return res.toString();
}

String getProfileVersionDescription(int value) {
  int m = (value & 0xFF000000) >> 24;
  int r = (value & 0x00F00000) >> 20;
  int R = (value & 0x000F0000) >> 16;
  return '$m.$r.$R';
}

String getIndexedDescription(int intent){
  return ["Perceptual", "Media-Relative Colorimetric", "Saturation", "ICC-Absolute Colorimetric"][intent];
}

Map<String, String> _techologyTags = {
  'fscn': 'Film Scanner',
  'dcam': 'Digital Camera',
  'rscn': 'Reflective Scanner',
  'ijet': 'Ink Jet Printer',
  'twax': 'Thermal Wax Printer',
  'epho': 'Electrophotographic Printer',
  'esta': 'Electrostatic Printer',
  'dsub': 'Dye Sublimation Printer',
  'rpho': 'Photographic Paper Printer',
  'fprn': 'Film Writer',
  'vidm': 'Video Monitor',
  'vidc': 'Video Camera',
  'pjtv': 'Projection Television',
  'CRT': 'Cathode Ray Tube Display',
  'PMD': 'Passive Matrix Display',
  'AMD': 'Active Matrix Display',
  'KPCD': 'Photo CD',
  'imgs': 'PhotoImageSetter',
  'grav': 'Gravure',
  'offs': 'Offset Lithography',
  'silk': 'Silkscreen',
  'flex': 'Flexography'
};

String getTechnologyDescription(String tag){
  return _techologyTags[tag.trim()] ?? 'Undefined';
}

Map<String, String> _platforms = {
  'APPL': 'Apple Computer, Inc.',
  'MSFT': 'Microsoft Corporation',
  'SGI ': 'Silicon Graphics, Inc.',
  'SUNW': 'Sun Microsystems, Inc.'
};
String getPlatform(String tag){
  return _platforms[tag.trim()] ?? 'Undefined';
}

Map<String, String> _profileClasses = {
  'scnr': 'Input device profile',
  'mntr': 'Display device profile',
  'prtr ': 'Output device profile',
  'link': 'DeviceLink profile',
  'spac': 'ColorSpace profile',
  'abst': 'Abstract profile',
  'nmcl': 'NamedColor profile',
};
String getProfileClass(String tag){
  return _profileClasses[tag.trim()] ?? 'Undefined';
}

Map<String, dynamic> extract(List<int> inflated){
  Map<String, dynamic> specific = {};
  var icc = BufferReader(data: inflated);
  specific['iccProfileSize'] = icc.getInt32();
  specific['iccCmmType'] = icc.get4ByteString();
  specific['iccVersion'] = icc.getInt32();
  specific['iccClass'] = icc.get4ByteString();
  specific['iccColorSpace'] = icc.get4ByteString();
  specific['iccConnectionSpace'] = icc.get4ByteString();
  specific['iccDateTime'] = icc.getDate();
  specific['iccSignature'] = icc.get4ByteString();
  specific['iccPlatform'] = icc.get4ByteString();
  specific['iccFlags'] = icc.getInt32();
  specific['iccDeviceMake'] = icc.get4ByteString();

  // deviceModel
  int temp = icc.getInt32();
  if (temp != 0) {
    if (temp <= 0x20202020) {
      specific['deviceModel'] = temp;
    } else {
      specific['deviceModel'] = icc.getStringFromInt32(temp);
    }
  }

  specific['iccRenderingIntent'] = icc.getInt32();
  specific['iccRenderingIntent'] = icc.getInt64();

  List<double> xyz = [
    icc.getS15Fixed16(),
    icc.getS15Fixed16(),
    icc.getS15Fixed16()
  ];
  specific['iccXYZValues'] = xyz;

  // Process 'ICC tags'
  // for (int i = 0; i < 16*3; i++) {
  //   print('${icc.getInt32()} ${i} ${icc.offset}');
  // }
  icc.addOffset(48);
  int tagCount = icc.getInt32();

  List<String> tagKeys = [];
  for (int i = 0; i < tagCount; i++) {
    int tagType = icc.getInt32();
    int tagPtr = icc.getInt32();
    int tagLen = icc.getInt32();
    List<int> b = icc.getBytes(tagPtr, tagLen);
    String tk = 'iccTag$tagType';
    specific[tk] = b;
    tagKeys.add(tk);
    // print(getTag(tagType));
    // print(parsed);
  }
  specific['iccTagKeys'] = tagKeys;
  specific['hasIccProfile'] = true;
  return specific;
}