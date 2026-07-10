import "dart:async";

import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/models/connection_status.dart";
import "../logging/logging.dart";
import "../repositories/bridge_repository.dart";
import "../repositories/registered_bridges_store.dart";

/// Reactive owner of the "this account has at least one registered bridge"
/// signal, shared by the connection overlay (to decide whether a bridge-offline
/// banner is meaningful) and the project list (to pick the bridge-disconnected
/// recovery flow).
///
/// "Registered" is a one-way latch: an account never reverts from *has a
/// registered bridge* to *none* (an offline bridge is still registered). The
/// answer is resolved in three tiers, cheapest first:
///
///  1. the in-process latch ([isRegistered]'s current value) answers instantly;
///  2. [RegisteredBridgesStore] answers from its in-memory / persisted latch,
///     surviving an app restart without a network round-trip;
///  3. only when neither is set does [hasRegisteredBridges] fall back to the
///     auth server via [BridgeRepository], latching a positive answer for good.
///
/// Two connection events latch the signal without any lookup:
///  * a successful E2E connection ([ConnectionConnected]) proves a bridge
///    exists, so the signal flips to `true` the moment the bridge is reachable —
///    this is what lets the overlay banner appear instantly when a connected
///    bridge later drops, with no network call;
///  * while the bridge is parked offline ([ConnectionBridgeOffline]) the signal
///    is (re)resolved so a consumer that only listens to [isRegistered] — the
///    overlay — gets the right answer without driving the lookup itself.
///
/// [RegisteredBridgesStore] is the Layer-2 persistence/cache repository (a
/// data-access role); this service is the Layer-3 orchestrator that adds the network tier,
/// the connection-driven latching, and the reactive stream on top of it. The
/// store clears its own persisted latch on logout; this service resets its
/// reactive latch on logout so a different account never inherits the answer.
@lazySingleton
class RegisteredBridgesService {
  final BridgeRepository _bridgeRepository;
  final RegisteredBridgesStore _store;

  /// The reactive latch. `true` once the account is known to have a registered
  /// bridge; `false` means "not yet known" — never a definitive "no bridges".
  final BehaviorSubject<bool> _isRegistered = BehaviorSubject<bool>.seeded(false);

  /// In-flight resolution, used to coalesce concurrent [hasRegisteredBridges]
  /// callers onto a single lookup.
  Future<bool>? _activeLookup;

  /// In-flight bridge-list fetch, used to coalesce concurrent
  /// [getRegisteredBridges] callers onto a single network request.
  Future<List<BridgeSummary>>? _activeFetch;

  /// Last successful bridge-list result, sorted in display order.
  List<BridgeSummary>? _cachedBridges;

  /// Auth generation, bumped on every logout. A lookup or connection-driven
  /// latch captures this when it starts; if a logout bumps it while the
  /// operation is in flight, the operation must not write the old account's
  /// answer to the store or the stream — otherwise the next account signing in
  /// on this device would inherit the latch and see a spurious bridge-offline
  /// flow.
  int _authGeneration = 0;

  StreamSubscription<ConnectionStatus>? _statusSubscription;
  StreamSubscription<AuthState>? _authSubscription;

  RegisteredBridgesService({
    required BridgeRepository bridgeRepository,
    required RegisteredBridgesStore registeredBridgesStore,
    required ConnectionService connectionService,
    required AuthSession authSession,
  }) : _bridgeRepository = bridgeRepository,
       _store = registeredBridgesStore {
    // Seed the reactive latch from the persisted answer (no network) so
    // consumers see the right value immediately, independent of connection state.
    unawaited(_seedFromStore());
    _statusSubscription = connectionService.status.listen(_onConnectionStatusChanged);
    _authSubscription = authSession.authStateStream.listen((state) {
      // Logout: bump the generation so any in-flight lookup/latch retires
      // instead of writing the old account's answer, then drop the reactive
      // latch so a different account signing in on the same device never
      // inherits this one's answer. The store clears its own persisted latch via
      // its own auth listener.
      if (state is AuthUnauthenticated) {
        _authGeneration++;
        _reset();
      }
    });
  }

  /// The account's registered-bridge latch as a reactive signal. Seeded `false`,
  /// flips to `true` once known, and resets to `false` on logout. Never emits a
  /// definitive "no bridges" — `false` only means "not yet known".
  ValueStream<bool> get isRegistered => _isRegistered.stream;

  /// Resolves whether the account has any registered bridge, latching a positive
  /// answer for the rest of the run. Concurrent calls are coalesced into a
  /// single resolution.
  Future<bool> hasRegisteredBridges() {
    return _activeLookup ??= _resolve().whenComplete(() => _activeLookup = null);
  }

  Future<void> _seedFromStore() async {
    if (await _store.hasRegisteredBridges()) _latchEmit();
  }

  Future<bool> _resolve() async {
    // Tiers 1 & 2: the in-process latch, then the store's in-memory / persisted
    // latch. A known-positive answer never reverts, so don't touch the network.
    if (_isRegistered.value) return true;
    if (await _store.hasRegisteredBridges()) {
      _latchEmit();
      return true;
    }
    // Tier 3: ask the auth server, latching a positive answer for next time.
    return _lookup();
  }

