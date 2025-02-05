import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';

import 'libPuzzle.dart';

import 'package:image/image.dart' as img;

int INT_MAX = 0x7FFFFFFFFFFFFFFF;
int SIZE_MAX = -1;

Future<int> puzzle_fill_dvec_from_file(PuzzleContext context, PuzzleDvec dvec, File file) async {
  int ret;
  img.Image? gdimage = await puzzle_create_gdimage_from_file(file);
  if (gdimage == null) {
    return -1;
  }
  gdimage = puzzle_remove_transparency(gdimage);
  ret = puzzle_fill_dvec_from_gdimage(context, dvec, gdimage!);
  return ret;
}

int puzzle_fill_dvec_from_gdimage(PuzzleContext context, PuzzleDvec dvec, img.Image gdimage) {
  PuzzleView view;
  PuzzleAvgLvls avglvls;
  int ret = 0;

  if (context.magic != 0xdeadbeef) {
    LibPuzzle.puzzle_err_bug('context.magic != 0xdeadbeef');
  }
  view = puzzle_init_view();
  avglvls = puzzle_init_avglvls();
  dvec = puzzle_init_dvec();
  ret = puzzle_getview_from_gdimage(context, view, gdimage);
  if (ret != 0) {
    throw Exception('no');
  }
  if (context.puzzle_enable_autocrop && (ret = puzzle_autocrop_view(context, view)) < 0) {
    throw Exception('no1');
  }
  // TODO
  // if ((ret = puzzle_fill_avglgls(context, avglvls, view, context.puzzle_lambdas)) != 0) {
  //   throw Exception('no2');
  // }
  // ret = puzzle_fill_dvec(dvec, avglvls);
  // puzzle_free_view(view);
  // puzzle_free_avglvls(avglvls);

  return ret;
}

int puzzle_autocrop_view(PuzzleContext context, PuzzleView view){
  int cropx0, cropx1;
  int cropy0, cropy1;
  int x, y;
  List<String> maptr;
  // TODO
  // if (puzzle_autocrop_axis(context, view, cropx0, cropx1, view.width, view.height, (int) view.width, 1 - (int) (view.width * view.height)) < 0 || puzzle_autocrop_axis(context, view, cropy0, cropy1, view.height, view.width, 1, 0) < 0) {
  //     return -1;
  // }
  // if (cropx0 > cropx1 || cropy0 > cropy1) {
  //   LibPuzzle.puzzle_err_bug(__FILE__, __LINE__);
  // }
  // maptr = view.map;
  // y = cropy0;
  // do {
  // x = cropx0;
  // do {
  // maptr.add(PUZZLE_VIEW_PIXEL(view, x, y));
  // } while (x++ != cropx1);
  // } while (y++ != cropy1);
  // view.width = cropx1 - cropx0 + 1U;
  // view.height = cropy1 - cropy0 + 1U;
  // view.sizeof_map = view.width * view.height;
  // if (view.width <= 0 || view.height <= 0 ||
  //   SIZE_MAX / view.width < view.height) {
  //   LibPuzzle.puzzle_err_bug(__FILE__, __LINE__);
  // }
  return 0;
}

int puzzle_getview_from_gdimage(PuzzleContext context, PuzzleView view, img.Image gdimage){
  int x, y;
  int x0 = 0, y0 = 0;
  int x1, y1;
  List<String> maptr = [];
  img.Pixel pixel;

  view.map = [];
  view.width = gdimage.width;
  view.height = gdimage.height;
  view.sizeof_map = gdimage.width * gdimage.height;
  if (view.width > context.puzzle_max_width || view.height > context.puzzle_max_height) {
    return -1;
  }
  if (view.sizeof_map <= 0 || INT_MAX / view.width < view.height || SIZE_MAX / view.width < view.height || view.sizeof_map != view.sizeof_map) {
    LibPuzzle.puzzle_err_bug('view.sizeof_map! <= 0 || INT_MAX / view.width < view.height || SIZE_MAX / view.width < view.height || view.sizeof_map != view.sizeof_map');
  }
  x1 = view.width - 1;
  y1 = view.height - 1;
  if (view.width <= 0 || view.height <= 0) {
    LibPuzzle.puzzle_err_bug('view.width! <= 0 || view.height! <= 0');
  }
  // if ((view.map = calloc(view.sizeof_map, view.map.length)) == null) { // TODO calloc
  //   return -1;
  // }
  if (x1 > INT_MAX || y1 > INT_MAX) { /* GD uses "int" for coordinates */
    LibPuzzle.puzzle_err_bug('x1 > INT_MAX || y1 > INT_MAX');
  }
  maptr = view.map;
  x = x1;
  do {
    y = y1;
    do {
      pixel = gdimage.getPixel(x, y);
      maptr.add(String.fromCharCode(((pixel.r * 77 + pixel.g * 151 + pixel.b * 28 + 128) / 256).round()));
    } while (y-- != y0);
  } while (x-- != x0);
  // if (gdImageTrueColor(gdimage) != 0) {
  //   do {
  //     y = y1;
  //     do {
  //       pixel = gdImageGetTrueColorPixel(gdimage, (int) x, (int) y);
  //       *maptr++ = (unsigned char)
  //       ((gdTrueColorGetRed(pixel) * 77 +
  //       gdTrueColorGetGreen(pixel) * 151 +
  //       gdTrueColorGetBlue(pixel) * 28 + 128) / 256);
  //     } while (y-- != y0);
  //   } while (x-- != x0);
  // } else {
  //   do {
  //     y = y1;
  //     do {
  //       pixel = gdImagePalettePixel(gdimage, x, y);
  //       *maptr++ = (unsigned char)((gdimage->red[pixel] * 77 + gdimage->green[pixel] * 151 + gdimage->blue[pixel] * 28 + 128) / 256);
  //     } while (y-- != y0);
  //   } while (x-- != x0);
  // }
  return 0;
}

PuzzleDvec puzzle_init_dvec(){
  return PuzzleDvec(
    sizeof_compressed_vec: 0,
    sizeof_vec: 0,
    vec: null
  );
}

PuzzleView puzzle_init_view(){
  return PuzzleView(
      width: 0,
      height: 0,
      sizeof_map: 0,
      map: []
  );
}

PuzzleAvgLvls puzzle_init_avglvls() {
  return PuzzleAvgLvls(
    lambdas: 0,
    sizeof_lvls: 0,
    lvls: 0
  );
}

img.Image? puzzle_remove_transparency(img.Image gdimage) {
  img.Image back = img.Image(width: gdimage.width, height: gdimage.height);
  back = img.fill(back, color: img.ColorRgb8(255, 255, 255));
  gdimage = img.compositeImage(back, gdimage);
  return gdimage;
}

Future<img.Image?> puzzle_create_gdimage_from_file(File file) async {
  img.Image? gdimage;
  final String mine = lookupMimeType(file.path) ?? 'unknown';
  switch (mine.split('/').last) {
    case 'png':
      gdimage = await compute(img.decodePngFile, file.path);
      break;
    case 'jpg':
    case 'jpeg':
      gdimage = await compute(img.decodeJpgFile, file.path);
      break;
    case 'gif':
      gdimage = await compute(img.decodeGifFile, file.path);
      break;
    case 'webp':
      gdimage = await compute(img.decodeWebPFile, file.path);
      break;
  }
  return gdimage;
}