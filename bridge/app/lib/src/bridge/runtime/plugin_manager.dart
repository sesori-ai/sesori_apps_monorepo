import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show BridgePlugin, Log;

/// Builds and starts a registered plugin instance.
///
/// Transitional seam (plugin-lifecycle migration, PR 5): the contract's
/// descriptors are meant to be const and registered directly, but
/// `LegacyOpenCodeDescriptor` can only be constructed inside the startup
/// mutex with the legacy services injected, so the runner registers a bound
/// start delegate instead. Collapses to `descriptor.start(host)` when the
/// real descriptor lands at the flip (PR 12).
typedef PluginStarter = Future<BridgePlugin> Function();

/// Owns which plugins are running: registered plugins are *not* auto-started;
/// each is independently startable and stoppable by id.
///
/// - [startPlugin] / [stopPlugin] are idempotent per id: a repeated start
///   shares the in-flight (or completed) start, a repeated stop shares the
///   one stop. After a stop completes the id may be started fresh.
/// - Stopping the active plugin first cancels the bridge session (when one
///   is bound via [bindActiveSession]), then runs the plugin's
///   `shutdown(budget)` — a stopped plugin must never be left behind a live
///   session still routing requests to it.
/// - The manager API is N-ready, but the bridge currently supports exactly
///   one active plugin (a single `BridgePluginApi` is constructor-baked into
///   the orchestrator's components); starting a second id while another is
///   active fails with a clear error.
class PluginManager {
  PluginManager();

  final Map<String, _PluginRegistration> _registrations = {};
  final Map<String, _RunningPlugin> _running = {};
  Future<void> Function()? _cancelActiveSession;

  /// Registers [starter] under [id] without starting it.
  ///
  /// [shutdownBudget] is the soft deadline granted to this plugin's
  /// `shutdown()` when [stopPlugin] runs it.
  void register({
    required String id,
    required PluginStarter starter,
    required Duration shutdownBudget,
  }) {
    if (_registrations.containsKey(id)) {
      throw StateError('Plugin "$id" is already registered.');
    }
    _registrations[id] = _PluginRegistration(starter: starter, shutdownBudget: shutdownBudget);
  }

  /// Binds how [stopPlugin] cancels the bridge session before tearing the
  /// active plugin down, replacing any previous binding.
  ///
  /// The runner binds `session.cancel()` once the session exists; the cancel
  /// is also invoked on stops that happen after the session already ended,
  /// so the bound callback must tolerate that (`OrchestratorSession.cancel`
  /// does — it is idempotent and never throws).
  void bindActiveSession({required Future<void> Function() cancel}) {
    _cancelActiveSession = cancel;
  }

  /// The successfully started, not yet stopping plugins, keyed by id.
  Map<String, BridgePlugin> get activePlugins {
    return Map<String, BridgePlugin>.unmodifiable(<String, BridgePlugin>{
      for (final MapEntry(key: id, value: running) in _running.entries)
        if (running.instance != null && running.stop == null) id: running.instance!,
    });
  }

  /// Starts the plugin registered under [id], or returns the already
  /// started/starting instance.
  ///
  /// A start over an in-flight [stopPlugin] of the same id waits for the
  /// stop to settle — even a *failed* stop frees the slot, and its error
  /// belongs to the stop caller — then starts fresh. Starting while a
  /// *different* id is active throws: the bridge supports exactly one
  /// active plugin until the orchestrator can rebind plugin APIs
  /// mid-session. A failed start
  /// untracks the id, so a later retry invokes the starter again.
  Future<BridgePlugin> startPlugin({required String id}) async {
    final registration = _registrations[id];
    if (registration == null) {
      throw StateError(
        'Unknown plugin "$id". Registered plugins: ${_registrations.keys.join(", ")}.',
      );
    }

    while (true) {
      for (final runningId in _running.keys) {
        if (runningId != id) {
          throw StateError(
            'Cannot start plugin "$id" while "$runningId" is active: '
            "the bridge supports exactly one active plugin.",
          );
        }
      }
      final existing = _running[id];
      if (existing == null) {
        break;
      }
      final stop = existing.stop;
      if (stop == null) {
        return existing.start;
      }
      // Wait the in-flight stop out, then re-check: another caller may have
      // restarted (or a different id may have started) in the meantime.
      try {
        await stop;
      } catch (error) {
        // The failed stop surfaces through the stopPlugin caller (the
        // runner's ordered shutdown step keeps it loud); the restart only
        // needs the slot free, which the stop guarantees on every path.
        Log.w('The previous stop of plugin "$id" failed: $error');
      }
    }

    // Track before invoking the starter: _startTracked runs synchronously up
    // to its first await, so a synchronously throwing starter would untrack
    // *before* a track placed after this call — wedging the id forever. No
    // await separates these statements, so no caller can observe the entry
    // without its start future.
    final running = _RunningPlugin();
    _running[id] = running;
    return running.start = _startTracked(id: id, running: running, starter: registration.starter);
  }

  /// Stops the plugin running under [id]; a no-op when nothing runs there.
  ///
  /// Order: cancel the bound session first (see [bindActiveSession]), then
  /// `shutdown(budget)` with the budget given at [register] time. A stop
  /// over an in-flight start waits for the start to settle first; if that
  /// start failed there is nothing to stop.
  Future<void> stopPlugin({required String id}) {
    final running = _running[id];
    if (running == null) {
      return Future.value();
    }
    return running.stop ??= _stopTracked(id: id, running: running);
  }

  Future<BridgePlugin> _startTracked({
    required String id,
    required _RunningPlugin running,
    required PluginStarter starter,
  }) async {
    try {
      final plugin = await starter();
      running.instance = plugin;
      return plugin;
    } catch (_) {
      _untrack(id: id, running: running);
      rethrow;
    }
  }

  Future<void> _stopTracked({required String id, required _RunningPlugin running}) async {
    final BridgePlugin plugin;
    try {
      plugin = await running.start;
    } catch (_) {
      // The start failed and untracked the id; its caller surfaces the
      // error. Nothing is running, so this stop trivially succeeded. The
      // untrack here is defense in depth (idempotent via the identical
      // guard) so a tracking bug can never wedge the id.
      _untrack(id: id, running: running);
      return;
    }

    final cancelActiveSession = _cancelActiveSession;
    if (cancelActiveSession != null) {
      try {
        await cancelActiveSession();
      } catch (error) {
        // A failed cancel must not leave the plugin running: proceed to
        // shutdown — the zombie to avoid is a live session over a stopped
        // plugin, not the reverse.
        Log.w('Cancelling the session before stopping plugin "$id" failed: $error');
      }
    }

    try {
      await plugin.shutdown(budget: _registrations[id]?.shutdownBudget);
    } finally {
      _untrack(id: id, running: running);
    }
  }

  void _untrack({required String id, required _RunningPlugin running}) {
    if (identical(_running[id], running)) {
      _running.remove(id);
    }
  }
}

class _PluginRegistration {
  const _PluginRegistration({required this.starter, required this.shutdownBudget});

  final PluginStarter starter;
  final Duration shutdownBudget;
}

class _RunningPlugin {
  late final Future<BridgePlugin> start;
  BridgePlugin? instance;
  Future<void>? stop;
}
