import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:antigravity_plugin/antigravity_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

AcpNewSessionResult _result({
  required String sessionId,
  required String current,
  required List<(String, String)> models,
}) => AcpNewSessionResult(
  sessionId: sessionId,
  modes: const [],
  configOptions: [
    {
      "id": "model",
      "type": "select",
      "currentValue": current,
      "options": [
        for (final model in models) {"value": model.$1, "name": model.$2},
      ],
    },
  ],
  raw: const {},
);

AcpNewSessionResult _variants({
  String sessionId = "session",
  String current = "gemini-3.7-flash-high",
}) => _result(
  sessionId: sessionId,
  current: current,
  models: const [
    ("gemini-3.7-flash-high", "Gemini 3.7 Flash (High)"),
    ("gemini-3.7-flash-medium", "Gemini 3.7 Flash (Medium)"),
    ("gemini-3.7-flash-low", "Gemini 3.7 Flash (Low)"),
    ("opaque", "Opaque"),
  ],
);

class _ConfigRepository() implements AcpSessionConfigRepository {
  final List<({String config, String value})> writes = [];
  AcpNewSessionResult? response;

  @override
  Future<AcpNewSessionResult?> setConfigOption({
    required String sessionId,
    required String configId,
    required String value,
  }) async {
    writes.add((config: configId, value: value));
    return response;
  }

  @override
  Future<void> setMode({required String sessionId, required String modeId}) async {
    writes.add((config: "mode", value: modeId));
  }
}

class _CatalogRepository() implements AntigravityCatalogRepository {
  List<AcpSessionInfo> sessions = const [];
  AcpNewSessionResult createResult = _variants(sessionId: "discovery");
  AcpNewSessionResult resumeResult = _variants(sessionId: "discovery");
  Object? listFailure;
  Object? createFailure;
  Object? resumeFailure;
  Completer<void>? listGate;
  Completer<void>? resumeGate;
  int listCalls = 0;
  int createCalls = 0;
  int resumeCalls = 0;
  final List<String> resumedIds = [];

  @override
  Future<List<AcpSessionInfo>> listSessions({required String directory}) async {
    listCalls++;
    await listGate?.future;
    if (listFailure case final failure?) throw failure;
    return sessions;
  }

  @override
  Future<AcpNewSessionResult> createSession({required String directory}) async {
    createCalls++;
    if (createFailure case final failure?) throw failure;
    return createResult;
  }

  @override
  Future<AcpNewSessionResult> resumeSession({required String sessionId, required String directory}) async {
    resumeCalls++;
    resumedIds.add(sessionId);
    await resumeGate?.future;
    if (resumeFailure case final failure?) throw failure;
    return resumeResult;
  }
}

