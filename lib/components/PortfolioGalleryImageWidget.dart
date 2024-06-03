import 'dart:io';

import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/material.dart';

class PortfolioGalleryImageWidget extends StatelessWidget {
  final ImageMeta imageMeta;
  final VoidCallback onImageTap;

  const PortfolioGalleryImageWidget({Key? key, required this.imageMeta, required this.onImageTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    late ImageProvider provider;
    if(!imageMeta.isLocal){
      provider = NetworkImage(imageMeta.networkThumbnail ?? imageMeta.fullNetworkPath!);
    } else {
      provider = FileImage(File(imageMeta.fullPath));
    }
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(5)),
      child: Material(
        color: Colors.transparent,
        child: Ink.image(
          image: provider,
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