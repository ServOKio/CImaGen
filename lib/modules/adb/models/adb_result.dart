/// Result of an ADB command execution
class AdbResult {
  final int exitCode;
  final String stdout;
  final String stderr;
  final Duration executionTime;

  const AdbResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    this.executionTime = Duration.zero,
  });

  /// Whether the command executed successfully
  bool get success => exitCode == 0;

  /// Get trimmed stdout content
  String get output => stdout.trim();

  /// Get trimmed stderr content
  String get error => stderr.trim();

  /// Check if output contains specific text
  bool outputContains(String text) => stdout.contains(text);

  /// Check if error contains specific text
  bool errorContains(String text) => stderr.contains(text);

  /// Parse output as list of lines
  List<String> get outputLines => output.isEmpty
      ? []
      : output.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

  /// Parse output lines as key-value pairs (format: "key: value")
  Map<String, String> get outputKeyValue {
    final map = <String, String>{};
    for (final line in outputLines) {
      final parts = line.split(RegExp(r':\s*'));
      if (parts.length == 2) {
        map[parts[0].trim()] = parts[1].trim();
      }
    }
    return map;
  }

  @override
  String toString() {
    if (success && output.isNotEmpty) {
      return 'AdbResult(success, output: $output)';
    }
    if (!success) {
      return 'AdbResult(failed, exitCode: $exitCode, error: $error)';
    }
    return 'AdbResult(success)';
  }
}