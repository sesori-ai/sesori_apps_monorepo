import "dart:async";
import "dart:io";

import "package:sesori_bridge/src/bridge/repositories/models/session_options_cache_key.dart";
import "package:sesori_bridge/src/bridge/repositories/session_options_repository.dart";
import "package:sesori_bridge/src/bridge/services/session_options_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  final now = DateTime.utc(2026, 7, 30, 12);

  group("SessionOptionsService cache validation", () {
    test("cache-only load resolves scope without activating or capturing a plugin", () async {
      final repository = _FakeSessionOptionsRepository()
        ..projectPaths["project-1"] = "/projects/one"
        ..put(
          _entry(
            key: const SessionOptionsCacheKey.plugin(pluginId: "plugin-1"),
            response: _response(marker: "cached"),
            capturedAt: now,
          ),
        );
      final service = _service(
        repository: repository,
        now: now,
        scopes: const {"plugin-1": PluginSessionOptionsScope.plugin},
      );

      final outcome = await service.loadCacheOnly(pluginId: "plugin-1", projectId: "project-1");

      expect(outcome, isA<SessionOptionsAvailable>());
      expect((outcome as SessionOptionsAvailable).response, _response(marker: "cached"));
      expect(repository.captureCalls, isEmpty);
      expect(repository.commitCalls, isEmpty);
      expect(repository.runtimeChecks, 0);
    });

    test("project absence is typed before cache access", () async {
      final repository = _FakeSessionOptionsRepository();
      final service = _service(repository: repository, now: now);

      final outcome = await service.loadCacheOnly(pluginId: "plugin-1", projectId: "missing");

      expect(outcome, isA<SessionOptionsProjectNotFound>());
      expect(repository.readCalls, 0);
    });

    test("captured path must exactly match the resolved key", () async {
      final repository = _FakeSessionOptionsRepository()
        ..projectPaths["project-1"] = "/projects/current"
        ..put(
          _entry(
            key: const SessionOptionsCacheKey.project(
              pluginId: "plugin-1",
              projectId: "project-1",
              projectPath: "/projects/old",
            ),
            response: _response(marker: "old-path"),
            capturedAt: now,
          ),
        );
      final service = _service(repository: repository, now: now);

      expect(
        await service.loadCacheOnly(pluginId: "plugin-1", projectId: "project-1"),
        isA<SessionOptionsCacheUnavailable>(),
      );
      expect(repository.deletedKeys.single, isA<ProjectSessionOptionsCacheKey>());
    });

    test("expired and future rows are deleted while the retention boundary remains valid", () async {
      final repository = _FakeSessionOptionsRepository()..projectPaths["project-1"] = "/projects/one";
      final service = _service(repository: repository, now: now);
      const key = SessionOptionsCacheKey.project(
        pluginId: "plugin-1",
        projectId: "project-1",
        projectPath: "/projects/one",
      );

      repository.put(
        _entry(
          key: key,
          response: _response(marker: "boundary"),
          capturedAt: now.subtract(const Duration(days: 30)),
        ),
      );
      expect(
        await service.loadCacheOnly(pluginId: "plugin-1", projectId: "project-1"),
        isA<SessionOptionsAvailable>(),
      );
      expect(repository.deletedKeys, isEmpty);

      repository.put(
        _entry(
          key: key,
          response: _response(marker: "expired"),
          capturedAt: now.subtract(const Duration(days: 30, milliseconds: 1)),
        ),
      );
      expect(
        await service.loadCacheOnly(pluginId: "plugin-1", projectId: "project-1"),
        isA<SessionOptionsCacheUnavailable>(),
      );
      expect(repository.deletedKeys, hasLength(1));

      repository.put(
        _entry(
          key: key,
          response: _response(marker: "future"),
          capturedAt: now.add(const Duration(milliseconds: 1)),
        ),
      );
      expect(
        await service.loadCacheOnly(pluginId: "plugin-1", projectId: "project-1"),
        isA<SessionOptionsCacheUnavailable>(),
      );
      expect(repository.deletedKeys, hasLength(2));
    });

    test("invalid cache deletion preserves a concurrently replaced revision", () async {
      final repository = _FakeSessionOptionsRepository()..projectPaths["project-1"] = "/projects/one";
      const key = SessionOptionsCacheKey.project(
        pluginId: "plugin-1",
        projectId: "project-1",
        projectPath: "/projects/one",
      );
      final expired = _entry(
        key: key,
        response: _response(marker: "expired"),
        capturedAt: now.subtract(const Duration(days: 31)),
        revision: 1,
      );
      final fresh = _entry(
        key: key,
        response: _response(marker: "fresh"),
        capturedAt: now,
        revision: 2,
      );
      repository
        ..put(expired)
        ..readHandler = (_) async {
          repository
            ..put(fresh)
            ..readHandler = null;
          return expired;
        };
      final service = _service(repository: repository, now: now);

      final outcome = await service.loadCacheOnly(pluginId: "plugin-1", projectId: "project-1");

      expect(outcome, isA<SessionOptionsAvailable>());
      expect((outcome as SessionOptionsAvailable).response, _response(marker: "fresh"));
      expect(repository.conditionalDeleteCalls.single.expectedRevision, 1);
      expect(repository.stored(key), fresh);
    });

    test("undecodable cache logging excludes the payload-bearing cause", () async {
      const key = SessionOptionsCacheKey.project(
        pluginId: "plugin-1",
        projectId: "project-1",
        projectPath: "/projects/one",
      );
      final fresh = _entry(
        key: key,
        response: _response(marker: "fresh"),
        capturedAt: now,
        revision: 2,
      );
      final repository = _FakeSessionOptionsRepository()..projectPaths["project-1"] = "/projects/one";
      repository.readHandler = (_) async {
        repository
          ..put(fresh)
          ..readHandler = null;
        throw SessionOptionsCacheDecodingException(
          cause: const FormatException("private-cache-payload"),
          causeStackTrace: StackTrace.current,
          revision: 1,
        );
      };
      final service = _service(repository: repository, now: now);

      final output = await _captureLogOutput(
        level: LogLevel.verbose,
        action: () async {
          final outcome = await service.loadCacheOnly(pluginId: "plugin-1", projectId: "project-1");
          expect(outcome, isA<SessionOptionsAvailable>());
          expect((outcome as SessionOptionsAvailable).response, _response(marker: "fresh"));
        },
      );

      expect(output, contains("Recovering from undecodable session options cache for plugin plugin-1"));
      expect(output, isNot(contains("private-cache-payload")));
      expect(repository.conditionalDeleteCalls.single.expectedRevision, 1);
      expect(repository.stored(key), fresh);
    });
  });

  group("SessionOptionsService refresh policy", () {
    test("capture failure retains only a previously valid row", () async {
      final repository = _FakeSessionOptionsRepository()
        ..projectPaths["project-1"] = "/projects/one"
        ..captureResult = const SessionOptionsCaptureFailed();
      const key = SessionOptionsCacheKey.project(
        pluginId: "plugin-1",
        projectId: "project-1",
        projectPath: "/projects/one",
      );
      repository.put(
        _entry(
          key: key,
          response: _response(marker: "retained"),
          capturedAt: now,
        ),
      );
      final service = _service(repository: repository, now: now);

      expect(
        await service.refreshExplicit(pluginId: "plugin-1", projectId: "project-1"),
        isA<SessionOptionsRefreshFailedRetained>(),
      );

      repository.remove(key);
      expect(
        await service.refreshExplicit(pluginId: "plugin-1", projectId: "project-1"),
        isA<SessionOptionsRefreshFailedUnavailable>(),
      );
    });

    test("capture failure revalidates retention before retaining the cached response", () async {
      final repository = _FakeSessionOptionsRepository()
        ..projectPaths["project-1"] = "/projects/one"
        ..captureResult = const SessionOptionsCaptureFailed();
      const key = SessionOptionsCacheKey.project(
        pluginId: "plugin-1",
        projectId: "project-1",
        projectPath: "/projects/one",
      );
      repository.put(
        _entry(
          key: key,
          response: _response(marker: "expired-during-capture"),
          capturedAt: now,
        ),
      );
      final service = SessionOptionsService(
        repository: repository,
        pluginScopes: const {"plugin-1": PluginSessionOptionsScope.project},
        clock: _AdvancingClock(now: now),
        retention: Duration.zero,
      );

      final outcome = await service.refreshExplicit(pluginId: "plugin-1", projectId: "project-1");

      expect(outcome, isA<SessionOptionsRefreshFailedUnavailable>());
      expect(repository.deletedKeys, [key]);
    });

    test("path-invalid and expired rows are deleted before failed capture and cannot be retained", () async {
      final repository = _FakeSessionOptionsRepository()
        ..projectPaths["project-1"] = "/projects/current"
        ..captureResult = const SessionOptionsCaptureFailed();
      const currentKey = SessionOptionsCacheKey.project(
        pluginId: "plugin-1",
        projectId: "project-1",
        projectPath: "/projects/current",
      );
      repository.put(
        _entry(
          key: const SessionOptionsCacheKey.project(
            pluginId: "plugin-1",
            projectId: "project-1",
            projectPath: "/projects/old",
          ),
          response: _response(marker: "old-path"),
          capturedAt: now,
        ),
      );
      final service = _service(repository: repository, now: now);

      expect(
        await service.refreshExplicit(pluginId: "plugin-1", projectId: "project-1"),
        isA<SessionOptionsRefreshFailedUnavailable>(),
      );
      expect(repository.deletedKeys, [currentKey]);

      repository.put(
        _entry(
          key: currentKey,
          response: _response(marker: "expired"),
          capturedAt: now.subtract(const Duration(days: 31)),
        ),
      );
      expect(
        await service.refreshExplicit(pluginId: "plugin-1", projectId: "project-1"),
        isA<SessionOptionsRefreshFailedUnavailable>(),
      );
      expect(repository.deletedKeys, [currentKey, currentKey]);
    });

    test("partial observations seed only empty cache and never replace retained data", () async {
      final repository = _FakeSessionOptionsRepository()
        ..projectPaths["project-1"] = "/projects/one"
        ..captureResult = _observed(
          marker: "partial-seed",
          completeness: PluginSessionOptionsCompleteness.partial,
          generation: 7,
        );
      final service = _service(repository: repository, now: now);
      const key = SessionOptionsCacheKey.project(
        pluginId: "plugin-1",
        projectId: "project-1",
        projectPath: "/projects/one",
      );

      final seeded = await service.refreshExplicit(pluginId: "plugin-1", projectId: "project-1");
      expect(seeded, isA<SessionOptionsAvailable>());
      expect(repository.commitCalls, hasLength(1));
      expect(repository.commitCalls.single.candidate.revision, 1);
      expect(repository.stored(key)!.completeness, PluginSessionOptionsCompleteness.partial);

      for (final completeness in PluginSessionOptionsCompleteness.values) {
        repository
          ..commitCalls.clear()
          ..put(
            _entry(
              key: key,
              response: _response(marker: "retained-${completeness.name}"),
              capturedAt: now,
              completeness: completeness,
              revision: 5,
            ),
          )
          ..captureResult = _observed(
            marker: "ignored",
            completeness: PluginSessionOptionsCompleteness.partial,
            generation: 7,
          );

        final outcome = await service.refreshExplicit(pluginId: "plugin-1", projectId: "project-1");

        expect(outcome, isA<SessionOptionsAvailable>());
        expect(
          (outcome as SessionOptionsAvailable).response,
          _response(marker: "retained-${completeness.name}"),
        );
        expect(repository.commitCalls, isEmpty);
      }
    });

    test("complete observations replace both partial and complete rows", () async {
      for (final completeness in PluginSessionOptionsCompleteness.values) {
        final repository = _FakeSessionOptionsRepository()
          ..projectPaths["project-1"] = "/projects/one"
          ..captureResult = _observed(
            marker: "complete",
            completeness: PluginSessionOptionsCompleteness.complete,
            generation: 7,
          );
        const key = SessionOptionsCacheKey.project(
          pluginId: "plugin-1",
          projectId: "project-1",
          projectPath: "/projects/one",
        );
        repository.put(
          _entry(
            key: key,
            response: _response(marker: "old"),
            capturedAt: now,
            completeness: completeness,
            revision: 4,
          ),
        );
        final service = _service(repository: repository, now: now);

        final outcome = await service.refreshExplicit(pluginId: "plugin-1", projectId: "project-1");

        expect(outcome, isA<SessionOptionsAvailable>());
        expect((outcome as SessionOptionsAvailable).response, _response(marker: "complete"));
        expect(repository.commitCalls.single.expectedRevision, 4);
        expect(repository.commitCalls.single.candidate.revision, 5);
        expect(repository.stored(key)!.completeness, PluginSessionOptionsCompleteness.complete);
      }
    });

    test("explicit and automatic refresh use the required activation and discovery pairs", () async {
      final repository = _FakeSessionOptionsRepository()
        ..projectPaths["project-1"] = "/projects/one"
        ..captureResult = _observed(
          marker: "captured",
          completeness: PluginSessionOptionsCompleteness.complete,
          generation: 7,
        );
      final service = _service(repository: repository, now: now);

      await service.refreshExplicit(pluginId: "plugin-1", projectId: "project-1");
      expect(repository.captureCalls.single.activation, SessionOptionsCaptureActivation.mayActivate);
      expect(repository.captureCalls.single.discoveryMode, PluginSessionOptionsDiscoveryMode.refresh);

      repository.captureCalls.clear();
      await service.refreshActiveOnly(pluginId: "plugin-1", projectId: "project-1", generation: 7);
      expect(repository.captureCalls.single.activation, SessionOptionsCaptureActivation.activeOnly);
      expect(repository.captureCalls.single.discoveryMode, PluginSessionOptionsDiscoveryMode.reuse);
    });

    test("backend-session refresh resolves the stable binding before capturing", () async {
      final repository = _FakeSessionOptionsRepository()
        ..projectPaths["stable-project"] = "/projects/stable"
        ..backendBindings["plugin-1/backend-session"] = "stable-project"
        ..captureResult = _observed(
          marker: "captured",
          completeness: PluginSessionOptionsCompleteness.complete,
          generation: 7,
        );
      final service = _service(repository: repository, now: now);

      final outcome = await service.refreshActiveOnlyForBackendSession(
        pluginId: "plugin-1",
        backendSessionId: "backend-session",
        generation: 7,
      );

      expect(outcome, isA<SessionOptionsAvailable>());
      expect(repository.captureCalls.single.projectPath, "/projects/stable");
      expect(repository.captureCalls.single.expectedGeneration, 7);
    });

    test("inactive and stale automatic triggers perform no cache write or capture", () async {
      final inactiveRepository = _FakeSessionOptionsRepository()
        ..pluginActive = false
        ..projectPaths["project-1"] = "/projects/current"
        ..put(
          _entry(
            key: const SessionOptionsCacheKey.project(
              pluginId: "plugin-1",
              projectId: "project-1",
              projectPath: "/projects/old",
            ),
            response: _response(marker: "invalid"),
            capturedAt: now,
          ),
        );
      final inactiveService = _service(repository: inactiveRepository, now: now);

      expect(
        await inactiveService.refreshActiveOnly(pluginId: "plugin-1", projectId: "project-1", generation: 7),
        isA<SessionOptionsAutomaticNoOp>(),
      );
      expect(inactiveRepository.captureCalls, isEmpty);
      expect(inactiveRepository.commitCalls, isEmpty);
      expect(inactiveRepository.deletedKeys, isEmpty);

      final staleRepository = _FakeSessionOptionsRepository()
        ..currentGeneration = 8
        ..backendBindings["plugin-1/backend-session"] = "project-1";
      final staleService = _service(repository: staleRepository, now: now);
      expect(
        await staleService.refreshActiveOnlyForBackendSession(
          pluginId: "plugin-1",
          backendSessionId: "backend-session",
          generation: 7,
        ),
        isA<SessionOptionsAutomaticNoOp>(),
      );
      expect(staleRepository.bindingReads, 0);
      expect(staleRepository.captureCalls, isEmpty);
      expect(staleRepository.commitCalls, isEmpty);
    });

    test("a moved project prevents stale in-flight capture from replacing the new-path cache", () async {
      final oldCapture = Completer<SessionOptionsCaptureResult>();
      final repository = _FakeSessionOptionsRepository()..projectPaths["project-1"] = "/projects/old";
      repository.captureHandler = (call) {
        if (call.projectPath == "/projects/old") return oldCapture.future;
        return Future.value(
          _observed(
            marker: "new-path",
            completeness: PluginSessionOptionsCompleteness.complete,
            generation: 7,
          ),
        );
      };
      final service = _service(repository: repository, now: now);
      const newKey = SessionOptionsCacheKey.project(
        pluginId: "plugin-1",
        projectId: "project-1",
        projectPath: "/projects/new",
      );

      final staleRefresh = service.refreshExplicit(pluginId: "plugin-1", projectId: "project-1");
      await _waitFor(condition: () => repository.captureCalls.length == 1);
      repository.projectPaths["project-1"] = "/projects/new";

      final currentOutcome = await service.refreshExplicit(pluginId: "plugin-1", projectId: "project-1");
      oldCapture.complete(
        _observed(
          marker: "old-path",
          completeness: PluginSessionOptionsCompleteness.complete,
          generation: 7,
        ),
      );
      final staleOutcome = await staleRefresh;

      expect(currentOutcome, isA<SessionOptionsAvailable>());
      expect(staleOutcome, isA<SessionOptionsRefreshFailedUnavailable>());
      expect(repository.stored(newKey)!.response, _response(marker: "new-path"));
      expect(repository.commitCalls, hasLength(1));
    });
  });

  group("SessionOptionsService CAS", () {
    test("a conflict rereads and retries the same complete observation once with the newest revision", () async {
      final repository = _FakeSessionOptionsRepository()
        ..projectPaths["project-1"] = "/projects/one"
        ..captureResult = _observed(
          marker: "observation",
          completeness: PluginSessionOptionsCompleteness.complete,
          generation: 7,
        );
      const key = SessionOptionsCacheKey.project(
        pluginId: "plugin-1",
        projectId: "project-1",
        projectPath: "/projects/one",
      );
      var attempt = 0;
      repository.commitHandler = (call) async {
        attempt++;
        if (attempt == 1) {
          repository.put(
            _entry(
              key: key,
              response: _response(marker: "concurrent"),
              capturedAt: now,
              revision: 4,
            ),
          );
          return false;
        }
        return repository.applyCas(call);
      };
      final service = SessionOptionsService(
        repository: repository,
        pluginScopes: const {"plugin-1": PluginSessionOptionsScope.project},
        clock: _AdvancingClock(now: now),
        retention: const Duration(days: 30),
      );

      final outcome = await service.refreshExplicit(pluginId: "plugin-1", projectId: "project-1");

      expect(outcome, isA<SessionOptionsAvailable>());
      expect((outcome as SessionOptionsAvailable).response, _response(marker: "observation"));
      expect(repository.commitCalls, hasLength(2));
      expect(repository.commitCalls[0].expectedRevision, isNull);
      expect(repository.commitCalls[0].candidate.revision, 1);
      expect(repository.commitCalls[1].expectedRevision, 4);
      expect(repository.commitCalls[1].candidate.revision, 5);
      expect(repository.commitCalls[1].candidate.capturedAt, repository.commitCalls[0].candidate.capturedAt);
    });

    test("a partial observation loses a conflict to the newest retained row without retrying", () async {
      final repository = _FakeSessionOptionsRepository()
        ..projectPaths["project-1"] = "/projects/one"
        ..captureResult = _observed(
          marker: "partial",
          completeness: PluginSessionOptionsCompleteness.partial,
          generation: 7,
        );
      const key = SessionOptionsCacheKey.project(
        pluginId: "plugin-1",
        projectId: "project-1",
        projectPath: "/projects/one",
      );
      repository.commitHandler = (_) async {
        repository.put(
          _entry(
            key: key,
            response: _response(marker: "concurrent-complete"),
            capturedAt: now,
            completeness: PluginSessionOptionsCompleteness.complete,
            revision: 2,
          ),
        );
        return false;
      };
      final service = _service(repository: repository, now: now);

      final outcome = await service.refreshExplicit(pluginId: "plugin-1", projectId: "project-1");

      expect(outcome, isA<SessionOptionsAvailable>());
      expect((outcome as SessionOptionsAvailable).response, _response(marker: "concurrent-complete"));
      expect(repository.commitCalls, hasLength(1));
    });

    test("a second conflict retains the newest row and never attempts a third CAS", () async {
      final repository = _FakeSessionOptionsRepository()
        ..projectPaths["project-1"] = "/projects/one"
        ..captureResult = _observed(
          marker: "observation",
          completeness: PluginSessionOptionsCompleteness.complete,
          generation: 7,
        );
      const key = SessionOptionsCacheKey.project(
        pluginId: "plugin-1",
        projectId: "project-1",
        projectPath: "/projects/one",
      );
      var attempt = 0;
      repository.commitHandler = (_) async {
        attempt++;
        repository.put(
          _entry(
            key: key,
            response: _response(marker: "concurrent-$attempt"),
            capturedAt: now,
            revision: attempt + 1,
          ),
        );
        return false;
      };
      final service = _service(repository: repository, now: now);

      final outcome = await service.refreshExplicit(pluginId: "plugin-1", projectId: "project-1");

      expect(outcome, isA<SessionOptionsAvailable>());
      expect((outcome as SessionOptionsAvailable).response, _response(marker: "concurrent-2"));
      expect(repository.commitCalls, hasLength(2));
    });
  });

  group("SessionOptionsService coalescing", () {
    test("forced callers during reuse share exactly one forced tail and await its result", () async {
      final reuseGate = Completer<SessionOptionsCaptureResult>();
      final forcedGate = Completer<SessionOptionsCaptureResult>();
      final repository = _FakeSessionOptionsRepository()..projectPaths["project-1"] = "/projects/one";
      repository.captureHandler = (call) {
        return switch (call.discoveryMode) {
          PluginSessionOptionsDiscoveryMode.reuse => reuseGate.future,
          PluginSessionOptionsDiscoveryMode.refresh => forcedGate.future,
        };
      };
      final service = _service(repository: repository, now: now);

      final automatic = service.refreshActiveOnly(pluginId: "plugin-1", projectId: "project-1", generation: 7);
      await _waitFor(condition: () => repository.captureCalls.length == 1);
      final firstForced = service.refreshExplicit(pluginId: "plugin-1", projectId: "project-1");
      final secondForced = service.refreshExplicit(pluginId: "plugin-1", projectId: "project-1");
      var forcedCompletions = 0;
      unawaited(firstForced.then((_) => forcedCompletions++));
      unawaited(secondForced.then((_) => forcedCompletions++));

      await Future<void>.delayed(Duration.zero);
      expect(repository.captureCalls, hasLength(1));
      expect(forcedCompletions, 0);

      reuseGate.complete(
        _observed(
          marker: "reuse",
          completeness: PluginSessionOptionsCompleteness.complete,
          generation: 7,
        ),
      );
      final automaticOutcome = await automatic;
      expect((automaticOutcome as SessionOptionsAvailable).response, _response(marker: "reuse"));
      await _waitFor(condition: () => repository.captureCalls.length == 2);
      expect(repository.captureCalls[0].discoveryMode, PluginSessionOptionsDiscoveryMode.reuse);
      expect(repository.captureCalls[1].discoveryMode, PluginSessionOptionsDiscoveryMode.refresh);
      expect(forcedCompletions, 0);

      forcedGate.complete(
        _observed(
          marker: "forced",
          completeness: PluginSessionOptionsCompleteness.complete,
          generation: 7,
        ),
      );
      final forcedOutcomes = await Future.wait([firstForced, secondForced]);

      expect(repository.captureCalls, hasLength(2));
      expect(forcedCompletions, 2);
      expect(
        forcedOutcomes.map((outcome) => (outcome as SessionOptionsAvailable).response),
        everyElement(_response(marker: "forced")),
      );
    });

    test("a current-generation reuse queues behind stale-generation reuse", () async {
      final staleCapture = Completer<SessionOptionsCaptureResult>();
      final repository = _FakeSessionOptionsRepository()..projectPaths["project-1"] = "/projects/one";
      repository.captureHandler = (call) {
        if (call.expectedGeneration == 7) return staleCapture.future;
        return Future.value(
          _observed(
            marker: "generation-8",
            completeness: PluginSessionOptionsCompleteness.complete,
            generation: 8,
          ),
        );
      };
      final service = _service(repository: repository, now: now);

      final stale = service.refreshActiveOnly(pluginId: "plugin-1", projectId: "project-1", generation: 7);
      await _waitFor(condition: () => repository.captureCalls.length == 1);
      repository.currentGeneration = 8;
      final current = service.refreshActiveOnly(pluginId: "plugin-1", projectId: "project-1", generation: 8);
      await Future<void>.delayed(Duration.zero);
      expect(repository.captureCalls, hasLength(1));

      staleCapture.complete(
        _observed(
          marker: "generation-7",
          completeness: PluginSessionOptionsCompleteness.complete,
          generation: 7,
        ),
      );

      expect(await stale, isA<SessionOptionsAutomaticNoOp>());
      final currentOutcome = await current;
      expect(currentOutcome, isA<SessionOptionsAvailable>());
      expect((currentOutcome as SessionOptionsAvailable).response, _response(marker: "generation-8"));
      expect(repository.captureCalls.map((call) => call.expectedGeneration), [7, 8]);
    });
  });
}