void main() {
  late AntigravityCatalogTracker tracker;
  late AcpSessionConfigurationTracker configuration;
  late AntigravitySessionOptionsService service;
  late _ConfigRepository configRepository;

  setUp(() {
    tracker = AntigravityCatalogTracker();
    configuration = AcpSessionConfigurationTracker();
    service = AntigravitySessionOptionsService(
      protocolMapper: const AntigravityProtocolMapper(),
      catalogTracker: tracker,
      configurationTracker: configuration,
      discoveryDirectory: "/discovery",
    );
    configRepository = _ConfigRepository();
  });

  test("paired High Medium Low models become one ordered family with normalized default", () async {
    service.capture(
      result: _variants(current: "gemini-3.7-flash-medium"),
      sessionId: "session",
      source: AntigravityCatalogSource.newSession,
    );

    final provider = service.getSessionOptions().providers.providers.single;
    expect(provider.defaultModelID, "gemini-3.7-flash");
    expect(provider.models.map((model) => model.id), ["gemini-3.7-flash", "opaque"]);
    expect(provider.models.first.name, "Gemini 3.7 Flash");
    expect(provider.models.first.variants, ["high", "medium", "low"]);
    expect(provider.models.first.defaultVariant, "medium");
    expect(provider.models.last.variants, isEmpty);
    expect(configuration.processDefaults.modelId, "gemini-3.7-flash");
    expect(configuration.processDefaults.variantId, "medium");

    await service.applyForPrompt(
      configRepository: configRepository,
      sessionId: "session",
      modelId: "gemini-3.7-flash",
      variant: null,
    );
    expect(configRepository.writes.first.value, "gemini-3.7-flash-medium");
    expect(configuration.snapshotForSession(sessionId: "session").variantId, "medium");
  });

  test("unpaired and ambiguous suffixes remain exact standalone models", () {
    service.capture(
      result: _result(
        sessionId: "session",
        current: "family-high",
        models: const [
          ("family-high", "Family (High)"),
          ("family-low", "Different (Low)"),
          ("family", "Standalone collision"),
          ("id-medium", "Wrong suffix"),
          (" spaced-high ", "Spaced (High)"),
          ("padded-low", " Padded (Low) "),
          ("future-ultra", "Future (Ultra)"),
        ],
      ),
      sessionId: "session",
      source: AntigravityCatalogSource.newSession,
    );

    final models = service.getSessionOptions().providers.providers.single.models;
    expect(models.map((model) => model.id), [
      "family-high",
      "family-low",
      "family",
      "id-medium",
      " spaced-high ",
      "padded-low",
      "future-ultra",
    ]);
    expect(models.every((model) => model.variants.isEmpty), isTrue);
    expect(service.getSessionOptions().providers.providers.single.defaultModelID, "family-high");
  });

  test("duplicate native IDs reject candidate and preserve last-good catalog", () {
    service.capture(
      result: _variants(),
      sessionId: "session",
      source: AntigravityCatalogSource.newSession,
    );
    final previous = tracker.snapshot;

    expect(
      () => service.capture(
        result: _result(
          sessionId: "session",
          current: "duplicate",
          models: const [("duplicate", "One"), ("duplicate", "Two")],
        ),
        sessionId: "session",
        source: AntigravityCatalogSource.newSession,
      ),
      throwsFormatException,
    );
    expect(tracker.snapshot, same(previous));
  });

  test("normalized model and variant dispatch exact native ID and stamp selection", () async {
    service.capture(
      result: _variants(),
      sessionId: "session",
      source: AntigravityCatalogSource.newSession,
    );
    configRepository.response = _variants(current: "gemini-3.7-flash-low");

    await service.applyForPrompt(
      configRepository: configRepository,
      sessionId: "session",
      modelId: "gemini-3.7-flash",
      variant: const PluginSessionVariant(id: "low"),
    );

    expect(configRepository.writes, [
      (config: "model", value: "gemini-3.7-flash-low"),
      (config: "mode", value: "default"),
    ]);
    final selection = configuration.snapshotForSession(sessionId: "session");
    expect((selection.modelId, selection.variantId), ("gemini-3.7-flash", "low"));
  });

  test("omitted family variant uses declared first variant while standalone rejects variants", () async {
    service.capture(
      result: _variants(),
      sessionId: "session",
      source: AntigravityCatalogSource.newSession,
    );
    await service.applyForPrompt(
      configRepository: configRepository,
      sessionId: "session",
      modelId: "gemini-3.7-flash",
      variant: null,
    );
    expect(configRepository.writes.first.value, "gemini-3.7-flash-high");

    for (final selection in [
      (model: "opaque", variant: const PluginSessionVariant(id: "high")),
      (model: "gemini-3.7-flash", variant: const PluginSessionVariant(id: "unknown")),
      (model: "missing", variant: null),
    ]) {
      configRepository.writes.clear();
      await expectLater(
        service.applyForPrompt(
          configRepository: configRepository,
          sessionId: "session",
          modelId: selection.model,
          variant: selection.variant,
        ),
        throwsA(isA<PluginStaleOptionsException>()),
      );
      expect(configRepository.writes, isEmpty);
    }
  });

  test("variant-only selection resolves against loaded normalized session model", () async {
    service.capture(
      result: _variants(current: "gemini-3.7-flash-medium"),
      sessionId: "loaded",
      source: AntigravityCatalogSource.existingSession,
    );
    service.validateSelection(
      operation: "sendPrompt",
      providerId: null,
      modelId: null,
      variant: const PluginSessionVariant(id: "low"),
      agent: null,
    );
    await service.applyForPrompt(
      configRepository: configRepository,
      sessionId: "loaded",
      modelId: null,
      variant: const PluginSessionVariant(id: "low"),
    );
    expect(configRepository.writes.first.value, "gemini-3.7-flash-low");
  });

  test("cold discovery coalesces, creates once, reuses cache, and refresh resumes", () async {
    final repository = _CatalogRepository()..listGate = Completer<void>();
    Future<AntigravityCatalogRepository> provider() async => repository;
    final first = service.discover(
      discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
      repositoryProvider: provider,
    );
    final second = service.discover(
      discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
      repositoryProvider: provider,
    );
    expect(identical(first, second), isTrue);
    repository.listGate!.complete();
    expect(await first, isA<PluginSessionOptionsDiscoveryObserved>());
    expect((repository.listCalls, repository.createCalls, repository.resumeCalls), (1, 1, 0));

    await service.discover(
      discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
      repositoryProvider: provider,
    );
    expect((repository.listCalls, repository.createCalls, repository.resumeCalls), (1, 1, 0));
    repository.resumeResult = _variants(sessionId: "discovery", current: "gemini-3.7-flash-low");
    expect(
      await service.discover(
        discoveryMode: PluginSessionOptionsDiscoveryMode.refresh,
        repositoryProvider: provider,
      ),
      isA<PluginSessionOptionsDiscoveryObserved>(),
    );
    expect(repository.resumedIds, ["discovery"]);
    expect(tracker.newSessionDefault?.variantId, "low");
  });

  test("restart-style discovery reuses first sorted reserved session", () async {
    final repository = _CatalogRepository()
      ..sessions = const [
        AcpSessionInfo(sessionId: "z", cwd: "/discovery", title: null, updatedAtMs: null),
        AcpSessionInfo(sessionId: "other", cwd: "/other", title: null, updatedAtMs: null),
        AcpSessionInfo(sessionId: "a", cwd: "/discovery", title: null, updatedAtMs: null),
      ]
      ..resumeResult = _variants(sessionId: "a");

    await service.discover(
      discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
      repositoryProvider: () async => repository,
    );
    expect(repository.resumedIds, ["a"]);
    expect(repository.createCalls, 0);
    expect(service.isDiscoverySession(sessionId: "z", directory: "/any"), isFalse);
    expect(service.isDiscoverySession(sessionId: "visible", directory: "/discovery"), isTrue);
  });

  test("list and resume failures do not create replacements and retain last-good", () async {
    final repository = _CatalogRepository()..listFailure = StateError("list failed");
    expect(
      await service.discover(
        discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
        repositoryProvider: () async => repository,
      ),
      isA<PluginSessionOptionsDiscoveryFailed>(),
    );
    expect(repository.createCalls, 0);

    repository
      ..listFailure = null
      ..sessions = const [AcpSessionInfo(sessionId: "reserved", cwd: "/discovery", title: null, updatedAtMs: null)];
    await service.discover(
      discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
      repositoryProvider: () async => repository,
    );
    final previous = tracker.snapshot;
    repository.resumeFailure = StateError("resume failed");
    expect(
      await service.discover(
        discoveryMode: PluginSessionOptionsDiscoveryMode.refresh,
        repositoryProvider: () async => repository,
      ),
      isA<PluginSessionOptionsDiscoveryFailed>(),
    );
    expect(repository.createCalls, 0);
    expect(tracker.snapshot, same(previous));

    repository
      ..resumeFailure = null
      ..resumeResult = const AcpNewSessionResult(
        sessionId: "reserved",
        modes: [],
        configOptions: [],
        raw: {},
      );
    expect(
      await service.discover(
        discoveryMode: PluginSessionOptionsDiscoveryMode.refresh,
        repositoryProvider: () async => repository,
      ),
      isA<PluginSessionOptionsDiscoveryFailed>(),
    );
    expect(tracker.snapshot, same(previous));
    expect(repository.createCalls, 0);
  });

  test("reset fences late discovery while retaining reserved ID for reconnect resume", () async {
    final repository = _CatalogRepository();
    await service.discover(
      discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
      repositoryProvider: () async => repository,
    );
    repository.resumeGate = Completer<void>();
    final refresh = service.discover(
      discoveryMode: PluginSessionOptionsDiscoveryMode.refresh,
      repositoryProvider: () async => repository,
    );
    await Future<void>.delayed(Duration.zero);
    service.resetConnection();
    repository.resumeGate!.complete();
    expect(await refresh, isA<PluginSessionOptionsDiscoveryFailed>());
    expect(tracker.snapshot, isNull);

    repository.resumeGate = null;
    await service.discover(
      discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
      repositoryProvider: () async => repository,
    );
    expect(repository.resumedIds.last, "discovery");
  });
}
