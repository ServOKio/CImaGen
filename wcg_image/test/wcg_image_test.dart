import 'package:flutter_test/flutter_test.dart';
import 'package:wcg_image/wcg_image.dart';
import 'package:wcg_image/wcg_image_platform_interface.dart';
import 'package:wcg_image/wcg_image_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockWcgImagePlatform
    with MockPlatformInterfaceMixin
    implements WcgImagePlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final WcgImagePlatform initialPlatform = WcgImagePlatform.instance;

  test('$MethodChannelWcgImage is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelWcgImage>());
  });

  test('getPlatformVersion', () async {
    WcgImage wcgImagePlugin = WcgImage();
    MockWcgImagePlatform fakePlatform = MockWcgImagePlatform();
    WcgImagePlatform.instance = fakePlatform;

    expect(await wcgImagePlugin.getPlatformVersion(), '42');
  });
}
