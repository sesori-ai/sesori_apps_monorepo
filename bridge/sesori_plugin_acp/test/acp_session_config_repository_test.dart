import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:test/test.dart";

void main() {
  late FakeAcpProcess process;
  late AcpStdioClient client;
  late AcpSessionConfigRepository repository;

  setUp(() async {
    process = FakeAcpProcess();
    client = AcpStdioClient(
      launchSpec: const AcpLaunchSpec(command: "agent", args: [], includeParentEnvironment: true),
      processFactory: (_) async => process,
    );
    await client.connect();
    repository = AcpSessionConfigRepository(api: AcpAgentApi(client: client));
  });
  tearDown(() async {
    await client.dispose();
    await process.close();
  });

  test("setMode sends standard typed session/mode params and awaits the correlated reply", () async {
    var completed = false;
    final request = repository.setMode(sessionId: "session-1", modeId: "default").then((_) => completed = true);
    final frame = process.written.single;
    expect(frame["method"], "session/set_mode");
    expect(frame["params"], {"sessionId": "session-1", "modeId": "default"});
    expect(completed, isFalse);
    process.emit({"jsonrpc": "2.0", "id": frame["id"], "result": <String, Object?>{}});
    await request;
    expect(completed, isTrue);
  });

  test("setMode does not convert agent rejection into success", () async {
    final assertion = expectLater(
      repository.setMode(sessionId: "session-1", modeId: "default"),
      throwsA(isA<AcpRpcException>()),
    );
    process.emit({
      "jsonrpc": "2.0",
      "id": process.written.single["id"],
      "error": {"code": -32602, "message": "unsupported mode"},
    });
    await assertion;
  });
}
