import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:test/test.dart";

class _Locality({required final String? _localBridgeId}) implements ActiveBridgeLocality {
  @override
  String? get localBridgeId => _localBridgeId;

  @override
  Stream<String?> get localBridgeIdStream => Stream.value(_localBridgeId);

  @override
  bool isLocalBridge({required String bridgeId}) => bridgeId == _localBridgeId;
}

const _reference = FileReference(absolutePath: "/work/repo/lib/main.dart", line: 12);

void main() {
  late MockConnectionService connection;
  late MockUrlLauncher launcher;

  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(UrlLaunchMode.externalApp);
  });

  setUp(() {
    connection = MockConnectionService();
    launcher = MockUrlLauncher();
    when(() => connection.activeConfig).thenReturn(
      const ServerConnectionConfig(relayHost: "relay", authToken: null, bridgeId: "br_here"),
    );
  });

  FileReferenceOpenService service({required String? localBridgeId}) => FileReferenceOpenService(
    connectionService: connection,
    locality: _Locality(localBridgeId: localBridgeId),
    urlLauncher: launcher,
  );

  test("opens a file on this computer in its default app", () async {
    when(() => launcher.launch(any(), mode: any(named: "mode"))).thenAnswer((_) async => true);

    final outcome = await service(localBridgeId: "br_here").open(reference: _reference);

    expect(outcome, isA<FileReferenceOpenedLocally>());
    verify(() => launcher.launch(Uri.file("/work/repo/lib/main.dart"), mode: UrlLaunchMode.externalApp)).called(1);
  });

  test("asks for the preview when the bridge is on another computer", () async {
    final outcome = await service(localBridgeId: "br_elsewhere").open(reference: _reference);

    expect(outcome, isA<FileReferenceNeedsPreview>());
    verifyNever(() => launcher.launch(any(), mode: any(named: "mode")));
  });

  test("asks for the preview when no bridge is connected", () async {
    when(() => connection.activeConfig).thenReturn(null);

    final outcome = await service(localBridgeId: "br_here").open(reference: _reference);

    expect(outcome, isA<FileReferenceNeedsPreview>());
  });

  test("falls back to the preview when the default app does not open", () async {
    when(() => launcher.launch(any(), mode: any(named: "mode"))).thenAnswer((_) async => false);

    expect(await service(localBridgeId: "br_here").open(reference: _reference), isA<FileReferenceNeedsPreview>());
  });

  test("falls back to the preview when the launcher throws", () async {
    when(() => launcher.launch(any(), mode: any(named: "mode"))).thenThrow(StateError("no handler"));

    expect(await service(localBridgeId: "br_here").open(reference: _reference), isA<FileReferenceNeedsPreview>());
  });
}
