import "dart:async";

import "package:rxdart/rxdart.dart";
import "package:sesori_bridge/src/bridge/runtime/bridge_runtime_server_exception.dart";
import "package:sesori_bridge/src/bridge/runtime/plugin_generation_factory.dart";
import "package:sesori_bridge/src/bridge/runtime/plugin_runtime.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  test("unknown plugin acquisitions preserve the typed unavailable contract", () async {
    final runtime = _runtime(
      factory: _FakeGenerationFactory(startGate: Future<void>.value()),
    );
    addTearDown(runtime.dispose);

    Matcher unavailableFor(String operation) => isA<PluginOperationException>()
        .having((error) => error.operation, "operation", operation)
        .having((error) => error.statusCode, "statusCode", 503)
        .having((error) => error.message, "message", contains("unknown"));

    await expectLater(
      runtime.use(pluginId: "removed-plugin", operation: _TestOperation.read, body: (_) async {}),
      throwsA(unavailableFor("read")),
    );
    await expectLater(
      runtime.useStream<int>(
        pluginId: "removed-plugin",
        operation: _TestOperation.watch,
        body: (_, _) => const Stream<int>.empty(),
      ),
      emitsError(unavailableFor("watch")),
    );
    await expectLater(
      runtime.useIfActive<void>(
        pluginId: "removed-plugin",
        operation: _TestOperation.activeRead,
        body: (_, _) async {},
      ),
      throwsA(unavailableFor("activeRead")),
    );
    expect(
      () => runtime.requireCurrentGeneration(
        pluginId: "removed-plugin",
        generation: 1,
        operation: _TestOperation.directFence,
      ),
      throwsA(
        isA<PluginOperationException>()
            .having((error) => error.operation, "operation", "directFence")
            .having((error) => error.statusCode, "statusCode", 503),
      ),
    );
  });

  test("concurrent acquisitions join one start and hold independent leases", () async {
    final startGate = Completer<void>();
    final operationGate = Completer<void>();
    final factory = _FakeGenerationFactory(startGate: startGate.future);
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);

    final first = runtime.use(
      pluginId: "one",
      operation: _TestOperation.first,
      body: (_) => operationGate.future,
    );
    final second = runtime.use(
      pluginId: "one",
      operation: _TestOperation.second,
      body: (_) => operationGate.future,
    );
    await Future<void>.delayed(Duration.zero);

    expect(factory.startCount, 1);
    startGate.complete();
    await _waitUntil(() => runtime.snapshot.single.leaseCount == 2);
    expect(runtime.activePluginIds, {"one"});

    operationGate.complete();
    await Future.wait([first, second]);
    expect(runtime.snapshot.single.leaseCount, 0);
  });

  test("stream acquisition retains its lease until cancellation", () async {
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    final source = StreamController<int>();

    final subscription = runtime
        .useStream(
          pluginId: "one",
          operation: _TestOperation.stream,
          body: (_, _) => source.stream,
        )
        .listen((_) {});
    await _waitUntil(() => runtime.snapshot.single.leaseCount == 1 && source.hasListener);

    await subscription.cancel();
    await _waitUntil(() => runtime.snapshot.single.leaseCount == 0);
    await source.close();
  });

  test("stream acquisition releases its lease and cancels its source after an error", () async {
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    final source = StreamController<int>();
    final cancelled = Completer<void>();
    source.onCancel = cancelled.complete;

    final error = StateError("source failed");
    final completion = expectLater(
      runtime.useStream(
        pluginId: "one",
        operation: _TestOperation.stream,
        body: (_, _) => source.stream,
      ),
      emitsError(same(error)),
    );
    await _waitUntil(() => runtime.snapshot.single.leaseCount == 1 && source.hasListener);

    source.addError(error);

    await completion;
    await cancelled.future;
    expect(runtime.snapshot.single.leaseCount, 0);
    await source.close();
  });

  test("stream cancellation releases its lease when source cancellation fails", () async {
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    final cancellationError = StateError("cancel failed");
    final source = StreamController<int>(
      onCancel: () => Future<void>.error(cancellationError),
    );
    final subscription = runtime
        .useStream(
          pluginId: "one",
          operation: _TestOperation.stream,
          body: (_, _) => source.stream,
        )
        .listen((_) {});
    await _waitUntil(() => runtime.snapshot.single.leaseCount == 1 && source.hasListener);

    await expectLater(subscription.cancel(), throwsA(same(cancellationError)));

    expect(runtime.snapshot.single.leaseCount, 0);
    await source.close();
  });

  test("stream cancellation before acquisition releases the eventual lease", () async {
    final startGate = Completer<void>();
    final factory = _FakeGenerationFactory(startGate: startGate.future);
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    var bodyCalled = false;
    final subscription = runtime
        .useStream(
          pluginId: "one",
          operation: _TestOperation.stream,
          body: (_, _) {
            bodyCalled = true;
            return const Stream<int>.empty();
          },
        )
        .listen((_) {});
    await _waitUntil(() => factory.startCount == 1);

    await subscription.cancel();
    startGate.complete();
    await _waitUntil(
      () => runtime.snapshot.single.state == PluginRuntimeState.active && runtime.snapshot.single.leaseCount == 0,
    );

    expect(bodyCalled, isFalse);
  });

  test("a safe stop blocks acquisitions once its transition begins", () async {
    final shutdownGate = Completer<void>();
    final factory = _FakeGenerationFactory(
      startGate: Future<void>.value(),
      pluginFactory: (_) => _FakePlugin(api: _FakeApi(), shutdownGate: shutdownGate.future),
    );
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.start(pluginId: "one");

    final stopping = runtime.stop(pluginId: "one", intent: PluginStopIntent.safe);
    await _waitUntil(() => runtime.snapshot.single.transition == PluginRuntimeTransition.stopping);

    await expectLater(
      runtime.use(pluginId: "one", operation: _TestOperation.duringStop, body: (_) async {}),
      throwsA(isA<PluginOperationException>()),
    );

    shutdownGate.complete();
    expect(await stopping, isA<PluginRuntimeCommandApplied>());
    expect(runtime.snapshot.single.state, PluginRuntimeState.dormant);
  });

  test("a command-owned stop rejects force takeover until teardown finishes", () async {
    final shutdownGate = Completer<void>();
    final factory = _FakeGenerationFactory(
      startGate: Future<void>.value(),
      pluginFactory: (generation) => _FakePlugin(
        api: _FakeApi(),
        shutdownGate: generation == 1 ? shutdownGate.future : null,
      ),
    );
    final runtime = _runtime(factory: factory);
    addTearDown(() async {
      if (!shutdownGate.isCompleted) shutdownGate.complete();
      await runtime.dispose();
    });
    await runtime.start(pluginId: "one");
    final originalPlugin = factory.plugins.single;

    final stopping = runtime.stop(pluginId: "one", intent: PluginStopIntent.safe);
    final takeover = await runtime.restart(pluginId: "one", intent: PluginStopIntent.force);

    expect(takeover, isA<PluginRuntimeCommandConflict>());
    expect(factory.startCount, 1);
    shutdownGate.complete();
    expect(await stopping, isA<PluginRuntimeCommandApplied>());
    expect(originalPlugin.shutdownInvocationCount, 1);
    expect(runtime.snapshot.single.generation, 1);
    expect(runtime.snapshot.single.state, PluginRuntimeState.dormant);
    expect(runtime.snapshot.single.transition, PluginRuntimeTransition.none);
  });

  test("a safe stop refuses active leases and backend work", () async {
    final operationGate = Completer<void>();
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.start(pluginId: "one");
    final plugin = factory.plugins.single;

    final operation = runtime.use<void>(
      pluginId: "one",
      operation: _TestOperation.leasedRead,
      body: (_) => operationGate.future,
    );
    await _waitUntil(() => runtime.snapshot.single.leaseCount == 1);
    final inFlight = await runtime.stop(pluginId: "one", intent: PluginStopIntent.safe);
    expect(
      inFlight,
      isA<PluginRuntimeCommandConflict>().having(
        (result) => result.reasons,
        "reasons",
        [PluginRuntimeConflictReason.inFlight],
      ),
    );

    operationGate.complete();
    await operation;
    plugin.workStates.add(PluginWorkState.busy);
    await _waitUntil(() => runtime.snapshot.single.workState == PluginWorkState.busy);
    final busy = await runtime.stop(pluginId: "one", intent: PluginStopIntent.safe);
    expect(
      busy,
      isA<PluginRuntimeCommandConflict>().having(
        (result) => result.reasons,
        "reasons",
        [PluginRuntimeConflictReason.busy],
      ),
    );

    plugin.workStates.add(PluginWorkState.unknown);
    await _waitUntil(() => runtime.snapshot.single.workState == PluginWorkState.unknown);
    final unknown = await runtime.stop(pluginId: "one", intent: PluginStopIntent.safe);
    expect(
      unknown,
      isA<PluginRuntimeCommandConflict>().having(
        (result) => result.reasons,
        "reasons",
        [PluginRuntimeConflictReason.workStateUnknown],
      ),
    );
  });

  test("safe commands ignore unknown work when no generation is live", () async {
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);

    expect(runtime.snapshot.single.state, PluginRuntimeState.dormant);
    expect(runtime.snapshot.single.workState, PluginWorkState.unknown);
    expect(
      await runtime.stop(pluginId: "one", intent: PluginStopIntent.safe),
      isA<PluginRuntimeCommandCurrent>(),
    );
    expect(
      await runtime.restart(pluginId: "one", intent: PluginStopIntent.safe),
      isA<PluginRuntimeCommandApplied>(),
    );
    expect(factory.startCount, 1);
    expect(runtime.snapshot.single.workState, PluginWorkState.idle);
  });

  test("use authentication failure fences and blocks its generation", () async {
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);

    await expectLater(
      runtime.use<void>(
        pluginId: "one",
        operation: _TestOperation.authenticatedRead,
        body: (_) => throw const PluginAuthenticationRequiredException(
          "authenticatedRead",
          actionHint: "Sign in locally.",
        ),
      ),
      throwsA(isA<PluginAuthenticationRequiredException>()),
    );
    await _waitUntil(
      () =>
          runtime.snapshot.single.state == PluginRuntimeState.blocked &&
          runtime.snapshot.single.transition == PluginRuntimeTransition.none,
    );

    final snapshot = runtime.snapshot.single;
    expect(snapshot.setup, const PluginSetupAuthenticationRequired(actionHint: "Sign in locally."));
    expect(snapshot.eligible, isTrue);
    expect(snapshot.startAllowed, isFalse);
    expect(snapshot.workState, PluginWorkState.unknown);
    expect(runtime.activePluginIds, isEmpty);
    expect(factory.plugins.single.shutdownCount, 1);
    expect(
      await runtime.restart(pluginId: "one", intent: PluginStopIntent.force),
      isA<PluginRuntimeCommandFailed>(),
    );
    expect(factory.startCount, 1);
  });

  test("useStream authentication failure fences before notifying its listener", () async {
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    final observed = Completer<PluginRuntimeSnapshot>();

    runtime
        .useStream<void>(
          pluginId: "one",
          operation: _TestOperation.authenticatedStream,
          body: (_, _) => Stream<void>.error(
            const PluginAuthenticationRequiredException(
              "authenticatedStream",
              actionHint: "Sign in locally.",
            ),
          ),
        )
        .listen(
          null,
          onError: (Object _) => observed.complete(runtime.snapshot.single),
        );

    final atNotification = await observed.future;
    expect(atNotification.startAllowed, isFalse);
    expect(atNotification.eligible, isTrue);
    var bodyCalled = false;
    await expectLater(
      runtime.use<void>(
        pluginId: "one",
        operation: _TestOperation.fencedRead,
        body: (_) async => bodyCalled = true,
      ),
      throwsA(isA<PluginOperationException>()),
    );
    expect(bodyCalled, isFalse);
    expect(factory.startCount, 1);
    await _waitUntil(
      () =>
          runtime.snapshot.single.state == PluginRuntimeState.blocked &&
          runtime.snapshot.single.transition == PluginRuntimeTransition.none,
    );
  });

  test("useIfActive authentication failure blocks its generation", () async {
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.start(pluginId: "one");

    await expectLater(
      runtime.useIfActive<void>(
        pluginId: "one",
        operation: _TestOperation.activeRead,
        body: (_, _) => throw const PluginAuthenticationRequiredException(
          "activeRead",
          actionHint: "Sign in locally.",
        ),
      ),
      throwsA(isA<PluginAuthenticationRequiredException>()),
    );
    await _waitUntil(
      () =>
          runtime.snapshot.single.state == PluginRuntimeState.blocked &&
          runtime.snapshot.single.transition == PluginRuntimeTransition.none,
    );

    expect(runtime.snapshot.single.setup, const PluginSetupAuthenticationRequired(actionHint: "Sign in locally."));
    expect(runtime.snapshot.single.eligible, isTrue);
    expect(runtime.activePluginIds, isEmpty);
  });

  test("backend event authentication failure blocks and retires its generation", () async {
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.start(pluginId: "one");

    factory.api.eventsController.addError(
      const PluginAuthenticationRequiredException(
        "queuedTurn",
        actionHint: "Sign in locally.",
      ),
    );
    await _waitUntil(
      () =>
          runtime.snapshot.single.state == PluginRuntimeState.blocked &&
          runtime.snapshot.single.transition == PluginRuntimeTransition.none,
    );

    expect(runtime.snapshot.single.setup, const PluginSetupAuthenticationRequired(actionHint: "Sign in locally."));
    expect(runtime.snapshot.single.eligible, isTrue);
    expect(runtime.activePluginIds, isEmpty);
    expect(factory.plugins.single.shutdownCount, 1);
  });

  test("authentication cleanup waits for concurrent operation leases", () async {
    final operationGate = Completer<void>();
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);

    final operation = runtime.use<String>(
      pluginId: "one",
      operation: _TestOperation.concurrentRead,
      body: (_) async {
        await operationGate.future;
        return "complete";
      },
    );
    await _waitUntil(() => runtime.snapshot.single.leaseCount == 1);

    await expectLater(
      runtime.use<void>(
        pluginId: "one",
        operation: _TestOperation.authenticatedRead,
        body: (_) => throw const PluginAuthenticationRequiredException(
          "authenticatedRead",
          actionHint: "Sign in locally.",
        ),
      ),
      throwsA(isA<PluginAuthenticationRequiredException>()),
    );

    expect(factory.plugins.single.shutdownCount, 0);
    expect(runtime.snapshot.single.startAllowed, isFalse);
    expect(runtime.snapshot.single.leaseCount, 1);

    operationGate.complete();
    await expectLater(
      operation,
      throwsA(
        isA<PluginOperationException>().having(
          (error) => error.operation,
          "operation",
          _TestOperation.concurrentRead.name,
        ),
      ),
    );
    await _waitUntil(
      () =>
          factory.plugins.single.shutdownCount == 1 &&
          runtime.snapshot.single.state == PluginRuntimeState.blocked &&
          runtime.snapshot.single.transition == PluginRuntimeTransition.none,
    );
  });

  test("stale generation authentication failure does not block its successor", () async {
    final operationGate = Completer<void>();
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);

    final operation = runtime.use<void>(
      pluginId: "one",
      operation: _TestOperation.staleAuthenticatedRead,
      body: (_) async {
        await operationGate.future;
        throw const PluginAuthenticationRequiredException(
          "staleAuthenticatedRead",
          actionHint: "Sign in locally.",
        );
      },
    );
    await _waitUntil(() => runtime.snapshot.single.leaseCount == 1);
    expect(
      await runtime.restart(pluginId: "one", intent: PluginStopIntent.force),
      isA<PluginRuntimeCommandApplied>(),
    );

    operationGate.complete();
    await expectLater(operation, throwsA(isA<PluginAuthenticationRequiredException>()));
    final snapshot = runtime.snapshot.single;
    expect(snapshot.generation, 2);
    expect(snapshot.state, PluginRuntimeState.active);
    expect(snapshot.startAllowed, isTrue);
    expect(snapshot.setup, isNot(isA<PluginSetupAuthenticationRequired>()));
  });

  test("shutdown bypasses authentication lease drain", () async {
    final operationGate = Completer<void>();
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    final operation = runtime.use<void>(
      pluginId: "one",
      operation: _TestOperation.longRead,
      body: (_) => operationGate.future,
    );
    await _waitUntil(() => runtime.snapshot.single.leaseCount == 1);

    await expectLater(
      runtime.use<void>(
        pluginId: "one",
        operation: _TestOperation.authenticatedRead,
        body: (_) => throw const PluginAuthenticationRequiredException(
          "authenticatedRead",
          actionHint: "Sign in locally.",
        ),
      ),
      throwsA(isA<PluginAuthenticationRequiredException>()),
    );
    expect(factory.plugins.single.shutdownCount, 0);

    runtime.beginShutdown();
    await runtime.dispose().timeout(const Duration(seconds: 1));
    expect(factory.plugins.single.shutdownCount, 1);

    operationGate.complete();
    await expectLater(operation, throwsA(isA<PluginOperationException>()));
  });

  test("a force stop fences an operation that completes after shutdown", () async {
    final operationGate = Completer<void>();
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.start(pluginId: "one");
    final operation = runtime.use(
      pluginId: "one",
      operation: _TestOperation.forceFenced,
      body: (_) => operationGate.future,
    );
    await _waitUntil(() => runtime.snapshot.single.leaseCount == 1);

    expect(
      await runtime.stop(pluginId: "one", intent: PluginStopIntent.force),
      isA<PluginRuntimeCommandApplied>(),
    );
    operationGate.complete();

    await expectLater(
      operation,
      throwsA(
        isA<PluginOperationException>().having(
          (error) => error.operation,
          "operation",
          "forceFenced",
        ),
      ),
    );
    expect(runtime.snapshot.single.state, PluginRuntimeState.dormant);
  });

  test("restart keeps its transition serialized through the successor start", () async {
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.start(pluginId: "one");

    final result = await runtime.restart(pluginId: "one", intent: PluginStopIntent.safe);

    expect(result, isA<PluginRuntimeCommandApplied>());
    expect(factory.startCount, 2);
    expect(runtime.snapshot.single.generation, 2);
    expect(runtime.snapshot.single.state, PluginRuntimeState.active);
    expect(runtime.snapshot.single.transition, PluginRuntimeTransition.none);
  });

  test("a force restart aborts an in-flight start before starting its successor", () async {
    final startGate = Completer<void>();
    final factory = _FakeGenerationFactory(startGate: startGate.future);
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    final initialStart = runtime.start(pluginId: "one");
    await _waitUntil(() => factory.startCount == 1);

    final restarting = runtime.restart(pluginId: "one", intent: PluginStopIntent.force);
    startGate.complete();

    await expectLater(initialStart, throwsA(isA<PluginStartAbortedException>()));
    expect(await restarting, isA<PluginRuntimeCommandApplied>());
    expect(factory.startCount, 2);
    expect(runtime.snapshot.single.generation, 2);
    expect(runtime.snapshot.single.state, PluginRuntimeState.active);
  });

  test("a force restart recovers a generation stuck in PluginStopping", () async {
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.start(pluginId: "one");
    final stoppingPlugin = factory.plugins.single;

    stoppingPlugin.statuses.add(const PluginStopping());
    await _waitUntil(() => runtime.snapshot.single.transition == PluginRuntimeTransition.stopping);

    expect(
      await runtime.restart(pluginId: "one", intent: PluginStopIntent.safe),
      isA<PluginRuntimeCommandConflict>(),
    );
    expect(
      await runtime.restart(pluginId: "one", intent: PluginStopIntent.force),
      isA<PluginRuntimeCommandApplied>(),
    );
    expect(stoppingPlugin.shutdownCount, 1);
    expect(factory.startCount, 2);
    expect(runtime.snapshot.single.generation, 2);
    expect(runtime.snapshot.single.state, PluginRuntimeState.active);
    expect(runtime.snapshot.single.transition, PluginRuntimeTransition.none);
  });

  test("a terminal plugin failure fences its generation and allows a later retry", () async {
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.start(pluginId: "one");
    final failedPlugin = factory.plugins.single;

    failedPlugin.statuses.add(const PluginFailed(reason: "terminal", cause: null));
    await _waitUntil(
      () =>
          runtime.snapshot.single.state == PluginRuntimeState.failed &&
          runtime.snapshot.single.transition == PluginRuntimeTransition.none,
    );

    final result = await runtime.use(
      pluginId: "one",
      operation: _TestOperation.retry,
      body: (_) async => "retried",
    );

    expect(result, "retried");
    expect(factory.startCount, 2);
    expect(runtime.snapshot.single.generation, 2);
    expect(failedPlugin.shutdownCount, 1);
  });

  test("shared factory failures propagate instead of degrading one plugin", () async {
    const error = BridgeRuntimeServerException("bridge ownership failed");
    final factory = _FakeGenerationFactory(
      startGate: Future<void>.value(),
      startError: error,
    );
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);

    await expectLater(
      runtime.start(pluginId: "one"),
      throwsA(same(error)),
    );
  });

  test("descriptor-local factory failures leave the plugin failed", () async {
    final factory = _FakeGenerationFactory(
      startGate: Future<void>.value(),
      startError: const PluginGenerationStartFailedException(
        pluginId: "one",
        cause: "descriptor failed",
      ),
    );
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);

    await runtime.start(pluginId: "one");

    expect(runtime.snapshot.single.state, PluginRuntimeState.failed);
    expect(runtime.activePluginIds, isEmpty);
  });

  test("an invalid returned plugin is shut down and never routed", () async {
    final factory = _FakeGenerationFactory(
      startGate: Future<void>.value(),
      pluginFactory: (_) => _FakePlugin(api: _FakeApi(id: "wrong")),
    );
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);

    await runtime.start(pluginId: "one");

    expect(runtime.activePluginIds, isEmpty);
    expect(runtime.snapshot.single.state, PluginRuntimeState.failed);
    expect(factory.plugins.single.shutdownCount, 1);
  });

  test("shutdown cleans up a plugin that returns after API disposal begins", () async {
    final startGate = Completer<void>();
    final factory = _FakeGenerationFactory(
      startGate: startGate.future,
      honorAbort: false,
    );
    final runtime = _runtime(factory: factory);
    final starting = runtime.start(pluginId: "one");
    await _waitUntil(() => factory.startCount == 1);

    runtime.beginShutdown();
    final disposingApis = runtime.disposeStartedApis();
    startGate.complete();

    await expectLater(starting, throwsA(isA<PluginStartAbortedException>()));
    await disposingApis;
    expect(factory.plugins.single.shutdownCount, 1);
    await runtime.dispose();
  });

  test("event closure during API disposal does not hide a later shutdown failure", () async {
    final shutdownError = StateError("runtime shutdown failed");
    final factory = _FakeGenerationFactory(
      startGate: Future<void>.value(),
      pluginFactory: (_) => _FakePlugin(
        api: _FakeApi(closeEventsOnDispose: true),
        shutdownError: shutdownError,
      ),
    );
    final runtime = _runtime(factory: factory);
    await runtime.start(pluginId: "one");

    runtime.beginShutdown();
    await runtime.disposeStartedApis();
    expect(runtime.snapshot.single.state, PluginRuntimeState.active);

    await expectLater(runtime.dispose(), throwsA(same(shutdownError)));
  });

  test("backend events carry plugin and generation attribution", () async {
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.start(pluginId: "one");

    final eventFuture = runtime.backendEvents.first;
    factory.api.eventsController.add(const BridgeSseProjectUpdated());
    final sourced = await eventFuture;

    expect(sourced.pluginId, "one");
    expect(sourced.generation, 1);
    expect(sourced.event, isA<BridgeSseProjectUpdated>());
  });
}

