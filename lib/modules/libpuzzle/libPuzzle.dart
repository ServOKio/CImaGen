
int PUZZLE_VERSION_MAJOR = 0;
int PUZZLE_VERSION_MINOR = 11;

double PUZZLE_CVEC_SIMILARITY_THRESHOLD = 0.6;
double PUZZLE_CVEC_SIMILARITY_HIGH_THRESHOLD = 0.7;
double PUZZLE_CVEC_SIMILARITY_LOW_THRESHOLD = 0.3;
double PUZZLE_CVEC_SIMILARITY_LOWER_THRESHOLD=  0.2;

void puzzle_init_context(PuzzleContext context) {
  //context = puzzle_global_context;
}
void puzzle_free_context(PuzzleContext context) {
  // TODO: implement puzzle_free_context
}
int puzzle_set_max_width(PuzzleContext context, int width) {
  if (width <= 0) {
    return -1;
  }
  context.puzzle_max_width = width;

  return 0;
}
int puzzle_set_max_height(PuzzleContext context, int height) {
  if (height <= 0) {
    return -1;
  }
  context.puzzle_max_height = height;

  return 0;
}
int puzzle_set_lambdas(PuzzleContext context, int lambdas) {
  if (lambdas <= 0) {
    return -1;
  }
  context.puzzle_lambdas = lambdas;

  return 0;
}
int puzzle_set_noise_cutoff(PuzzleContext context, double noise_cutoff) {
  context.puzzle_noise_cutoff = noise_cutoff;
  return 0;
}
int puzzle_set_p_ratio(PuzzleContext context, double p_ratio) {
  if (p_ratio < 1.0) {
    return -1;
  }
  context.puzzle_p_ratio = p_ratio;

  return 0;
}
int puzzle_set_contrast_barrier_for_cropping(PuzzleContext context, double barrier) {
  if (barrier <= 0.0) {
    return -1;
  }
  context.puzzle_contrast_barrier_for_cropping = barrier;
  return 0;
}
int puzzle_set_max_cropping_ratio(PuzzleContext context, double ratio) {
  if (ratio <= 0.0) {
    return -1;
  }
  context.puzzle_max_cropping_ratio = ratio;

  return 0;
}
int puzzle_set_autocrop(PuzzleContext context, bool enable) {
  context.puzzle_enable_autocrop = enable != true;

  return 0;
}
void puzzle_init_cvec(PuzzleContext context, PuzzleCvec cvec) {
  cvec.sizeof_vec = 0;
  cvec.vec = null;
}
PuzzleDvec puzzle_init_dvec(PuzzleContext context, PuzzleDvec dvec) {
  dvec.sizeof_vec = dvec.sizeof_compressed_vec = 0;
  dvec.vec = null;
  return dvec;
}
// START FROM THIS
int puzzle_fill_cvec_from_file(PuzzleContext context, PuzzleCvec cvec, String file) {
  // TODO: implement puzzle_fill_cvec_from_file
  throw UnimplementedError();
}
int puzzle_fill_dvec_from_mem(PuzzleContext context, PuzzleDvec dvec, void mem, int size) {
  // TODO: implement puzzle_fill_dvec_from_mem
  throw UnimplementedError();
}
int puzzle_fill_cvec_from_mem(PuzzleContext context, PuzzleCvec cvec, void mem, int size) {
  // TODO: implement puzzle_fill_cvec_from_mem
  throw UnimplementedError();
}
int puzzle_fill_cvec_from_dvec(PuzzleContext context, PuzzleCvec cvec, PuzzleDvec dvec) {
  // TODO: implement puzzle_fill_cvec_from_dvec
  throw UnimplementedError();
}
void puzzle_free_cvec(PuzzleContext context, PuzzleCvec cvec) {
  cvec.vec = null;
}
void puzzle_free_dvec(PuzzleContext context, PuzzleDvec dvec) {
  // TODO: implement puzzle_free_dvec
}
int puzzle_dump_cvec(PuzzleContext context, PuzzleCvec cvec) {
  int s = cvec.sizeof_vec!;
  double vecptr = cvec.vec!;

  if (s <= 0) {
    puzzle_err_bug('puzzle_dump_cvec: s <= 0');
  }
  do {
    print('${vecptr++}');
  } while (--s != 0);

  return 0;
}
int puzzle_dump_dvec(PuzzleContext context,PuzzleDvec dvec) {
  // TODO: implement puzzle_dump_dvec
  throw UnimplementedError();
}
int puzzle_cvec_cksum(PuzzleContext context, PuzzleCvec cvec, int sum) {
  // TODO: implement puzzle_cvec_cksum
  throw UnimplementedError();
}
void puzzle_init_compressed_cvec(PuzzleContext context, PuzzleCompressedCvec compressed_cvec) {
  // TODO: implement puzzle_init_compressed_cvec
}
void puzzle_free_compressed_cvec(PuzzleContext context, PuzzleCompressedCvec compressed_cvec) {
  // TODO: implement puzzle_free_compressed_cvec
}
int puzzle_compress_cvec(PuzzleContext context, PuzzleCompressedCvec compressed_cvec, PuzzleCvec cvec) {
  // TODO: implement puzzle_compress_cvec
  throw UnimplementedError();
}
int puzzle_uncompress_cvec(PuzzleContext context, PuzzleCompressedCvec compressed_cvec, PuzzleCvec cvec) {
  // TODO: implement puzzle_uncompress_cvec
  throw UnimplementedError();
}
int puzzle_vector_sub(PuzzleContext context, PuzzleCvec cvecr, PuzzleCvec cvec1, PuzzleCvec cvec2, int fix_for_texts) {
  // TODO: implement puzzle_vector_sub
  throw UnimplementedError();
}
double puzzle_vector_euclidean_length(PuzzleContext context, PuzzleCvec cvec) {
  // TODO: implement puzzle_vector_euclidean_length
  throw UnimplementedError();
}
double puzzle_vector_normalized_distance(PuzzleContext context, PuzzleCvec cvec1, PuzzleCvec cvec2, int fix_for_texts) {
  // TODO: implement puzzle_vector_normalized_distance
  throw UnimplementedError();
}