  Future<bool> _lookup() async => (await getRegisteredBridges()).isNotEmpty;

  /// Fetches the account's registered bridges from the auth server, most
  /// recently seen first, latching the positive has-registered answer as a
  /// side effect. Concurrent calls are coalesced into a single request.
  ///
  /// Fail-soft: an error response, an unexpected throw, or a logout racing the
  /// request all yield an empty list, so callers degrade (e.g. hide the
  /// machine-name row) instead of surfacing a failure. Reached fire-and-forget
  /// from the connection listener via [hasRegisteredBridges], so an unexpected
  /// throw (network timeout, deserialization) — rather than an ErrorResponse —
  /// would otherwise surface as an uncaught async error.
  Future<List<BridgeSummary>> getRegisteredBridges() {
    final cached = _cachedBridges;
    if (cached != null) return Future.value(cached);
    return _activeFetch ??= _fetchRegisteredBridges().whenComplete(() => _activeFetch = null);
  }

  Future<List<BridgeSummary>> _fetchRegisteredBridges() async {
    final generation = _authGeneration;
    try {
      final response = await _bridgeRepository.getRegisteredBridges();
      // A logout during the in-flight request retires this result: the account
      // that asked is gone, so latching or reporting its answer would leak onto
      // the device and the next account would inherit it.
      if (generation != _authGeneration) return const [];
      switch (response) {
        case SuccessResponse(:final data):
          if (data.isEmpty) return const [];
          // Latch the positive answer so future transitions skip the network.
          await _latch(generation);
          // A logout may have raced the latch: it abandons (and undoes) the
          // write, so reporting the bridges here would still leak the old
          // account's answer to the caller. Retire the result to match.
          if (generation != _authGeneration) return const [];
          final sorted = List<BridgeSummary>.unmodifiable(_sortedByRecency(bridges: data));
          _cachedBridges = sorted;
          return sorted;
        case ErrorResponse(:final error):
          logw("Failed to fetch registered bridges: ${error.toString()}");
          return const [];
      }
    } on Object catch (error, stackTrace) {
      logw("Failed to fetch registered bridges (unexpected error)", error, stackTrace);
      return const [];
    }
  }

  /// Most recently seen bridge first; never-seen bridges sort after seen ones,
  /// newest registration first among themselves. The first entry is what a
  /// consumer should name when it has room for only one machine.
  static List<BridgeSummary> _sortedByRecency({required List<BridgeSummary> bridges}) {
    return [...bridges]..sort((a, b) {
      final aSeen = a.lastSeenAt;
      final bSeen = b.lastSeenAt;
      if (aSeen != null && bSeen != null) {
        final seenCompare = bSeen.compareTo(aSeen);
        if (seenCompare != 0) return seenCompare;
        return b.addedAt.compareTo(a.addedAt);
      }
      if (aSeen != null) return -1;
      if (bSeen != null) return 1;
      return b.addedAt.compareTo(a.addedAt);
    });
  }

  void _onConnectionStatusChanged(ConnectionStatus status) {
    switch (status) {
      // A live E2E connection proves a bridge exists — latch without a lookup.
      case ConnectionConnected():
        _cachedBridges = null;
        unawaited(_latch());
      // Parked offline: (re)resolve so a consumer of [isRegistered] alone — the
      // overlay — gets the right answer. Coalesced, and a no-op once latched.
      case ConnectionBridgeOffline():
        unawaited(hasRegisteredBridges());
      // Pre-connection / transient states carry no registration signal.
      case ConnectionDisconnected():
      case ConnectionReconnecting():
      case ConnectionLost():
        break;
    }
  }

  /// Latches the positive answer in the store and emits it on the stream. A
  /// no-op once already latched, so repeat calls (e.g. each [ConnectionConnected]
  /// transition) cost nothing.
  ///
  /// [generation] is the auth generation captured when the latch was initiated
  /// (defaults to the current one for connection-driven latches). If a logout
  /// bumps it before or during the persist, the latch is abandoned — and any
  /// write that already landed is undone — so the signed-out, or next, account
  /// never inherits this answer.
  Future<void> _latch([int? generation]) async {
    if (_isRegistered.value) return;
    final gen = generation ?? _authGeneration;
    if (gen != _authGeneration) return;
    await _store.markRegistered();
    if (gen != _authGeneration) {
      // A logout raced the persist; the store's own logout-clear may have run
      // before markRegistered landed, so undo it rather than leave the old
      // account's latch resurrected for the next account. Skip the undo if the
      // current account has since latched its own answer (_isRegistered is
      // true) — clearing unconditionally would wipe that valid latch.
      if (!_isRegistered.value) await _store.clear();
      return;
    }
    _latchEmit();
  }

  void _latchEmit() {
    if (!_isRegistered.isClosed && !_isRegistered.value) _isRegistered.add(true);
  }

  void _reset() {
    _cachedBridges = null;
    if (!_isRegistered.isClosed && _isRegistered.value) _isRegistered.add(false);
  }

  @disposeMethod
  Future<void> dispose() async {
    await _statusSubscription?.cancel();
    await _authSubscription?.cancel();
    _statusSubscription = null;
    _authSubscription = null;
    await _isRegistered.close();
  }
}
