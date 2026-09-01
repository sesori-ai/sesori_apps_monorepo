import "dart:async";
import "dart:io";

import "package:sesori_bridge/src/repositories/models/session_options_cache_key.dart";
import "package:sesori_bridge/src/repositories/new_session_defaults_repository.dart";
import "package:sesori_bridge/src/repositories/session_options_repository.dart";
import "package:sesori_bridge/src/services/session_options_service.dart";
import "package:sesori_plugin_interface/plugin_interface_testing.dart";
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

    test("client-facing options include the last successful creation defaults for that plugin", () async {
      final repository = _FakeSessionOptionsRepository()
        ..projectPaths["project-1"] = "/projects/one"
        ..put(
          _entry(
            key: const SessionOptionsCacheKey.plugin(pluginId: "plugin-1"),
            response: _response(marker: "cached"),
            capturedAt: now,
          ),
        );
      final defaultsRepository = _FakeNewSessionDefaultsRepository()
        ..defaultsByPlugin["plugin-1"] = const SessionPromptDefaults(
          agent: "build",
          model: AgentModel(providerID: "provider", modelID: "model", variant: "high"),
        );
      final service = SessionOptionsService(
        repository: repository,
        newSessionDefaultsRepository: defaultsRepository,
        pluginScopes: const {"plugin-1": PluginSessionOptionsScope.plugin},
        clock: _FixedClock(nowValue: now),
        retention: const Duration(days: 30),
      );

      final outcome = await service.loadCacheOnly(pluginId: "plugin-1", projectId: "project-1");

      expect(
        (outcome as SessionOptionsAvailable).response.lastUsedPromptDefaults,
        defaultsRepository.defaultsByPlugin["plugin-1"],
      );
      expect(defaultsRepository.readCalls, 1);
    });

    test("a defaults read failure keeps the options catalog usable and observable", () async {
      final repository = _FakeSessionOptionsRepository()
        ..projectPaths["project-1"] = "/projects/one"
        ..put(
          _entry(
            key: const SessionOptionsCacheKey.plugin(pluginId: "plugin-1"),
            response: _response(marker: "cached"),
            capturedAt: now,
          ),
        );
      final defaultsRepository = _FakeNewSessionDefaultsRepository()..readError = StateError("defaults unavailable");
      final service = SessionOptionsService(
        repository: repository,
        newSessionDefaultsRepository: defaultsRepository,
        pluginScopes: const {"plugin-1": PluginSessionOptionsScope.plugin},
        clock: _FixedClock(nowValue: now),
        retention: const Duration(days: 30),
      );

      late SessionOptionsOutcome outcome;
      final output = await _captureLogOutput(
        level: LogLevel.debug,
        action: () async {
          outcome = await service.loadCacheOnly(pluginId: "plugin-1", projectId: "project-1");
        },
      );

      expect(outcome, isA<SessionOptionsAvailable>());
      expect((outcome as SessionOptionsAvailable).response.lastUsedPromptDefaults, isNull);
      expect(output, contains("Failed to read new-session defaults for plugin plugin-1"));
      expect(output, contains("defaults unavailable"));
    });

    test("cache-only load does not expose a project row after its path moves", () async {
      const key = SessionOptionsCacheKey.project(
        pluginId: "plugin-1",
        projectId: "project-1",
        projectPath: "/projects/old",
      );
      final repository = _FakeSessionOptionsRepository()
        ..projectPaths["project-1"] = "/projects/old"
        ..put(
          _entry(
            key: key,
            response: _response(marker: "old-path"),
            capturedAt: now,
          ),
        );
      repository.readHandler = (_) async {
        repository.projectPaths["project-1"] = "/projects/new";
        return repository.stored(key);
      };
      final service = _service(repository: repository, now: now);

      final outcome = await service.loadCacheOnly(pluginId: "plugin-1", projectId: "project-1");

      expect(outcome, isA<SessionOptionsCacheUnavailable>());
    });

    test("cache-only load does not expose a row read across stale-send invalidation", () async {
      const key = SessionOptionsCacheKey.project(
        pluginId: "plugin-1",
        projectId: "project-1",
        projectPath: "/projects/one",
      );
      final readStarted = Completer<void>();
      final readGate = Completer<void>();
      final repository = _FakeSessionOptionsRepository()
        ..projectPaths["project-1"] = "/projects/one"
        ..put(
          _entry(
            key: key,
            response: _response(marker: "rejected"),
            capturedAt: now,
          ),
        );
      repository.readHandler = (_) async {
        final captured = repository.stored(key);
        readStarted.complete();
        await readGate.future;
        return captured;
      };
      final service = _service(repository: repository, now: now);

      final load = service.loadCacheOnly(pluginId: "plugin-1", projectId: "project-1");
      await readStarted.future;
      await service.invalidateRejectedSelection(pluginId: "plugin-1", projectId: "project-1");
      readGate.complete();

      expect(await load, isA<SessionOptionsCacheUnavailable>());
    });

    test("cache-only load does not expose a row when invalidation starts during path validation", () async {
      const key = SessionOptionsCacheKey.project(
        pluginId: "plugin-1",
        projectId: "project-1",
        projectPath: "/projects/one",
      );
      final validationStarted = Completer<void>();
      final validationGate = Completer<void>();
      final repository = _FakeSessionOptionsRepository()
        ..projectPaths["project-1"] = "/projects/one"
        ..put(
          _entry(
            key: key,
            response: _response(marker: "rejected"),
            capturedAt: now,
          ),
        );
      repository.resolveProjectPathHandler = (projectId) async {
        if (repository.resolveProjectPathCalls == 2) {
          validationStarted.complete();
          await validationGate.future;
        }
        return repository.projectPaths[projectId];
      };
      final service = _service(repository: repository, now: now);

      final load = service.loadCacheOnly(pluginId: "plugin-1", projectId: "project-1");
      await validationStarted.future;
      await service.invalidateRejectedSelection(pluginId: "plugin-1", projectId: "project-1");
      validationGate.complete();

      expect(await load, isA<SessionOptionsCacheUnavailable>());
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

    test("matching-key expiry does not delete a new-path replacement with the same revision", () async {
      const oldKey = SessionOptionsCacheKey.project(
        pluginId: "plugin-1",
        projectId: "project-1",
        projectPath: "/projects/old",
      );
      const newKey = SessionOptionsCacheKey.project(
        pluginId: "plugin-1",
        projectId: "project-1",
        projectPath: "/projects/new",
      );
      final expired = _entry(
        key: oldKey,
        response: _response(marker: "expired"),
        capturedAt: now.subtract(const Duration(days: 31)),
        revision: 1,
      );
      final fresh = _entry(
        key: newKey,
        response: _response(marker: "fresh"),
        capturedAt: now,
        revision: 1,
      );
      final repository = _FakeSessionOptionsRepository()
        ..projectPaths["project-1"] = "/projects/old"
        ..put(expired);
      repository.readHandler = (_) async {
        repository
          ..projectPaths["project-1"] = "/projects/new"
          ..put(fresh)
          ..readHandler = null;
        return expired;
      };
      final service = _service(repository: repository, now: now);

      final outcome = await service.loadDynamic(pluginId: "plugin-1", projectId: "project-1");

      expect(outcome, isA<SessionOptionsRefreshFailedUnavailable>());
      expect(repository.conditionalDeleteCalls, isEmpty);
      expect(repository.captureCalls, isEmpty);
      expect(repository.stored(newKey), fresh);
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

    test("decode recovery does not delete a new-path replacement with the same revision", () async {
      const newKey = SessionOptionsCacheKey.project(
        pluginId: "plugin-1",
        projectId: "project-1",
        projectPath: "/projects/new",
      );
      final fresh = _entry(
        key: newKey,
        response: _response(marker: "fresh"),
        capturedAt: now,
        revision: 1,
      );
      final repository = _FakeSessionOptionsRepository()..projectPaths["project-1"] = "/projects/old";
      repository.readHandler = (_) async {
        repository
          ..projectPaths["project-1"] = "/projects/new"
          ..put(fresh)
          ..readHandler = null;
        throw SessionOptionsCacheDecodingException(
          cause: const FormatException("corrupt"),
          causeStackTrace: StackTrace.current,
          revision: 1,
        );
      };
      final service = _service(repository: repository, now: now);

      final outcome = await service.loadDynamic(pluginId: "plugin-1", projectId: "project-1");

      expect(outcome, isA<SessionOptionsRefreshFailedUnavailable>());
      expect(repository.conditionalDeleteCalls, isEmpty);
      expect(repository.captureCalls, isEmpty);
      expect(repository.stored(newKey), fresh);
    });

    test("decode failure without a revision preserves a concurrently replaced row", () async {
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
          cause: ArgumentError("unknown completeness"),
          causeStackTrace: StackTrace.current,
          revision: null,
        );
      };
      final service = _service(repository: repository, now: now);

      final outcome = await service.loadCacheOnly(pluginId: "plugin-1", projectId: "project-1");

      expect(outcome, isA<SessionOptionsAvailable>());
      expect((outcome as SessionOptionsAvailable).response, _response(marker: "fresh"));
      expect(repository.deletedKeys, isEmpty);
      expect(repository.stored(key), fresh);
    });
  });

  group("SessionOptionsService dynamic loading", () {
    test("a cache read crossing stale-send invalidation discovers fresh options", () async {
      const key = SessionOptionsCacheKey.project(
        pluginId: "plugin-1",
        projectId: "project-1",
        projectPath: "/projects/one",
      );
      final readStarted = Completer<void>();
      final readGate = Completer<void>();
      final repository = _FakeSessionOptionsRepository()
        ..projectPaths["project-1"] = "/projects/one"
        ..captureResult = _observed(
          marker: "fresh",
          completeness: PluginSessionOptionsCompleteness.complete,
          generation: 7,
        )
        ..put(
          _entry(
            key: key,
            response: _response(marker: "rejected"),
            capturedAt: now,
          ),
        );
      repository.readHandler = (_) async {
        final captured = repository.stored(key);
        readStarted.complete();
        await readGate.future;
        return captured;
      };
      final service = _service(repository: repository, now: now);

      final load = service.loadDynamic(pluginId: "plugin-1", projectId: "project-1");
      await readStarted.future;
      await service.invalidateRejectedSelection(pluginId: "plugin-1", projectId: "project-1");
      repository.readHandler = null;
      readGate.complete();

      final outcome = await load;
      expect(outcome, isA<SessionOptionsAvailable>());
      expect((outcome as SessionOptionsAvailable).response, _response(marker: "fresh"));
      expect(repository.captureCalls, hasLength(1));
    });

    test("valid cache returns immediately without plugin capture", () async {
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

      final outcome = await service.loadDynamic(pluginId: "plugin-1", projectId: "project-1");

      expect(outcome, isA<SessionOptionsAvailable>());
      expect((outcome as SessionOptionsAvailable).response, _response(marker: "cached"));
      expect(outcome.response.stale, isFalse);
      expect(repository.captureCalls, isEmpty);
    });

    test("a cache past the freshness window is still served, reported stale", () async {
      final repository = _FakeSessionOptionsRepository()
        ..projectPaths["project-1"] = "/projects/one"
        ..put(
          _entry(
            key: const SessionOptionsCacheKey.plugin(pluginId: "plugin-1"),
            response: _response(marker: "cached"),
            capturedAt: now.subtract(const Duration(days: 1, seconds: 1)),
          ),
        );
      final service = _service(
        repository: repository,
        now: now,
        scopes: const {"plugin-1": PluginSessionOptionsScope.plugin},
      );

      final outcome = await service.loadDynamic(pluginId: "plugin-1", projectId: "project-1");

      expect(outcome, isA<SessionOptionsAvailable>());
      expect((outcome as SessionOptionsAvailable).response.agents, _response(marker: "cached").agents);
      expect(outcome.response.stale, isTrue);
      expect(repository.captureCalls, isEmpty);
    });

    test("cache miss activates only the selected plugin with reuse discovery", () async {
      final repository = _FakeSessionOptionsRepository()
        ..projectPaths["project-1"] = "/projects/one"
        ..captureResult = _observed(
          marker: "dynamic",
          completeness: PluginSessionOptionsCompleteness.complete,
          generation: 7,
        );
      final service = _service(repository: repository, now: now);

      final outcome = await service.loadDynamic(pluginId: "plugin-1", projectId: "project-1");

      expect(outcome, isA<SessionOptionsAvailable>());
      expect((outcome as SessionOptionsAvailable).response, _response(marker: "dynamic"));
      expect(repository.captureCalls, hasLength(1));
      expect(repository.captureCalls.single.activation, SessionOptionsCaptureActivation.mayActivate);
      expect(repository.captureCalls.single.discoveryMode, PluginSessionOptionsDiscoveryMode.reuse);
      expect(repository.captureCalls.single.expectedGeneration, isNull);
    });

    test("failed dynamic capture returns a concurrently published valid row", () async {
      const key = SessionOptionsCacheKey.project(
        pluginId: "plugin-1",
        projectId: "project-1",
        projectPath: "/projects/one",
      );
      final repository = _FakeSessionOptionsRepository()..projectPaths["project-1"] = "/projects/one";
      repository.captureHandler = (_) async {
        repository.put(
          _entry(
            key: key,
            response: _response(marker: "concurrent"),
            capturedAt: now,
          ),
        );
        return const SessionOptionsCaptureFailed();
      };
      final service = _service(repository: repository, now: now);

      late SessionOptionsOutcome outcome;
      final output = await _captureLogOutput(
        level: LogLevel.debug,
        action: () async {
          outcome = await service.loadDynamic(pluginId: "plugin-1", projectId: "project-1");
        },
      );

      expect(outcome, isA<SessionOptionsAvailable>());
      expect((outcome as SessionOptionsAvailable).response, _response(marker: "concurrent"));
      expect(
        RegExp("session options discovery failed for plugin plugin-1", caseSensitive: false).allMatches(output),
        hasLength(1),
      );
    });

    test("failed dynamic capture does not recover a row read across invalidation", () async {
      const key = SessionOptionsCacheKey.project(
        pluginId: "plugin-1",
        projectId: "project-1",
        projectPath: "/projects/one",
      );
      final recoveryReadStarted = Completer<void>();
      final recoveryReadGate = Completer<void>();
      final repository = _FakeSessionOptionsRepository()..projectPaths["project-1"] = "/projects/one";
      repository.captureHandler = (_) async {
        repository.put(
          _entry(
            key: key,
            response: _response(marker: "rejected"),
            capturedAt: now,
          ),
        );
        return const SessionOptionsCaptureFailed();
      };
      repository.readHandler = (_) async {
        final captured = repository.stored(key);
        if (repository.readCalls == 4) {
          recoveryReadStarted.complete();
          await recoveryReadGate.future;
        }
        return captured;
      };
      final service = _service(repository: repository, now: now);

      final load = service.loadDynamic(pluginId: "plugin-1", projectId: "project-1");
      await recoveryReadStarted.future;
      await service.invalidateRejectedSelection(pluginId: "plugin-1", projectId: "project-1");
      recoveryReadGate.complete();

      expect(await load, isA<SessionOptionsRefreshFailedUnavailable>());
    });

    test("failed dynamic capture without a cache returns unavailable", () async {
      final repository = _FakeSessionOptionsRepository()
        ..projectPaths["project-1"] = "/projects/one"
        ..captureResult = const SessionOptionsCaptureFailed();
      final service = _service(repository: repository, now: now);

      final output = await _captureLogOutput(
        level: LogLevel.debug,
        action: () async {
          final outcome = await service.loadDynamic(pluginId: "plugin-1", projectId: "project-1");
          expect(outcome, isA<SessionOptionsRefreshFailedUnavailable>());
        },
      );

      expect(output, contains("Session options discovery failed for plugin plugin-1"));
    });

    test("project absence is returned without cache or plugin access", () async {
      final repository = _FakeSessionOptionsRepository();
      final service = _service(repository: repository, now: now);

      final outcome = await service.loadDynamic(pluginId: "plugin-1", projectId: "missing");

      expect(outcome, isA<SessionOptionsProjectNotFound>());
      expect(repository.readCalls, 0);
      expect(repository.captureCalls, isEmpty);
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

    test("authentication-required refresh preserves cache but does not serve it as success", () async {
      const key = SessionOptionsCacheKey.project(
        pluginId: "plugin-1",
        projectId: "project-1",
        projectPath: "/projects/one",
      );
      final retained = _entry(
        key: key,
        response: _response(marker: "retained"),
        capturedAt: now,
      );
      final repository = _FakeSessionOptionsRepository()
        ..projectPaths["project-1"] = "/projects/one"
        ..captureResult = const SessionOptionsCaptureAuthenticationRequired(
          actionHint: "Authenticate locally.",
        )
        ..put(retained);
      final service = _service(repository: repository, now: now);

      final outcome = await service.refreshExplicit(pluginId: "plugin-1", projectId: "project-1");

      expect(
        outcome,
        isA<SessionOptionsAuthenticationRequired>().having(
          (value) => value.actionHint,
          "action hint",
          "Authenticate locally.",
        ),
      );
      expect(repository.stored(key), retained);
      expect(repository.commitCalls, isEmpty);
      expect(repository.deletedKeys, isEmpty);
    });

    test("stale-send invalidation deletes the rejected row before client discovery", () async {
      const key = SessionOptionsCacheKey.project(
        pluginId: "plugin-1",
        projectId: "project-1",
        projectPath: "/projects/one",
      );
      final repository = _FakeSessionOptionsRepository()
        ..projectPaths["project-1"] = "/projects/one"
        ..captureResult = const SessionOptionsCaptureFailed()
        ..put(
          _entry(
            key: key,
            response: _response(marker: "rejected"),
            capturedAt: now,
          ),
        );
      final service = _service(repository: repository, now: now);

      await service.invalidateRejectedSelection(
        pluginId: "plugin-1",
        projectId: "project-1",
      );

      expect(repository.deletedKeys, [key]);
      expect(repository.stored(key), isNull);
      expect(repository.captureCalls, isEmpty);
    });

    test("stale-send invalidation fences a capture that finishes before its delete", () async {
      const key = SessionOptionsCacheKey.project(
        pluginId: "plugin-1",
        projectId: "project-1",
        projectPath: "/projects/one",
      );
      final capture = Completer<SessionOptionsCaptureResult>();
      final deleteGate = Completer<void>();
      final repository = _FakeSessionOptionsRepository()
        ..projectPaths["project-1"] = "/projects/one"
        ..deleteGate = deleteGate
        ..put(
          _entry(
            key: key,
            response: _response(marker: "rejected"),
            capturedAt: now,
          ),
        );
      repository.captureHandler = (_) => capture.future;
      final service = _service(repository: repository, now: now);

      final refresh = service.refreshExplicit(pluginId: "plugin-1", projectId: "project-1");
      while (repository.captureCalls.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      // The delete is issued against the discovery still running, not behind it.
      final invalidation = service.invalidateRejectedSelection(pluginId: "plugin-1", projectId: "project-1");
      await Future<void>.delayed(Duration.zero);
      expect(repository.deletedKeys, [key]);
      expect(repository.captureCalls, hasLength(1));

      capture.complete(
        _observed(
          marker: "fresh",
          completeness: PluginSessionOptionsCompleteness.complete,
          generation: 7,
        ),
      );
      // The pre-rejection discovery cannot commit even when it finishes before
      // the overlapping delete settles.
      await Future<void>.delayed(Duration.zero);
      expect(repository.commitCalls, isEmpty);

      deleteGate.complete();
      await invalidation;
      final outcome = await refresh;
      expect(outcome, isA<SessionOptionsRefreshFailedUnavailable>());
      expect(repository.commitCalls, isEmpty);
      expect(repository.stored(key), isNull);
    });

    test("stale-send invalidation fences a capture that finishes after its delete", () async {
      const key = SessionOptionsCacheKey.project(
        pluginId: "plugin-1",
        projectId: "project-1",
        projectPath: "/projects/one",
      );
      final capture = Completer<SessionOptionsCaptureResult>();
      final repository = _FakeSessionOptionsRepository()
        ..projectPaths["project-1"] = "/projects/one"
        ..put(
          _entry(
            key: key,
            response: _response(marker: "rejected"),
            capturedAt: now,
          ),
        );
      repository.captureHandler = (_) => capture.future;
      final service = _service(repository: repository, now: now);

      final refresh = service.refreshExplicit(pluginId: "plugin-1", projectId: "project-1");
      await _waitFor(condition: () => repository.captureCalls.length == 1);
      await service.invalidateRejectedSelection(pluginId: "plugin-1", projectId: "project-1");
      expect(repository.stored(key), isNull);

      capture.complete(
        _observed(
          marker: "rejected",
          completeness: PluginSessionOptionsCompleteness.complete,
          generation: 7,
        ),
      );

      expect(await refresh, isA<SessionOptionsRefreshFailedUnavailable>());
      expect(repository.commitCalls, isEmpty);
      expect(repository.stored(key), isNull);
    });

    test("stale-send invalidation removes a pre-rejection commit that lands after its delete", () async {
      const key = SessionOptionsCacheKey.project(
        pluginId: "plugin-1",
        projectId: "project-1",
        projectPath: "/projects/one",
      );
      final commitGate = Completer<void>();
      final repository = _FakeSessionOptionsRepository()
        ..projectPaths["project-1"] = "/projects/one"
        ..captureResult = _observed(
          marker: "rejected",
          completeness: PluginSessionOptionsCompleteness.complete,
          generation: 7,
        );
      repository.commitHandler = (call) async {
        await commitGate.future;
        return repository.applyCas(call);
      };
      final service = _service(repository: repository, now: now);

      final refresh = service.refreshExplicit(pluginId: "plugin-1", projectId: "project-1");
      await _waitFor(condition: () => repository.commitCalls.length == 1);
      await service.invalidateRejectedSelection(pluginId: "plugin-1", projectId: "project-1");

      commitGate.complete();
      expect(await refresh, isA<SessionOptionsRefreshFailedUnavailable>());
      expect(repository.conditionalDeleteCalls, hasLength(1));
      expect(repository.stored(key), isNull);
    });

    test("capture failure waits for stale-send invalidation before checking retained cache", () async {
      const key = SessionOptionsCacheKey.project(
        pluginId: "plugin-1",
        projectId: "project-1",
        projectPath: "/projects/one",
      );
      final capture = Completer<SessionOptionsCaptureResult>();
      final deleteGate = Completer<void>();
      final repository = _FakeSessionOptionsRepository()
        ..projectPaths["project-1"] = "/projects/one"
        ..deleteGate = deleteGate
        ..put(
          _entry(
            key: key,
            response: _response(marker: "rejected"),
            capturedAt: now,
          ),
        );
      repository.captureHandler = (_) => capture.future;
      final service = _service(repository: repository, now: now);

      final refresh = service.refreshExplicit(pluginId: "plugin-1", projectId: "project-1");
      await _waitFor(condition: () => repository.captureCalls.length == 1);
      final invalidation = service.invalidateRejectedSelection(pluginId: "plugin-1", projectId: "project-1");
      await _waitFor(condition: () => repository.deletedKeys.length == 1);
      var refreshCompleted = false;
      unawaited(refresh.then((_) => refreshCompleted = true));

      capture.complete(const SessionOptionsCaptureFailed());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(refreshCompleted, isFalse);

      deleteGate.complete();
      await invalidation;
      expect(await refresh, isA<SessionOptionsRefreshFailedUnavailable>());
      expect(repository.stored(key), isNull);
    });

    test("explicit thrown capture retains a privacy-safe typed cause", () async {
      final cause = StateError("private capture details");
      final causeStackTrace = StackTrace.current;
      final repository = _FakeSessionOptionsRepository()
        ..projectPaths["project-1"] = "/projects/one"
        ..captureHandler = (_) => Future.error(cause, causeStackTrace);
      final service = _service(repository: repository, now: now);

      late SessionOptionsOutcome outcome;
      final output = await _captureLogOutput(
        level: LogLevel.debug,
        action: () async {
          outcome = await service.refreshExplicit(pluginId: "plugin-1", projectId: "project-1");
        },
      );

      expect(outcome, isA<SessionOptionsRefreshFailedUnavailable>());
      final failure = (outcome as SessionOptionsRefreshFailedUnavailable).failure;
      expect(failure, isA<SessionOptionsCaughtRefreshFailure>());
      final caught = failure as SessionOptionsCaughtRefreshFailure;
      expect(caught.cause, same(cause));
      expect(caught.causeStackTrace, same(causeStackTrace));
      expect(caught.toString(), isNot(contains("private capture details")));
      expect(output, contains("Session options capture failed for plugin plugin-1"));
      expect(output, contains("private capture details"));
    });

    test("capture failure revalidates retention before retaining the cached response", () async {
      final clock = _MutableClock(nowValue: now);
      final repository = _FakeSessionOptionsRepository()..projectPaths["project-1"] = "/projects/one";
      repository.captureHandler = (_) async {
        clock.nowValue = now.add(const Duration(seconds: 1));
        return const SessionOptionsCaptureFailed();
      };
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
        newSessionDefaultsRepository: _FakeNewSessionDefaultsRepository(),
        pluginScopes: const {"plugin-1": PluginSessionOptionsScope.project},
        clock: clock,
        retention: Duration.zero,
      );

      final outcome = await service.refreshExplicit(pluginId: "plugin-1", projectId: "project-1");

      expect(outcome, isA<SessionOptionsRefreshFailedUnavailable>());
      expect(repository.deletedKeys, [key]);
    });

    test("failed plugin-scoped refresh retains cache when its triggering project moves", () async {
      const key = SessionOptionsCacheKey.plugin(pluginId: "plugin-1");
      final repository = _FakeSessionOptionsRepository()
        ..projectPaths["project-1"] = "/projects/old"
        ..put(
          _entry(
            key: key,
            response: _response(marker: "plugin-cache"),
            capturedAt: now,
          ),
        );
      repository.captureHandler = (_) async {
        repository.projectPaths["project-1"] = "/projects/new";
        return const SessionOptionsCaptureFailed();
      };
      final service = _service(
        repository: repository,
        now: now,
        scopes: const {"plugin-1": PluginSessionOptionsScope.plugin},
      );

      final outcome = await service.refreshExplicit(pluginId: "plugin-1", projectId: "project-1");

      expect(outcome, isA<SessionOptionsRefreshFailedRetained>());
      expect(repository.stored(key)!.response, _response(marker: "plugin-cache"));
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

    test("partial observation seeds after the retained row expires during capture", () async {
      final clock = _MutableClock(nowValue: now);
      final repository = _FakeSessionOptionsRepository()..projectPaths["project-1"] = "/projects/one";
      const key = SessionOptionsCacheKey.project(
        pluginId: "plugin-1",
        projectId: "project-1",
        projectPath: "/projects/one",
      );
      repository
        ..put(
          _entry(
            key: key,
            response: _response(marker: "retained"),
            capturedAt: now,
            revision: 1,
          ),
        )
        ..captureHandler = (_) async {
          clock.nowValue = now.add(const Duration(seconds: 1));
          return _observed(
            marker: "partial",
            completeness: PluginSessionOptionsCompleteness.partial,
            generation: 7,
          );
        };
      final service = SessionOptionsService(
        repository: repository,
        newSessionDefaultsRepository: _FakeNewSessionDefaultsRepository(),
        pluginScopes: const {"plugin-1": PluginSessionOptionsScope.project},
        clock: clock,
        retention: Duration.zero,
      );

      final outcome = await service.refreshExplicit(pluginId: "plugin-1", projectId: "project-1");

      expect(outcome, isA<SessionOptionsAvailable>());
      expect((outcome as SessionOptionsAvailable).response, _response(marker: "partial"));
      expect(repository.commitCalls.single.expectedRevision, isNull);
      expect(repository.stored(key)!.response, _response(marker: "partial"));
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
        newSessionDefaultsRepository: _FakeNewSessionDefaultsRepository(),
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
    test("dynamic load queued behind automatic reuse returns its newly cached row", () async {
      final automaticGate = Completer<SessionOptionsCaptureResult>();
      final repository = _FakeSessionOptionsRepository()
        ..projectPaths["project-1"] = "/projects/one"
        ..captureHandler = (_) => automaticGate.future;
      final service = _service(repository: repository, now: now);

      final automatic = service.refreshActiveOnly(
        pluginId: "plugin-1",
        projectId: "project-1",
        generation: 7,
      );
      await _waitFor(condition: () => repository.captureCalls.length == 1);
      final dynamic = service.loadDynamic(pluginId: "plugin-1", projectId: "project-1");
      await Future<void>.delayed(Duration.zero);

      automaticGate.complete(
        _observed(
          marker: "automatic",
          completeness: PluginSessionOptionsCompleteness.complete,
          generation: 7,
        ),
      );

      expect((await automatic as SessionOptionsAvailable).response, _response(marker: "automatic"));
      expect((await dynamic as SessionOptionsAvailable).response, _response(marker: "automatic"));
      expect(repository.captureCalls, hasLength(1));
    });

    test("dynamic callers coalesce while a forced refresh queues one forced tail", () async {
      final dynamicGate = Completer<SessionOptionsCaptureResult>();
      final forcedGate = Completer<SessionOptionsCaptureResult>();
      final repository = _FakeSessionOptionsRepository()..projectPaths["project-1"] = "/projects/one";
      repository.captureHandler = (call) {
        return switch (call.discoveryMode) {
          PluginSessionOptionsDiscoveryMode.reuse => dynamicGate.future,
          PluginSessionOptionsDiscoveryMode.refresh => forcedGate.future,
        };
      };
      final service = _service(repository: repository, now: now);

      final dynamic = service.loadDynamic(pluginId: "plugin-1", projectId: "project-1");
      await _waitFor(condition: () => repository.captureCalls.length == 1);
      final joinedDynamic = service.loadDynamic(pluginId: "plugin-1", projectId: "project-1");
      await Future<void>.delayed(Duration.zero);
      final forced = service.refreshExplicit(pluginId: "plugin-1", projectId: "project-1");

      expect(repository.captureCalls, hasLength(1));
      dynamicGate.complete(
        _observed(
          marker: "dynamic",
          completeness: PluginSessionOptionsCompleteness.complete,
          generation: 7,
        ),
      );
      expect((await dynamic as SessionOptionsAvailable).response, _response(marker: "dynamic"));
      expect((await joinedDynamic as SessionOptionsAvailable).response, _response(marker: "dynamic"));

      await _waitFor(condition: () => repository.captureCalls.length == 2);
      expect(repository.captureCalls[0].discoveryMode, PluginSessionOptionsDiscoveryMode.reuse);
      expect(repository.captureCalls[1].discoveryMode, PluginSessionOptionsDiscoveryMode.refresh);
      forcedGate.complete(
        _observed(
          marker: "forced",
          completeness: PluginSessionOptionsCompleteness.complete,
          generation: 7,
        ),
      );
      expect((await forced as SessionOptionsAvailable).response, _response(marker: "forced"));
    });

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

    test("forced refresh after invalidation does not reuse pre-rejection discovery", () async {
      final preRejection = Completer<SessionOptionsCaptureResult>();
      final postRejection = Completer<SessionOptionsCaptureResult>();
      final repository = _FakeSessionOptionsRepository()..projectPaths["project-1"] = "/projects/one";
      repository.captureHandler = (_) => switch (repository.captureCalls.length) {
        1 => preRejection.future,
        2 => postRejection.future,
        _ => throw StateError("unexpected capture"),
      };
      final service = _service(repository: repository, now: now);

      final staleRefresh = service.refreshExplicit(pluginId: "plugin-1", projectId: "project-1");
      await _waitFor(condition: () => repository.captureCalls.length == 1);
      await service.invalidateRejectedSelection(pluginId: "plugin-1", projectId: "project-1");
      final recoveryRefresh = service.refreshExplicit(pluginId: "plugin-1", projectId: "project-1");

      preRejection.complete(
        _observed(
          marker: "rejected",
          completeness: PluginSessionOptionsCompleteness.complete,
          generation: 7,
        ),
      );
      expect(await staleRefresh, isA<SessionOptionsRefreshFailedUnavailable>());
      await _waitFor(condition: () => repository.captureCalls.length == 2);

      postRejection.complete(
        _observed(
          marker: "fresh",
          completeness: PluginSessionOptionsCompleteness.complete,
          generation: 7,
        ),
      );
      final recoveryOutcome = await recoveryRefresh;
      expect(recoveryOutcome, isA<SessionOptionsAvailable>());
      expect((recoveryOutcome as SessionOptionsAvailable).response, _response(marker: "fresh"));
      expect(repository.captureCalls, hasLength(2));
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
    newSessionDefaultsRepository: _FakeNewSessionDefaultsRepository(),
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
    lastUsedPromptDefaults: null,
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
  final stdoutBuffer = BufferingStdout();
  final stderrBuffer = BufferingStdout();
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

class const _FixedClock({required final DateTime nowValue}) extends ServerClock {
  @override
  DateTime now() => nowValue;
}

class _MutableClock({required var DateTime nowValue}) extends ServerClock {
  @override
  DateTime now() => nowValue;
}

class _AdvancingClock({required var DateTime _now}) extends ServerClock {
  @override
  DateTime now() {
    final value = _now;
    _now = _now.add(const Duration(seconds: 1));
    return value;
  }
}

typedef _CacheIdentity = ({String pluginId, PluginSessionOptionsScope scope, String ownerId});

class const _CaptureCall({
  required final SessionOptionsCacheKey key,
  required final String projectPath,
  required final SessionOptionsCaptureActivation activation,
  required final PluginSessionOptionsDiscoveryMode discoveryMode,
  required final int? expectedGeneration,
});

class const _CommitCall({
  required final SessionOptionsCacheEntry candidate,
  required final int? expectedRevision,
  required final int generation,
});

class const _ConditionalDeleteCall({required final SessionOptionsCacheKey key, required final int expectedRevision});

class _FakeNewSessionDefaultsRepository() implements NewSessionDefaultsRepository {
  final Map<String, SessionPromptDefaults> defaultsByPlugin = {};
  Object? readError;
  int readCalls = 0;

  @override
  Future<SessionPromptDefaults?> read({required String pluginId}) async {
    readCalls++;
    final error = readError;
    if (error != null) throw error;
    return defaultsByPlugin[pluginId];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSessionOptionsRepository() implements SessionOptionsRepository {
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
  int resolveProjectPathCalls = 0;
  SessionOptionsCaptureResult captureResult = _observed(
    marker: "default",
    completeness: PluginSessionOptionsCompleteness.complete,
    generation: 7,
  );
  Completer<void>? deleteGate;
  Future<String?> Function(String projectId)? resolveProjectPathHandler;
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
  Future<String?> resolveProjectPath({required String projectId}) async {
    resolveProjectPathCalls++;
    final handler = resolveProjectPathHandler;
    return await (handler == null ? projectPaths[projectId] : handler(projectId));
  }

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
    return await (handler == null ? stored(key) : handler(key));
  }

  @override
  Future<void> delete({required SessionOptionsCacheKey key}) async {
    deletedKeys.add(key);
    await deleteGate?.future;
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
    return await (handler == null ? captureResult : handler(call));
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
    return await (handler == null ? applyCas(call) : handler(call));
  }

  _CacheIdentity _identity(SessionOptionsCacheKey key) {
    return (pluginId: key.pluginId, scope: key.scope, ownerId: key.ownerId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
