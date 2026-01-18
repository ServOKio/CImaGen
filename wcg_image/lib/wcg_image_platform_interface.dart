import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'wcg_image_method_channel.dart';

abstract class WcgImagePlatform extends PlatformInterface {
  /// Constructs a WcgImagePlatform.
  WcgImagePlatform() : super(token: _token);

  static final Object _token = Object();

  static WcgImagePlatform _instance = MethodChannelWcgImage();

  /// The default instance of [WcgImagePlatform] to use.
  ///
  /// Defaults to [MethodChannelWcgImage].
  static WcgImagePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [WcgImagePlatform] when
  /// they register themselves.
  static set instance(WcgImagePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
