import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// Shared derive-style plugin fake with catalog-call recording.
class FakeDerivedBridgePlugin({
  @override required final String id,
  @override required final String launchDirectory,
  required var List<PluginSession> allSessions,
}) implements BridgeDerivedProjectsPluginApi {
  Object? listAllSessionsError;
  int listAllSessionsCallCount = 0;
  Set<String>? receivedKnownDirectories;
  final List<({String sessionId, String directory})> primedDirectories = [];

  @override
  Future<List<PluginSession>> listAllSessions({required Set<String> knownDirectories}) async {
    listAllSessionsCallCount++;
    if (listAllSessionsError case final error?) throw error;
    receivedKnownDirectories = knownDirectories;
    return allSessions;
  }

  @override
  void primeSessionDirectory({required String sessionId, required String directory}) {
    primedDirectories.add((sessionId: sessionId, directory: directory));
  }

  @override
  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) => throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
