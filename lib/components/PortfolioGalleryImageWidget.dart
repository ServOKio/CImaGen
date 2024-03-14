import 'dart:io';

import 'package:flutter/material.dart';

class PortfolioGalleryImageWidget extends StatelessWidget {
  final String imagePath;
  final VoidCallback onImageTap;

  const PortfolioGalleryImageWidget({Key? key, required this.imagePath, required this.onImageTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(5)),
      child: Material(
        color: Colors.transparent,
        child: Ink.image(
          image: FileImage(File(imagePath)),
          fit: BoxFit.scaleDown,
          child: InkWell(
              onTap: onImageTap,
              onFocusChange: (f) { if(f) onImageTap();},
          ),
        ),
      ),
    );
  }
}