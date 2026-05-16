import 'dart:convert';
import 'dart:io';

class Adbtool {
  final String adbPath;

  Adbtool({this.adbPath = 'adb'});

  Future<ProcessResult> _run(List<String> args) async {
    return await Process.run(adbPath, args);
  }

  Future<List<String>> getRemoteDevices() async {
    final result = await _run(['devices']);

    if (result.exitCode != 0) {
      throw Exception('ADB error: ${result.stderr}');
    }

    final lines = LineSplitter.split(result.stdout);

    return lines
        .skip(1)
        .where((l) => l.trim().isNotEmpty && l.contains('\tdevice'))
        .map((l) => l.split('\t').first)
        .toList();
  }

  Future<List<Map<String, dynamic>>> getDeviceDisplays(String deviceId) async {
    final result = await _run(['-s', deviceId, 'shell', 'dumpsys display']);

    if (result.exitCode != 0) {
      throw Exception('Failed to get display info');
    }

    final output = result.stdout.toString();

    final displays = <Map<String, dynamic>>[];

    final regex = RegExp(
      r'DisplayDeviceInfo\{.*?displayId (\d+).*?(\d+) x (\d+).*?density (\d+)',
      dotAll: true,
    );

    for (final match in regex.allMatches(output)) {
      displays.add({
        'id': int.parse(match.group(1)!),
        'width': int.parse(match.group(2)!),
        'height': int.parse(match.group(3)!),
        'density': int.parse(match.group(4)!),
      });
    }

    return displays;
  }

  Future<void> setDeviceWallpaper(
      String deviceId,
      int screenId,
      File imageFile,
      ) async {
    final remotePath = '/sdcard/temp_wallpaper.png';

    // 1. Push file
    final push = await _run([
      '-s',
      deviceId,
      'push',
      imageFile.path,
      remotePath,
    ]);

    if (push.exitCode != 0) {
      throw Exception('Failed to push image: ${push.stderr}');
    }

    final cmdWallpaper = await _run([
      '-s',
      deviceId,
      'shell',
      'cmd',
      'wallpaper',
      'set',
      remotePath,
    ]);

    if (cmdWallpaper.exitCode == 0) return;

    // 3. Fallback (open wallpaper picker with image)
    final intent = await _run([
      '-s',
      deviceId,
      'shell',
      'am',
      'start',
      '-a',
      'android.intent.action.ATTACH_DATA',
      '-d',
      'file://$remotePath',
      '-t',
      'image/*',
    ]);

    if (intent.exitCode != 0) {
      throw Exception('Failed to set wallpaper');
    }
  }
}