/// [value] without surrounding whitespace, or null when nothing is left.
String? trimmedOrNull({required String? value}) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
