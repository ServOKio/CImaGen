abstract class DatabaseCheckException implements Exception {
  final String message;
  const DatabaseCheckException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

class DuplicateGenerationParamsException extends DatabaseCheckException {
  final List<String> keyups;

  const DuplicateGenerationParamsException(this.keyups)
      : super('Duplicate generation_params detected');
}

class OrphanGenerationParamsException extends DatabaseCheckException {
  final List<String> keyups;

  const OrphanGenerationParamsException(this.keyups)
      : super('Orphan generation_params detected');
}

class InvalidSizeFormatException extends DatabaseCheckException {
  final List<String> keyups;

  const InvalidSizeFormatException(this.keyups)
      : super('Invalid size format detected');
}