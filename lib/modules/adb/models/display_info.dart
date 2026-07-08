import 'dart:math' as math;

/// Display information for an Android device
class AndroidDisplayInfo {
  final int displayId;
  final int width;
  final int height;
  final int density;
  final double densityDpi;
  final int refreshRate;
  final int overscanLeft;
  final int overscanTop;
  final int overscanRight;
  final int overscanBottom;
  final bool isPrimary;
  final String name;
  final int flags;

  const AndroidDisplayInfo({
    this.displayId = 0,
    required this.width,
    required this.height,
    required this.density,
    required this.densityDpi,
    this.refreshRate = 60,
    this.overscanLeft = 0,
    this.overscanTop = 0,
    this.overscanRight = 0,
    this.overscanBottom = 0,
    this.isPrimary = true,
    this.name = 'default',
    this.flags = 0,
  });

  /// Get resolution as string "WIDTHxHEIGHT"
  String get resolution => '${width}x$height';

  /// Get physical size in inches (approximate)
  double get approximateScreenSizeInches {
    // Convert density to actual DPI
    final actualDpi = density * 160;
    if (actualDpi <= 0) return 0;
    final diagonalPixels = (width * width + height * height).toDouble();
    return math.sqrt(diagonalPixels / (actualDpi * actualDpi));
  }

  /// Get aspect ratio as simplified string (e.g., "16:9")
  String get aspectRatio {
    final gcd = _gcd(width, height);
    return '${width ~/ gcd}:${height ~/ gcd}';
  }

  /// Check if display is in portrait orientation
  bool get isPortrait => height > width;

  /// Check if display is in landscape orientation
  bool get isLandscape => width > height;

  /// Check if display has high DPI (retina-like)
  bool get isHighDpi => densityDpi >= 2.0;

  /// Check if display supports high refresh rate
  bool get isHighRefreshRate => refreshRate > 60;

  int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

  @override
  String toString() =>
      'AndroidDisplayInfo(id: $displayId, $resolution, ${densityDpi}x, ${refreshRate}Hz)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is AndroidDisplayInfo && displayId == other.displayId;

  @override
  int get hashCode => displayId.hashCode;
}

/// All displays information for a device
class DeviceDisplaysInfo {
  final List<AndroidDisplayInfo> displays;
  final String physicalSizeOverride;
  final String densityOverride;

  const DeviceDisplaysInfo({
    this.displays = const [],
    this.physicalSizeOverride = '',
    this.densityOverride = '',
  });

  /// Get primary display
  AndroidDisplayInfo? get primaryDisplay {
    try {
      return displays.firstWhere((d) => d.isPrimary);
    } catch (_) {
      return displays.isNotEmpty ? displays.first : null;
    }
  }

  /// Get number of displays
  int get count => displays.length;

  /// Check if has multiple displays
  bool get hasMultipleDisplays => displays.length > 1;

  @override
  String toString() =>
      'DeviceDisplaysInfo(count: $count, primary: $primaryDisplay)';
}

/// Wallpaper dimensions info for proper image sizing
class WallpaperDimensions {
  final int width;
  final int height;
  final int statusBarHeight;
  final int navigationBarHeight;
  final int screenWidth;
  final int screenHeight;
  final int density;

  const WallpaperDimensions({
    required this.width,
    required this.height,
    required this.statusBarHeight,
    required this.navigationBarHeight,
    required this.screenWidth,
    required this.screenHeight,
    required this.density,
  });

  /// Get recommended wallpaper size (accounts for parallax scrolling)
  int get recommendedWidth => (screenWidth * 1.2).ceil();

  /// Get recommended wallpaper height
  int get recommendedHeight => screenHeight + statusBarHeight + navigationBarHeight;

  /// Get aspect ratio for wallpaper
  double get aspectRatio => width / height;

  @override
  String toString() =>
      'WallpaperDimensions(${width}x${height}, screen: ${screenWidth}x${screenHeight}, density: ${density}x)';
}