class ChecksumManifest({required Map<String, String> entries}) {
  final Map<String, String> _entries = Map.unmodifiable(entries);

  String? checksumForFileName({required String fileName}) {
    return _entries[fileName];
  }
}
