import '../adb_manager.dart';

/// Exception for ADB-related errors
class AdbException implements Exception {
  final String message;
  final String? stdout;
  final String? stderr;
  final int? exitCode;

  const AdbException(
      this.message, {
        this.stdout,
        this.stderr,
        this.exitCode,
      });

  @override
  String toString() {
    final buffer = StringBuffer('AdbException: $message');
    if (exitCode != null) buffer.write('\n  Exit code: $exitCode');
    if (stdout != null && stdout!.isNotEmpty) {
      buffer.write('\n  STDOUT: $stdout');
    }
    if (stderr != null && stderr!.isNotEmpty) {
      buffer.write('\n  STDERR: $stderr');
    }
    return buffer.toString();
  }
}

/// Exception when ADB executable is not found
class AdbNotFoundException extends AdbException {
  const AdbNotFoundException(String path)
      : super('ADB executable not found at: $path');
}

/// Exception when no device is connected
class NoDeviceConnectedException extends AdbException {
  const NoDeviceConnectedException()
      : super('No Android device connected or selected');
}

/// Exception when device is unauthorized
class DeviceUnauthorizedException extends AdbException {
  final String serialNumber;

  const DeviceUnauthorizedException(this.serialNumber)
      : super('Device $serialNumber is unauthorized. Check device screen for USB debugging confirmation.');
}

/// Exception when ADB command times out
class AdbTimeoutException extends AdbException {
  final Duration timeout;

  AdbTimeoutException(this.timeout) : super('ADB command timed out after ${timeout.inSeconds} seconds');
}

/// Exception for wallpaper-specific errors with detailed info
class WallpaperException extends AdbException {
  final String? localFilePath;
  final String? remoteFilePath;
  final WallpaperTarget target;
  final String? adbStdout;
  final String? adbStderr;
  final int? adbExitCode;
  final String? method;  // Which method was tried

  const WallpaperException(
      String message, {
        this.localFilePath,
        this.remoteFilePath,
        required this.target,
        this.adbStdout,
        this.adbStderr,
        this.adbExitCode,
        this.method,
      }) : super(message);

  @override
  String toString() {
    final buffer = StringBuffer('WallpaperException: $message');
    if (method != null) buffer.write('\n  Method: $method');
    if (target != WallpaperTarget.both) buffer.write('\n  Target: $target');
    if (localFilePath != null) buffer.write('\n  Local: $localFilePath');
    if (remoteFilePath != null) buffer.write('\n  Remote: $remoteFilePath');
    if (adbExitCode != null) buffer.write('\n  Exit Code: $adbExitCode');
    if (adbStdout != null && adbStdout!.isNotEmpty) {
      buffer.write('\n  STDOUT:\n${_indent(adbStdout!)}');
    }
    if (adbStderr != null && adbStderr!.isNotEmpty) {
      buffer.write('\n  STDERR:\n${_indent(adbStderr!)}');
    }
    return buffer.toString();
  }

  String _indent(String text) {
    return text.split('\n').map((l) => '    $l').join('\n');
  }

  /// Get a user-friendly error message
  String get userFriendlyMessage {
    // Parse common errors
    if (adbStderr?.contains('No such file') == true ||
        adbStderr?.contains('No such file or directory') == true) {
      return 'File not found on device. Push may have failed.';
    }
    if (adbStderr?.contains('Permission denied') == true) {
      return 'Permission denied. Try using /sdcard/ path instead.';
    }
    if (adbStderr?.contains('Not a valid image') == true ||
        adbStderr?.contains('Corrupt') == true) {
      return 'Image file is corrupt or in unsupported format.';
    }
    if (adbStderr?.contains('Unknown option') == true) {
      return 'Unsupported command for this Android version.';
    }
    if (adbStderr?.contains('device offline') == true) {
      return 'Device went offline. Reconnect USB.';
    }
    if (adbStderr?.contains('device unauthorized') == true) {
      return 'Device unauthorized. Check phone screen for USB debugging prompt.';
    }
    if (adbStderr?.contains('no devices') == true ||
        adbStderr?.contains('error: no device') == true) {
      return 'No device connected. Check USB connection.';
    }
    if (adbExitCode != null && adbExitCode! != 0) {
      return 'ADB command failed (exit code $adbExitCode). ${adbStderr?.trim() ?? ""}';
    }
    return message;
  }
}