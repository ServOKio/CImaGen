
import 'wcg_image_platform_interface.dart';

class WcgImage {
  Future<String?> getPlatformVersion() {
    return WcgImagePlatform.instance.getPlatformVersion();
  }
}
