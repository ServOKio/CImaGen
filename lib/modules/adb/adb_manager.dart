import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

import 'exceptions/adb_exception.dart';
import 'models/adb_result.dart';
import 'models/device_info.dart';
import 'models/display_info.dart';

/// Wallpaper target type
enum WallpaperTarget {
  /// Set wallpaper for home screen only
  home,
  /// Set wallpaper for lock screen only
  lock,
  /// Set wallpaper for both home and lock screen (default on most devices)
  both,
}

class WallpaperSetResult {
  final bool success;
  final String? errorMessage;
  final String? method;

  const WallpaperSetResult({
    required this.success,
    this.errorMessage,
    this.method,
  });
}

class _WallpaperAttemptResult {
  final bool success;
  final String method;
  final String? error;
  final String? output;

  const _WallpaperAttemptResult({
    required this.success,
    required this.method,
    this.error,
    this.output,
  });
}

/// Wallpaper setting result
class WallpaperResult {
  final bool success;
  final String? localFilePath;
  final String? remoteFilePath;
  final WallpaperTarget target;
  final String? error;
  final Duration duration;

  const WallpaperResult({
    required this.success,
    this.localFilePath,
    this.remoteFilePath,
    required this.target,
    this.error,
    required this.duration,
  });

  @override
  String toString() {
    if (success) {
      return 'WallpaperResult(success, target: $target, path: $remoteFilePath, time: ${duration.inMilliseconds}ms)';
    }
    return 'WallpaperResult(failed, error: $error)';
  }
}

/// Main ADB manager class for Android device interaction
class AdbManager {
  final String _adbPath;
  String? _selectedDeviceSerial;
  bool _isInitialized = false;

  /// Default timeout for ADB commands
  static const Duration defaultTimeout = Duration(seconds: 30);

  /// Timeout for file transfer operations
  static const Duration transferTimeout = Duration(minutes: 2);

  /// Create ADB manager from platform-tools directory path
  AdbManager(String platformToolsPath) : _adbPath = _getAdbPath(platformToolsPath) {
    if (!File(_adbPath).existsSync()) {
      throw AdbNotFoundException(_getAdbPath(''));
    }
    _isInitialized = true;
  }

  /// Create ADB manager with direct path to adb executable
  AdbManager.fromPath(String adbPath) : _adbPath = adbPath {
    if (!File(_adbPath).existsSync()) {
      throw AdbNotFoundException(adbPath);
    }
    _isInitialized = true;
  }

  static String _getAdbPath(String platformToolsPath) {
    final executable = Platform.isWindows ? 'adb.exe' : 'adb';
    return p.join(platformToolsPath, executable);
  }

  /// Get ADB executable path
  String get adbPath => _adbPath;

  /// Check if manager is properly initialized
  bool get isInitialized => _isInitialized;

  /// Get or set the selected device serial number
  String? get selectedDevice => _selectedDeviceSerial;
  set selectedDevice(String? serial) => _selectedDeviceSerial = serial;

  /// Check if a device is selected
  bool get hasSelectedDevice => _selectedDeviceSerial != null;

  // ==================== Core Command Execution ====================

  /// Execute an ADB command and return the result
  Future<AdbResult> executeCommand(
      List<String> arguments, {
        Duration? timeout = defaultTimeout,
        bool includeDeviceSelector = true,
      }) async {
    if (!_isInitialized) {
      throw const AdbException('ADB Manager not initialized');
    }

    final stopwatch = Stopwatch()..start();
    final cmd = <String>[_adbPath];

    // Add device selector if needed
    if (includeDeviceSelector && _selectedDeviceSerial != null) {
      cmd.addAll(['-s', _selectedDeviceSerial!]);
    }

    cmd.addAll(arguments);

    Process? process;
    try {
      process = await Process.start(
        cmd.first,
        cmd.sublist(1),
        mode: ProcessStartMode.normal,
      );
    } catch (e) {
      stopwatch.stop();
      throw AdbException('Failed to start ADB process: $e');
    }

    final stdoutCompleter = Completer<String>();
    final stderrCompleter = Completer<String>();

    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();

    process.stdout.transform(utf8.decoder).listen(
      stdoutBuffer.write,
      onDone: () {
        if (!stdoutCompleter.isCompleted) {
          stdoutCompleter.complete(stdoutBuffer.toString());
        }
      },
      onError: (e) {
        if (!stdoutCompleter.isCompleted) {
          stdoutCompleter.completeError(e);
        }
      },
    );

    process.stderr.transform(utf8.decoder).listen(
      stderrBuffer.write,
      onDone: () {
        if (!stderrCompleter.isCompleted) {
          stderrCompleter.complete(stderrBuffer.toString());
        }
      },
      onError: (e) {
        if (!stderrCompleter.isCompleted) {
          stderrCompleter.completeError(e);
        }
      },
    );

    try {
      await process.exitCode.timeout(
        timeout ?? defaultTimeout,
        onTimeout: () {
          process?.kill(ProcessSignal.sigkill);
          throw AdbTimeoutException(timeout ?? defaultTimeout);
        },
      );
    } catch (e) {
      stopwatch.stop();
      rethrow;
    }

    final stdout = await stdoutCompleter.future;
    final stderr = await stderrCompleter.future;
    stopwatch.stop();

    return AdbResult(
      exitCode: await process.exitCode,
      stdout: stdout,
      stderr: stderr,
      executionTime: stopwatch.elapsed,
    );
  }

  /// Execute a shell command on the device
  Future<AdbResult> shell(
      String command, {
        Duration? timeout = defaultTimeout,
      }) {
    return executeCommand(['shell', command], timeout: timeout);
  }

  /// Execute command that doesn't require device selection (e.g., adb devices)
  Future<AdbResult> executeGlobalCommand(
      List<String> arguments, {
        Duration? timeout = defaultTimeout,
      }) {
    return executeCommand(arguments,
        timeout: timeout, includeDeviceSelector: false);
  }

  // ==================== Server Management ====================

  /// Start ADB server
  Future<AdbResult> startServer() async {
    return executeGlobalCommand(['start-server']);
  }

  /// Kill ADB server
  Future<AdbResult> killServer() async {
    return executeGlobalCommand(['kill-server']);
  }

  /// Restart ADB server
  Future<void> restartServer() async {
    await killServer();
    await Future.delayed(const Duration(milliseconds: 500));
    await startServer();
  }

  // ==================== Device Management ====================

  /// Get list of connected devices
  Future<List<ConnectedDevice>> getConnectedDevices() async {
    final result = await executeGlobalCommand(['devices', '-l']);

    if (!result.success) {
      throw AdbException('Failed to get devices list',
          stdout: result.stdout, stderr: result.stderr, exitCode: result.exitCode);
    }

    final devices = <ConnectedDevice>[];
    final lines = result.outputLines;

    for (final line in lines) {
      // Skip header line
      if (line.startsWith('List of devices') || line.isEmpty) continue;

      // Parse device line: "serial  state  key:value key:value ..."
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length < 2) continue;

      final serial = parts[0];
      final state = parts[1];

      // Parse additional properties
      String? product, model, device, transportId;
      for (var i = 2; i < parts.length; i++) {
        final kv = parts[i].split(':');
        if (kv.length == 2) {
          switch (kv[0]) {
            case 'product':
              product = kv[1];
              break;
            case 'model':
              model = kv[1];
              break;
            case 'device':
              device = kv[1];
              break;
            case 'transport_id':
              transportId = kv[1];
              break;
          }
        }
      }

      devices.add(ConnectedDevice(
        serialNumber: serial,
        state: state,
        product: product,
        model: model,
        device: device,
        transportId: transportId,
      ));
    }