enum _TestOperation {
  read,
  watch,
  activeRead,
  directFence,
  first,
  second,
  stream,
  duringStop,
  leasedRead,
  authenticatedRead,
  authenticatedStream,
  fencedRead,
  concurrentRead,
  staleAuthenticatedRead,
  longRead,
  forceFenced,
  retry,
}

PluginRuntime _runtime({required _FakeGenerationFactory factory}) {
  final runtime = PluginRuntime(
    registrations: const [
      PluginRuntimeRegistration(
        descriptor: _FakeDescriptor(),
        config: PluginConfig(values: {}),
        stateDirectory: ".",
      ),
    ],
    generationFactory: factory,
    setupProcesses: const _UnusedHostProcessService(),
    environment: const {},
    clock: const ServerClock(),
    shutdownBudget: const Duration(seconds: 1),
  );
  runtime.applyAccess(
    entries: const [
      PluginRuntimeAccess(
        pluginId: "one",
        eligible: true,
        startAllowed: true,
      ),
    ],
  );
  return runtime;
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError("condition did not become true");
}

class _FakeGenerationFactory implements PluginGenerationFactory {
  _FakeGenerationFactory({
    required this.startGate,
    this.pluginFactory,
    this.startError,
    this.honorAbort = true,
  });

  final Future<void> startGate;
  final _FakePlugin Function(int generation)? pluginFactory;
  final Object? startError;
  final bool honorAbort;
  final List<_FakePlugin> plugins = <_FakePlugin>[];
  int startCount = 0;

