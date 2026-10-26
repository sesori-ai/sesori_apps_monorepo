import "package:sesori_bridge/src/repositories/session_metadata_repository.dart";

class FakeSessionMetadataRepository() implements SessionMetadataRepository {
  String? generateResult = "Generated title";
  String? lastGenerateMessage;

  @override
  void beginShutdown() {}

  @override
  Future<GeneratedSessionMetadata> generateMetadata({required String firstMessage}) async {
    lastGenerateMessage = firstMessage;
    return (title: generateResult ?? (throw StateError("metadata unavailable")));
  }
}
