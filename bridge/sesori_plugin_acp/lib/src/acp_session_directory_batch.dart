/// One immutable recovery result. Existing live directory attribution remains
/// authoritative when a plugin registers this batch.
class AcpSessionDirectoryBatch({required Map<String, String> directories}) {
  final Map<String, String> directories = Map.unmodifiable(directories);
}
