class ChecksumManifest {
  final Map<String, String> _entries;

  ChecksumManifest({required Map<String, String> entries}) : _entries = Map.unmodifiable(entries);

  String? checksumForFileName({required String fileName}) {
    return _entries[fileName];
  }
}
