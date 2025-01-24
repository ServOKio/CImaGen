import 'libPuzzle.dart';

// int puzzle_fill_dvec_from_file(PuzzleContext context, PuzzleDvec dvec, String file) {
//   int ret;
//   gdImagePtr gdimage = puzzle_create_gdimage_from_file(file);
//   if (gdimage == null) {
//     return -1;
//   }
//   puzzle_remove_transparency(gdimage);
//   ret = puzzle_fill_dvec_from_gdimage(context, dvec, gdimage);
//   gdImageDestroy(gdimage);
//   return ret;
// }