    return devices;
  }

  /// Get first authorized device
  Future<ConnectedDevice?> getFirstAuthorizedDevice() async {
    final devices = await getConnectedDevices();
    try {
      return devices.firstWhere((d) => d.isAuthorized);
    } catch (_) {
      return null;
    }
  }

  /// Select first available authorized device
  Future<bool> selectFirstDevice() async {
    final device = await getFirstAuthorizedDevice();
    if (device != null) {
      _selectedDeviceSerial = device.serialNumber;
      return true;
    }
    return false;
  }

  /// Connect to a device via TCP/IP
  Future<AdbResult> connectTcpDevice(String host, {int port = 5555}) async {
    return executeGlobalCommand(['connect', '$host:$port']);
  }

  /// Disconnect from a TCP/IP device
  Future<AdbResult> disconnectTcpDevice(String host, {int port = 5555}) async {
    return executeGlobalCommand(['disconnect', '$host:$port']);
  }

  /// Enable TCP/IP mode on connected USB device
  Future<AdbResult> enableTcpIp({int port = 5555}) async {
    _ensureDeviceSelected();
    return executeCommand(['tcpip', '$port'], includeDeviceSelector: true);
  }

  /// Reconnect to USB mode
  Future<AdbResult> reconnectUsb() async {
    return executeCommand(['usb'], includeDeviceSelector: true);
  }

  // ==================== Device Information ====================

  /// Get detailed device information
  Future<AndroidDeviceInfo> getDeviceInfo() async {
    _ensureDeviceSelected();

    // Get all properties in one call for efficiency
    final props = [
      'ro.product.model',
      'ro.product.manufacturer',
      'ro.product.brand',
      'ro.build.version.release',
      'ro.build.version.sdk',
      'ro.build.display.id',
      'ro.build.fingerprint',
      'ro.build.version.security_patch',
      'ro.build.baseband',
      'ro.bootloader',
      'ro.hardware',
      'ro.product.name',
      'ro.product.device',
      'ro.product.board',
      'ro.product.cpu.abi',
      'ro.product.cpu.abilist',
    ];

    final propResults = <String, String>{};

    // Batch getprop call
    final getPropsResult = await shell(
      'getprop',
      timeout: const Duration(seconds: 15),
    );

    if (getPropsResult.success) {
      final propRegex = RegExp(r'\[(.+?)\]:\s*\[(.+?)\]');
      for (final match in propRegex.allMatches(getPropsResult.stdout)) {
        propResults[match.group(1)!] = match.group(2)!;
      }
    }

    // Fallback for individual props if batch failed
    for (final prop in props) {
      if (!propResults.containsKey(prop)) {
        final result = await shell('getprop $prop');
        propResults[prop] = result.output.replaceAll(RegExp(r'^\[|\]$'), '');
      }
    }

    // Get memory info
    int? totalMemory, availableMemory;
    try {
      final memResult = await shell('cat /proc/meminfo');
      if (memResult.success) {
        final memRegex = RegExp(r'(\w+):\s*(\d+)\s*kB');
        for (final match in memRegex.allMatches(memResult.stdout)) {
          final name = match.group(1)!;
          final value = int.parse(match.group(2)!);
          if (name == 'MemTotal') {
            totalMemory = (value / 1024).round();
          } else if (name == 'MemAvailable') {
            availableMemory = (value / 1024).round();
          }
        }
      }
    } catch (_) {}

    // Get battery info
    int? batteryLevel;
    bool? isCharging;
    String? chargingType;
    try {
      final batteryResult = await shell('dumpsys battery');
      if (batteryResult.success) {
        for (final line in batteryResult.outputLines) {
          if (line.startsWith('level:')) {
            batteryLevel = int.tryParse(line.split(':').last.trim());
          } else if (line.startsWith('status:')) {
            final status = line.split(':').last.trim();
            isCharging = status == '2' || status == 'Charging';
          } else if (line.startsWith('plug type:')) {
            final plugType = int.tryParse(line.split(':').last.trim());
            chargingType = switch (plugType) {
              1 => 'AC',
              2 => 'USB',
              3 => 'Wireless',
              _ => null,
            };
          }
        }
      }
    } catch (_) {}

    // Get screen info
    String? screenResolution;
    int? screenDensity, screenDensityDpi;
    try {
      final sizeResult = await shell('wm size');
      if (sizeResult.success && sizeResult.outputContains('x')) {
        final match = RegExp(r'(\d+)x(\d+)').firstMatch(sizeResult.output);
        if (match != null) {
          screenResolution = '${match.group(1)}x${match.group(2)}';
        }
      }

      final densityResult = await shell('wm density');
      if (densityResult.success) {
        final match = RegExp(r'(\d+)').firstMatch(densityResult.output);
        if (match != null) {
          screenDensity = int.tryParse(match.group(1)!);
        }
      }

      final dpiResult = await shell('getprop ro.sf.lcd_density');
      if (dpiResult.success) {
        screenDensityDpi = int.tryParse(dpiResult.output);
      }
    } catch (_) {}

    final supportedAbis = propResults['ro.product.cpu.abilist']?.split(',') ?? [];

    return AndroidDeviceInfo(
      serialNumber: _selectedDeviceSerial!,
      model: propResults['ro.product.model'] ?? 'Unknown',
      manufacturer: propResults['ro.product.manufacturer'] ?? 'Unknown',
      brand: propResults['ro.product.brand'] ?? '',
      androidVersion: propResults['ro.build.version.release'] ?? 'Unknown',
      sdkVersion: propResults['ro.build.version.sdk'] ?? 'Unknown',
      buildNumber: propResults['ro.build.display.id'] ?? '',
      buildFingerprint: propResults['ro.build.fingerprint'] ?? '',
      securityPatch: propResults['ro.build.version.security_patch'] ?? '',
      baseband: propResults['ro.build.baseband'] ?? '',
      bootloader: propResults['ro.bootloader'] ?? '',
      hardware: propResults['ro.hardware'] ?? '',
      product: propResults['ro.product.name'] ?? '',
      device: propResults['ro.product.device'] ?? '',
      board: propResults['ro.product.board'] ?? '',
      cpuAbi: propResults['ro.product.cpu.abi'] ?? '',
      supportedAbis: supportedAbis,
      totalMemoryMb: totalMemory,
      availableMemoryMb: availableMemory,
      batteryLevel: batteryLevel,
      isCharging: isCharging,
      chargingType: chargingType,
      screenResolution: screenResolution,
      screenDensity: screenDensity,
      screenDensityDpi: screenDensityDpi,
    );
  }

  // ==================== Display Information ====================

  /// Get basic display size info
  Future<AndroidDisplayInfo> getDisplaySize() async {
    _ensureDeviceSelected();

    int width = 0, height = 0;

    // Get physical size
    final sizeResult = await shell('wm size');
    if (sizeResult.success) {
      final match = RegExp(r'(\d+)x(\d+)').firstMatch(sizeResult.output);
      if (match != null) {
        width = int.parse(match.group(1)!);
        height = int.parse(match.group(2)!);
      }
    }

    // Get density
    int density = 0;
    final densityResult = await shell('wm density');
    if (densityResult.success) {
      final match = RegExp(r'(\d+)').firstMatch(densityResult.output);
      if (match != null) {
        density = int.parse(match.group(1)!);
      }
    }

    // Calculate DPI from density (density * 160 = DPI)
    final densityDpi = density / 160.0;

    return AndroidDisplayInfo(
      width: width,
      height: height,
      density: density,
      densityDpi: densityDpi,
    );
  }

  /// Get all display information (detailed)
  Future<DeviceDisplaysInfo> getAllDisplays() async {
    _ensureDeviceSelected();

    final displays = <AndroidDisplayInfo>[];
    String physicalSizeOverride = '';
    String densityOverride = '';

    // Get basic size info
    final sizeResult = await shell('wm size');
    if (sizeResult.success) {
      final parts = sizeResult.output.split(RegExp(r'\s+'));
      if (parts.length > 1) {
        physicalSizeOverride = parts.last;
      }
    }

    // Get basic density info
    final densityResult = await shell('wm density');
    if (densityResult.success) {
      final parts = densityResult.output.split(RegExp(r'\s+'));
      if (parts.length > 1) {
        densityOverride = parts.last;
      }
    }

    // Get detailed display info from dumpsys
    final dumpResult = await shell('dumpsys window displays',
        timeout: const Duration(seconds: 10));

    if (dumpResult.success) {
      // Parse display blocks
      final displayRegex = RegExp(
        r'Display #(\d+).*?'
        r'init=(\d+)x(\d+).*?'
        r'density=(\d+).*?'
        r'refreshRate=([\d.]+)',
        dotAll: true,
      );

      for (final match in displayRegex.allMatches(dumpResult.stdout)) {
        final displayId = int.parse(match.group(1)!);
        final width = int.parse(match.group(2)!);
        final height = int.parse(match.group(3)!);
        final density = int.parse(match.group(4)!);
        final refreshRate = (double.parse(match.group(5)!) * 1000).round();

        // Check if primary
        final isPrimary = displayId == 0 ||
            dumpResult.stdout.contains('mDisplayId=$displayId') &&
                !dumpsysContainsDisplayFlag(dumpResult.stdout, displayId, 'FLAG_SUPPORTS_PROTECTED_BUFFERS');

        displays.add(AndroidDisplayInfo(
          displayId: displayId,
          width: width,
          height: height,
          density: density,
          densityDpi: density / 160.0,
          refreshRate: refreshRate,
          isPrimary: isPrimary,
        ));
      }
    }

    // If no displays parsed, fall back to basic info
    if (displays.isEmpty) {
      final basicInfo = await getDisplaySize();
      displays.add(basicInfo);
    }

    return DeviceDisplaysInfo(
      displays: displays,
      physicalSizeOverride: physicalSizeOverride,
      densityOverride: densityOverride,
    );
  }

  bool dumpsysContainsDisplayFlag(String output, int displayId, String flag) {
    // Simplified check
    return output.contains('Display #$displayId') && output.contains(flag);
  }

  /// Get wallpaper dimensions info
  Future<WallpaperDimensions> getWallpaperDimensions() async {
    _ensureDeviceSelected();

    final displayInfo = await getDisplaySize();
    int screenWidth = displayInfo.width;
    int screenHeight = displayInfo.height;

    // Get status bar height
    int statusBarHeight = 0;
    try {
      final result = await shell('wm overscan');
      if (result.success) {
        // Parse overscan: 0,0,0,-48 (top overscan negative = status bar)
        final match = RegExp(r'-?\d+,-?\d+,-?\d+,-?(\d+)').firstMatch(result.output);
        if (match != null) {
          statusBarHeight = int.parse(match.group(1)!).abs();
        }
      }
    } catch (_) {}

    // Try to get status bar height via resources
    try {
      final result = await shell(
        "dumpsys window windows | grep -E 'mStatusBar|StatusBar'",
        timeout: const Duration(seconds: 5),
      );
      if (result.success) {
        final heightMatch = RegExp(r'height=(\d+)').firstMatch(result.stdout);
        if (heightMatch != null) {
          statusBarHeight = int.parse(heightMatch.group(1)!);
        }
      }
    } catch (_) {}

    // Get navigation bar height (approximate)
    int navigationBarHeight = 48; // Default
    try {
      final result = await shell(
        "dumpsys window windows | grep -E 'NavigationBar|mNavigationBar'",
        timeout: const Duration(seconds: 5),
      );
      if (result.success) {
        final heightMatch = RegExp(r'height=(\d+)').firstMatch(result.stdout);
        if (heightMatch != null) {
          navigationBarHeight = int.parse(heightMatch.group(1)!);
        }
      }
    } catch (_) {}

    // Calculate wallpaper dimensions (accounts for parallax)
    final wallpaperWidth = (screenWidth * 1.2).ceil();
    final wallpaperHeight = screenHeight;

    return WallpaperDimensions(
      width: wallpaperWidth,
      height: wallpaperHeight,
      statusBarHeight: statusBarHeight,
      navigationBarHeight: navigationBarHeight,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      density: displayInfo.density,
    );
  }

  // // ==================== Wallpaper Functions ====================
  //
  // /// Set wallpaper from a local file
  // ///
  // /// [localFilePath] - Path to the image file on the computer
  // /// [target] - Which screen to set the wallpaper on
  // /// [remotePath] - Optional custom remote path (default: /sdcard/wallpaper_temp.jpg)
  // /// [deleteAfter] - Whether to delete the file from device after setting (default: true)
  // Future<WallpaperResult> setWallpaper(
  //     String localFilePath, {
  //       WallpaperTarget target = WallpaperTarget.both,
  //       String? remotePath,
  //       bool deleteAfter = true,
  //     }) async {
  //   _ensureDeviceSelected();
  //   final stopwatch = Stopwatch()..start();
  //
  //   // Validate local file
  //   final localFile = File(localFilePath);
  //   if (!localFile.existsSync()) {
  //     stopwatch.stop();
  //     return WallpaperResult(
  //       success: false,
  //       localFilePath: localFilePath,
  //       target: target,
  //       error: 'Local file not found: $localFilePath',
  //       duration: stopwatch.elapsed,
  //     );
  //   }
  //
  //   // Check file size (max 50MB for safety)
  //   final fileSize = await localFile.length();
  //   if (fileSize > 50 * 1024 * 1024) {
  //     stopwatch.stop();
  //     return WallpaperResult(
  //       success: false,
  //       localFilePath: localFilePath,
  //       target: target,
  //       error: 'File too large: ${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB (max 50MB)',
  //       duration: stopwatch.elapsed,
  //     );
  //   }
  //
  //   // Check file extension
  //   final extension = p.extension(localFilePath).toLowerCase();
  //   if (!['.jpg', '.jpeg', '.png', '.webp'].contains(extension)) {
  //     stopwatch.stop();
  //     return WallpaperResult(
  //       success: false,
  //       localFilePath: localFilePath,
  //       target: target,
  //       error: 'Unsupported image format: $extension. Supported: .jpg, .jpeg, .png, .webp',
  //       duration: stopwatch.elapsed,
  //     );
  //   }
  //
  //   // Set default remote path
  //   final remote = remotePath ?? '/sdcard/wallpaper_temp$extension';
  //
  //   try {
  //     // Step 1: Push file to device
  //     final pushResult = await pushFile(localFilePath, remote);
  //     if (!pushResult.success) {
  //       stopwatch.stop();
  //       return WallpaperResult(
  //         success: false,
  //         localFilePath: localFilePath,
  //         remoteFilePath: remote,
  //         target: target,
  //         error: 'Failed to push file to device.\n'
  //             'Exit code: ${pushResult.exitCode}\n'
  //             '${pushResult.stderr.isNotEmpty ? "Error: ${pushResult.stderr}" : pushResult.stdout}',
  //         duration: stopwatch.elapsed,
  //       );
  //     }
  //
  //     // Verify file exists on device
  //     final existsResult = await shell('ls -la "$remote" 2>&1');
  //     if (!existsResult.success || existsResult.outputContains('No such file')) {
  //       stopwatch.stop();
  //       return WallpaperResult(
  //         success: false,
  //         localFilePath: localFilePath,
  //         remoteFilePath: remote,
  //         target: target,
  //         error: 'File push reported success but file not found on device.\n'
  //             'ls output: ${existsResult.output}',
  //         duration: stopwatch.elapsed,
  //       );
  //     }
  //
  //     // Step 2: Try to set wallpaper using appropriate method
  //     WallpaperSetResult setResult;
  //
  //     if (target == WallpaperTarget.lock) {
  //       // Lock screen wallpaper - try multiple methods
  //       setResult = await _setLockWallpaper(remote);
  //     } else {
  //       // Home or both - use wm command
  //       setResult = await _setHomeWallpaper(remote, target);
  //     }
  //
  //     if (!setResult.success) {
  //       // Clean up on failure
  //       if (deleteAfter) {
  //         await shell('rm -f "$remote"').catchError((_) => null);
  //       }
  //       stopwatch.stop();
  //       return WallpaperResult(
  //         success: false,
  //         localFilePath: localFilePath,
  //         remoteFilePath: remote,
  //         target: target,
  //         error: setResult.errorMessage,
  //         duration: stopwatch.elapsed,
  //       );
  //     }
  //
  //     // Clean up remote file
  //     if (deleteAfter) {
  //       await shell('rm -f "$remote"').catchError((_) => null);
  //     }
  //
  //     stopwatch.stop();
  //     return WallpaperResult(
  //       success: true,
  //       localFilePath: localFilePath,
  //       remoteFilePath: remote,
  //       target: target,
  //       duration: stopwatch.elapsed,
  //     );
  //   } on AdbException catch (e) {
  //     // Clean up on exception
  //     if (deleteAfter) {
  //       try {
  //         await shell('rm -f "$remote"');
  //       } catch (_) {}
  //     }
  //     stopwatch.stop();
  //     return WallpaperResult(
  //       success: false,
  //       localFilePath: localFilePath,
  //       remoteFilePath: remote,
  //       target: target,
  //       error: 'ADB Exception: ${e.message}\n${e.stderr ?? ""}',
  //       duration: stopwatch.elapsed,
  //     );
  //   } catch (e) {
  //     if (deleteAfter) {
  //       try {
  //         await shell('rm -f "$remote"');
  //       } catch (_) {}
  //     }
  //     stopwatch.stop();
  //     return WallpaperResult(
  //       success: false,
  //       localFilePath: localFilePath,
  //       remoteFilePath: remote,
  //       target: target,
  //       error: 'Unexpected error: $e',
  //       duration: stopwatch.elapsed,
  //     );
  //   }
  // }
  //
  // /// Set wallpaper for home screen
  // Future<WallpaperSetResult> _setHomeWallpaper(
  //     String remotePath,
  //     WallpaperTarget target,
  //     ) async {
  //   // Method 1: wm set-wallpaper (Android 7.0+, API 24+)
  //   final result1 = await shell('wm set-wallpaper "$remotePath"');
  //   if (result1.success) {
  //     return WallpaperSetResult(
  //       success: true,
  //       method: 'wm set-wallpaper',
  //     );
  //   }
  //
  //   // If failed, try Method 2: Using content provider
  //   final result2 = await _tryContentProviderMethod(remotePath);
  //   if (result2.success) {
  //     return result2;
  //   }
  //
  //   // If all methods failed, return detailed error
  //   return WallpaperSetResult(
  //     success: false,
  //     method: 'multiple attempts',
  //     errorMessage: 'All wallpaper methods failed:\n\n'
  //         'Method 1 (wm set-wallpaper):\n'
  //         '  Exit code: ${result1.exitCode}\n'
  //         '  stdout: ${result1.stdout.trim()}\n'
  //         '  stderr: ${result1.stderr.trim()}\n\n'
  //         'Method 2 (content provider):\n'
  //         '  ${result2.errorMessage ?? "Failed"}',
  //   );
  // }
  //
  // /// Method using content provider
  // Future<WallpaperSetResult> _tryContentProviderMethod(String remotePath) async {
  //   try {
  //     // Get file MIME type
  //     final ext = p.extension(remotePath).toLowerCase();
  //     final mimeType = switch (ext) {
  //       '.png' => 'image/png',
  //       '.webp' => 'image/webp',
  //       _ => 'image/jpeg',
  //     };
  //
  //     final result = await shell(
  //       'content call --uri content://com.android.wallpaper --method set_wallpaper '
  //           '--es file_path "$remotePath" --es mime_type "$mimeType"',
  //     );
  //
  //     if (result.success) {
  //       return WallpaperSetResult(success: true, method: 'content provider');
  //     }
  //
  //     return WallpaperSetResult(
  //       success: false,
  //       method: 'content provider',
  //       errorMessage: 'Exit code: ${result.exitCode}\n'
  //           'stdout: ${result.stdout.trim()}\n'
  //           'stderr: ${result.stderr.trim()}',
  //     );
  //   } catch (e) {
  //     return WallpaperSetResult(
  //       success: false,
  //       method: 'content provider',
  //       errorMessage: 'Exception: $e',
  //     );
  //   }
  // }
  //
  // /// Method using intent (opens wallpaper picker)
  // Future<WallpaperSetResult> _tryIntentMethod(String remotePath) async {
  //   try {
  //     final result = await executeCommand([
  //       'shell',
  //       'am',
  //       'start',
  //       '-a',
  //       'android.intent.action.ATTACH_DATA',
  //       '-d',
  //       'file://$remotePath',
  //       '-t',
  //       'image/*',
  //     ]);
  //
  //     if (result.success) {
  //       return WallpaperSetResult(
  //         success: true,
  //         method: 'intent ATTACH_DATA (may require user interaction)',
  //       );
  //     }
  //
  //     return WallpaperSetResult(
  //       success: false,
  //       method: 'intent ATTACH_DATA',
  //       errorMessage: 'Exit code: ${result.exitCode}\n'
  //           'stdout: ${result.stdout.trim()}\n'
  //           'stderr: ${result.stderr.trim()}',
  //     );
  //   } catch (e) {
  //     return WallpaperSetResult(
  //       success: false,
  //       method: 'intent ATTACH_DATA',
  //       errorMessage: 'Exception: $e',
  //     );
  //   }
  // }
  //
  // /// Method using settings database
  // Future<WallpaperSetResult> _trySettingsMethod(String remotePath) async {
  //   try {
  //     // This method sets the wallpaper via system settings
  //     // It may not work on all devices
  //     final result = await shell('''
  //       FILE="$remotePath"
  //       if [ -f "\$FILE" ]; then
  //         am broadcast -a android.intent.action.SET_WALLPAPER \\
  //           --es filepath "\$FILE" \\
  //           --ez lockscreen true \\
  //           com.android.systemui
  //       else
  //         echo "ERROR: File not found: \$FILE"
  //         exit 1
  //       fi
  //     ''');
  //
  //     if (result.success && !result.outputContains('ERROR')) {
  //       return WallpaperSetResult(success: true, method: 'settings broadcast');
  //     }
  //
  //     return WallpaperSetResult(
  //       success: false,
  //       method: 'settings broadcast',
  //       errorMessage: 'Exit code: ${result.exitCode}\n'
  //           'output: ${result.output.trim()}',
  //     );
  //   } catch (e) {
  //     return WallpaperSetResult(
  //       success: false,
  //       method: 'settings broadcast',
  //       errorMessage: 'Exception: $e',
  //     );
  //   }
  // }
  //
  // /// Set wallpaper for home screen
  // Future<WallpaperResult> setHomeWallpaper(String localFilePath) {
  //   return setWallpaper(localFilePath, target: WallpaperTarget.home);
  // }
  //
  // /// Set wallpaper for lock screen
  // Future<WallpaperResult> setLockWallpaper(String localFilePath) {
  //   return setWallpaper(localFilePath, target: WallpaperTarget.lock);
  // }
  //
  // /// Set lock screen wallpaper (requires different approach)
  // Future<WallpaperSetResult> _setLockWallpaper(String remotePath) async {
  //   // Method 1: wm set-wallpaper --lock (Android 7.0+, API 24+)
  //   final result1 = await shell('wm set-wallpaper --lock "$remotePath"');
  //   if (result1.success) {
  //     return WallpaperSetResult(
  //       success: true,
  //       method: 'wm set-wallpaper --lock',
  //     );
  //   }
  //
  //   // Method 2: Try without --lock flag (some devices don't support it)
  //   if (result1.stderr?.contains('Unknown option') == true ||
  //       result1.stderr?.contains('--lock') == true) {
  //     final result1b = await shell('wm set-wallpaper "$remotePath"');
  //     if (result1b.success) {
  //       return WallpaperSetResult(
  //         success: true,
  //         method: 'wm set-wallpaper (no --lock flag)',
  //       );
  //     }
  //   }
  //
  //   // Method 3: Using intent (opens wallpaper picker - less ideal)
  //   final result3 = await _tryIntentMethod(remotePath);
  //   if (result3.success) {
  //     return result3;
  //   }
  //
  //   // Method 4: Using settings command
  //   final result4 = await _trySettingsMethod(remotePath);
  //   if (result4.success) {
  //     return result4;
  //   }
  //
  //   // All methods failed
  //   return WallpaperSetResult(
  //     success: false,
  //     method: 'multiple attempts',
  //     errorMessage: 'All lock screen wallpaper methods failed:\n\n'
  //         'Method 1 (wm set-wallpaper --lock):\n'
  //         '  Exit code: ${result1.exitCode}\n'
  //         '  stdout: ${result1.stdout.trim()}\n'
  //         '  stderr: ${result1.stderr.trim()}\n\n'
  //         'Method 3 (intent):\n'
  //         '  ${result3.errorMessage ?? "Failed"}\n\n'
  //         'Method 4 (settings):\n'
  //         '  ${result4.errorMessage ?? "Failed"}',
  //   );
  // }
  //
  // /// Set wallpaper for both screens
  // Future<WallpaperResult> setBothWallpapers(String localFilePath) {
  //   return setWallpaper(localFilePath, target: WallpaperTarget.both);
  // }
  //
  // String _getWallpaperCommand(WallpaperTarget target, String remotePath) {
  //   switch (target) {
  //     case WallpaperTarget.home:
  //       return 'wm set-wallpaper "$remotePath"';
  //     case WallpaperTarget.lock:
  //       return 'wm set-wallpaper --lock "$remotePath"';
  //     case WallpaperTarget.both:
  //       return 'wm set-wallpaper "$remotePath"';
  //   }
  // }
  //
  // /// Clear wallpaper (restore default)
  // Future<AdbResult> clearWallpaper({WallpaperTarget target = WallpaperTarget.both}) async {
  //   _ensureDeviceSelected();
  //
  //   final command = switch (target) {
  //     WallpaperTarget.home => 'wm set-wallpaper --disable',
  //     WallpaperTarget.lock => 'wm set-wallpaper --lock --disable',
  //     WallpaperTarget.both => 'wm set-wallpaper --disable',
  //   };
  //
  //   // Try native command first
  //   var result = await shell(command);
  //   if (result.success) return result;
  //
  //   // Fallback: set a solid color wallpaper using am command
  //   try {
  //     result = await shell(
  //       'am broadcast -a android.intent.action.SET_WALLPAPER --ez lockscreen ${target == WallpaperTarget.lock ? 'true' : 'false'}',
  //     );
  //   } catch (_) {}
  //
  //   return result;
  // }

  // ==================== File Operations ====================

  Future<WallpaperResult> setWallpaper(
      String localFilePath, {
        WallpaperTarget target = WallpaperTarget.both,
        String? remotePath,
        bool deleteAfter = true,
      }) async {
    _ensureDeviceSelected();
    final stopwatch = Stopwatch()..start();

    // Validate local file
    final localFile = File(localFilePath);
    if (!localFile.existsSync()) {
      stopwatch.stop();
      return WallpaperResult(
        success: false,
        localFilePath: localFilePath,
        target: target,
        error: 'Local file not found: $localFilePath',
        duration: stopwatch.elapsed,
      );
    }

    final fileSize = await localFile.length();
    if (fileSize > 50 * 1024 * 1024) {
      stopwatch.stop();
      return WallpaperResult(
        success: false,
        localFilePath: localFilePath,
        target: target,
        error: 'File too large: ${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB',
        duration: stopwatch.elapsed,
      );
    }

    final extension = p.extension(localFilePath).toLowerCase();
    if (!['.jpg', '.jpeg', '.png', '.webp'].contains(extension)) {
      stopwatch.stop();
      return WallpaperResult(
        success: false,
        localFilePath: localFilePath,
        target: target,
        error: 'Unsupported format: $extension',
        duration: stopwatch.elapsed,
      );
    }

    final remote = remotePath ?? '/sdcard/cimagen_wallpaper_temp$extension';
    final errors = <String>[];

    try {
      // Step 1: Push file
      final pushResult = await pushFile(localFilePath, remote);
      if (!pushResult.success) {
        stopwatch.stop();
        return WallpaperResult(
          success: false,
          localFilePath: localFilePath,
          remoteFilePath: remote,
          target: target,
          error: 'Push failed: ${pushResult.stderr.isNotEmpty ? pushResult.stderr : pushResult.stdout}',
          duration: stopwatch.elapsed,
        );
      }

      // Step 2: Verify file on device
      final verifyResult = await shell('ls -la "$remote" 2>&1');
      if (verifyResult.outputContains('No such file') || !verifyResult.success) {
        stopwatch.stop();
        return WallpaperResult(
          success: false,
          localFilePath: localFilePath,
          remoteFilePath: remote,
          target: target,
          error: 'File not found on device after push.',
          duration: stopwatch.elapsed,
        );
      }

      // Step 3: Get SDK version
      int sdkVersion = 0;
      try {
        final sdkResult = await shell('getprop ro.build.version.sdk');
        sdkVersion = int.tryParse(sdkResult.output) ?? 0;
      } catch (_) {}

      // Step 4: Try methods in order of reliability
      bool success = false;
      String? usedMethod;

      // === METHOD 1: cmd wallpaper (Try even if not in help - some ROMs hide it) ===
      if (!success && sdkVersion >= 29) {
        final result = await _tryCmdWallpaper(remote, target);
        if (result.success) {
          success = true;
          usedMethod = result.method;
        } else {
          errors.add('cmd wallpaper: ${result.error}');
        }
      }

      // === METHOD 2: wm set-wallpaper (Try even if not in help) ===
      if (!success) {
        final result = await _tryWmSetWallpaper(remote, target);
        if (result.success) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (await _verifyWallpaperChanged()) {
            success = true;
            usedMethod = result.method;
          } else {
            errors.add('wm set-wallpaper: Ran without error but wallpaper unchanged (ROM blocked it)');
          }
        } else {
          errors.add('wm set-wallpaper: ${result.error}');
        }
      }

      // === METHOD 3: UI Simulation (Nuclear option for locked ROMs like Nubia) ===
      if (!success) {
        final result = await _tryServiceCallWallpaper(remote, target);
        if (result.success) {
          success = true;
          usedMethod = result.method;
        } else {
          errors.add('UI Simulation: ${result.error}');
        }
      }

      // Clean up
      if (deleteAfter) {
        await shell('rm -f "$remote"').catchError((_) => null);
      }

      stopwatch.stop();

      if (success) {
        return WallpaperResult(
          success: true,
          localFilePath: localFilePath,
          remoteFilePath: remote,
          target: target,
          duration: stopwatch.elapsed,
        );
      }

      return WallpaperResult(
        success: false,
        localFilePath: localFilePath,
        remoteFilePath: remote,
        target: target,
        error: 'All methods failed (SDK $sdkVersion). ROM has blocked wallpaper commands.\n\n'
            '${errors.map((e) => '• $e').join('\n')}',
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      if (deleteAfter) {
        try { await shell('rm -f "$remote"'); } catch (_) {}
      }
      stopwatch.stop();
      return WallpaperResult(
        success: false,
        localFilePath: localFilePath,
        remoteFilePath: remote,
        target: target,
        error: 'Unexpected error: $e',
        duration: stopwatch.elapsed,
      );
    }
  }

  Future<_WallpaperAttemptResult> _tryCmdWallpaper(
      String remotePath,
      WallpaperTarget target,
      ) async {
    try {
      final flag = switch (target) {
        WallpaperTarget.home => '2',
        WallpaperTarget.lock => '1',
        WallpaperTarget.both => '3',
      };

      // Try with flag
      var result = await shell('cmd wallpaper set-file "$remotePath" $flag 2>&1');
      if (result.success &&
          !result.errorContains('Error') &&
          !result.errorContains('Unknown') &&
          !result.errorContains('Invalid')) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (await _verifyWallpaperChanged()) {
          return _WallpaperAttemptResult(success: true, method: 'cmd wallpaper set-file', output: result.output);
        }
      }

      // Try without flag
      result = await shell('cmd wallpaper set-file "$remotePath" 2>&1');
      if (result.success &&
          !result.errorContains('Error') &&
          !result.errorContains('Unknown')) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (await _verifyWallpaperChanged()) {
          return _WallpaperAttemptResult(success: true, method: 'cmd wallpaper set-file (no flag)', output: result.output);
        }
      }

      return _WallpaperAttemptResult(
        success: false,
        method: 'cmd wallpaper',
        error: 'Command failed or wallpaper unchanged',
      );
    } catch (e) {
      return _WallpaperAttemptResult(success: false, method: 'cmd wallpaper', error: e.toString());
    }
  }

  /// METHOD 2: wm set-wallpaper (blind attempt)
  Future<_WallpaperAttemptResult> _tryWmSetWallpaper(
      String remotePath,
      WallpaperTarget target,
      ) async {
    try {
      final command = switch (target) {
        WallpaperTarget.home => 'wm set-wallpaper "$remotePath"',
        WallpaperTarget.lock => 'wm set-wallpaper --lock "$remotePath"',
        WallpaperTarget.both => 'wm set-wallpaper "$remotePath"',
      };

      final result = await shell('$command 2>&1');

      if (result.success && !result.errorContains('Unknown') && !result.errorContains('Invalid')) {
        return _WallpaperAttemptResult(
          success: true,
          method: 'wm set-wallpaper',
          output: result.output,
        );
      }

      return _WallpaperAttemptResult(
        success: false,
        method: 'wm set-wallpaper',
        error: 'exit=${result.exitCode}, stderr=${result.stderr.trim().isEmpty ? "(empty)" : result.stderr.trim()}',
      );
    } catch (e) {
      return _WallpaperAttemptResult(success: false, method: 'wm set-wallpaper', error: e.toString());
    }
  }

  /// METHOD 3: UI Simulation - Opens crop UI and auto-taps "Set" button
  /// This is the ONLY reliable method on ROMs that strip wallpaper commands
  /// METHOD 3: UI Simulation - Directly launches the crop activity by name
  Future<_WallpaperAttemptResult> _tryServiceCallWallpaper(
      String remotePath,
      WallpaperTarget target,
      ) async {
    try {
      final targetFlag = switch (target) {
        WallpaperTarget.home => 2,  // FLAG_SYSTEM
        WallpaperTarget.lock => 1,  // FLAG_LOCK
        WallpaperTarget.both => 3,  // FLAG_SYSTEM | FLAG_LOCK
      };

      // Escape single quotes in path for safe shell injection
      final safePath = remotePath.replaceAll("'", "'\\''");

      // This script does magic:
      // 1. Opens the image as a Linux file descriptor (fd 3)
      // 2. Brute-forces the transaction ID for setWallpaper (usually 8-15)
      // 3. Passes the FD directly to the Java system service
      // 4. Waits for the background thread to read the image
      final script = '''
        REMOTE='$safePath'
        REQUESTED_TARGET='$targetFlag'
        
        # 1. Open file descriptor 3 for reading the image
        exec 3<"\$REMOTE"
        if [ \$? -ne 0 ]; then
          echo "ERROR: Cannot open file descriptor"
          exit 1
        fi
        
        FOUND_ID=""
        
        # 2. Scan transaction IDs. 
        # We use TARGET=2 (HOME) for scanning because it is universally supported
        # and won't throw argument-specific errors that might hide the correct ID.
        for ID in \$(seq 1 40); do
          RES=\$(service call wallpaper \$ID i32 0 fd 3 s16 "cimagen" i32 0 i32 2 i32 0 2>&1)
          
          # If it doesn't throw "Unknown transaction", we found the right method!
          if ! echo "\$RES" | grep -qiE "unknown|code -|dead object"; then
            FOUND_ID=\$ID
            echo "FOUND_ID: \$ID"
            break
          fi
        done
        
        if [ -z "\$FOUND_ID" ]; then
          exec 3>&-
          echo "ERROR: setWallpaper transaction ID not found"
          exit 1
        fi
        
        # 3. CRITICAL: Wait for the Java background thread to finish reading 
        # the image from the file descriptor before we close it!
        sleep 2.5
        
        # 4. If the user requested LOCK or BOTH, we must call it again because 
        # our scan used HOME (2) to safely find the ID.
        if [ "\$REQUESTED_TARGET" != "2" ]; then
          # Close old FD and open a new one
          exec 3>&-
          exec 3<"\$REMOTE"
          
          FINAL_RES=\$(service call wallpaper \$FOUND_ID i32 0 fd 3 s16 "cimagen" i32 0 i32 \$REQUESTED_TARGET i32 0 2>&1)
          
          # Check if the ROM supports this specific target (some disable lock screen changes)
          if echo "\$FINAL_RES" | grep -qiE "exception|error|unsupported"; then
            exec 3>&-
            echo "ERROR: ROM blocked target \$REQUESTED_TARGET. Output: \$FINAL_RES"
            exit 1
          fi
          
          # Wait for final read
          sleep 2.5
        fi
        
        # Clean up file descriptor
        exec 3>&-
        echo "SERVICE_CALL_SUCCESS"
      ''';

      final result = await shell(script);

      // Parse results
      if (result.outputContains('SERVICE_CALL_SUCCESS')) {
        final idMatch = RegExp(r'FOUND_ID: (\d+)').firstMatch(result.output);
        return _WallpaperAttemptResult(
          success: true,
          method: 'Service Call Hack (Transaction ${idMatch?.group(1) ?? "?"})',
          output: 'Directly injected image stream into WallpaperManagerService.',
        );
      }

      if (result.outputContains('ERROR:')) {
        final errMatch = RegExp(r'ERROR: (.+)').firstMatch(result.output);
        return _WallpaperAttemptResult(
          success: false,
          method: 'service call',
          error: errMatch?.group(1) ?? 'Unknown error',
        );
      }

      return _WallpaperAttemptResult(
        success: false,
        method: 'service call',
        error: 'Unexpected output: ${result.output}',
      );
    } catch (e) {
      return _WallpaperAttemptResult(
        success: false,
        method: 'service call',
        error: 'Exception: $e',
      );
    }
  }

  /// Verify wallpaper actually changed
  Future<bool> _verifyWallpaperChanged() async {
    try {
      final result = await shell('dumpsys wallpaper 2>&1 | head -30');
      if (!result.success) return false;

      final output = result.stdout.toLowerCase();

      // If a custom image is set, mName usually contains a file path or ID
      // Default wallpapers have mName empty or point to a resource
      return output.contains('mname = /') ||
          output.contains('crop') ||
          output.contains('wallpaper_temp');
    } catch (_) {
      return false;
    }
  }

  /// Clear wallpaper
  Future<AdbResult> clearWallpaper({WallpaperTarget target = WallpaperTarget.both}) async {
    _ensureDeviceSelected();

    // Try cmd wallpaper clear first
    final cmdResult = await shell('cmd wallpaper clear 2>&1');
    if (cmdResult.success && !cmdResult.errorContains('Error') && !cmdResult.errorContains('Unknown')) {
      return cmdResult;
    }

    // Fallback to wm
    final command = switch (target) {
      WallpaperTarget.home => 'wm set-wallpaper --disable',
      WallpaperTarget.lock => 'wm set-wallpaper --lock --disable',
      WallpaperTarget.both => 'wm set-wallpaper --disable',
    };
    return shell(command);
  }

  /// Convenience methods
  Future<WallpaperResult> setHomeWallpaper(String localFilePath) =>
      setWallpaper(localFilePath, target: WallpaperTarget.home);

  Future<WallpaperResult> setLockWallpaper(String localFilePath) =>
      setWallpaper(localFilePath, target: WallpaperTarget.lock);

  Future<WallpaperResult> setBothWallpapers(String localFilePath) =>
      setWallpaper(localFilePath, target: WallpaperTarget.both);

  Future<Map<String, String>> getCurrentWallpaperInfo() async {
    _ensureDeviceSelected();

    final info = <String, String>{};

    try {
      final result = await shell('dumpsys wallpaper 2>&1');
      if (!result.success) return info;

      // Parse wallpaper info
      for (final line in result.outputLines) {
        if (line.contains('mCurrentWallpaper') ||
            line.contains('mLockWallpaper') ||
            line.contains('wallpaperComponent') ||
            line.contains('mWidth') ||
            line.contains('mHeight') ||
            line.contains('mName')) {
          final parts = line.split('=');
          if (parts.length >= 2) {
            info[parts[0].trim()] = parts.sublist(1).join('=').trim();
          }
        }
      }
    } catch (_) {}

    return info;
  }

  /// Push a file to the device
  Future<AdbResult> pushFile(
      String localPath,
      String remotePath, {
        Duration? timeout = transferTimeout,
      }) async {
    _ensureDeviceSelected();

    if (!File(localPath).existsSync()) {
      throw AdbException('Local file not found: $localPath');
    }

    return executeCommand(['push', localPath, remotePath], timeout: timeout);
  }

  /// Pull a file from the device
  Future<AdbResult> pullFile(
      String remotePath,
      String localPath, {
        Duration? timeout = transferTimeout,
      }) async {
    _ensureDeviceSelected();

    // Ensure local directory exists
    final localDir = p.dirname(localPath);
    if (!Directory(localDir).existsSync()) {
      Directory(localDir).createSync(recursive: true);
    }

    return executeCommand(['pull', remotePath, localPath], timeout: timeout);
  }

  /// Delete a file on the device
  Future<AdbResult> deleteFile(String remotePath) async {
    _ensureDeviceSelected();
    return shell('rm -f "$remotePath"');
  }

  /// Check if file exists on device
  Future<bool> fileExists(String remotePath) async {
    _ensureDeviceSelected();
    final result = await shell('test -f "$remotePath" && echo "exists" || echo "not found"');
    return result.outputContains('exists');
  }

  /// List files in a directory on device
  Future<List<String>> listFiles(String remotePath, {bool recursive = false}) async {
    _ensureDeviceSelected();
    final flag = recursive ? '-R' : '';
    final result = await shell('ls $flag "$remotePath" 2>/dev/null');
    if (!result.success) return [];
    return result.outputLines;
  }

  /// Get file info from device
  Future<Map<String, String>> getFileInfo(String remotePath) async {
    _ensureDeviceSelected();
    final result = await shell('ls -la "$remotePath" 2>/dev/null');
    if (!result.success) return {};

    // Parse ls -la output
    final lines = result.outputLines;
    if (lines.isEmpty) return {};

    final parts = lines.first.split(RegExp(r'\s+'));
    if (parts.length < 7) return {};

    return {
      'permissions': parts[0],
      'owner': parts[1],
      'group': parts[2],
      'size': parts[3],
      'modified': '${parts[4]} ${parts[5]} ${parts[6]}',
    };
  }

  // ==================== Utility Functions ====================

  /// Take a screenshot and save to local path
  Future<AdbResult> takeScreenshot(String localPath) async {
    _ensureDeviceSelected();

    final remotePath = '/sdcard/screenshot_temp.png';

    // Take screenshot on device
    final captureResult = await shell('screencap -p "$remotePath"');
    if (!captureResult.success) {
      throw AdbException('Failed to capture screenshot: ${captureResult.error}');
    }

    try {
      // Pull screenshot to computer
      final pullResult = await pullFile(remotePath, localPath);

      // Clean up
      await shell('rm -f "$remotePath"');

      return pullResult;
    } catch (e) {
      await shell('rm -f "$remotePath"');
      rethrow;
    }
  }

  /// Record screen (returns process that needs to be stopped)
  Future<Process> startScreenRecording({
    String remotePath = '/sdcard/screenrecord.mp4',
    int bitRate = 4000000,
    int maxDurationSec = 180,
    bool showTouches = false,
  }) async {
    _ensureDeviceSelected();

    final args = <String>['shell', 'screenrecord'];
    if (showTouches) args.add('--show-touches');
    args.addAll([
      '--bit-rate', '$bitRate',
      '--time-limit', '$maxDurationSec',
      remotePath,
    ]);

    if (_selectedDeviceSerial != null) {
      args.insertAll(0, ['-s', _selectedDeviceSerial!]);
    }

    return Process.start(_adbPath, args);
  }

  /// Stop screen recording and pull the file
  Future<AdbResult> stopScreenRecording(
      Process recordingProcess,
      String localPath, {
        String remotePath = '/sdcard/screenrecord.mp4',
      }) async {
    recordingProcess.kill(ProcessSignal.sigint);
    await Future.delayed(const Duration(milliseconds: 500));

    final result = await pullFile(remotePath, localPath);
    await shell('rm -f "$remotePath"');

    return result;
  }

  /// Get screen brightness
  Future<int> getScreenBrightness() async {
    _ensureDeviceSelected();
    final result = await shell('settings get system screen_brightness');
    return int.tryParse(result.output) ?? -1;
  }

  /// Set screen brightness (0-255)
  Future<AdbResult> setScreenBrightness(int brightness) async {
    _ensureDeviceSelected();
    final clamped = brightness.clamp(0, 255);
    return shell('settings put system screen_brightness $clamped');
  }

  /// Get current volume level for a stream
  Future<int> getVolumeLevel({String stream = 'music'}) async {
    _ensureDeviceSelected();
    final result = await shell('settings get system volume_${stream}_stream');
    return int.tryParse(result.output) ?? -1;
  }

  /// Set volume level (0-15 typically)
  Future<AdbResult> setVolumeLevel(
      int level, {
        String stream = 'music',
      }) async {
    _ensureDeviceSelected();
    final clamped = level.clamp(0, 15);
    return shell('media volume --set $clamped --stream $stream');
  }

  /// Send a text to the device (types it as if from keyboard)
  Future<AdbResult> sendText(String text) async {
    _ensureDeviceSelected();
    // Escape special characters
    final escaped = text
        .replaceAll(' ', '%s')
        .replaceAll("'", "\\'")
        .replaceAll('"', '\\"');
    return shell('input text "$escaped"');
  }

  /// Send a key event (keycode)
  /// See: https://developer.android.com/reference/android/view/KeyEvent
  Future<AdbResult> sendKeyEvent(int keyCode) async {
    _ensureDeviceSelected();
    return shell('input keyevent $keyCode');
  }

  /// Tap on screen at coordinates
  Future<AdbResult> tap(int x, int y) async {
    _ensureDeviceSelected();
    return shell('input tap $x $y');
  }

  /// Swipe on screen
  Future<AdbResult> swipe(
      int x1,
      int y1,
      int x2,
      int y2, {
        int durationMs = 300,
      }) async {
    _ensureDeviceSelected();
    return shell('input swipe $x1 $y1 $x2 $y2 $durationMs');
  }

  /// Open an URL on the device
  Future<AdbResult> openUrl(String url) async {
    _ensureDeviceSelected();
    return shell('am start -a android.intent.action.VIEW -d "$url"');
  }

  /// Open an app by package name
  Future<AdbResult> openApp(String packageName) async {
    _ensureDeviceSelected();
    return shell('monkey -p $packageName -c android.intent.category.LAUNCHER 1');
  }

  /// Force stop an app
  Future<AdbResult> forceStopApp(String packageName) async {
    _ensureDeviceSelected();
    return shell('am force-stop $packageName');
  }

  /// Clear app data
  Future<AdbResult> clearAppData(String packageName) async {
    _ensureDeviceSelected();
    return shell('pm clear $packageName');
  }

  /// Install an APK
  Future<AdbResult> installApk(
      String localPath, {
        bool reinstall = false,
        bool downgrade = false,
        bool grantAllPermissions = false,
      }) async {
    _ensureDeviceSelected();

    final args = <String>['install'];
    if (reinstall) args.add('-r');
    if (downgrade) args.add('-d');
    if (grantAllPermissions) args.add('-g');
    args.add(localPath);

    return executeCommand(args, timeout: const Duration(minutes: 3));
  }

  /// Uninstall an app
  Future<AdbResult> uninstallApp(String packageName, {bool keepData = false}) async {
    _ensureDeviceSelected();
    final flag = keepData ? '-k' : '';
    return executeCommand(['uninstall', flag, packageName].where((s) => s.isNotEmpty).toList());
  }

  /// List installed packages
  Future<List<String>> getInstalledPackages({String filter = ''}) async {
    _ensureDeviceSelected();
    final result = await shell('pm list packages $filter');
    if (!result.success) return [];
    return result.outputLines.map((l) => l.replaceFirst('package:', '')).toList();
  }

  /// Check if app is installed
  Future<bool> isAppInstalled(String packageName) async {
    _ensureDeviceSelected();
    final result = await shell('pm list packages $packageName');
    return result.success && result.outputContains(packageName);
  }

  /// Get battery info
  Future<Map<String, dynamic>> getBatteryInfo() async {
    _ensureDeviceSelected();
    final result = await shell('dumpsys battery');

    final info = <String, dynamic>{};

    if (result.success) {
      for (final line in result.outputLines) {
        final parts = line.split(':');
        if (parts.length == 2) {
          final key = parts[0].trim();
          final value = parts[1].trim();

          switch (key) {
            case 'level':
              info['level'] = int.tryParse(value) ?? 0;
            case 'status':
              info['status'] = switch (value) {
                '1' => 'Unknown',
                '2' => 'Charging',
                '3' => 'Discharging',
                '4' => 'Not charging',
                '5' => 'Full',
                _ => value,
              };
              info['isCharging'] = value == '2';
            case 'health':
              info['health'] = switch (value) {
                '1' => 'Unknown',
                '2' => 'Good',
                '3' => 'Overheat',
                '4' => 'Dead',
                '5' => 'Over voltage',
                '6' => 'Unspecified failure',
                '7' => 'Cold',
                _ => value,
              };
            case 'present':
              info['present'] = value == 'true';
            case 'plugged':
              info['plugged'] = switch (value) {
                '0' => 'Battery',
                '1' => 'AC',
                '2' => 'USB',
                '3' => 'Wireless',
                _ => 'Unknown',
              };
            case 'temperature':
              info['temperature'] = (int.tryParse(value) ?? 0) / 10.0;
            case 'voltage':
              info['voltage'] = int.tryParse(value) ?? 0;
            case 'technology':
              info['technology'] = value;
          }
        }
      }
    }

    return info;
  }

  /// Reboot device
  Future<AdbResult> reboot({String mode = ''}) async {
    _ensureDeviceSelected();
    if (mode.isNotEmpty) {
      return executeCommand(['reboot', mode]);
    }
    return executeCommand(['reboot']);
  }

  /// Shutdown device
  Future<AdbResult> shutdown() async {
    _ensureDeviceSelected();
    return shell('reboot -p');
  }

  /// Get device uptime
  Future<Duration> getUptime() async {
    _ensureDeviceSelected();
    final result = await shell('cat /proc/uptime');
    if (!result.success) return Duration.zero;

    final seconds = double.tryParse(result.output.split(' ').first) ?? 0;
    return Duration(milliseconds: (seconds * 1000).round());
  }

  /// Get current date/time on device
  Future<DateTime> getDeviceDateTime() async {
    _ensureDeviceSelected();
    final result = await shell('date "+%Y-%m-%d %H:%M:%S"');
    if (!result.success) return DateTime.now();

    try {
      return DateTime.parse(result.output.replaceAll(' ', 'T'));
    } catch (_) {
      return DateTime.now();
    }
  }

  /// Set device date/time
  Future<AdbResult> setDeviceDateTime(DateTime dateTime) async {
    _ensureDeviceSelected();
    final formatted = dateTime.toString().replaceAll('T', ' ').substring(0, 19);
    return shell('date -s "$formatted"');
  }

  // ==================== Helper Methods ====================

  void _ensureDeviceSelected() {
    if (_selectedDeviceSerial == null) {
      throw const NoDeviceConnectedException();
    }
  }

  /// Stream device logcat
  Stream<String> streamLogcat({
    String filter = '',
    int pid = -1,
  }) async* {
    _ensureDeviceSelected();

    final args = <String>['logcat', '-v', 'time'];
    if (pid > 0) args.addAll(['--pid', '$pid']);
    if (filter.isNotEmpty) args.add(filter);

    final process = await Process.start(_adbPath, [
      '-s', _selectedDeviceSerial!,
      'shell',
      ...args,
    ]);

    await for (final chunk in process.stdout.transform(utf8.decoder)) {
      for (final line in chunk.split('\n')) {
        if (line.trim().isNotEmpty) {
          yield line;
        }
      }
    }
  }

  /// Dispose of resources
  void dispose() {
    _selectedDeviceSerial = null;
  }
}