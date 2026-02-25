import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import '../Utils.dart';
import '../main.dart';
import '../pages/sub/BodySizeCalculation.dart';
import '../pages/sub/DevicePreview.dart';
import '../pages/sub/Publish.dart';
import '../utils/ImageManager.dart';
import 'GalleryImageMiniView.dart';
import 'ImageInfo.dart';

class GalleryImageFullMain extends StatefulWidget {
  final List<dynamic> images;
  final int currentIndex;

  const GalleryImageFullMain({super.key, required this.images, required this.currentIndex});

  @override
  _GalleryImageFullMainState createState() => _GalleryImageFullMainState();
}

class _GalleryImageFullMainState extends State<GalleryImageFullMain> {
  late int _currentIndex;
  late PageController _pageController;
  bool _showAppBar = true;
  bool showOriginalSize = false;
  late PhotoViewScaleStateController _currentScaleController;
  late List<PhotoViewScaleStateController> _scaleControllers;
  late List<PhotoViewController> _photoControllers; // Added for mouse wheel control
  late PhotoViewController _currentPhotoController;
  late ScrollController _thumbnailController;

  int gpState = 0;
  final GlobalKey<ScaffoldState> _scaffoldkey = GlobalKey();
  ImageMeta? im;

  @override
  void initState() {
    super.initState();
    showOriginalSize = prefs.getBool('imageview_show_original_size') ?? false;
    _currentIndex = widget.currentIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _scaleControllers = List.generate(
      widget.images.length,
          (_) => PhotoViewScaleStateController(),
    );
    _photoControllers = List.generate(
      widget.images.length,
          (_) => PhotoViewController(),
    );
    _currentScaleController = _scaleControllers[_currentIndex];
    _currentPhotoController = _photoControllers[_currentIndex];
    _thumbnailController = ScrollController();
    load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrent();
      _setInitialScaleState();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setInitialScaleState();
  }

  void _setInitialScaleState() {
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    if (showOriginalSize) {
      _currentPhotoController.scale = 1 / dpr;
    } else {
      _currentScaleController.scaleState = PhotoViewScaleState.initial;
    }
  }

  Future<void> load() async {
    if (prefs.getBool('imageview_use_fullscreen') ?? false) {
      await WindowManager.instance.setFullScreen(true);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _scaleControllers) {
      controller.dispose();
    }
    for (var controller in _photoControllers) {
      controller.dispose();
    }
    _thumbnailController.dispose();
    disp();
    super.dispose();
  }

  Future<void> disp() async {
    if (prefs.getBool('imageview_use_fullscreen') ?? false) {
      await WindowManager.instance.setFullScreen(false);
    }
  }

