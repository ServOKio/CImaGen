/// Connected device information from `adb devices -l`
class ConnectedDevice {
  final String serialNumber;
  final String state;
  final String? product;
  final String? model;
  final String? device;
  final String? transportId;

  const ConnectedDevice({
    required this.serialNumber,
    required this.state,
    this.product,
    this.model,
    this.device,
    this.transportId,
  });

  /// Device connection states
  bool get isAuthorized => state == 'device';
  bool get isUnauthorized => state == 'unauthorized';
  bool get isOffline => state == 'offline';
  bool get isRecovery => state == 'recovery';
  bool get isFastboot => state == 'fastboot';
  bool get isDisconnected => state == 'disconnect';
  bool get isUsb => serialNumber.startsWith('usb:');
  bool get isEmulator => serialNumber.startsWith('emulator-');
  bool get isTcpIp => serialNumber.contains(':') && !isUsb && !isEmulator;

  /// Get human-readable device name
  String get displayName {
    if (model != null) return model!;
    if (product != null) return product!;
    if (isEmulator) return 'Emulator ${serialNumber.replaceAll('emulator-', '')}';
    if (isTcpIp) return 'TCP/IP Device';
    return serialNumber;
  }

  /// Get connection type description
  String get connectionType {
    if (isUsb) return 'USB';
    if (isTcpIp) return 'TCP/IP';
    if (isEmulator) return 'Emulator';
    return 'Unknown';
  }

  /// Get state description
  String get stateDescription {
    switch (state) {
      case 'device': return 'Connected';
      case 'unauthorized': return 'Unauthorized';
      case 'offline': return 'Offline';
      case 'recovery': return 'Recovery Mode';
      case 'fastboot': return 'Fastboot Mode';
      case 'disconnect': return 'Disconnected';
      default: return state;
    }
  }

  @override
  String toString() => 'ConnectedDevice($serialNumber, $state, ${displayName})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ConnectedDevice && serialNumber == other.serialNumber;

  @override
  int get hashCode => serialNumber.hashCode;
}

/// Detailed device information
class AndroidDeviceInfo {
  final String serialNumber;
  final String model;
  final String manufacturer;
  final String brand;
  final String androidVersion;
  final String sdkVersion;
  final String buildNumber;
  final String buildFingerprint;
  final String securityPatch;
  final String baseband;
  final String bootloader;
  final String hardware;
  final String product;
  final String device;
  final String board;
  final String cpuAbi;
  final List<String> supportedAbis;
  final int? totalMemoryMb;
  final int? availableMemoryMb;
  final int? batteryLevel;
  final bool? isCharging;
  final String? chargingType;
  final String? screenResolution;
  final int? screenDensity;
  final int? screenDensityDpi;

  const AndroidDeviceInfo({
    required this.serialNumber,
    required this.model,
    required this.manufacturer,
    this.brand = '',
    required this.androidVersion,
    required this.sdkVersion,
    this.buildNumber = '',
    this.buildFingerprint = '',
    this.securityPatch = '',
    this.baseband = '',
    this.bootloader = '',
    this.hardware = '',
    this.product = '',
    this.device = '',
    this.board = '',
    this.cpuAbi = '',
    this.supportedAbis = const [],
    this.totalMemoryMb,
    this.availableMemoryMb,
    this.batteryLevel,
    this.isCharging,
    this.chargingType,
    this.screenResolution,
    this.screenDensity,
    this.screenDensityDpi,
  });

  /// Get display name: "Manufacturer Model"
  String get displayName => '$manufacturer $model'.trim();

  /// Check if device supports a specific ABI
  bool supportsAbi(String abi) => supportedAbis.contains(abi);

  /// Check if Android version is at least the specified version
  bool isAndroidVersionAtLeast(int version) {
    try {
      return int.parse(androidVersion.split('.').first) >= version;
    } catch (_) {
      return false;
    }
  }

  /// Check if SDK version is at least the specified version
  bool isSdkVersionAtLeast(int sdk) {
    try {
      return int.parse(sdkVersion) >= sdk;
    } catch (_) {
      return false;
    }
  }

  /// Get formatted memory info
  String get memoryInfo {
    if (totalMemoryMb == null) return 'Unknown';
    final available = availableMemoryMb ?? 0;
    return '${available}MB / ${totalMemoryMb}MB';
  }

  @override
  String toString() =>
      'AndroidDeviceInfo($displayName, Android $androidVersion, SDK $sdkVersion)';
}