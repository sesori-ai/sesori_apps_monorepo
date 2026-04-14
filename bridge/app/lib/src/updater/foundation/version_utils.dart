int compareVersions({required String a, required String b}) {
  try {
    final aNums = a.split('-')[0].split('.').map(int.parse).toList();
    final bNums = b.split('-')[0].split('.').map(int.parse).toList();

    final len = aNums.length > bNums.length ? aNums.length : bNums.length;
    for (var i = 0; i < len; i++) {
      final aVal = i < aNums.length ? aNums[i] : 0;
      final bVal = i < bNums.length ? bNums[i] : 0;
      if (aVal != bVal) return aVal - bVal;
    }

    final aIsPre = a.contains('-');
    final bIsPre = b.contains('-');
    if (aIsPre && !bIsPre) return -1;
    if (!aIsPre && bIsPre) return 1;
    return 0;
  } on Object {
    return 0;
  }
}
