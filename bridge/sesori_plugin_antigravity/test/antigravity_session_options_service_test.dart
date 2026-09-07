import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:antigravity_plugin/antigravity_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

AcpNewSessionResult _result({required List<Map<String, dynamic>> configs}) => AcpNewSessionResult(
  sessionId: "session",
  modes: const [],
  configOptions: configs,
  raw: const {},
);

Map<String, dynamic> _selector({required String current, required List<Object?> options}) => {
  "id": "model",
  "type": "select",
  "currentValue": current,
  "options": options,
};

AcpNewSessionResult _catalog({required String id}) => _result(
  configs: [
    _selector(
      current: id,
      options: [
        {"value": id, "name": "Label $id"},
      ],
    ),
  ],
);

class _ConfigRepository() implements AcpSessionConfigRepository {
  final List<({String session, String config, String value})> writes = [];
  AcpNewSessionResult? response;
  Object? modelFailure;
  Object? modeFailure;
  Completer<void>? modelGate;

  @override
  Future<AcpNewSessionResult?> setConfigOption({
    required String sessionId,
    required String configId,
    required String value,
  }) async {
    writes.add((session: sessionId, config: configId, value: value));
    await modelGate?.future;
    if (modelFailure case final error?) throw error;
    return response;
  }

  @override
  Future<void> setMode({required String sessionId, required String modeId}) async {
    writes.add((session: sessionId, config: "mode", value: modeId));
    if (modeFailure case final error?) throw error;
  }
}