SessionOptionsService _service({
  required _FakeSessionOptionsRepository repository,
  required DateTime now,
  Map<String, PluginSessionOptionsScope> scopes = const {"plugin-1": PluginSessionOptionsScope.project},
}) {
  return SessionOptionsService(
    repository: repository,
    pluginScopes: scopes,
    clock: _FixedClock(nowValue: now),
    retention: const Duration(days: 30),
  );
}

SessionOptionsCacheEntry _entry({
  required SessionOptionsCacheKey key,
  required SessionOptionsResponse response,
  required DateTime capturedAt,
  PluginSessionOptionsCompleteness completeness = PluginSessionOptionsCompleteness.complete,
  int revision = 1,
}) {
  return SessionOptionsCacheEntry(
    key: key,
    revision: revision,
    capturedAt: capturedAt,
    completeness: completeness,
    response: response,
  );
}

SessionOptionsCaptureObserved _observed({
  required String marker,
  required PluginSessionOptionsCompleteness completeness,
  required int generation,
}) {
  return SessionOptionsCaptureObserved(
    response: _response(marker: marker),
    completeness: completeness,
    generation: generation,
  );
}

SessionOptionsResponse _response({required String marker}) {
  return SessionOptionsResponse(
    agents: Agents(
      agents: [
        AgentInfo(
          name: marker,
          description: null,
          model: null,
          mode: AgentMode.primary,
        ),
      ],
    ),
    providers: const ProviderListResponse(items: [], connectedOnly: true),
    commands: const CommandListResponse(items: []),
  );
}

