import 'dvec.dart';
import 'libPuzzle.dart';

// int puzzle_fill_cvec_from_file(PuzzleContext context, PuzzleCvec cvec, String file){
//   PuzzleDvec dvec;
//   int ret;
//
//   dvec = puzzle_init_dvec(context, dvec);
//   if ((ret = puzzle_fill_dvec_from_file(context, dvec, file)) == 0) {
//   ret = puzzle_fill_cvec_from_dvec(context, cvec, dvec);
//   }
//   puzzle_free_dvec(context, dvec);
//
//   return ret;
// }

// int puzzle_fill_cvec_from_dvec(PuzzleContext context, PuzzleCvec cvec, PuzzleDvec dvec) {
//   int s;
//   double dvecptr;
//   String cvecptr;
//   double? lights = null, darks = null;
//   int pos_lights = 0, pos_darks = 0;
//   int sizeof_lights, sizeof_darks;
//   double lighter_cutoff, darker_cutoff;
//   int err = 0;
//   double dv;
//
//   if ((cvec.sizeof_vec = dvec.sizeof_compressed_vec!) <= 0) {
//     puzzle_err_bug(__FILE__, __LINE__);
//   }
//   if ((cvec->vec = calloc(cvec->sizeof_vec, sizeof *cvec->vec)) == NULL) {
//   return -1;
//   }
//   sizeof_lights = sizeof_darks = cvec->sizeof_vec;
//   if ((lights = calloc(sizeof_lights, sizeof *lights)) == NULL ||
//   (darks = calloc(sizeof_darks, sizeof *darks)) == NULL) {
//   err = -1;
//   goto out;
//   }
//   dvecptr = dvec->vec;
//   s = cvec->sizeof_vec;
//   do {
//   dv = *dvecptr++;
//   if (dv >= - context->puzzle_noise_cutoff &&
//   dv <= context->puzzle_noise_cutoff) {
//   continue;
//   }
//   if (dv < context->puzzle_noise_cutoff) {
//   darks[pos_darks++] = dv;
//   if (pos_darks > sizeof_darks) {
//   puzzle_err_bug(__FILE__, __LINE__);
//   }
//   } else if (dv > context->puzzle_noise_cutoff) {
//   lights[pos_lights++] = dv;
//   if (pos_lights > sizeof_lights) {
//   puzzle_err_bug(__FILE__, __LINE__);
//   }
//   }
//   } while (--s != (size_t) 0U);
//   lighter_cutoff = puzzle_median(lights, pos_lights);
//   darker_cutoff = puzzle_median(darks, pos_darks);
//   free(lights);
//   lights = NULL;
//   free(darks);
//   darks = NULL;
//   dvecptr = dvec->vec;
//   cvecptr = cvec->vec;
//   s = cvec->sizeof_vec;
//   do {
//   dv = *dvecptr++;
//   if (dv >= - context->puzzle_noise_cutoff &&
//   dv <= context->puzzle_noise_cutoff) {
//   *cvecptr++ = 0;
//   } else if (dv < 0.0) {
//   *cvecptr++ = dv < darker_cutoff ? -2 : -1;
//   } else {
//   *cvecptr++ = dv > lighter_cutoff ? +2 : +1;
//   }
//   } while (--s != (size_t) 0U);
//   if ((size_t) (cvecptr - cvec->vec) != cvec->sizeof_vec) {
//   puzzle_err_bug(__FILE__, __LINE__);
//   }
//   out:
//   free(lights);
//   free(darks);
//
//   return err;
// }