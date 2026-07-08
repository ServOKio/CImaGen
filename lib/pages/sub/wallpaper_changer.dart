import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:external_path/external_path.dart';

import 'package:cimagen/utils/ImageManager.dart';

import '../../modules/adb/adb_manager.dart';
import '../../modules/adb/models/display_info.dart';

// ==================== Configuration ====================

class WallpaperConfig {
  static const String adbRelativePath = 'CImaGen/utils/AndroidSDKPlatformTools/platform-tools';
  static const String remoteTempPath = '/sdcard/cimagen_wallpaper_temp.jpg';
  static const int minSwipeThreshold = 8;
  static const double maxHorizontalOffset = 0.3; // Max 30% offset
  static const double maxVerticalOffset = 0.2;   // Max 20% offset
}

// ==================== State Models ====================

class DeviceState {
  final bool isInitialized;
  final bool isConnected;
  final String? selectedDeviceSerial;
  final String? deviceName;
  final AndroidDisplayInfo? displayInfo;
  final String? error;

  const DeviceState({
    this.isInitialized = false,
    this.isConnected = false,
    this.selectedDeviceSerial,
    this.deviceName,
    this.displayInfo,
    this.error,
  });

  DeviceState copyWith({
    bool? isInitialized,
    bool? isConnected,
    String? selectedDeviceSerial,
    String? deviceName,
    AndroidDisplayInfo? displayInfo,
    String? error,
  }) {
    return DeviceState(
      isInitialized: isInitialized ?? this.isInitialized,
      isConnected: isConnected ?? this.isConnected,
      selectedDeviceSerial: selectedDeviceSerial ?? this.selectedDeviceSerial,
      deviceName: deviceName ?? this.deviceName,
      displayInfo: displayInfo ?? this.displayInfo,
      error: error,
    );
  }
}

class ImagePosition {
  final double horizontalOffset; // -1.0 to 1.0 (normalized)
  final double verticalOffset;   // -1.0 to 1.0 (normalized)
  final double scale;

  const ImagePosition({
    this.horizontalOffset = 0.0,
    this.verticalOffset = 0.0,
    this.scale = 1.0,
  });

  ImagePosition copyWith({
    double? horizontalOffset,
    double? verticalOffset,
    double? scale,
  }) {
    return ImagePosition(
      horizontalOffset: horizontalOffset ?? this.horizontalOffset,
      verticalOffset: verticalOffset ?? this.verticalOffset,
      scale: scale ?? this.scale,
    );
  }

  static const zero = ImagePosition();
}

// ==================== Main Widget ====================

class WallpaperChanger extends StatefulWidget {
  final ImageMeta? imageMeta;

  const WallpaperChanger({super.key, this.imageMeta});

  @override
  State<WallpaperChanger> createState() => _WallpaperChangerState();
}

class _WallpaperChangerState extends State<WallpaperChanger> {
  // ADB Manager
  AdbManager? _adbManager;
  DeviceState _deviceState = const DeviceState();

  // Image data
  late final Future<Uint8List?> _imageFuture;
  img.Image? _decodedImage;
  int? _imageWidth;
  int? _imageHeight;

  // Position state
  ImagePosition _position = ImagePosition.zero;
  bool _isDragging = false;
  double? _dragStartX;
  double? _dragStartY;
  ImagePosition _dragStartPosition = ImagePosition.zero;

  // Wallpaper settings
  WallpaperTarget _selectedTarget = WallpaperTarget.both;
  bool _isSettingWallpaper = false;
  String? _lastError;
  String? _lastSuccess;

  // Animation controller for smooth transitions
  late final AnimationController _resetAnimation;

  @override
  void initState() {
    super.initState();
    _imageFuture = _loadImage();
    _initializeAdb();
  }

  @override
  void dispose() {
    _adbManager?.dispose();
    super.dispose();
  }

  // ==================== Initialization ====================