  _FakeApi get api => plugins.last.api;

  @override
  Future<void> enforceBridgeOwnership() async {}

  @override
  Stream<PluginGenerationStartEvent> start({
    required PluginRuntimeRegistration registration,
    required StartAbortSignal startAborted,
  }) async* {
    startCount++;
    await startGate;
    if (startError case final error?) throw error;
    if (honorAbort && startAborted.isAborted) throw const PluginStartAbortedException();
    final plugin = pluginFactory?.call(startCount) ?? _FakePlugin(api: _FakeApi());
    plugins.add(plugin);
    yield PluginGenerationStarted(plugin: plugin);
  }
}

class _FakeDescriptor extends BridgePluginDescriptor {
  const _FakeDescriptor();

  @override
  String get id => "one";

  @override
  String get displayName => "One";

  @override
  PluginProjectOwnership get projectOwnership => PluginProjectOwnership.native;

  @override
  List<PluginOption> get options => const [];

  @override
  Future<BridgePlugin> start(PluginHost host) => throw UnsupportedError("fake factory owns construction");
}

class _FakePlugin implements BridgePlugin {
  _FakePlugin({required this.api, this.shutdownGate, this.shutdownError});

  final BehaviorSubject<PluginStatus> statuses = BehaviorSubject.seeded(const PluginReady());
  final BehaviorSubject<PluginWorkState> workStates = BehaviorSubject.seeded(PluginWorkState.idle);
  final Future<void>? shutdownGate;
  final Object? shutdownError;
  Future<void>? _shutdownFuture;
  int shutdownInvocationCount = 0;
  int shutdownCount = 0;

