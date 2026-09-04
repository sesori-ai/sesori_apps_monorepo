import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:antigravity_plugin/antigravity_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

const target = PlatformTarget(os: PlatformOs.linux, arch: PlatformArch.x64);
const pathPair = AntigravityRuntimePair(
  serverPath: "/path/agy_acp_server.par",
  harnessPath: "/path/localharness_external",
  target: target,
);
const managedPair = AntigravityRuntimePair(
  serverPath: "/managed/agy_acp_server.par",
  harnessPath: "/managed/localharness_external",
  target: target,
);

AntigravityInitializeDto initializeResult({required String agentVersion}) => AntigravityInitializeDto(
  protocolVersion: 1,
  agentInfo: AntigravityAgentInfoDto(name: "antigravity-acp", title: "Google Antigravity", version: agentVersion),
  agentCapabilities: const AntigravityAgentCapabilitiesDto(
    loadSession: true,
    sessionCapabilities: AntigravitySessionCapabilitiesDto(list: true, resume: true, close: false),
    auth: AntigravityAuthCapabilitiesDto(logout: true),
  ),
  authMethods: const [AntigravityAuthMethodDto(id: "oauth-personal")],
);

class _FakeStorage({
  required final Map<String, AntigravityRuntimePairReadResult> pairResults,
  required final AntigravityRuntimePairReadResult pathResult,
}) extends AntigravityRuntimeStorage {
  int pathInspections = 0;
  final List<String> inspectedPaths = [];

  @override
  AntigravityRuntimePairReadResult inspectPair({required String serverPath, required PlatformTarget target}) {
    inspectedPaths.add(serverPath);
    return pairResults[serverPath]!;
  }

  @override
  AntigravityRuntimePairReadResult findOnPath({
    required Map<String, String> environment,
    required PlatformTarget target,
  }) {
    pathInspections++;
    return pathResult;
  }
}

Future<AcpProcessHandle> _unimplementedFactory(AcpLaunchSpec spec) => throw UnimplementedError();

class _FakeAcpApi({required final List<Future<AntigravityInitializeDto> Function()> outcomes})
    extends AntigravityAcpApi {
  this : super(processFactory: _unimplementedFactory);

  final List<AcpLaunchSpec> launches = [];

  @override
  Future<AntigravityInitializeDto> initializeOnly({
    required AcpLaunchSpec launchSpec,
    required Duration timeout,
    required StartAbortSignal abortSignal,
  }) {
    launches.add(launchSpec);
    return outcomes.removeAt(0)();
  }
}

AntigravityRuntimeService _service({required _FakeStorage storage, required _FakeAcpApi api}) =>
    AntigravityRuntimeService(
      runtimeRepository: AntigravityRuntimeRepository(
        runtimeStorage: storage,
        acpApi: api,
        launchSpecBuilder: const AntigravityLaunchSpecBuilder(),
      ),
    );

Future<AntigravityRuntimeResolution> _resolve({
  required AntigravityRuntimeService service,
  required String? explicitServerPath,
  required String? managedServerPath,
  required StartAbortSignal abortSignal,
}) => service.resolve(
  explicitServerPath: explicitServerPath,
  managedServerPath: managedServerPath,
  pathEnvironment: const {"PATH": "/path"},
  probeEnvironment: const {"GEMINI_HOME": "/isolated"},
  target: target,
  timeout: const Duration(seconds: 5),
  abortSignal: abortSignal,
);