  Future<void> _initializeAdb() async {
    try {
      Directory? docDir;
      if (Platform.isAndroid) {
        docDir = Directory(await ExternalPath.getExternalStoragePublicDirectory(
            ExternalPath.DIRECTORY_DOCUMENTS));
      } else if (Platform.isWindows) {
        docDir = await getApplicationDocumentsDirectory();
      } else {
        docDir = await getApplicationDocumentsDirectory();
      }

      if (!docDir.existsSync()) {
        throw Exception('Documents folder not found');
      }

      final platformToolsPath = p.join(
        docDir.path,
        WallpaperConfig.adbRelativePath,
      );

      _adbManager = AdbManager(platformToolsPath);

      if (mounted) {
        setState(() {
          _deviceState = _deviceState.copyWith(isInitialized: true);
        });
        await _connectToDevice();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _deviceState = _deviceState.copyWith(
            isInitialized: false,
            error: e.toString(),
          );
        });
      }
    }
  }

  Future<void> _connectToDevice() async {
    if (_adbManager == null) return;

    try {
      final devices = await _adbManager!.getConnectedDevices();
      final authorizedDevice = devices.where((d) => d.isAuthorized).toList();

      if (authorizedDevice.isEmpty) {
        if (mounted) {
          setState(() {
            _deviceState = _deviceState.copyWith(
              isConnected: false,
              error: devices.isEmpty
                  ? 'No devices connected via USB'
                  : 'Device unauthorized. Check phone screen.',
            );
          });
        }
        return;
      }

      // Select first authorized device
      final device = authorizedDevice.first;
      _adbManager!.selectedDevice = device.serialNumber;

      // Get display info
      AndroidDisplayInfo? displayInfo;
      try {
        final displaysInfo = await _adbManager!.getAllDisplays();
        displayInfo = displaysInfo.primaryDisplay;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _deviceState = _deviceState.copyWith(
            isConnected: true,
            selectedDeviceSerial: device.serialNumber,
            deviceName: device.displayName,
            displayInfo: displayInfo,
            error: null,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _deviceState = _deviceState.copyWith(
            isConnected: false,
            error: 'Failed to connect: $e',
          );
        });
      }
    }
  }

  Future<Uint8List?> _loadImage() async {
    try {
      if (widget.imageMeta?.fullImage == null) {
        await widget.imageMeta?.makeFullImage();
      }
      final bytes = widget.imageMeta?.fullImage;
      if (bytes != null) {
        // Decode to get dimensions for cropping
        _decodedImage = img.decodeImage(bytes);
        if (_decodedImage != null) {
          _imageWidth = _decodedImage!.width;
          _imageHeight = _decodedImage!.height;
        }
      }
      return bytes;
    } on PathNotFoundException {
      throw 'Image file not found';
    }
  }

  // ==================== Image Positioning ====================

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _dragStartX = details.localPosition.dx;
      _dragStartY = details.localPosition.dy;
      _dragStartPosition = _position;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging || _dragStartX == null) return;

    final containerWidth = context.size?.width ?? 400;
    final containerHeight = context.size?.height ?? 800;

    // Calculate delta in normalized coordinates
    final deltaX = (details.localPosition.dx - _dragStartX!) / containerWidth;
    final deltaY = (details.localPosition.dy - _dragStartY!) / containerHeight;

    // Apply sensitivity and clamp
    final sensitivity = 2.0;
    final newHorizontal = (_dragStartPosition.horizontalOffset + deltaX * sensitivity)
        .clamp(-WallpaperConfig.maxHorizontalOffset, WallpaperConfig.maxHorizontalOffset);
    final newVertical = (_dragStartPosition.verticalOffset + deltaY * sensitivity)
        .clamp(-WallpaperConfig.maxVerticalOffset, WallpaperConfig.maxVerticalOffset);

    setState(() {
      _position = _position.copyWith(
        horizontalOffset: newHorizontal,
        verticalOffset: newVertical,
      );
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
      _dragStartX = null;
      _dragStartY = null;
    });
  }

  void _resetPosition() {
    setState(() {
      _position = ImagePosition.zero;
    });
  }

  void _nudgePosition(double horizontalDelta, double verticalDelta) {
    setState(() {
      _position = _position.copyWith(
        horizontalOffset: (_position.horizontalOffset + horizontalDelta)
            .clamp(-WallpaperConfig.maxHorizontalOffset, WallpaperConfig.maxHorizontalOffset),
        verticalOffset: (_position.verticalOffset + verticalDelta)
            .clamp(-WallpaperConfig.maxVerticalOffset, WallpaperConfig.maxVerticalOffset),
      );
    });
  }

  // ==================== Wallpaper Cropping & Setting ====================

  Future<Uint8List?> _cropImageForWallpaper() async {
    if (_decodedImage == null || _deviceState.displayInfo == null) {
      return null;
    }

    final display = _deviceState.displayInfo!;

    // Calculate target wallpaper dimensions
    // Account for parallax scrolling (typically 1.2x width)
    final targetWidth = (display.width * 1.2).ceil();
    final targetHeight = display.height;

    // Calculate source crop region based on position
    final srcWidth = _decodedImage!.width;
    final srcHeight = _decodedImage!.height;

    // Calculate the crop that maintains aspect ratio
    final srcAspect = srcWidth / srcHeight;
    final targetAspect = targetWidth / targetHeight;

    int cropWidth, cropHeight, cropX, cropY;

    if (srcAspect > targetAspect) {
      // Image is wider than needed - crop sides
      cropHeight = srcHeight;
      cropWidth = (srcHeight * targetAspect).round();
      cropX = ((srcWidth - cropWidth) / 2).round();
      cropY = 0;
    } else {
      // Image is taller than needed - crop top/bottom
      cropWidth = srcWidth;
      cropHeight = (srcWidth / targetAspect).round();
      cropX = 0;
      cropY = ((srcHeight - cropHeight) / 2).round();
    }

    // Apply position offset
    final maxOffsetX = (srcWidth - cropWidth) / 2;
    final maxOffsetY = (srcHeight - cropHeight) / 2;

    cropX = (cropX + (maxOffsetX * _position.horizontalOffset)).round()
        .clamp(0, srcWidth - cropWidth);
    cropY = (cropY + (maxOffsetY * _position.verticalOffset)).round()
        .clamp(0, srcHeight - cropHeight);

    // Crop the image
    final cropped = img.copyCrop(
      _decodedImage!,
      x: cropX,
      y: cropY,
      width: cropWidth,
      height: cropHeight,
    );

    // Resize to exact target dimensions
    final resized = img.copyResize(
      cropped,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.linear,
    );

    // Encode to JPEG with good quality
    return Uint8List.fromList(img.encodeJpg(resized, quality: 95));
  }

  Future<File> _saveTempFile(Uint8List bytes) async {
    final tempDir = await getTemporaryDirectory();
    final filePath = p.join(tempDir.path, 'wallpaper_${DateTime.now().millisecondsSinceEpoch}.jpg');
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> _setWallpaper() async {
    if (_adbManager == null || !_deviceState.isConnected) {
      _showError('No device connected');
      return;
    }

    setState(() {
      _isSettingWallpaper = true;
      _lastError = null;
      _lastSuccess = null;
    });

    try {
      // Crop image based on current position
      final croppedBytes = await _cropImageForWallpaper();
      if (croppedBytes == null) {
        throw Exception('Failed to crop image. Check image and display info.');
      }

      // Save to temp file
      final tempFile = await _saveTempFile(croppedBytes);

      try {
        // Set wallpaper via ADB
        final result = await _adbManager!.setWallpaper(
          tempFile.path,
          target: _selectedTarget,
          remotePath: WallpaperConfig.remoteTempPath,
          deleteAfter: true,
        );

        if (result.success) {
          if (mounted) {
            setState(() {
              _lastSuccess = 'Wallpaper set successfully!\n'
                  'Target: ${_selectedTarget.name}\n'
                  'Time: ${result.duration.inMilliseconds}ms';
            });
          }
        } else {
          throw Exception(result.error ?? 'Unknown error');
        }
      } finally {
        // Clean up local temp file
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    } catch (e) {
      if (mounted) {
        _showError(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSettingWallpaper = false;
        });
      }
    }
  }

  void _showError(String message) {
    setState(() {
      _lastError = message;
      _lastSuccess = null;
    });
  }

  // ==================== Build UI ====================

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const breakpoint = 600.0;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: const Color(0xaa000000),
        elevation: 0,
        title: Text(
          _deviceState.deviceName ?? 'Wallpaper Changer',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          if (_deviceState.isConnected)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withAlpha(100)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Connected',
                    style: TextStyle(color: Colors.green.shade300, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withAlpha(100)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Disconnected',
                    style: TextStyle(color: Colors.red.shade300, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
      endDrawer: screenWidth >= breakpoint ? null : _buildMenu(),
      drawerEdgeDragWidth: screenWidth >= breakpoint ? null : MediaQuery.of(context).size.width / 2,
      body: SafeArea(
        child: screenWidth >= breakpoint
            ? Row(
          children: [
            Expanded(child: _buildMain()),
            _buildMenu(),
          ],
        )
            : _buildMain(),
      ),
    );
  }

  Widget _buildMain() {
    final screenHeight = MediaQuery.of(context).size.height;

    return Center(
      child: FutureBuilder<Uint8List?>(
        future: _imageFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white54),
            );
          }

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Preview container
              GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: const Color(0xff383a3c),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white12),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Stack(
                    children: [
                      // Image with position offset
                      SizedBox(
                        height: screenHeight * 0.75,
                        child: AspectRatio(
                          aspectRatio: 9 / 20,
                          child: ClipRect(
                            child: Transform.translate(
                              offset: Offset(
                                _position.horizontalOffset * 100,
                                _position.verticalOffset * 100,
                              ),
                              child: Image.memory(
                                snapshot.data!,
                                gaplessPlayback: true,
                                scale: _position.scale,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Dark overlay
                      Positioned.fill(
                        child: Container(color: Colors.black.withAlpha(40)),
                      ),
                      // Clock preview
                      Positioned.fill(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '12\n00',
                              style: TextStyle(
                                fontSize: screenHeight * 0.12,
                                fontWeight: FontWeight.w400,
                                height: 0.8,
                                color: Colors.white.withAlpha(200),
                                shadows: const [
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      // Drag indicator
                      if (_isDragging)
                        Positioned(
                          bottom: 12,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(150),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Adjusting position...',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                      // Position indicator
                      if (!_isDragging && _position != ImagePosition.zero)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: GestureDetector(
                            onTap: _resetPosition,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(150),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.refresh, size: 14, color: Colors.white70),
                                  SizedBox(width: 4),
                                  Text('Reset', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Position controls
              _buildPositionControls(),
              const SizedBox(height: 8),
              // Status messages
              if (_lastError != null)
                _buildStatusMessage(_lastError!, isError: true),
              if (_lastSuccess != null)
                _buildStatusMessage(_lastSuccess!, isError: false),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPositionControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Left button
          _buildControlButton(
            icon: Icons.chevron_left,
            onPressed: () => _nudgePosition(-0.05, 0),
            tooltip: 'Move left',
          ),
          // Up button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _buildControlButton(
              icon: Icons.arrow_upward,
              onPressed: () => _nudgePosition(0, -0.05),
              tooltip: 'Move up',
            ),
          ),
          // Center/Reset button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _buildControlButton(
              icon: Icons.center_focus_strong,
              onPressed: _resetPosition,
              tooltip: 'Center',
              highlight: _position == ImagePosition.zero,
            ),
          ),
          // Down button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _buildControlButton(
              icon: Icons.arrow_downward,
              onPressed: () => _nudgePosition(0, 0.05),
              tooltip: 'Move down',
            ),
          ),
          // Right button
          _buildControlButton(
            icon: Icons.chevron_right,
            onPressed: () => _nudgePosition(0.05, 0),
            tooltip: 'Move right',
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
    bool highlight = false,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: highlight ? Colors.white24 : Colors.white10,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: highlight ? Colors.white38 : Colors.white24,
            ),
          ),
          child: Icon(icon, color: Colors.white70, size: 20),
        ),
      ),
    );
  }

  Widget _buildStatusMessage(String message, {required bool isError}) {
    // Truncate very long messages for display, but show full in tooltip
    final displayMessage = message.length > 200
        ? '${message.substring(0, 200)}...'
        : message;

    return Tooltip(
      message: message,
      decoration: BoxDecoration(
        color: isError ? Colors.red.shade900 : Colors.green.shade900,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isError ? Colors.red.withAlpha(30) : Colors.green.withAlpha(30),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isError ? Colors.red.withAlpha(60) : Colors.green.withAlpha(60),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: isError ? Colors.red.shade300 : Colors.green.shade300,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                displayMessage,
                style: TextStyle(
                  color: isError ? Colors.red.shade300 : Colors.green.shade300,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() {
                _lastError = null;
                _lastSuccess = null;
              }),
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.close,
                  color: (isError ? Colors.red : Colors.green).withAlpha(150),
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.broken_image_outlined,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load image',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ==================== Menu Panel ====================

  Widget _buildMenu() {
    return Container(
      width: 380,
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xff1a1a1a),
        border: Border(left: BorderSide(color: Colors.white10)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionTitle('Device'),
            _buildDeviceSection(),
            const SizedBox(height: 20),
            _buildSectionTitle('Display'),
            _buildDisplaySection(),
            const SizedBox(height: 20),
            _buildSectionTitle('Wallpaper Target'),
            _buildTargetSection(),
            const SizedBox(height: 20),
            _buildSectionTitle('Actions'),
            _buildActionsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey.shade500,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDeviceSection() {
    if (!_deviceState.isInitialized) {
      return _buildInfoCard(
        icon: Icons.usb_off,
        iconColor: Colors.orange,
        title: 'ADB Not Initialized',
        subtitle: 'Check platform-tools path',
      );
    }

    if (!_deviceState.isConnected) {
      return Column(
        children: [
          _buildInfoCard(
            icon: Icons.phone_android,
            iconColor: Colors.grey,
            title: 'No Device Connected',
            subtitle: _deviceState.error ?? 'Connect device via USB',
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _connectToDevice,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white54,
              side: const BorderSide(color: Colors.white24),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildInfoCard(
          icon: Icons.phone_android,
          iconColor: Colors.green,
          title: _deviceState.deviceName ?? 'Unknown Device',
          subtitle: 'Serial: ${_deviceState.selectedDeviceSerial ?? "N/A"}',
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _connectToDevice,
          icon: const Icon(Icons.sync, size: 16),
          label: const Text('Refresh Connection'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white54,
            side: const BorderSide(color: Colors.white24),
          ),
        ),
      ],
    );
  }

  Widget _buildDisplaySection() {
    final display = _deviceState.displayInfo;

    if (!_deviceState.isConnected || display == null) {
      return _buildInfoCard(
        icon: Icons.monitor,
        iconColor: Colors.grey,
        title: 'No Display Info',
        subtitle: 'Connect a device first',
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          _buildInfoRow('Resolution', '${display.width} × ${display.height}'),
          _buildInfoRow('Density', '${display.densityDpi.toStringAsFixed(1)}x (${display.density} dpi)'),
          _buildInfoRow('Refresh Rate', '${display.refreshRate} mHz (${(display.refreshRate / 1000).toStringAsFixed(0)} Hz)'),
          _buildInfoRow('Aspect Ratio', display.aspectRatio),
          _buildInfoRow('Orientation', display.isPortrait ? 'Portrait' : 'Landscape'),
          if (_imageWidth != null && _imageHeight != null) ...[
            const Divider(color: Colors.white12, height: 20),
            _buildInfoRow('Image Size', '${_imageWidth} × ${_imageHeight}'),
            _buildInfoRow('Image Aspect',
                (_imageWidth! / _imageHeight!).toStringAsFixed(2)),
          ],
        ],
      ),
    );
  }

  Widget _buildTargetSection() {
    return Column(
      children: WallpaperTarget.values.map((target) {
        final isSelected = _selectedTarget == target;
        final info = _getTargetInfo(target);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isSettingWallpaper ? null : () {
                setState(() => _selectedTarget = target);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue.withAlpha(30) : Colors.white.withAlpha(5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.blue.withAlpha(80) : Colors.white12,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      info.icon,
                      color: isSelected ? Colors.blue.shade300 : Colors.grey.shade400,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            info.title,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey.shade300,
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                            ),
                          ),
                          Text(
                            info.description,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: Colors.blue.shade300,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionsSection() {
    final canSetWallpaper = _deviceState.isConnected && !_isSettingWallpaper;

    return Column(
      children: [
        // Set Wallpaper Button (existing code)
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: canSetWallpaper ? _setWallpaper : null,
            icon: _isSettingWallpaper
                ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white.withAlpha(150),
              ),
            )
                : const Icon(Icons.wallpaper),
            label: Text(
              _isSettingWallpaper
                  ? 'Setting Wallpaper...'
                  : 'Set Wallpaper',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: canSetWallpaper ? Colors.blue : Colors.grey.shade800,
              foregroundColor: canSetWallpaper ? Colors.white : Colors.grey.shade500,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),

        // ... existing secondary buttons ...

        const SizedBox(height: 16),

        // Debug section
        const Divider(color: Colors.white12),
        const SizedBox(height: 12),

        OutlinedButton.icon(
          onPressed: _deviceState.isConnected ? _showDebugInfo : null,
          icon: const Icon(Icons.bug_report_outlined, size: 16),
          label: const Text('Show Debug Info'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.grey.shade400,
            side: const BorderSide(color: Colors.white24),
          ),
        ),
      ],
    );
  }

  Future<void> _showDebugInfo() async {
    if (_adbManager == null) return;

    final debugInfo = StringBuffer();

    // Device info
    debugInfo.writeln('=== Device Info ===');
    debugInfo.writeln('Serial: ${_deviceState.selectedDeviceSerial}');
    debugInfo.writeln('Name: ${_deviceState.deviceName}');

    // Display info
    if (_deviceState.displayInfo != null) {
      final d = _deviceState.displayInfo!;
      debugInfo.writeln('\n=== Display Info ===');
      debugInfo.writeln('Resolution: ${d.width}x${d.height}');
      debugInfo.writeln('Density: ${d.density} (${d.densityDpi}x)');
      debugInfo.writeln('Refresh: ${d.refreshRate}mHz');
    }

    // ADB connection test
    debugInfo.writeln('\n=== ADB Test ===');
    try {
      final echoResult = await _adbManager!.shell('echo "test"');
      debugInfo.writeln('Echo test: ${echoResult.success ? "OK" : "FAILED"}');
    } catch (e) {
      debugInfo.writeln('Echo test FAILED: $e');
    }

    // File system test
    debugInfo.writeln('\n=== File System Test ===');
    try {
      final lsResult = await _adbManager!.shell('ls -la /sdcard/ | head -3');
      debugInfo.writeln('/sdcard/ accessible: ${lsResult.success}');
    } catch (e) {
      debugInfo.writeln('Failed: $e');
    }

    // SDK Version
    debugInfo.writeln('\n=== Android Version ===');
    try {
      final sdk = await _adbManager!.shell('getprop ro.build.version.sdk');
      final version = await _adbManager!.shell('getprop ro.build.version.release');
      debugInfo.writeln('SDK: ${sdk.output}');
      debugInfo.writeln('Android: ${version.output}');
    } catch (e) {
      debugInfo.writeln('Failed: $e');
    }

    // Wallpaper command availability - DETAILED
    debugInfo.writeln('\n=== Wallpaper Commands ===');

    // Test wm set-wallpaper
    try {
      final wmHelp = await _adbManager!.shell('wm help 2>&1');
      final hasWmWallpaper = wmHelp.stdout.contains('set-wallpaper');
      debugInfo.writeln('wm set-wallpaper: ${hasWmWallpaper ? "AVAILABLE" : "NOT AVAILABLE"}');
      if (!hasWmWallpaper) {
        debugInfo.writeln('  (wm help output does not contain set-wallpaper)');
      }
    } catch (e) {
      debugInfo.writeln('wm set-wallpaper: ERROR - $e');
    }

    // Test cmd wallpaper - THIS IS THE KEY ONE
    try {
      final cmdHelp = await _adbManager!.shell('cmd wallpaper help 2>&1');
      debugInfo.writeln('\ncmd wallpaper help output:');
      debugInfo.writeln('---');
      debugInfo.writeln(cmdHelp.output.isNotEmpty ? cmdHelp.output : '(empty)');
      debugInfo.writeln('---');

      final hasSetFile = cmdHelp.stdout.contains('set-file');
      debugInfo.writeln('cmd wallpaper set-file: ${hasSetFile ? "AVAILABLE" : "NOT AVAILABLE"}');

      if (hasSetFile) {
        // Try a dry run or get current status
        final status = await _adbManager!.shell('cmd wallpaper get-current 2>&1');
        debugInfo.writeln('cmd wallpaper get-current: ${status.output}');
      }
    } catch (e) {
      debugInfo.writeln('cmd wallpaper: ERROR - $e');
    }

    // Test service call availability
    debugInfo.writeln('\n=== Service Test ===');
    try {
      // List services to find wallpaper
      final services = await _adbManager!.shell('service list 2>&1 | grep -i wallpaper');
      debugInfo.writeln('Wallpaper services found:');
      debugInfo.writeln(services.output.isNotEmpty ? services.output : '(none)');
    } catch (e) {
      debugInfo.writeln('Service list failed: $e');
    }

    // Current wallpaper info
    debugInfo.writeln('\n=== Current Wallpaper ===');
    try {
      final wpInfo = await _adbManager!.getCurrentWallpaperInfo();
      if (wpInfo.isNotEmpty) {
        wpInfo.forEach((key, value) {
          debugInfo.writeln('$key = $value');
        });
      } else {
        // Try dumpsys directly
        final dump = await _adbManager!.shell('dumpsys wallpaper 2>&1 | head -30');
        debugInfo.writeln(dump.output);
      }
    } catch (e) {
      debugInfo.writeln('Failed: $e');
    }

    // Image info
    debugInfo.writeln('\n=== Image Info ===');
    debugInfo.writeln('Dimensions: ${_imageWidth}x${_imageHeight}');
    debugInfo.writeln('Position: H=${_position.horizontalOffset.toStringAsFixed(3)}, V=${_position.verticalOffset.toStringAsFixed(3)}');

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xff1a1a1a),
          title: const Text('Debug Info', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(
                debugInfo.toString(),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                  fontFamily: 'monospace',
                  height: 1.3,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: debugInfo.toString()));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied to clipboard'),
                    backgroundColor: Colors.grey,
                  ),
                );
              },
              child: const Text('Copy All'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  // ==================== Helper Widgets ====================

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }

  ({IconData icon, String title, String description}) _getTargetInfo(WallpaperTarget target) {
    return switch (target) {
      WallpaperTarget.home => (
      icon: Icons.home_outlined,
      title: 'Home Screen',
      description: 'Set wallpaper for home screen only',
      ),
      WallpaperTarget.lock => (
      icon: Icons.lock_outline,
      title: 'Lock Screen',
      description: 'Set wallpaper for lock screen only',
      ),
      WallpaperTarget.both => (
      icon: Icons.wallpaper,
      title: 'Both Screens',
      description: 'Set wallpaper for home and lock screen',
      ),
    };
  }
}