void main() {
  late AntigravityCatalogTracker tracker;
  late _ConfigRepository repository;
  late AntigravitySessionOptionsService service;

  setUp(() {
    tracker = AntigravityCatalogTracker();
    repository = _ConfigRepository();
    service = AntigravitySessionOptionsService(
      protocolMapper: const AntigravityProtocolMapper(),
      catalogTracker: tracker,
    );
  });

  test("fresh process exposes one primary agent and no fabricated model or discovery writes", () {
    final options = service.getSessionOptions();
    expect(options.completeness, PluginSessionOptionsCompleteness.partial);
    expect(options.agents.single.name, AntigravityIdentity.pluginId);
    expect(options.agents.single.mode, PluginAgentMode.primary);
    expect(options.agents.single.model, isNull);
    expect(options.providers.providers, isEmpty);
    expect(repository.writes, isEmpty);
  });

  test("flat and grouped account models retain exact IDs, labels, order and current default", () {
    service.capture(
      source: AntigravityCatalogSource.newSession,
      result: _result(
        configs: [
          {"id": "unrelated", "type": "future-option"},
          _selector(
            current: "opaque:two",
            options: [
              {"value": " opaque one ", "name": " First label "},
              {
                "group": "Premium",
                "options": [
                  {"value": "opaque:two", "name": "Same name"},
                ],
              },
              {"value": "opaque:three", "name": "Same name"},
            ],
          ),
        ],
      ),
    );
    final options = service.getSessionOptions();
    expect(options.completeness, PluginSessionOptionsCompleteness.complete);
    final provider = options.providers.providers.single;
    expect(provider.defaultModelID, "opaque:two");
    expect(provider.models.map((model) => model.id), [" opaque one ", "opaque:two", "opaque:three"]);
    expect(provider.models.map((model) => model.name), [" First label ", "Same name", "Same name"]);
    expect(provider.models.every((model) => model.isAvailable && model.variants.isEmpty), isTrue);
    expect(() => tracker.snapshot!.models.clear(), throwsUnsupportedError);
    expect(repository.writes, isEmpty);
  });

  test("session selections cannot redefine the new-session default", () async {
    AcpNewSessionResult models({required String current}) => _result(
      configs: [
        _selector(
          current: current,
          options: [
            {"value": "account-default", "name": "Default"},
            {"value": "session-model", "name": "Selected"},
          ],
        ),
      ],
    );
    service.capture(
      source: AntigravityCatalogSource.existingSession,
      result: models(current: "session-model"),
    );
    expect(service.getSessionOptions().providers.providers.single.defaultModelID, isNull);
    service.capture(
      source: AntigravityCatalogSource.newSession,
      result: models(current: "account-default"),
    );
    service.capture(
      source: AntigravityCatalogSource.existingSession,
      result: models(current: "session-model"),
    );
    expect(service.getSessionOptions().providers.providers.single.defaultModelID, "account-default");
    repository.response = models(current: "session-model");
    await service.applyForPrompt(configRepository: repository, sessionId: "existing", modelId: "session-model");
    expect(service.getSessionOptions().providers.providers.single.defaultModelID, "account-default");
    expect(tracker.snapshot!.currentModelId, "session-model");
    service.capture(
      source: AntigravityCatalogSource.existingSession,
      result: _catalog(id: "replacement"),
    );
    expect(service.getSessionOptions().providers.providers.single.defaultModelID, isNull);
  });

  test("connection reset clears catalog and default before accepting new process options", () async {
    service.capture(
      source: AntigravityCatalogSource.newSession,
      result: _catalog(id: "old"),
    );
    tracker.clear();
    expect(service.getSessionOptions().providers.providers, isEmpty);
    expect(service.getSessionOptions().completeness, PluginSessionOptionsCompleteness.partial);
    expect(tracker.newSessionDefaultModelId, isNull);
    await expectLater(
      service.applyForPrompt(configRepository: repository, sessionId: "s", modelId: "old"),
      throwsA(isA<PluginStaleOptionsException>()),
    );
    expect(repository.writes, isEmpty);
    service.capture(
      source: AntigravityCatalogSource.newSession,
      result: _catalog(id: "fresh"),
    );
    expect(service.getSessionOptions().providers.providers.single.defaultModelID, "fresh");
  });

  test("missing selector is partial initially and does not erase an existing snapshot", () {
    service.capture(
      source: AntigravityCatalogSource.newSession,
      result: _result(configs: []),
    );
    expect(tracker.snapshot, isNull);
    service.capture(
      source: AntigravityCatalogSource.newSession,
      result: _catalog(id: "good"),
    );
    final previous = tracker.snapshot;
    service.capture(
      source: AntigravityCatalogSource.newSession,
      result: _result(configs: []),
    );
    expect(tracker.snapshot, same(previous));
  });

  test("malformed, empty, duplicate and unsupported candidates never replace the last-good catalog", () {
    service.capture(
      source: AntigravityCatalogSource.newSession,
      result: _catalog(id: "good"),
    );
    final previous = tracker.snapshot;
    for (final invalid in [
      [_selector(current: "good", options: [])],
      [
        _selector(
          current: "missing",
          options: [
            {"value": "good", "name": "Good"},
          ],
        ),
      ],
      [
        _selector(
          current: " ",
          options: [
            {"value": " ", "name": "Good"},
          ],
        ),
      ],
      [
        _selector(
          current: "good",
          options: [
            {"value": "good", "name": " "},
          ],
        ),
      ],
      [
        _selector(
          current: "good",
          options: [
            {"value": "good", "name": "Good"},
            {"value": "good", "name": "Again"},
          ],
        ),
      ],
      [
        _selector(
          current: "good",
          options: [
            {
              "options": [
                {"value": "good", "name": null},
              ],
            },
          ],
        ),
      ],
      [
        {..._selector(current: "good", options: []), "type": "future-kind"},
      ],
      [_selector(current: "good", options: []), _selector(current: "other", options: [])],
    ]) {
      expect(
        () => service.capture(
          source: AntigravityCatalogSource.newSession,
          result: _result(configs: invalid),
        ),
        throwsA(anyOf(isA<FormatException>(), isA<TypeError>())),
      );
      expect(tracker.snapshot, same(previous));
    }
  });

  test("no explicit selection preserves first-session account default and still sends default mode", () async {
    await service.applyForPrompt(configRepository: repository, sessionId: "first", modelId: null);
    expect(repository.writes, [(session: "first", config: "mode", value: "default")]);
    expect(tracker.snapshot, isNull);
  });

  test("unknown, stale, blank and pre-catalog model choices fail before any writes", () async {
    await expectLater(
      service.applyForPrompt(configRepository: repository, sessionId: "s", modelId: "old"),
      throwsA(isA<PluginStaleOptionsException>()),
    );
    service.capture(
      source: AntigravityCatalogSource.newSession,
      result: _catalog(id: "old"),
    );
    service.capture(
      source: AntigravityCatalogSource.newSession,
      result: _catalog(id: "new"),
    );
    for (final id in ["old", "unknown", "", "new "]) {
      await expectLater(
        service.applyForPrompt(configRepository: repository, sessionId: "s", modelId: id),
        throwsA(isA<PluginStaleOptionsException>()),
      );
    }
    expect(repository.writes, isEmpty);
    final longId = "x" * 1000;
    await expectLater(
      service.applyForPrompt(configRepository: repository, sessionId: "s", modelId: longId),
      throwsA(
        isA<PluginStaleOptionsException>().having(
          (error) => error.toString(),
          "bounded diagnostic",
          isNot(contains(longId)),
        ),
      ),
    );
  });

  test("exact model selection completes before default mode and captures returned catalog", () async {
    service.capture(
      source: AntigravityCatalogSource.newSession,
      result: _catalog(id: " chosen "),
    );
    repository.modelGate = Completer<void>();
    repository.response = _catalog(id: " chosen ");
    final apply = service.applyForPrompt(configRepository: repository, sessionId: "session-2", modelId: " chosen ");
    expect(repository.writes, [(session: "session-2", config: "model", value: " chosen ")]);
    repository.modelGate!.complete();
    await apply;
    expect(repository.writes.last, (session: "session-2", config: "mode", value: "default"));
    expect(tracker.snapshot!.currentModelId, " chosen ");
  });

  test("a different returned model fails before mode or prompt dispatch and retains last-good state", () async {
    service.capture(
      source: AntigravityCatalogSource.newSession,
      result: _catalog(id: "requested"),
    );
    final previous = tracker.snapshot;
    repository.response = _catalog(id: "different");
    var prompted = false;
    final dispatch = service
        .applyForPrompt(configRepository: repository, sessionId: "s", modelId: "requested")
        .then((_) => prompted = true);
    await expectLater(dispatch, throwsStateError);
    expect(prompted, isFalse);
    expect(repository.writes.single.config, "model");
    expect(tracker.snapshot, same(previous));
    expect(tracker.newSessionDefaultModelId, "requested");
  });

  test("model or mode failure propagates and prevents the caller's later prompt dispatch", () async {
    service.capture(
      source: AntigravityCatalogSource.newSession,
      result: _catalog(id: "good"),
    );
    final failure = StateError("synthetic config failure");
    repository.modelFailure = failure;
    await expectLater(
      service.applyForPrompt(configRepository: repository, sessionId: "s", modelId: "good"),
      throwsA(same(failure)),
    );
    expect(repository.writes, hasLength(1));
    repository.modelFailure = null;
    repository.modeFailure = failure;
    var prompted = false;
    final dispatch = service
        .applyForPrompt(configRepository: repository, sessionId: "s", modelId: "good")
        .then((_) => prompted = true);
    await expectLater(dispatch, throwsA(same(failure)));
    expect(prompted, isFalse);
    expect(repository.writes.map((write) => write.value), ["good", "good", "default"]);
  });

  test("malformed configuration response cannot replace the last-good catalog or continue to mode", () async {
    service.capture(
      source: AntigravityCatalogSource.newSession,
      result: _catalog(id: "good"),
    );
    final previous = tracker.snapshot;
    repository.response = _result(
      configs: [_selector(current: "good", options: [])],
    );
    await expectLater(
      service.applyForPrompt(configRepository: repository, sessionId: "s", modelId: "good"),
      throwsFormatException,
    );
    expect(tracker.snapshot, same(previous));
    expect(repository.writes.single.config, "model");
  });
}
