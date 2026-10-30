import "dart:async";
import "dart:math";

import "package:collection/collection.dart";
import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/models/connection_status.dart";
import "../capabilities/server_connection/models/sse_event.dart";
import "../capabilities/server_connection/target_bridge_change_tracker.dart";
import "../errors/api_error_remote_failure_x.dart";
import "../logging/logging.dart";
import "../repositories/models/session_page_result.dart";
import "../repositories/project_repository.dart";
import "../repositories/session_repository.dart";
import "catalog_rescan_service.dart";
import "models/all_sessions_mode.dart";
import "models/project_list_state.dart";
import "models/session_list_item_state.dart";
import "models/session_list_quick_filter.dart";
import "models/session_window_state.dart";
import "project_inventory_service.dart";
import "session_unseen_tracker.dart";
import "sse_event_tracker.dart";

/// The root sessions of one [AllSessionsMode] under one [key], loaded from
/// the bridge a page at a time, newest first, and kept current by live
/// events. It owns the one rule for whether a session matches a key.
///
/// The caller owns this factory instance and disposes it with its scope.
@injectable
class SessionWindowService({
  @factoryParam required final AllSessionsMode _mode,
  @factoryParam required final ProjectInventoryService _projectInventory,
  required final SessionRepository _sessionRepository,
  required final ProjectRepository _projectRepository,
  required final ConnectionService _connectionService,
  required final SseEventTracker _sseEventTracker,
  required final SessionUnseenTracker _sessionUnseenTracker,
  required CatalogRescanService catalogRescanService,
}) {
  static const int pageSize = 200;

  /// The largest page the bridge serves.
  static const int maxPageSize = 1000;

  /// How long a typed query waits before the bridge is asked.
  static const Duration queryDelay = Duration(milliseconds: 250);

  /// How long live changes gather before the counts, or a chip's rows, are
  /// asked again.
  static const Duration liveRefreshDelay = Duration(seconds: 1);

  final BehaviorSubject<SessionWindowState> _state = BehaviorSubject.seeded(const SessionWindowLoading());
  final CompositeSubscription _subscriptions = CompositeSubscription();
  final TargetBridgeChangeTracker _targetChange = TargetBridgeChangeTracker(
    initialStatus: _connectionService.currentStatus,
  );

  SessionWindowKey _key = (projectId: null, query: null, filter: SessionListQuickFilter.all);

  /// Bumped by every load that replaces the rows, so an answer the user has
  /// moved past is dropped.
  int _generation = 0;

  /// The session changes seen since the rows' request was sent, re-applied
  /// over its answer; null while no request is in flight.
  List<_SessionChange>? _replay;

  // COMPATIBILITY 2026-10-28 (v1.10.2): every root session of the mode on a
  // bridge without /sessions/page, held so keys, chips and counts are answered
  // locally; null in paged mode. Remove once no supported bridge predates the
  // route.
  List<Session>? _completeSessions;

  // COMPATIBILITY 2026-10-28 (v1.10.2): the inventory projects whose sessions
  // [_completeSessions] holds. Remove with it.
  Set<String> _completeProjectIds = const {};

  bool _connected = false;

  /// A load failed and left older rows on screen, so the next reconnect
  /// loads them again instead of relying on the replayed events. In complete
  /// mode: some project's sessions failed to list.
  bool _rowsOutdated = false;

  /// The generation [loadMore]'s page request was sent under, so a lost
  /// connection tells it from a load that replaces the rows.
  int? _pageGeneration;
  Timer? _queryTimer;
  Timer? _reloadTimer;
  Timer? _countsTimer;

  this {
    _subscriptions.add(_connectionService.status.listen(_onConnectionStatus));
    _subscriptions.add(_connectionService.events.listen(_onEvent));
    _subscriptions.add(
      _sseEventTracker.sessionActivity
          .distinct(const DeepCollectionEquality().equals)
          .skip(1)
          .listen((_) => _onLiveStateChanged()),
    );
    // Seeding from a page moves this tracker too, so paged mode follows the
    // bridge's unseen events instead; complete mode only re-reads it. Both
    // follow fresh user activity.
    _subscriptions.add(
      _sessionUnseenTracker.sessionUnseen.skip(1).listen((unseen) {
        _applyUserActivity(unseen: unseen);
        if (_completeSessions case final sessions?) _emitComplete(sessions: sessions);
      }),
    );
    _subscriptions.add(
      _projectInventory.stateStream.listen((inventory) => unawaited(_admitProjects(inventory: inventory))),
    );
    // Pages leave out hidden projects, so a changed project set reloads them.
    _subscriptions.add(
      _projectInventory.stateStream
          .whereType<ProjectListLoaded>()
          .map((inventory) => {for (final project in inventory.projects) project.id})
          .distinct(const SetEquality<String>().equals)
          .skip(1)
          .listen((_) {
            if (_completeSessions == null && _state.value is SessionWindowLoaded) unawaited(reload());
          }),
    );
    _subscriptions.add(_connectionService.dataMayBeStale.listen((_) => unawaited(reload())));
    _subscriptions.add(catalogRescanService.catalogChanged.listen((_) => unawaited(reload())));
  }

  ValueStream<SessionWindowState> get state => _state.stream;

  AllSessionsMode get mode => _mode;

  SessionWindowKey get key => _key;

  /// Lists [key] instead. The rows already loaded narrow to it at once; the
  /// bridge's answer replaces them [queryDelay] after a typed query, and at
  /// once for any other change. Listing everything, a typed query narrows
  /// the rows only once typing pauses: each narrowing reads every session.
  void select({required SessionWindowKey key}) {
    final previous = _key;
    if (key == previous || _state.isClosed) return;
    _key = key;
    final typed = key.query != null && key.projectId == previous.projectId && key.filter == previous.filter;
    if (_completeSessions case final sessions?) {
      _queryTimer?.cancel();
      if (typed) {
        _queryTimer = Timer(queryDelay, () {
          if (_completeSessions case final current?) _emitComplete(sessions: current);
        });
      } else {
        _emitComplete(sessions: sessions);
      }
      return;
    }
    // Drops any answer for the previous key, and holds live changes for the
    // coming one.
    _generation++;
    _replay = [];
    _cancelTimers();
    if (_state.value case final SessionWindowLoaded loaded) {
      final projects = _projectsById();
      _emit(
        SessionWindowLoaded(
          sessions: List.unmodifiable(
            loaded.sessions.where((session) => _matches(session: session, projects: projects)),
          ),
          counts: loaded.counts,
          nextCursor: loaded.nextCursor,
          loadMore: SessionWindowLoadMore.idle,
          awaitingAnswer: true,
        ),
      );
    }
    if (typed) {
      _queryTimer = Timer(queryDelay, () => unawaited(_loadPaged(limit: pageSize)));
    } else {
      unawaited(_loadPaged(limit: pageSize));
    }
  }

  /// Appends the next page. Does nothing while the rows are being replaced,
  /// while a page is already on its way, or when none follows. Rows a failed
  /// load left behind are reloaded instead: their cursor may belong to an
  /// earlier key. While the bridge is away the page fails at once, and the
  /// reconnect asks for it.
  Future<void> loadMore() async {
    if (_state.isClosed || _replay != null) return;
    final loaded = _state.value;
    if (loaded is! SessionWindowLoaded || loaded.loadMore == SessionWindowLoadMore.loading) return;
    final cursor = loaded.nextCursor;
    if (cursor == null) return;
    if (!_connected) {
      _emit(_withLoadMore(loaded: loaded, loadMore: SessionWindowLoadMore.failed));
      return;
    }
    if (_rowsOutdated) {
      _emit(_withLoadMore(loaded: loaded, loadMore: SessionWindowLoadMore.loading));
      await reload();
      return;
    }
    final generation = _generation;
    _pageGeneration = generation;
    _replay = [];
    _emit(_withLoadMore(loaded: loaded, loadMore: SessionWindowLoadMore.loading));
    final unseenTick = _sessionUnseenTracker.tick;
    final result = await _sessionRepository.getSessionPage(
      request: _request(cursor: cursor, limit: pageSize),
    );
    // A newer load owns the rows, and the changes gathered meanwhile.
    if (_state.isClosed || generation != _generation) return;
    final replay = _takeReplay();
    final current = _state.value;
    if (current is! SessionWindowLoaded) return;
    switch (result) {
      case SessionPageLoaded(:final page):
        _seedUnseen(sessions: page.items, sinceTick: unseenTick);
        final known = {for (final session in current.sessions) session.id};
        _emit(
          SessionWindowLoaded(
            sessions: List.unmodifiable([
              ...current.sessions,
              ...page.items.where((session) => !known.contains(session.id)),
            ]),
            counts: page.counts,
            nextCursor: page.nextCursor,
            loadMore: SessionWindowLoadMore.idle,
            // A key change stops pages until its own answer.
            awaitingAnswer: false,
          ),
        );
        _reapply(replay);
      case SessionPageUnsupported():
        unawaited(_loadComplete());
      case SessionPageFailure(:final error):
        loge("Failed to load the next page of sessions", error);
        _emit(_withLoadMore(loaded: current, loadMore: SessionWindowLoadMore.failed));
    }
  }

  /// Refetches the loaded range, at least one page, and swaps it in once
  /// every page has arrived, so a reader far down keeps their place. Answers
  /// false when it failed, and true when it succeeded or a newer load
  /// superseded it; that load reports through [state].
  Future<bool> reload() {
    if (_state.isClosed) return Future.value(false);
    if (_completeSessions != null) return _loadComplete();
    final loaded = switch (_state.value) {
      SessionWindowLoaded(:final sessions) => sessions.length,
      SessionWindowLoading() || SessionWindowFailed() => 0,
    };
    return _loadPaged(limit: max(pageSize, loaded));
  }

  /// The newest sessions of every project matching [query], at most [limit],
  /// whatever the key. A blank query matches every session. While the bridge
  /// is away, and once it leaves, this fails at once.
  Future<SessionWindowSearchResult> search({required String query, required int limit}) async {
    if (_completeSessions case final sessions?) {
      return SessionWindowSearchMatches(
        sessions: _searchLocally(sessions: sessions, query: query, limit: limit),
      );
    }
    const away = SessionWindowSearchFailure(reason: RemoteFailureReason.networkDown);
    if (!_connected) return away;
    final lost = Completer<SessionPageResult?>();
    final watch = _connectionService.status.where((status) => status is! ConnectionConnected).listen((_) {
      if (!lost.isCompleted) lost.complete(null);
    });
    final SessionPageResult? result;
    try {
      result = await Future.any([
        _sessionRepository.getSessionPage(
          request: SessionPageRequest(
            mode: _pageMode,
            projectId: null,
            // The bridge rejects a blank query; leaving it out lists every session.
            query: searchWords(query: query).isEmpty ? null : query,
            filter: SessionPageFilter.all,
            cursor: null,
            limit: limit,
          ),
        ),
        lost.future,
      ]);
    } finally {
      unawaited(watch.cancel());
    }
    if (result == null) return away;
    // The result keeps only the reason, so the original error is logged here.
    if (result case SessionPageFailure(:final error)) logw("Session search failed", error);
    return switch (result) {
      SessionPageLoaded(:final page) => SessionWindowSearchMatches(sessions: page.items),
      // The window's own loads switch to listing everything; until then, the
      // loaded rows are what can be searched.
      SessionPageUnsupported() => SessionWindowSearchMatches(
        sessions: switch (_state.value) {
          SessionWindowLoaded(:final sessions) => _searchLocally(sessions: sessions, query: query, limit: limit),
          SessionWindowLoading() || SessionWindowFailed() => const [],
        },
      ),
      SessionPageFailure(:final error) => SessionWindowSearchFailure(reason: error.remoteFailureReason),
    };
  }

  /// What can be shown for [query] before [search] answers: the loaded rows
  /// (in complete mode every session of the mode) and [earlier], an earlier
  /// answer, that match it, newest first, at most [limit]. A blank query
  /// matches every row.
  List<Session> searchLoaded({required String query, required List<Session> earlier, required int limit}) {
    final loaded =
        _completeSessions ??
        switch (_state.value) {
          SessionWindowLoaded(:final sessions) => sessions,
          SessionWindowLoading() || SessionWindowFailed() => const <Session>[],
        };
    // A loaded row is the fresher copy of a session both hold.
    final loadedIds = {for (final session in loaded) session.id};
    final candidates = [
      ...loaded,
      ...earlier.where((session) => _inMode(session) && !loadedIds.contains(session.id)),
    ];
    final projects = _projectsById();
    final matches =
        candidates.where((session) => _matchesQuery(session: session, query: query, projects: projects)).toList()
          ..sort((a, b) => _compare(a: a, b: b));
    return matches.take(limit).toList();
  }

  Future<bool> _loadPaged({required int limit}) async {
    if (_state.isClosed) return false;
    final generation = ++_generation;
    _replay = [];
    _cancelTimers();
    final unseenTick = _sessionUnseenTracker.tick;
    final sessions = <Session>[];
    String? cursor;
    late SessionPageCounts counts;
    do {
      final result = await _sessionRepository.getSessionPage(
        request: _request(cursor: cursor, limit: min(maxPageSize, limit - sessions.length)),
      );
      if (_state.isClosed || generation != _generation) return true;
      switch (result) {
        case SessionPageLoaded(:final page):
          sessions.addAll(page.items);
          cursor = page.nextCursor;
          counts = page.counts;
        case SessionPageUnsupported():
          return await _loadComplete();
        case SessionPageFailure(:final error):
          loge("Failed to load sessions", error);
          _fail(reason: error.remoteFailureReason);
          return false;
      }
    } while (cursor != null && sessions.length < limit);
    _seedUnseen(sessions: sessions, sinceTick: unseenTick);
    final replay = _takeReplay();
    _rowsOutdated = false;
    _emit(
      SessionWindowLoaded(
        sessions: List.unmodifiable(sessions),
        counts: counts,
        nextCursor: cursor,
        loadMore: SessionWindowLoadMore.idle,
        awaitingAnswer: false,
      ),
    );
    _reapply(replay);
    return true;
  }

  /// Re-applies the changes seen during a load; the answer's counts predate
  /// them, so they are asked again.
  void _reapply(List<_SessionChange> replay) {
    if (replay.isEmpty) return;
    replay.forEach(_applyChange);
    _scheduleCounts();
  }

  // COMPATIBILITY 2026-10-28 (v1.10.2): a bridge without /sessions/page lists
  // every root session of every project, as the session list did before
  // pages. Remove once no supported bridge predates the route.
  Future<bool> _loadComplete() async {
    if (_state.isClosed) return false;
    final generation = ++_generation;
    _replay = [];
    _cancelTimers();
    final unseenTick = _sessionUnseenTracker.tick;
    final inventory = await _settledInventory();
    if (_state.isClosed || generation != _generation) return true;
    final List<ProjectSummary> listed;
    switch (inventory) {
      case ProjectListLoaded(:final projects):
        listed = projects;
      case ProjectListFailed(:final reason):
        _fail(reason: reason);
        return false;
      // Loading is skipped above.
      case ProjectListBridgeDisconnected() || ProjectListLoading():
        _fail(reason: RemoteFailureReason.networkDown);
        return false;
    }
    final (:sessions, :succeeded) = await _listProjectSessions(projects: listed, unseenTick: unseenTick);
    if (_state.isClosed || generation != _generation) return true;
    _completeProjectIds = {for (final project in listed) project.id};
    var complete = List<Session>.unmodifiable(sessions..sort((a, b) => _compare(a: a, b: b)));
    for (final change in _takeReplay()) {
      complete = _upsert(
        sessions: complete,
        session: change.session,
        keep: !change.removed && _inMode(change.session),
        inRange: true,
      );
    }
    _completeSessions = complete;
    _rowsOutdated = !succeeded;
    _emitComplete(sessions: complete);
    // The inventory may have changed while the projects were read.
    unawaited(_admitProjects(inventory: _projectInventory.state));
    return succeeded;
  }

  /// The inventory's project set once it has one. Completes from the first
  /// settled value rather than awaiting the subscription's cancellation, as
  /// `firstWhere` would.
  Future<ProjectListState> _settledInventory() {
    final current = _projectInventory.state;
    if (current is! ProjectListLoading) return Future.value(current);
    final settled = Completer<ProjectListState>();
    _projectInventory.stateStream.where((state) => state is! ProjectListLoading).take(1).listen(settled.complete);
    return settled.future;
  }

  /// The mode's root sessions of [projects], read one project at a time. A
  /// project that fails is logged and left out; the next reload retries it.
  Future<({List<Session> sessions, bool succeeded})> _listProjectSessions({
    required List<ProjectSummary> projects,
    required int unseenTick,
  }) async {
    final responses = await Future.wait(
      projects.map((project) => _projectRepository.listSessions(projectId: project.id)),
    );
    var succeeded = true;
    final sessions = <Session>[];
    for (final (index, response) in responses.indexed) {
      switch (response) {
        case SuccessResponse(:final data):
          final roots = data.items.where((session) => session.parentID == null).toList();
          _seedUnseen(sessions: roots, sinceTick: unseenTick);
          sessions.addAll(roots.where(_inMode));
        case ErrorResponse(:final error):
          loge("Failed to list sessions of project ${projects[index].id}", error);
          succeeded = false;
      }
    }
    return (sessions: sessions, succeeded: succeeded);
  }

  /// Follows the inventory's project set while listing everything: lists the
  /// added projects' sessions and drops the removed projects' rows.
  Future<void> _admitProjects({required ProjectListState inventory}) async {
    final known = _completeProjectIds;
    if (_completeSessions == null || inventory is! ProjectListLoaded) return;
    final ids = {for (final project in inventory.projects) project.id};
    final removed = known.difference(ids);
    final added = inventory.projects.where((project) => !known.contains(project.id)).toList();
    if (removed.isEmpty && added.isEmpty) return;
    _completeProjectIds = ids;
    if (removed.isNotEmpty) {
      if (_completeSessions case final current?) {
        _setComplete(sessions: current.where((session) => !removed.contains(session.projectID)).toList());
      }
    }
    if (added.isEmpty) return;
    final generation = _generation;
    final (:sessions, succeeded: _) = await _listProjectSessions(
      projects: added,
      unseenTick: _sessionUnseenTracker.tick,
    );
    // A full load since then answers for these projects too.
    if (_state.isClosed || generation != _generation) return;
    if (_completeSessions case final current?) {
      // Rows that live events already brought are newer than this read.
      // A project the inventory dropped meanwhile stays out.
      final listed = {for (final session in current) session.id};
      final admitted = sessions.where(
        (session) => !listed.contains(session.id) && _completeProjectIds.contains(session.projectID),
      );
      _setComplete(
        sessions: [...current, ...admitted]..sort((a, b) => _compare(a: a, b: b)),
      );
    }
  }

  void _setComplete({required List<Session> sessions}) {
    final complete = List<Session>.unmodifiable(sessions);
    _completeSessions = complete;
    _emitComplete(sessions: complete);
  }

  void _emitComplete({required List<Session> sessions}) {
    // A typed query still waiting narrows the latest sessions once it fires.
    if (_queryTimer?.isActive ?? false) return;
    final projects = _projectsById();
    final counted = sessions.where((session) => _matchesSearch(session: session, projects: projects)).toList();
    _emit(
      SessionWindowLoaded(
        sessions: List.unmodifiable(counted.where((session) => _matchesFilter(session: session))),
        counts: SessionPageCounts(
          all: counted.length,
          running: counted.where(_isRunning).length,
          unread: counted.where(_isUnseen).length,
        ),
        nextCursor: null,
        // No page follows, so a failed one marks a project read that failed;
        // reload retries it.
        loadMore: _rowsOutdated ? SessionWindowLoadMore.failed : SessionWindowLoadMore.idle,
        awaitingAnswer: false,
      ),
    );
  }

  void _onConnectionStatus(ConnectionStatus status) {
    if (_state.isClosed) return;
    final changed = _targetChange.changed(status: status);
    if (changed) {
      // Another computer: nothing listed applies, and it may serve pages even
      // if the previous one did not.
      _generation++;
      _replay = null;
      _completeSessions = null;
      _rowsOutdated = false;
      _cancelTimers();
      _emit(const SessionWindowLoading());
    }
    final connected = status is ConnectionConnected;
    final reconnected = connected && !_connected;
    final lost = !connected && _connected;
    _connected = connected;
    // A load sent before the bridge left may never answer, so it fails at
    // once: a page's row offers Retry and the reconnect asks for it again,
    // and rows being replaced are reloaded on reconnect.
    if (_state.value case final SessionWindowLoaded loaded when lost && _replay != null) {
      final pageOnItsWay = _pageGeneration == _generation;
      _generation++;
      _cancelTimers();
      if (pageOnItsWay) {
        _replay = null;
        _emit(_withLoadMore(loaded: loaded, loadMore: SessionWindowLoadMore.failed));
      } else {
        _fail(reason: RemoteFailureReason.networkDown);
      }
    }
    if (!connected || !(changed || reconnected)) return;
    // A plain reconnect relies on the replayed events, unless a load failed
    // meanwhile, nothing loaded yet, or the bridge listed everything: it may
    // serve pages since. A page that failed is asked again.
    if (_completeSessions == null) {
      if (_state.value case final SessionWindowLoaded loaded) {
        if (_rowsOutdated) {
          unawaited(reload());
        } else if (loaded.loadMore == SessionWindowLoadMore.failed) {
          unawaited(loadMore());
        }
        return;
      }
    }
    _completeSessions = null;
    unawaited(_loadPaged(limit: pageSize));
  }

  void _onEvent(SseEvent event) {
    if (_state.isClosed) return;
    final data = event.data;
    if (data is SesoriSessionUnseenChanged) {
      if (_completeSessions == null) _onLiveStateChanged();
      return;
    }
    final _SessionChange change;
    if (data case SesoriSessionCreated(:final info) || SesoriSessionUpdated(:final info)) {
      change = (session: info, removed: false);
    } else if (data case SesoriSessionDeleted(:final info)) {
      change = (session: info, removed: true);
    } else {
      return;
    }
    if (change.session.parentID != null) return;
    _replay?.add(change);
    _applyChange(change);
    _scheduleCounts();
  }

  void _applyChange(_SessionChange change) {
    final session = change.session;
    if (_completeSessions case final sessions?) {
      final complete = _upsert(
        sessions: sessions,
        session: session,
        keep: !change.removed && _inMode(session),
        inRange: true,
      );
      _completeSessions = complete;
      _emitComplete(sessions: complete);
      return;
    }
    final loaded = _state.value;
    if (loaded is! SessionWindowLoaded) return;
    final sessions = _upsert(
      sessions: loaded.sessions,
      session: session,
      keep: !change.removed && _matches(session: session, projects: _projectsById()),
      inRange: loaded.nextCursor == null,
    );
    if (identical(sessions, loaded.sessions)) return;
    _emit(
      SessionWindowLoaded(
        sessions: sessions,
        counts: loaded.counts,
        nextCursor: loaded.nextCursor,
        loadMore: loaded.loadMore,
        awaitingAnswer: loaded.awaitingAnswer,
      ),
    );
  }

  /// A prompt the bridge reports only as user activity still makes its session
  /// the newest, as the bridge folds that activity into a session's update
  /// time. Only loaded rows move; a page brings the others already folded.
  void _applyUserActivity({required Map<String, Map<String, SessionListItemState>> unseen}) {
    final loaded =
        _completeSessions ??
        switch (_state.value) {
          SessionWindowLoaded(:final sessions) => sessions,
          SessionWindowLoading() || SessionWindowFailed() => const <Session>[],
        };
    for (final session in loaded) {
      final activityAt = unseen[session.projectID]?[session.id]?.lastUserActivityAt;
      final time = session.time;
      if (activityAt == null || time == null || activityAt <= time.updated) continue;
      final _SessionChange change = (
        session: session.copyWith(time: time.copyWith(updated: activityAt), lastUserActivityAt: activityAt),
        removed: false,
      );
      _replay?.add(change);
      _applyChange(change);
    }
  }

  /// [sessions] without [session], then with it in order when [keep] and it
  /// sorts no later than the last loaded row, or anywhere when [inRange]. The
  /// same list when nothing changes.
  List<Session> _upsert({
    required List<Session> sessions,
    required Session session,
    required bool keep,
    required bool inRange,
  }) {
    final existing = sessions.firstWhereOrNull((row) => row.id == session.id);
    final others = existing == null ? sessions : sessions.where((row) => row.id != session.id).toList();
    // The last loaded row itself bounds the range, so it stays when its key
    // does not move.
    final last = sessions.lastOrNull;
    if (!keep || !(inRange || (last != null && _compare(a: session, b: last) <= 0))) {
      return existing == null ? sessions : List.unmodifiable(others);
    }
    final merged = existing == null
        ? session
        : session.copyWith(
            lastUserActivityAt: latestUserActivityAt(
              first: existing.lastUserActivityAt,
              second: session.lastUserActivityAt,
            ),
          );
    final at = others.indexWhere((row) => _compare(a: merged, b: row) < 0);
    return List.unmodifiable([...others]..insert(at < 0 ? others.length : at, merged));
  }

  /// Running and unread change without a session event: a chip on either
  /// asks again for its rows, and every chip's counts follow.
  void _onLiveStateChanged() {
    if (_state.isClosed) return;
    if (_completeSessions case final sessions?) {
      _emitComplete(sessions: sessions);
      return;
    }
    if (_key.filter != SessionListQuickFilter.all && _state.value is SessionWindowLoaded) {
      _reloadTimer?.cancel();
      _reloadTimer = Timer(liveRefreshDelay, () => unawaited(reload()));
    }
    _scheduleCounts();
  }

  void _scheduleCounts() {
    if (_completeSessions != null || _state.value is! SessionWindowLoaded) return;
    _countsTimer?.cancel();
    _countsTimer = Timer(liveRefreshDelay, () => unawaited(_refreshCounts()));
  }

  Future<void> _refreshCounts() async {
    final generation = _generation;
    final result = await _sessionRepository.getSessionPage(request: _request(cursor: null, limit: 0));
    if (_state.isClosed || generation != _generation) return;
    switch (result) {
      case SessionPageLoaded(:final page):
        if (_state.value case final SessionWindowLoaded loaded) {
          _emit(
            SessionWindowLoaded(
              sessions: loaded.sessions,
              counts: page.counts,
              nextCursor: loaded.nextCursor,
              loadMore: loaded.loadMore,
              awaitingAnswer: loaded.awaitingAnswer,
            ),
          );
        }
      case SessionPageUnsupported():
        unawaited(_loadComplete());
      case SessionPageFailure(:final error):
        // The counts stay as they were until the next change or load.
        loge("Failed to refresh the session counts", error);
    }
  }

  bool _matches({required Session session, required Map<String, ProjectSummary> projects}) =>
      _inMode(session) && _matchesSearch(session: session, projects: projects) && _matchesFilter(session: session);

  /// The key's project and query: each word must occur in the title or in
  /// the project's own name, as the bridge matches it.
  bool _matchesSearch({required Session session, required Map<String, ProjectSummary> projects}) {
    if (_key.projectId case final projectId? when session.projectID != projectId) return false;
    final query = _key.query;
    if (query == null) return true;
    return _matchesQuery(session: session, query: query, projects: projects);
  }

  bool _matchesQuery({
    required Session session,
    required String query,
    required Map<String, ProjectSummary> projects,
  }) => matchTexts(
    items: [session],
    textsOf: (session) => [
      session.title,
      if (projects[session.projectID] case final project?) projectOwnName(project: project),
    ],
    query: query,
  ).isNotEmpty;

  bool _matchesFilter({required Session session}) => switch (_key.filter) {
    SessionListQuickFilter.all => true,
    SessionListQuickFilter.running => _isRunning(session),
    SessionListQuickFilter.unread => _isUnseen(session),
  };

  bool _inMode(Session session) => switch (_mode) {
    AllSessionsMode.active => session.time?.archived == null,
    AllSessionsMode.archived => session.time?.archived != null,
  };

  bool _isRunning(Session session) =>
      _sseEventTracker.currentSessionActivity[session.projectID]?[session.id]?.isRunning ?? false;

  bool _isUnseen(Session session) =>
      _sessionUnseenTracker.currentSessionUnseen[session.projectID]?[session.id]?.unseen ?? session.unseen;

  /// The bridge's order: newest first (archived: most recently archived
  /// first), then by id descending.
  int _compare({required Session a, required Session b}) {
    final order = switch (_mode) {
      AllSessionsMode.active => (b.time?.updated ?? 0).compareTo(a.time?.updated ?? 0),
      AllSessionsMode.archived => (b.time?.archived ?? 0).compareTo(a.time?.archived ?? 0),
    };
    return order != 0 ? order : b.id.compareTo(a.id);
  }

  List<Session> _searchLocally({required List<Session> sessions, required String query, required int limit}) {
    final projects = _projectsById();
    return sessions
        .where((session) => _matchesQuery(session: session, query: query, projects: projects))
        .take(limit)
        .toList();
  }

  Map<String, ProjectSummary> _projectsById() => switch (_projectInventory.state) {
    ProjectListLoaded(:final projects) => {for (final project in projects) project.id: project},
    ProjectListLoading() || ProjectListFailed() || ProjectListBridgeDisconnected() => const {},
  };

  SessionPageRequest _request({required String? cursor, required int limit}) => SessionPageRequest(
    mode: _pageMode,
    projectId: _key.projectId,
    query: _key.query,
    filter: switch (_key.filter) {
      SessionListQuickFilter.all => SessionPageFilter.all,
      SessionListQuickFilter.running => SessionPageFilter.running,
      SessionListQuickFilter.unread => SessionPageFilter.unread,
    },
    cursor: cursor,
    limit: limit,
  );

  SessionPageMode get _pageMode => switch (_mode) {
    AllSessionsMode.active => SessionPageMode.active,
    AllSessionsMode.archived => SessionPageMode.archived,
  };

  /// Each page merges into the tracker, which keeps the projects' other
  /// sessions it already holds.
  void _seedUnseen({required List<Session> sessions, required int sinceTick}) {
    final byProject = groupBy(sessions, (Session session) => session.projectID);
    for (final MapEntry(key: projectId, value: projectSessions) in byProject.entries) {
      _sessionUnseenTracker.seedSessions(
        projectId: projectId,
        stateBySessionId: <String, SessionListItemState>{
          for (final session in projectSessions)
            session.id: (unseen: session.unseen, lastUserActivityAt: session.lastUserActivityAt),
        },
        sinceTick: sinceTick,
      );
    }
  }

  List<_SessionChange> _takeReplay() {
    final replay = _replay ?? const <_SessionChange>[];
    _replay = null;
    return replay;
  }

  /// Keeps the rows already shown; only a window with none shows the failure.
  void _fail({required RemoteFailureReason reason}) {
    _replay = null;
    switch (_state.value) {
      // A key narrowed to no rows has nothing to show but the failure.
      case SessionWindowLoaded(awaitingAnswer: true, sessions: []):
        _emit(SessionWindowFailed(reason: reason));
      // Nothing more is coming for rows narrowed from the previous key, and a
      // page request the failed load superseded never answers: its row offers
      // Retry rather than asking again by itself.
      case final SessionWindowLoaded loaded
          when loaded.awaitingAnswer || loaded.loadMore == SessionWindowLoadMore.loading:
        _rowsOutdated = true;
        _emit(
          SessionWindowLoaded(
            sessions: loaded.sessions,
            counts: loaded.counts,
            nextCursor: loaded.nextCursor,
            loadMore: loaded.loadMore == SessionWindowLoadMore.loading
                ? SessionWindowLoadMore.failed
                : loaded.loadMore,
            awaitingAnswer: false,
          ),
        );
      case SessionWindowLoaded():
        _rowsOutdated = true;
      case SessionWindowLoading() || SessionWindowFailed():
        _emit(SessionWindowFailed(reason: reason));
    }
  }

  SessionWindowLoaded _withLoadMore({required SessionWindowLoaded loaded, required SessionWindowLoadMore loadMore}) =>
      SessionWindowLoaded(
        sessions: loaded.sessions,
        counts: loaded.counts,
        nextCursor: loaded.nextCursor,
        loadMore: loadMore,
        awaitingAnswer: loaded.awaitingAnswer,
      );

  void _cancelTimers() {
    _queryTimer?.cancel();
    _reloadTimer?.cancel();
    _countsTimer?.cancel();
  }

  void _emit(SessionWindowState state) {
    if (!_state.isClosed) _state.add(state);
  }

  Future<void> dispose() async {
    _cancelTimers();
    await _subscriptions.dispose();
    await _state.close();
  }
}

/// A live session event: the session as it now reads, or its removal.
typedef _SessionChange = ({Session session, bool removed});
