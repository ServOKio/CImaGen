import 'dart:convert';

import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class GalleryImageFullView extends StatelessWidget {
  final ImageMeta imageMeta;
  final VoidCallback onImageTap;

  const GalleryImageFullView({Key? key, required this.imageMeta, required this.onImageTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    late ImageProvider provider;
    if(!imageMeta.isLocal){
      provider = NetworkImage(imageMeta.networkThumbnail ?? imageMeta.fullNetworkPath ?? context.read<ImageManager>().getter.getThumbnailUrlImage(imageMeta));
    } else {
      provider = MemoryImage(base64Decode(imageMeta.thumbnail ?? ''));
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