void puzzle_err_bug(String message) {
  print('*BUG* Message: [$message}]\n');
  throw Exception(message);
}

void test(){
  print('Start of test...');
}

class PuzzleDvec {
  int? sizeof_vec;
  int? sizeof_compressed_vec;
  double? vec;

  PuzzleDvec({
    this.sizeof_vec,
    this.sizeof_compressed_vec,
    this.vec
  });
}

class PuzzleCvec {
  int? sizeof_vec;
  double? vec;

  PuzzleCvec({
    this.sizeof_vec,
    this.vec
  });
}

class PuzzleCompressedCvec {
  int? sizeof_compressed_vec;
  String? vec; // unsigned char *vec;

  PuzzleCompressedCvec({
    this.sizeof_compressed_vec,
    this.vec
  });
}

class PuzzleContext {
  int? puzzle_max_width;
  int? puzzle_max_height;
  int? puzzle_lambdas;
  double? puzzle_p_ratio;
  double? puzzle_noise_cutoff;
  double? puzzle_contrast_barrier_for_cropping;
  double? puzzle_max_cropping_ratio;
  bool? puzzle_enable_autocrop;
  int? magic;


  PuzzleContext({
    this.puzzle_max_width,
    this.puzzle_max_height,
    this.puzzle_lambdas,
    this.puzzle_p_ratio,
    this.puzzle_noise_cutoff,
    this.puzzle_contrast_barrier_for_cropping,
    this.puzzle_max_cropping_ratio,
    this.magic,
    this.puzzle_enable_autocrop
  });
}