  @override
  final _FakeApi api;

  @override
  PluginStatus get currentStatus => statuses.value;

  @override
  Stream<PluginStatus> get status => statuses.stream;

  @override
  PluginWorkState get currentWorkState => workStates.value;

  @override
  Stream<PluginWorkState> get workState => workStates.stream;

  @override
  PluginDiagnostics describe() => const PluginDiagnostics(pluginId: "one", endpoint: null, details: {});

  @override
  Future<void> shutdown({required Duration? budget}) {
    shutdownInvocationCount++;
    return _shutdownFuture ??= _shutdown();
  }

  Future<void> _shutdown() async {
    shutdownCount++;
    await shutdownGate;
    await api.dispose();
    if (shutdownError case final error?) throw error;
    if (!api.eventsController.isClosed) await api.eventsController.close();
    if (!statuses.isClosed) await statuses.close();
    if (!workStates.isClosed) await workStates.close();
  }
}

class _FakeApi extends NativeProjectsPluginApi {
  _FakeApi({this.id = "one", this.closeEventsOnDispose = false});

  final StreamController<BridgeSseEvent> eventsController = StreamController.broadcast();
  final bool closeEventsOnDispose;
  int disposeCount = 0;

  @override
  final String id;

  @override
  Stream<BridgeSseEvent> get events => eventsController.stream;

  @override
  Future<void> dispose() async {
    disposeCount++;
    if (closeEventsOnDispose && !eventsController.isClosed) await eventsController.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedHostProcessService implements HostProcessService {
  const _UnusedHostProcessService();

  @override
  Future<ProcessIdentity?> inspect({required int pid}) => throw UnsupportedError("unused");

  @override
  Future<SignalResult> signalForce({required int pid}) => throw UnsupportedError("unused");

  @override
  Future<SignalResult> signalGraceful({required int pid}) => throw UnsupportedError("unused");

  @override
  Future<SpawnedProcess> spawn({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
  }) => throw UnsupportedError("unused");
}
