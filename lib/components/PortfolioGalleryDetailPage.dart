import 'dart:io';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cimagen/components/PortfolioGalleryImageWidget.dart';

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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    return Stack(
      children: <Widget>[
        _buildPhotoViewGallery(),
        _buildIndicator(),
      ],
    );
  }

  Widget _buildIndicator() {
    return Positioned(
      bottom: 0.0,
      left: 0.0,
      right: 0.0,
      // child: _buildDottedIndicator(),
      child: _buildImageCarouselSlider(),
    );
  }

  Widget _buildImageCarouselSlider() {
    return CarouselSlider.builder(
      itemCount: widget.imagePaths.length,
      itemBuilder: (ctx, index, realIdx) {
        return PortfolioGalleryImageWidget(
          imagePath: widget.imagePaths[index],
          onImageTap: () => _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.ease)
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

  Row _buildDottedIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: widget.imagePaths.map<Widget>((String imagePath) => _buildDot(imagePath)).toList(),
    );
  }

  Container _buildDot(String imagePath) {
    return Container(
      width: 8,
      height: 8,
      margin: EdgeInsets.symmetric(vertical: 10.0, horizontal: 2.0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _currentIndex == widget.imagePaths.indexOf(imagePath)
            ? Colors.white
            : Colors.grey.shade700,
      ),
    );
  }

  PhotoViewGallery _buildPhotoViewGallery() {
    return PhotoViewGallery.builder(
      itemCount: widget.imagePaths.length,
      builder: (BuildContext context, int index) {
        return PhotoViewGalleryPageOptions(
          imageProvider: FileImage(
              File(widget.imagePaths[index])
          ),
          minScale: PhotoViewComputedScale.contained * 1,
          maxScale: PhotoViewComputedScale.covered * 1,
        );
      },
      enableRotation: true,
      scrollPhysics: const BouncingScrollPhysics(),
      pageController: _pageController,
      loadingBuilder: (context, event) => Center(
        child: Container(
          width: 20.0,
          height: 20.0,
          child: CircularProgressIndicator(
            value: event == null ? 0 : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 0),
          ),
        ),
      ),
      onPageChanged: (int index) {
        setState(() {
          _currentIndex = index;
        });
      },
    );
  }
}