Future<void> _waitFor({required bool Function() condition}) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail("condition was not reached");
}

Future<String> _captureLogOutput({
  required LogLevel level,
  required Future<void> Function() action,
}) async {
  final stdoutBuffer = _BufferingStdout();
  final stderrBuffer = _BufferingStdout();
  final previousLevel = Log.level;
  try {
    Log.level = level;
    await IOOverrides.runZoned(
      action,
      stdout: () => stdoutBuffer,
      stderr: () => stderrBuffer,
    );
  } finally {
    Log.level = previousLevel;
  }
  return stderrBuffer.text;
}

class _BufferingStdout implements Stdout {
  final StringBuffer _buffer = StringBuffer();

  String get text => _buffer.toString();

  @override
  void write(Object? object) => _buffer.write(object);

  @override
  void writeln([Object? object = ""]) => _buffer.writeln(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FixedClock extends ServerClock {
  const _FixedClock({required this.nowValue});

  final DateTime nowValue;

  @override
  DateTime now() => nowValue;
}

class _AdvancingClock extends ServerClock {
  _AdvancingClock({required DateTime now}) : _now = now;

  DateTime _now;

  @override
  DateTime now() {
    final value = _now;
    _now = _now.add(const Duration(seconds: 1));
    return value;
  }
}

typedef _CacheIdentity = ({String pluginId, PluginSessionOptionsScope scope, String ownerId});

class _CaptureCall {
  const _CaptureCall({
    required this.key,
    required this.projectPath,
    required this.activation,
    required this.discoveryMode,
    required this.expectedGeneration,
  });

  final SessionOptionsCacheKey key;
  final String projectPath;
  final SessionOptionsCaptureActivation activation;
  final PluginSessionOptionsDiscoveryMode discoveryMode;
  final int? expectedGeneration;
}

class _CommitCall {
  const _CommitCall({
    required this.candidate,
    required this.expectedRevision,
    required this.generation,
  });

  final SessionOptionsCacheEntry candidate;
  final int? expectedRevision;
  final int generation;
}

class _ConditionalDeleteCall {
  const _ConditionalDeleteCall({required this.key, required this.expectedRevision});

  final SessionOptionsCacheKey key;
  final int expectedRevision;
}

class _FakeSessionOptionsRepository implements SessionOptionsRepository {
  final Map<String, String> projectPaths = {};
  final Map<String, String> backendBindings = {};
  final Map<_CacheIdentity, SessionOptionsCacheEntry> _cache = {};
  final List<SessionOptionsCacheKey> deletedKeys = [];
  final List<_ConditionalDeleteCall> conditionalDeleteCalls = [];
  final List<_CaptureCall> captureCalls = [];
  final List<_CommitCall> commitCalls = [];
  bool pluginActive = true;
  int currentGeneration = 7;
  int runtimeChecks = 0;
  int bindingReads = 0;
  int readCalls = 0;
  SessionOptionsCaptureResult captureResult = _observed(
    marker: "default",
    completeness: PluginSessionOptionsCompleteness.complete,
    generation: 7,
  );
  Future<SessionOptionsCacheEntry?> Function(SessionOptionsCacheKey key)? readHandler;
  Future<SessionOptionsCaptureResult> Function(_CaptureCall call)? captureHandler;
  Future<bool> Function(_CommitCall call)? commitHandler;

  void put(SessionOptionsCacheEntry entry) {
    _cache[_identity(entry.key)] = entry;
  }

  void remove(SessionOptionsCacheKey key) {
    _cache.remove(_identity(key));
  }

  SessionOptionsCacheEntry? stored(SessionOptionsCacheKey key) => _cache[_identity(key)];

  bool applyCas(_CommitCall call) {
    final current = stored(call.candidate.key);
    if (current?.revision != call.expectedRevision) return false;
    put(call.candidate);
    return true;
  }

  @override
  Future<String?> resolveProjectPath({required String projectId}) async => projectPaths[projectId];

  @override
  Future<String?> resolveProjectIdForBackendSession({
    required String pluginId,
    required String backendSessionId,
  }) async {
    bindingReads++;
    return backendBindings["$pluginId/$backendSessionId"];
  }

  @override
  bool isPluginActive({required String pluginId}) {
    runtimeChecks++;
    return pluginActive;
  }

  @override
  bool isCurrentGeneration({required String pluginId, required int generation}) {
    runtimeChecks++;
    return generation == currentGeneration;
  }

  @override
  Future<SessionOptionsCacheEntry?> read({required SessionOptionsCacheKey key}) async {
    readCalls++;
    final handler = readHandler;
    return handler == null ? stored(key) : handler(key);
  }

  @override
  Future<void> delete({required SessionOptionsCacheKey key}) async {
    deletedKeys.add(key);
    remove(key);
  }

  @override
  Future<bool> deleteIfRevision({
    required SessionOptionsCacheKey key,
    required int expectedRevision,
  }) async {
    conditionalDeleteCalls.add(_ConditionalDeleteCall(key: key, expectedRevision: expectedRevision));
    final current = stored(key);
    if (current == null || current.revision != expectedRevision) return false;
    deletedKeys.add(key);
    remove(key);
    return true;
  }

  @override
  Future<SessionOptionsCaptureResult> capture({
    required SessionOptionsCacheKey key,
    required String projectPath,
    required SessionOptionsCaptureActivation activation,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
    required int? expectedGeneration,
  }) async {
    final call = _CaptureCall(
      key: key,
      projectPath: projectPath,
      activation: activation,
      discoveryMode: discoveryMode,
      expectedGeneration: expectedGeneration,
    );
    captureCalls.add(call);
    final handler = captureHandler;
    return handler == null ? captureResult : handler(call);
  }

  @override
  Future<bool> commit({
    required SessionOptionsCacheEntry candidate,
    required int? expectedRevision,
    required int generation,
  }) async {
    if (generation != currentGeneration) {
      throw PluginOperationException(
        SessionOptionsRuntimeOperation.commit.name,
        statusCode: 503,
        message: "stale generation",
      );
    }
    final call = _CommitCall(
      candidate: candidate,
      expectedRevision: expectedRevision,
      generation: generation,
    );
    commitCalls.add(call);
    final handler = commitHandler;
    return handler == null ? applyCas(call) : handler(call);
  }

  _CacheIdentity _identity(SessionOptionsCacheKey key) {
    return (pluginId: key.pluginId, scope: key.scope, ownerId: key.ownerId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
