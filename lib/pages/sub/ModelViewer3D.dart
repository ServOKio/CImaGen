import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gl/flutter_gl.dart';
import 'package:three_js/three_js.dart' as three;

class GlbViewerPage extends StatefulWidget {
  final String assetPath;

  const GlbViewerPage({super.key, required this.assetPath});

  @override
  State<GlbViewerPage> createState() => _GlbViewerPageState();
}

class _GlbViewerPageState extends State<GlbViewerPage> {
  late FlutterGlPlugin gl;
  late three.WebGLRenderer renderer;
  late three.Scene scene;
  late three.PerspectiveCamera camera;
  late three.OrbitControls controls;

  bool ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final size = MediaQuery.of(context).size;

    gl = FlutterGlPlugin();
    await gl.initialize(options: {
      "width": size.width.toInt(),
      "height": size.height.toInt(),
      "dpr": MediaQuery.of(context).devicePixelRatio,
      "antialias": true,
    });
    await gl.prepareContext();

    renderer = three.WebGLRenderer(
      three.WebGLRendererParameters(
        gl: gl.gl,
        width: size.width,
        height: size.height,
        antialias: true,
        alpha: true,
      ),
    );


    renderer.setSize(size.width, size.height, false);
    renderer.setPixelRatio(MediaQuery.of(context).devicePixelRatio);


    scene = three.Scene();
    scene.background = three.Color.fromHex32(0x111111);

    camera = three.PerspectiveCamera(
      60,
      size.width / size.height,
      0.1,
      1000,
    );
    camera.position.setValues(0, 1.2, 3);

    // Lights (Sketchfab-ish)
    scene.add(three.AmbientLight(0xffffff, 0.6));

    final dir = three.DirectionalLight(0xffffff, 1.4);
    dir.position.setValues(5, 10, 7);
    scene.add(dir);

    controls = three.OrbitControls(camera, gl.element);
    controls.enableDamping = true;

    await _loadGlb(widget.assetPath);

    setState(() => ready = true);
    _animate();
  }

  Future<void> _loadGlb(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();

    final loader = three.GLTFLoader();
    final gltf = await loader.fromBytes(bytes);

    final model = gltf.scene!;
    final box = three.Box3().setFromObject(model);
    final center = box.getCenter(three.Vector3());
    model.position.sub(center);

    scene.add(model);
  }

  void _animate() {
    if (!mounted) return;
    controls.update();
    renderer.render(scene, camera);
    gl.dispose();
    Future.delayed(const Duration(milliseconds: 16), _animate);
  }

  @override
  void dispose() {
    controls.dispose();
    renderer.dispose();
    gl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('GLB Viewer')),
      body: Center(
        child: ready
            ? Texture(textureId: gl.textureId!)
            : const CircularProgressIndicator(),
      ),
    );
  }
}