void main() {
  test("an explicit path is authoritative and maps its storage failure", () async {
    final failure = StateError("storage failed");
    final stackTrace = StackTrace.current;
    final storage = _FakeStorage(
      pairResults: {
        "/explicit/agy_acp_server.par": AntigravityRuntimeStorageFailure(
          cause: failure,
          stackTrace: stackTrace,
        ),
      },
      pathResult: const AntigravityRuntimePairFound(pair: pathPair),
    );
    final result = await _resolve(
      service: _service(
        storage: storage,
        api: _FakeAcpApi(outcomes: []),
      ),
      explicitServerPath: "/explicit/agy_acp_server.par",
      managedServerPath: managedPair.serverPath,
      abortSignal: StartAbortSignal.never,
    ) as AntigravityRuntimeStorageFailed;

    expect(result.source, AntigravityRuntimeSource.explicit);
    expect(result.cause, same(failure));
    expect(result.stackTrace, same(stackTrace));
    expect(storage.pathInspections, 0);
  });

  test("selects PATH before managed and forwards only the prepared environment", () async {
    final storage = _FakeStorage(
      pairResults: const {},
      pathResult: const AntigravityRuntimePairFound(pair: pathPair),
    );
    final api = _FakeAcpApi(
      outcomes: [() async => initializeResult(agentVersion: AntigravityRelease.agentVersion)],
    );
    final result = await _resolve(
      service: _service(storage: storage, api: api),
      explicitServerPath: null,
      managedServerPath: managedPair.serverPath,
      abortSignal: StartAbortSignal.never,
    ) as AntigravityRuntimeSelected;

    expect((result.source, result.pair), (AntigravityRuntimeSource.path, pathPair));
    expect(storage.inspectedPaths, isEmpty);
    expect(api.launches.single.environment, {
      "GEMINI_HOME": "/isolated",
      AntigravityRelease.harnessPathEnvironmentKey: pathPair.harnessPath,
    });
  });

  test("falls back to managed after a PATH contract rejection", () async {
    final storage = _FakeStorage(
      pairResults: const {"/managed/agy_acp_server.par": AntigravityRuntimePairFound(pair: managedPair)},
      pathResult: const AntigravityRuntimePairFound(pair: pathPair),
    );
    final api = _FakeAcpApi(
      outcomes: [
        () async => initializeResult(agentVersion: "different-release"),
        () async => initializeResult(agentVersion: AntigravityRelease.agentVersion),
      ],
    );
    final result = await _resolve(
      service: _service(storage: storage, api: api),
      explicitServerPath: null,
      managedServerPath: managedPair.serverPath,
      abortSignal: StartAbortSignal.never,
    ) as AntigravityRuntimeSelected;

    expect((result.source, result.pair), (AntigravityRuntimeSource.managed, managedPair));
    expect(api.launches.map((launch) => launch.command), [pathPair.serverPath, managedPair.serverPath]);
  });

  test("shares one timeout budget across PATH and managed probes", () async {
    final storage = _FakeStorage(
      pairResults: const {"/managed/agy_acp_server.par": AntigravityRuntimePairFound(pair: managedPair)},
      pathResult: const AntigravityRuntimePairFound(pair: pathPair),
    );
    final api = _FakeAcpApi(
      outcomes: [
        () async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return initializeResult(agentVersion: "different-release");
        },
        () async => initializeResult(agentVersion: AntigravityRelease.agentVersion),
      ],
    );

    await expectLater(
      _service(storage: storage, api: api).resolve(
        explicitServerPath: null,
        managedServerPath: managedPair.serverPath,
        pathEnvironment: const {"PATH": "/path"},
        probeEnvironment: const {"GEMINI_HOME": "/isolated"},
        target: target,
        timeout: const Duration(milliseconds: 50),
        abortSignal: StartAbortSignal.never,
      ),
      throwsA(isA<TimeoutException>()),
    );
    expect(api.launches.map((launch) => launch.command), [pathPair.serverPath]);
    expect(storage.inspectedPaths, isEmpty);
  });

  test("does not inspect managed storage after cancellation at a probe boundary", () async {
    final controller = StartAbortController();
    final storage = _FakeStorage(
      pairResults: const {"/managed/agy_acp_server.par": AntigravityRuntimePairFound(pair: managedPair)},
      pathResult: const AntigravityRuntimePairFound(pair: pathPair),
    );
    final api = _FakeAcpApi(
      outcomes: [
        () async {
          controller.abort();
          return initializeResult(agentVersion: "different-release");
        },
      ],
    );

    await expectLater(
      _resolve(
        service: _service(storage: storage, api: api),
        explicitServerPath: null,
        managedServerPath: managedPair.serverPath,
        abortSignal: controller.signal,
      ),
      throwsA(isA<PluginStartAbortedException>()),
    );
    expect(api.launches.map((launch) => launch.command), [pathPair.serverPath]);
    expect(storage.inspectedPaths, isEmpty);
  });

  test("reports every exact contract violation", () async {
    const invalid = AntigravityInitializeDto(
      protocolVersion: 2,
      agentInfo: AntigravityAgentInfoDto(name: "other", title: null, version: "other"),
      agentCapabilities: AntigravityAgentCapabilitiesDto(
        loadSession: false,
        sessionCapabilities: AntigravitySessionCapabilitiesDto(list: false, resume: false, close: true),
        auth: AntigravityAuthCapabilitiesDto(logout: false),
      ),
      authMethods: [],
    );
    final api = _FakeAcpApi(outcomes: [() async => invalid]);
    final result =
        await _service(
              storage: _FakeStorage(
                pairResults: const {},
                pathResult: const AntigravityRuntimePairMissing(component: AntigravityRuntimeComponent.server),
              ),
              api: api,
            ).validatePair(
              source: AntigravityRuntimeSource.explicit,
              pair: pathPair,
              probeEnvironment: const {},
              timeout: const Duration(seconds: 5),
              abortSignal: StartAbortSignal.never,
            )
            as AntigravityRuntimeContractRejected;

    expect(result.violations, AntigravityRuntimeContractViolation.values);
  });

  test("preserves probe failures and aborts before touching boundaries", () async {
    final failure = StateError("probe failed");
    final storage = _FakeStorage(
      pairResults: const {},
      pathResult: const AntigravityRuntimePairFound(pair: pathPair),
    );
    final api = _FakeAcpApi(outcomes: [() async => throw failure]);
    final failed = await _service(storage: storage, api: api).validatePair(
      source: AntigravityRuntimeSource.explicit,
      pair: pathPair,
      probeEnvironment: const {},
      timeout: const Duration(seconds: 5),
      abortSignal: StartAbortSignal.never,
    ) as AntigravityRuntimeProbeFailed;
    expect(failed.cause, same(failure));
    expect(failed.stackTrace, isNotNull);

    final controller = StartAbortController()..abort();
    await expectLater(
      _resolve(
        service: _service(
          storage: storage,
          api: _FakeAcpApi(outcomes: []),
        ),
        explicitServerPath: null,
        managedServerPath: null,
        abortSignal: controller.signal,
      ),
      throwsA(isA<PluginStartAbortedException>()),
    );
    expect(storage.pathInspections, 0);
  });
}
