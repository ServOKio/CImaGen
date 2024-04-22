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