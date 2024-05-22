import 'dart:io';
import 'dart:ui';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:cimagen/Utils.dart';
import 'package:cimagen/components/ImageInfo.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cimagen/components/PortfolioGalleryImageWidget.dart';
import 'package:provider/provider.dart';
import 'package:gap/gap.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import '../utils/ImageManager.dart';

class PortfolioGalleryDetailPage extends StatefulWidget {

  final List<dynamic> images;
  final int currentIndex;

  const PortfolioGalleryDetailPage({Key? key, required this.images, required this.currentIndex}) : super(key: key);

  @override
  _PortfolioGalleryDetailPageState createState() => _PortfolioGalleryDetailPageState();
}

class _PortfolioGalleryDetailPageState extends State<PortfolioGalleryDetailPage> {
  late int _currentIndex;
  late PageController _pageController;
  bool _showAppBar = true;

  bool showOriginalSize = true;
  late PhotoViewScaleStateController changeScale;

  void backCall(PhotoViewScaleStateController ns){
    changeScale = ns;
    // changeScale.scaleState = PhotoViewScaleState.originalSize;
  }

  late CarouselController carouselController;

  int gpState = 0;

  final GlobalKey<ScaffoldState> _scaffoldkey = GlobalKey();

  ImageMeta? im;

  late SharedPreferences prefs;

