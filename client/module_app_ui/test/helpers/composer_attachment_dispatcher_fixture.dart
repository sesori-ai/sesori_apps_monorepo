import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

/// A picker the user always dismisses.
class const NoOpComposerFilePicker() implements ComposerFilePicker {
  @override
  Future<ComposerPickResult?> pick() async => null;
}

class _MockConnectionService() extends Mock implements ConnectionService;

class const _FixedLocality({required final bool _isLocal}) implements ActiveBridgeLocality {
  @override
  bool isLocalBridge({required String bridgeId}) => _isLocal;

  @override
  String? get localBridgeId => null;

  @override
  Stream<String?> get localBridgeIdStream => const Stream.empty();
}

/// A real dispatcher over real file access, connected to a bridge that runs
/// on this computer when [bridgeIsLocal] is true.
ComposerAttachmentDispatcher composerAttachmentDispatcherForTest({
  required ComposerFilePicker filePicker,
  required ComposerImageDownscaleBuilder downscaleBuilder,
  required bool bridgeIsLocal,
}) {
  final connectionService = _MockConnectionService();
  when(() => connectionService.activeConfig).thenReturn(
    const ServerConnectionConfig(relayHost: "relay.example", authToken: null, bridgeId: "test-bridge"),
  );
  return ComposerAttachmentDispatcher(
    filePicker: filePicker,
    downscaleBuilder: downscaleBuilder,
    fileClient: const HostFileClient(),
    connectionService: connectionService,
    locality: _FixedLocality(isLocal: bridgeIsLocal),
  );
}
