import 'dart:convert';

import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class GalleryImageMiniView extends StatelessWidget {
  final ImageMeta imageMeta;
  final VoidCallback onImageTap;

  const GalleryImageMiniView({Key? key, required this.imageMeta, required this.onImageTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(5)),
      child: Material(
        color: Colors.transparent,
        child: Ink.image(
          image: MemoryImage(imageMeta.thumbnail!),
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