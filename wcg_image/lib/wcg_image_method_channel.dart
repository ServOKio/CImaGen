import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'wcg_image_platform_interface.dart';

/// An implementation of [WcgImagePlatform] that uses method channels.
class MethodChannelWcgImage extends WcgImagePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('wcg_image');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
