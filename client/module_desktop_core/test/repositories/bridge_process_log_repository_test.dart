import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

void main() {
  test("maps the prepared log path to its containing directory URI", () async {
    final BridgeProcessLogRepository repository = BridgeProcessLogRepository(
      storage: _FakeBridgeProcessLogStorage(),
    );

    expect(await repository.logDirectoryUri, Uri.directory("/tmp/sesori/logs"));
  });
}

class _FakeBridgeProcessLogStorage() implements BridgeProcessLogStorage {
  @override
  Future<String> get logFilePath async => "/tmp/sesori/logs/bridge.log";

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
