List<Map<String, dynamic>> processLiteIsolate(
    List<Map<String, dynamic>> list,
    ) {
  final map = <int, List<Map<String, dynamic>>>{};

  for (final im in list) {
    final dayKey = im['dateMillis'] ~/ Duration.millisecondsPerDay;
    map.putIfAbsent(dayKey, () => []).add(im);
  }

  final result = <Map<String, dynamic>>[];

  map.forEach((dayKey, images) {
    result.add({
      'dayKey': dayKey,
      'files': images,
    });
  });

  return result;
}