  @override
  void initState() {
    super.initState();
    carouselController = CarouselController();
    _currentIndex = widget.currentIndex;
    _pageController = PageController(initialPage: _currentIndex);
    load();
  }

  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();
    if(prefs.getBool('imageview_use_fullscreen') ?? false) await WindowManager.instance.setFullScreen(true);
  }

  @override
  void dispose() {
    disp();
    super.dispose();
  }

  Future<void> disp() async {
    if(prefs.getBool('imageview_use_fullscreen') ?? false) await WindowManager.instance.setFullScreen(false);
  }

  @override
  Widget build(BuildContext context) {
    final imageManager = Provider.of<ImageManager>(context);
    AppBar appBar = AppBar(
      backgroundColor: Colors.black,
      title: Text(widget.images[_currentIndex].fileName),
      actions: [
        IconButton(
            icon: Icon(
              showOriginalSize ? Icons.photo_size_select_large_rounded : Icons.photo_size_select_actual_rounded,
            ),
            onPressed: (){
              setState(() {
                showOriginalSize = !showOriginalSize;
                changeScale.scaleState = showOriginalSize ? PhotoViewScaleState.originalSize : PhotoViewScaleState.initial;
              });
            }
        ),
        const Gap(6),
        IconButton(
            icon: Icon(
              imageManager.favoritePaths.contains(widget.images[_currentIndex].fullPath) ? Icons.star : Icons.star_outline,
            ),
            onPressed: (){
              imageManager.toogleFavorite(widget.images[_currentIndex].fullPath);
            }
        ),
        const Gap(6),
        IconButton(
            icon: const Icon(
              Icons.info_outline,
            ),
            onPressed: (){
              setState(() {
                gpState = 0;
              });
              _scaffoldkey.currentState!.openEndDrawer();
              im = widget.images[_currentIndex];
              setState(() {
                gpState = 1;
              });
              //requestInfo(widget.images[_currentIndex]);
            }
        ),
        const Gap(6),
        IconButton(
            icon: const Icon(
              Icons.open_in_new,
            ),
            onPressed: () async {
              if(!widget.images[_currentIndex].isLocal){
                final Uri url = Uri.parse(widget.images[_currentIndex].fullNetworkPath);
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
              // final String dir = dirname(widget.images[_currentIndex].fullPath);
              // await OpenFile.open('$dir\\');
            }
        ),
        const Gap(6),
        IconButton(
            icon: const Icon(
              Icons.more_vert,
            ),
            onPressed: (){}
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
          height: _showAppBar ? appBar.preferredSize.height*2 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: appBar,
        ),
      ),
      body: _buildContent(),
      endDrawer: Theme(
          data: ThemeData.dark(useMaterial3: false).copyWith(
              canvasColor: Colors.black.withOpacity(0.5),
          ),
          child: SizedBox(
            width: 300,
            child: Drawer(
                child: Stack(
                    children: <Widget> [
                      BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0), //this is dependent on the import statment above
                          child: Container(
                              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface.withOpacity(0.5))
                          )
                      ),
                      SingleChildScrollView(
                        child: Container(
                            padding: const EdgeInsets.all(6),
                            child: [
                              const Center(child: CircularProgressIndicator()),
                              im != null ? MyImageInfo(im!) : const Text('None'),
                              const Text('Error')
                            ][gpState]
                        ),
                      )
                    ]
                )
            )
          )
      ),
      onEndDrawerChanged: (isOpen) {
        if(!isOpen) im = null;
      },
    );
  }

  // Вся херня
  Widget _buildContent() {
    return Stack(
      children: <Widget>[
        _buildPhotoViewGallery(backCall), //Ебало
        _buildIndicator() //Дно
      ],
    );
  }

  Widget _buildIndicator() {
    return Positioned(
      bottom: 0.0,
      left: 0.0,
      right: 0.0,
      // child: _buildDottedIndicator(),
      child: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: AnimatedContainer(
              curve: Curves.ease,
              height: _showAppBar ? 100.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child:  _buildImageCarouselSlider()
          )
      ),
    );
  }

  Widget _buildImageCarouselSlider() {
    return CarouselSlider.builder(
      itemCount: widget.images.length,
      carouselController: carouselController,
      itemBuilder: (ctx, index, realIdx) {
        return PortfolioGalleryImageWidget(
          imageMeta: widget.images[index],
          onImageTap: () {
            carouselController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.ease);
            _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.ease);
          }
        );
      },
      options: CarouselOptions(
        aspectRatio: 1/1,
        enableInfiniteScroll: false,
        animateToClosest: true,
        autoPlay: false,
        enlargeCenterPage: false,
        padEnds: true,
        pageSnapping: false,
        viewportFraction: 0.1,
        height: 100,
        initialPage: _currentIndex
      )
    );
  }

  PhotoViewScaleStateController scaleStateController = PhotoViewScaleStateController();

  // ТУТ МЫ ЕБАШИМ ВЕРХ
  PhotoViewGallery _buildPhotoViewGallery(Function changeScale) {
    changeScale(scaleStateController);
    return PhotoViewGallery.builder(
      itemCount: widget.images.length,
      builder: (BuildContext context, int index) {
        ImageProvider? provider;
        if(!widget.images[index].isLocal){
          provider = NetworkImage(widget.images[index].fullNetworkPath);
        } else {
          provider = FileImage(File(widget.images[index].fullPath));
        }
        return PhotoViewGalleryPageOptions(
          scaleStateController: scaleStateController,
          imageProvider: provider,
          initialScale: PhotoViewComputedScale.contained,
          minScale: 0.1,
          maxScale: PhotoViewComputedScale.covered * 1,
          onTapUp: (_, __, ___) => setState(() {
            //scaleStateController.scaleState = PhotoViewScaleState.initial;
            _showAppBar = !_showAppBar;
          })
        );
      },
      enableRotation: true,
      scrollPhysics: const BouncingScrollPhysics(),
      pageController: _pageController,
      loadingBuilder: (context, event) => const Center(
        child: CircularProgressIndicator(),
      ),
      onPageChanged: (int index) => setState(() {
        _currentIndex = index;
      })
    );
  }
}

class InfoBox extends StatelessWidget{
  final String one;
  final String two;
  final bool inner;

  const InfoBox({ Key? key, required this.one, required this.two, this.inner = false}): super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: !inner ? Theme.of(context).scaffoldBackgroundColor : const Color(0xff1a1a1a),
          borderRadius: const BorderRadius.all(Radius.circular(4))
      ),
      child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Text(one, style: const TextStyle(fontSize: 12, color: Colors.white70)),
              const Spacer(),
              SelectableText(two, style: const TextStyle(fontSize: 13))
            ],
          )
      )
    );
  }
}