  void previous() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.ease,
    );
  }

  void next() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.ease,
    );
  }

  void _scrollToCurrent() {
    if (!_thumbnailController.hasClients) return;
    const double thumbnailWidth = 110.0; // Adjust based on actual thumbnail size + padding
    final double viewWidth = MediaQuery.of(context).size.width;
    double offset = (_currentIndex * thumbnailWidth) - (viewWidth / 2) + (thumbnailWidth / 2);
    offset = offset.clamp(0.0, _thumbnailController.position.maxScrollExtent);
    _thumbnailController.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.ease,
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageManager = Provider.of<ImageManager>(context);
    final theme = Theme.of(context);
    final appBar = AppBar(
      backgroundColor: Colors.black,
      title: Text(widget.images[_currentIndex].fileName),
      actions: [
        IconButton(
          icon: Icon(
            showOriginalSize
                ? Icons.photo_size_select_large_rounded
                : Icons.photo_size_select_actual_rounded,
          ),
          onPressed: () {
            setState(() {
              showOriginalSize = !showOriginalSize;
              _setInitialScaleState();
            });
            prefs.setBool('imageview_show_original_size', showOriginalSize);
          },
        ),
        IconButton(
          icon: Icon(
            imageManager.favoritePaths.contains(widget.images[_currentIndex].fullPath)
                ? Icons.star
                : Icons.star_outline,
          ),
          onPressed: () {
            imageManager.toogleFavorite(
              widget.images[_currentIndex].fullPath,
              host: widget.images[_currentIndex].host,
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.info_outline),
          onPressed: () {
            setState(() {
              gpState = 0;
            });
            _scaffoldkey.currentState!.openEndDrawer();
            im = widget.images[_currentIndex];
            setState(() {
              gpState = 1;
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.devices_other),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DevicePreview(imageMeta: widget.images[_currentIndex]),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.accessibility),
          tooltip: 'Calculate body dimensions',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BodySizeCalculation(imageMeta: widget.images[_currentIndex]),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Publish(imageMeta: widget.images[_currentIndex]),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.open_in_new),
          onPressed: () async {
            if (!widget.images[_currentIndex].isLocal) {
              final Uri url = Uri.parse(
                widget.images[_currentIndex].fullNetworkPath ??
                    context.read<ImageManager>().getter.getFullUrlImage(widget.images[_currentIndex]),
              );
              if (!await launchUrl(url)) {
                await showDialog<String>(
                  context: context,
                  builder: (BuildContext context) => AlertDialog(
                    title: const Text('AlertDialog Title'),
                    content: const Text('AlertDialog description'),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.pop(context, 'Cancel'),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, 'OK'),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              }
            } else {
              showInExplorer(widget.images[_currentIndex].fullPath);
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () {},
        ),
      ],
    );
    return Scaffold(
      key: _scaffoldkey,
      backgroundColor: Colors.black,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(appBar.preferredSize.height),
        child: AnimatedContainer(
          curve: Curves.ease,
          height: _showAppBar ? appBar.preferredSize.height : 0.0,
          duration: const Duration(milliseconds: 200),
          child: appBar,
        ),
      ),
      body: _buildContent(),
      endDrawer: Theme(
        data: ThemeData.dark(useMaterial3: false).copyWith(
          canvasColor: Colors.black,
        ),
        child: SizedBox(
          width: 300,
          child: Drawer(
            child: Stack(
              children: <Widget>[
                Theme(
                  data: theme,
                  child: SingleChildScrollView(
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      child: [
                        const Center(child: CircularProgressIndicator()),
                        if (im != null) MyImageInfo(im!),
                        const Text('Error'),
                      ][gpState],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      onEndDrawerChanged: (isOpen) {
        if (!isOpen) im = null;
      },
    );
  }

  Widget _buildContent() {
    return Stack(
      children: <Widget>[
        _buildPhotoViewGallery(),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: previous,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                width: 50,
                alignment: Alignment.center,
                child: const Icon(Icons.arrow_left),
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          top: 0,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: next,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  width: 50,
                  alignment: Alignment.center,
                  child: const Icon(Icons.arrow_right),
                ),
              ),
            ),
          ),
        ),
        if (widget.images.length > 1) _buildIndicator(),
      ],
    );
  }

  Widget _buildIndicator() {
    return Positioned(
      bottom: 0.0,
      left: 0.0,
      right: 0.0,
      child: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: AnimatedContainer(
          curve: Curves.ease,
          height: _showAppBar ? 100.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: _buildThumbnailList(),
        ),
      ),
    );
  }

  Widget _buildThumbnailList() {
    return SizedBox(
      height: 100.0,
      child: ListView.builder(
        controller: _thumbnailController,
        scrollDirection: Axis.horizontal,
        itemCount: widget.images.length,
        itemBuilder: (ctx, index) {
          return GestureDetector(
            onTap: () {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.ease,
              );
            },
            child: Container(
              width: 90.0,
              margin: const EdgeInsets.symmetric(horizontal: 5.0),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _currentIndex == index ? Colors.white : Colors.transparent,
                  width: 2.0,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              clipBehavior: Clip.hardEdge,
              child: GalleryImageMiniView(
                imageMeta: widget.images[index], onImageTap: (){
                  _pageController.jumpToPage(index);
                  _setInitialScaleState();
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPhotoViewGallery() {
    return Listener(
      onPointerSignal: (PointerSignalEvent event) {
        if (event is PointerScrollEvent) {
          final double currentScale = _currentPhotoController.scale ?? 1.0;
          // Adjust sensitivity: smaller step for finer control
          final double zoomDelta = -event.scrollDelta.dy / 1000.0;
          final double newScale = (currentScale + zoomDelta).clamp(0.1, 4.0);
          _currentPhotoController.scale = newScale;
        }
      },
      child: PhotoViewGallery.builder(
        itemCount: widget.images.length,
        builder: (BuildContext context, int index) {
          final ImageMeta im = widget.images[index];
          ImageProvider? provider;
          if (!im.isLocal) {
            final String net = im.fullNetworkPath ??
                context.read<ImageManager>().getter.getFullUrlImage(im);
            provider = net == ''
                ? FileImage(File(im.tempFilePath ?? im.cacheFilePath ?? 'e.png'))
                : NetworkImage(net);
          } else {
            provider = FileImage(File(im.fullPath ?? im.tempFilePath ?? im.cacheFilePath ?? 'e.png'));
          }
          return PhotoViewGalleryPageOptions(
            controller: _photoControllers[index], // Added for mouse wheel
            scaleStateController: _scaleControllers[index],
            imageProvider: provider,
            errorBuilder: (context, error, stackTrace) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  im.thumbnail != null
                      ? AspectRatio(
                    aspectRatio: im.size!.width / im.size!.height,
                    child: Image.memory(
                      im.thumbnail!,
                      filterQuality: FilterQuality.low,
                      gaplessPlayback: true,
                    ),
                  )
                      : !im.isLocal && im.networkThumbnail != null
                      ? CachedNetworkImage(
                    imageUrl: im.networkThumbnail!,
                    imageBuilder: (context, imageProvider) => AspectRatio(
                      aspectRatio: im.size!.width / im.size!.height,
                      child: Image(
                        image: imageProvider,
                        gaplessPlayback: true,
                      ),
                    ),
                  )
                      : const Text('Error'),
                  Transform.rotate(
                    angle: 45 * math.pi / 180,
                    child: Text(
                      'Deleted',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontWeight: FontWeight.bold,
                        fontSize: 32,
                      ),
                    ),
                  ),
                ],
              );
            },
            initialScale: PhotoViewComputedScale.contained,
            minScale: 0.1,
            maxScale: PhotoViewComputedScale.covered * 4.0, // Allow more zoom for details
            onTapUp: (_, __, ___) => setState(() {
              _showAppBar = !_showAppBar;
            }),
          );
        },
        enableRotation: true,
        scrollPhysics: const BouncingScrollPhysics(),
        pageController: _pageController,
        loadingBuilder: (context, event) {
          final ImageMeta imageMeta = widget.images[_currentIndex];
          return Stack(
            children: [
              if (!imageMeta.isLocal && imageMeta.cacheFilePath != null)
                Image.file(File(imageMeta.cacheFilePath!)),
              Center(
                child: CircularProgressIndicator(
                  value: event == null
                      ? null
                      : event.expectedTotalBytes != null
                      ? event.cumulativeBytesLoaded / event.expectedTotalBytes!
                      : null,
                ),
              ),
            ],
          );
        },
        onPageChanged: (int index) {
          setState(() {
            _currentIndex = index;
            _currentScaleController = _scaleControllers[index];
            _currentPhotoController = _photoControllers[index]; // Update current controller
            _setInitialScaleState();
          });
          SchedulerBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
        },
      ),
    );
  }
}