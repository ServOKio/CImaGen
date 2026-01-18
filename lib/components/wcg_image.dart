import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

class WcgImage extends StatefulWidget {
  final String? filePath;
  final Uint8List? bytes;

  const WcgImage.file(this.filePath, {super.key}) : bytes = null;
  const WcgImage.memory(this.bytes, {super.key}) : filePath = null;

  @override
  State<WcgImage> createState() => _WcgImageState();
}

class _WcgImageState extends State<WcgImage> {
  static const MethodChannel _channel = MethodChannel('wcg_image');

  int? _textureId;
  int? _width;
  int? _height;

  @override
  void initState() {
    super.initState();
    _create();
  }

  Future<void> _create() async {
    final result = await _channel.invokeMethod<Map>('createTexture', {
      'path': widget.filePath,
      'bytes': widget.bytes,
    });

    if (!mounted || result == null) return;

    setState(() {
      _textureId = result['id'];
      _width = result['width'];
      _height = result['height'];
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_textureId == null || _width == null || _height == null) {
      return const SizedBox();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return FittedBox(
          fit: BoxFit.contain, // 👈 SAME AS Image.file
          child: SizedBox(
            width: _width!.toDouble(),   // 👈 intrinsic width
            height: _height!.toDouble(), // 👈 intrinsic height
            child: Texture(textureId: _textureId!),
          ),
        );
      },
    );
  }

}
