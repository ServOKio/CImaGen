import 'dart:io';
import 'dart:ui';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:cimagen/Utils.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cimagen/components/PortfolioGalleryImageWidget.dart';
import 'package:provider/provider.dart';
import 'package:gap/gap.dart';

import '../utils/ImageManager.dart';
import '../utils/SQLite.dart';

class PortfolioGalleryDetailPage extends StatefulWidget {

  final List<String> imagePaths;
  final int currentIndex;

  const PortfolioGalleryDetailPage({Key? key, required this.imagePaths, required this.currentIndex}) : super(key: key);

  @override
  _PortfolioGalleryDetailPageState createState() => _PortfolioGalleryDetailPageState();
}

class _PortfolioGalleryDetailPageState extends State<PortfolioGalleryDetailPage> {
  late int _currentIndex;
  late PageController _pageController;
  bool _showAppBar = true;

  late CarouselController carouselController;

  int gpState = 0;

  final GlobalKey<ScaffoldState> _scaffoldkey = GlobalKey();

  GenerationParams? gp;

  @override
  void initState() {
    super.initState();
    carouselController = CarouselController();
    _currentIndex = widget.currentIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  void requestInfo(String path){
    // 0 load
    // 1 done
    // 2 error
    setState(() {
      gpState = 0;
    });
    _scaffoldkey.currentState!.openEndDrawer();
    context.read<SQLite>().getGPByPath(path: path).then((v2) {
      if(v2.isNotEmpty) gp = v2.first;
      setState(() {
        gpState = 1;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final imageManager = Provider.of<ImageManager>(context);
    return Scaffold(
      key: _scaffoldkey,
      backgroundColor: Colors.black,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AnimatedContainer(
          curve: Curves.ease,
          height: _showAppBar ? 55.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: AppBar(
            backgroundColor: Colors.black,
            title: Text(widget.imagePaths[_currentIndex]),
            actions: [
              IconButton(
                  icon: Icon(
                    imageManager.favoritePaths.contains(widget.imagePaths[_currentIndex]) ? Icons.star : Icons.star_outline,
                  ),
                  onPressed: (){
                    imageManager.toogleFavorite(widget.imagePaths[_currentIndex]);
                  }
              ),
              const Gap(6),
              IconButton(
                  icon: const Icon(
                    Icons.info_outline,
                  ),
                  onPressed: (){
                    requestInfo(widget.imagePaths[_currentIndex]);
                  }
              ),
              const Gap(6),
              IconButton(
                  icon: const Icon(
                    Icons.open_in_new,
                  ),
                  onPressed: (){}
              ),
              const Gap(6),
              IconButton(
                  icon: const Icon(
                    Icons.more_vert,
                  ),
                  onPressed: (){}
              ),
            ],
          ),
        ),
      ),
      body: _buildContent(),
      endDrawer: Theme(
          data: ThemeData.dark(useMaterial3: false).copyWith(
              canvasColor: Colors.black.withOpacity(0.5),
          ),
          child: SizedBox(
            width: MediaQuery.of(context).size.width > 1280 ? 720 : MediaQuery.of(context).size.width * 0.75, // 75% of screen will be occupied
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
                            child: [
                              const Center(child: CircularProgressIndicator()),
                              gp != null ? Padding(padding: const EdgeInsets.all(8), child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Container(
                                        padding: const EdgeInsets.all(4.0),
                                        margin: const EdgeInsets.only(bottom: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          border: Border.all(color: Colors.green, width: 1),
                                          borderRadius: const BorderRadius.all(Radius.circular(5.0)),
                                        ),
                                        child: FractionallySizedBox(
                                            widthFactor: 1.0,
                                            child: SelectableText(gp?.positive ?? '', style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 14))
                                        )
                                    ),
                                    Container(
                                        padding: const EdgeInsets.all(4.0),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          border: Border.all(color: Colors.red, width: 1,),
                                          borderRadius: const BorderRadius.all(Radius.circular(5.0)),
                                        ),
                                        child: FractionallySizedBox(
                                            widthFactor: 1.0,
                                            child: SelectableText(gp?.negative ?? '', style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 14))
                                        )
                                    ),
                                    const Gap(8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Parameters', style: TextStyle(color: Colors.deepPurple.shade50, fontWeight: FontWeight.w600, fontSize: 18)),
                                        Container(width: 20, height: 2, color: Colors.deepPurple.shade400),
                                      ],
                                    ),
                                    const Gap(4),
                                    Container(
                                      decoration: BoxDecoration(
                                          color: Theme.of(context).scaffoldBackgroundColor,
                                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(4))
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(6),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            InfoBox(one: 'SD checkpoint', two: '${gp?.model} (${gp?.modelHash})'),
                                            const Gap(6),
                                            Container(
                                              decoration: const BoxDecoration(
                                                  color: Color(0xff303030),
                                                  borderRadius: BorderRadius.all(Radius.circular(4))
                                              ),
                                              child: Padding(
                                                  padding: const EdgeInsets.all(8),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      const Text('Sampling', style: TextStyle(fontSize: 12, color: Colors.white70)),
                                                      const Gap(6),
                                                      Column(
                                                        children: [
                                                          InfoBox(one: 'Method', two: gp?.sampler ?? '', inner: true),
                                                          const Gap(4),
                                                          InfoBox(one: 'Steps', two: gp?.steps.toString() ?? '', inner: true),
                                                          const Gap(4),
                                                          InfoBox(one: 'CFG Scale', two: gp?.cfgScale.toString() ?? '', inner: true),
                                                        ],
                                                      )
                                                    ],
                                                  )
                                              )
                                            ),
                                            const Gap(6),
                                            InfoBox(one: 'Sampling steps', two: gp?.steps.toString() ?? ''),
                                            const Gap(6),
                                            InfoBox(one: 'CFG Scale', two: gp?.cfgScale.toString() ?? ''),
                                            const Gap(6),
                                            InfoBox(one: 'Width and height', two:  '${gp?.size.width}x${gp?.size.height}'),
                                            const Gap(6),
                                            InfoBox(one: 'Version', two: gp?.version ?? ''),
                                          ],
                                        ),
                                      ),
                                    ),
                                    gp?.rawData != null ? ExpansionTile(
                                      title: const Text('All parameters'),
                                      subtitle: const Text('View raw generation parameters without parsing'),
                                      children: <Widget>[
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                              color: Theme.of(context).scaffoldBackgroundColor,
                                              borderRadius: const BorderRadius.all(Radius.circular(4))
                                          ),
                                          child: SelectableText(
                                              (gp?.rawData ?? '').replaceFirst('parameters', ''),
                                              style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 14, color: Colors.white70)
                                          )
                                        ),
                                      ],
                                    ) : const SizedBox.shrink(),
                                  ]
                              )) : const Text('None'),
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
        if(!isOpen) gp = null;
      },
    );
  }

  // Вся херня
  Widget _buildContent() {
    return Stack(
      children: <Widget>[
        _buildPhotoViewGallery(), //Ебало
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
      itemCount: widget.imagePaths.length,
      carouselController: carouselController,
      itemBuilder: (ctx, index, realIdx) {
        return PortfolioGalleryImageWidget(
          imagePath: widget.imagePaths[index],
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

  PhotoViewGallery _buildPhotoViewGallery() {
    return PhotoViewGallery.builder(
      itemCount: widget.imagePaths.length,
      builder: (BuildContext context, int index) {
        return PhotoViewGalleryPageOptions(
          imageProvider: FileImage(File(widget.imagePaths[index])),
          minScale: PhotoViewComputedScale.contained * 1,
          maxScale: PhotoViewComputedScale.covered * 1,
          onTapUp: (_, __, ___) => setState(() {
            _showAppBar = !_showAppBar;
          })
        );
      },
      enableRotation: true,
      scrollPhysics: const BouncingScrollPhysics(),
      pageController: _pageController,
      loadingBuilder: (context, event) => Center(
        child: SizedBox(
          width: 20.0,
          height: 20.0,
          child: CircularProgressIndicator(
            value: event == null ? 0 : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 0),
          ),
        ),
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