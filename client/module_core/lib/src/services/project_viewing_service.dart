import "dart:async";

import "package:get_it/get_it.dart";
import "package:injectable/injectable.dart";
import "package:meta/meta.dart";
import "package:rxdart/rxdart.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/models/connection_status.dart";
import "../logging/logging.dart";
import "../platform/lifecycle_source.dart";
import "../platform/route_source.dart";
import "../repositories/project_view_repository.dart";
import "../routing/app_routes.dart";

/// Opaque generation owner for one list or detail project claim.
///
/// The service compares claims by identity, so cleanup from an older cubit
/// cannot erase the claim installed by its replacement.
class ProjectViewClaim();

/// Opaque generation owner for one adaptive shell's wide list pane.
///
/// The service compares pane claims by identity so a replaced shell cannot
/// clear the presence reported by its replacement when Flutter disposes them
/// out of order.
class ProjectViewPaneClaim();

/// Layer-3 owner of this client's single effective viewed project.
///
/// List and detail cubits contribute pending/ready claims. Route and adaptive
/// pane visibility decide which ready claim is actually visible. The resulting
/// declaration is serialized, cleared while the app is hidden, and reasserted
/// after resume or relay reconnect. A desktop window that loses focus or is
/// occluded reports [LifecycleState.inactive], so it keeps its declaration. This is intentionally independent from
/// session-view declarations, whose mark-seen side effect has different rules.
@lazySingleton
class ProjectViewingService({
  required final ProjectViewRepository _viewRepository,
  required LifecycleSource lifecycleSource,
  required ConnectionService connectionService,
  required RouteSource routeSource,
}) with Disposable {
  final CompositeSubscription _subscriptions = CompositeSubscription();

  _ProjectViewClaimState? _listClaim;
  _ProjectViewClaimState? _detailClaim;
  AppRouteDef? _route = routeSource.currentRoute;
  String? _detailTransitionProjectId;
  ProjectViewPaneClaim? _latestWideListPaneClaim;
  ProjectViewPaneClaim? _visibleWideListPaneClaim;
  bool _backgrounded = _isBackgroundState(state: lifecycleSource.lifecycleState);
  bool _wasConnected = connectionService.currentStatus is ConnectionConnected;
  bool _disposed = false;

  String? _declaredProjectId;
  String? _lastSentProjectId;
  bool _hasSent = false;
  bool _forceNextSend = false;
  Future<void> _sendTail = Future<void>.value();
  Future<void>? _disposeFuture;

  this {
    _subscriptions
      ..add(
        routeSource.currentRouteStream.distinct().listen(
          (route) => _onRouteChanged(route: route),
          onError: (Object error, StackTrace stackTrace) {
            logw("project view route tracking failed", error, stackTrace);
          },
        ),
      )
      ..add(
        lifecycleSource.lifecycleStateStream.listen(
          (state) => _onLifecycleChanged(state: state),
          onError: (Object error, StackTrace stackTrace) {
            logw("project view lifecycle tracking failed", error, stackTrace);
          },
        ),
      )
      ..add(
        connectionService.status.listen(
          (status) => _onConnectionStatusChanged(status: status),
          onError: (Object error, StackTrace stackTrace) {
            logw("project view connection tracking failed", error, stackTrace);
          },
        ),
      );
  }

  ProjectViewClaim beginListClaim({required String projectId}) {
    _checkUsable();
    _validateProjectId(projectId: projectId);
    final claim = ProjectViewClaim();
    _listClaim = _ProjectViewClaimPending(claim: claim, projectId: projectId);
    _recomputeDeclaration();
    return claim;
  }

  ProjectViewClaim beginDetailClaim({required String projectId}) {
    _checkUsable();
    _validateProjectId(projectId: projectId);
    final previousVisibleProjectId = _resolveVisibleProjectId();
    _detailTransitionProjectId = previousVisibleProjectId == projectId ? projectId : null;
    final claim = ProjectViewClaim();
    _detailClaim = _ProjectViewClaimPending(claim: claim, projectId: projectId);
    _recomputeDeclaration();
    return claim;
  }

  void markClaimReady({required ProjectViewClaim claim, required String projectId}) {
    if (_disposed) return;
    _validateProjectId(projectId: projectId);
    final listClaim = _listClaim;
    if (listClaim != null && identical(listClaim.claim, claim)) {
      _listClaim = _ProjectViewClaimReady(claim: claim, projectId: projectId);
      _recomputeDeclaration();
      return;
    }

    final detailClaim = _detailClaim;
    if (detailClaim != null && identical(detailClaim.claim, claim)) {
      _detailClaim = _ProjectViewClaimReady(claim: claim, projectId: projectId);
      _detailTransitionProjectId = null;
      _recomputeDeclaration();
    }
  }

  void markClaimFailed({required ProjectViewClaim claim}) {
    if (_disposed) return;
    final listClaim = _listClaim;
    if (listClaim != null && identical(listClaim.claim, claim)) {
      _listClaim = _ProjectViewClaimFailed(claim: claim, projectId: listClaim.projectId);
      _recomputeDeclaration();
      return;
    }

    final detailClaim = _detailClaim;
    if (detailClaim != null && identical(detailClaim.claim, claim)) {
      _detailClaim = _ProjectViewClaimFailed(claim: claim, projectId: detailClaim.projectId);
      _detailTransitionProjectId = null;
      _recomputeDeclaration();
    }
  }

  void releaseClaim({required ProjectViewClaim claim}) {
    if (_disposed) return;
    final listClaim = _listClaim;
    if (listClaim != null && identical(listClaim.claim, claim)) {
      _listClaim = null;
      _recomputeDeclaration();
      return;
    }

    final detailClaim = _detailClaim;
    if (detailClaim != null && identical(detailClaim.claim, claim)) {
      _detailClaim = null;
      _detailTransitionProjectId = null;
      _recomputeDeclaration();
    }
  }

  ProjectViewPaneClaim beginWideListPaneClaim() {
    _checkUsable();
    final claim = ProjectViewPaneClaim();
    _latestWideListPaneClaim = claim;
    return claim;
  }

  /// Reports whether one adaptive shell is actually mounting its list pane.
  void setWideListPaneVisible({required ProjectViewPaneClaim claim, required bool isVisible}) {
    if (_disposed) return;
    if (isVisible) {
      if (!identical(_latestWideListPaneClaim, claim)) return;
      if (identical(_visibleWideListPaneClaim, claim)) return;
      _visibleWideListPaneClaim = claim;
    } else {
      if (!identical(_visibleWideListPaneClaim, claim)) return;
      _visibleWideListPaneClaim = null;
    }
    _recomputeDeclaration();
  }

  void releaseWideListPaneClaim({required ProjectViewPaneClaim claim}) {
    if (_disposed) return;
    if (identical(_latestWideListPaneClaim, claim)) {
      _latestWideListPaneClaim = null;
    }
    if (!identical(_visibleWideListPaneClaim, claim)) return;
    _visibleWideListPaneClaim = null;
    _recomputeDeclaration();
  }

  @visibleForTesting
  Future<void> get sendTail => _sendTail;

  @visibleForTesting
  String? get declaredProjectId => _declaredProjectId;

  void _onRouteChanged({required AppRouteDef? route}) {
    if (_disposed || _route == route) return;
    final previousVisibleProjectId = _resolveVisibleProjectId();
    final previousRoute = _route;
    _route = route;
    if (route == AppRouteDef.sessionDetail && previousRoute != AppRouteDef.sessionDetail) {
      _detailTransitionProjectId = previousVisibleProjectId;
    } else if (route != AppRouteDef.sessionDetail) {
      _detailTransitionProjectId = null;
    }
    _recomputeDeclaration();
  }

  void _onLifecycleChanged({required LifecycleState state}) {
    if (_disposed || state == LifecycleState.inactive) return;
    final backgrounded = _isBackgroundState(state: state);
    if (_backgrounded == backgrounded) return;
    _backgrounded = backgrounded;
    _recomputeDeclaration();
  }

  void _onConnectionStatusChanged({required ConnectionStatus status}) {
    if (_disposed) return;
    final connected = status is ConnectionConnected;
    final reconnected = connected && !_wasConnected;
    _wasConnected = connected;
    if (reconnected && _declaredProjectId != null) {
      _enqueueSend(force: true);
    }
  }

  void _recomputeDeclaration() {
    final nextProjectId = _backgrounded ? null : _resolveVisibleProjectId();
    if (_declaredProjectId == nextProjectId) return;
    _declaredProjectId = nextProjectId;
    _enqueueSend(force: false);
  }

  String? _resolveVisibleProjectId() {
    final wideListPaneVisible = _visibleWideListPaneClaim != null;
    final listProjectId = switch (_listClaim) {
      _ProjectViewClaimReady(:final projectId) => projectId,
      _ProjectViewClaimPending() || _ProjectViewClaimFailed() || null => null,
    };

    return switch (_route) {
      AppRouteDef.sessions => listProjectId,
      AppRouteDef.newSession || AppRouteDef.sessionDiffs => wideListPaneVisible ? listProjectId : null,
      AppRouteDef.sessionDetail => switch (_detailClaim) {
        _ProjectViewClaimReady(:final projectId) => projectId,
        _ProjectViewClaimPending(:final projectId) =>
          _detailTransitionProjectId == projectId ? projectId : (wideListPaneVisible ? listProjectId : null),
        _ProjectViewClaimFailed() => wideListPaneVisible ? listProjectId : null,
        null => _detailTransitionProjectId ?? (wideListPaneVisible ? listProjectId : null),
      },
      AppRouteDef.splash ||
      AppRouteDef.login ||
      AppRouteDef.projects ||
      AppRouteDef.settings ||
      AppRouteDef.settingsNotifications ||
      AppRouteDef.settingsHarnesses ||
      AppRouteDef.settingsProfile ||
      null => null,
    };
  }

  void _enqueueSend({required bool force}) {
    _forceNextSend = _forceNextSend || force;
    _sendTail = _sendTail
        .then((_) async {
          final shouldForce = _forceNextSend;
          _forceNextSend = false;
          final projectId = _declaredProjectId;
          if (!_hasSent && projectId == null && !shouldForce) return;
          if (!shouldForce && _hasSent && projectId == _lastSentProjectId) return;
          await _viewRepository.sendProjectView(projectId: projectId);
          _lastSentProjectId = projectId;
          _hasSent = true;
        })
        .catchError((Object _) {
          logw("project view declaration failed");
        });
    unawaited(_sendTail);
  }

  void _checkUsable() {
    if (_disposed) throw StateError("ProjectViewingService has been disposed");
  }

  static void _validateProjectId({required String projectId}) {
    if (projectId.isEmpty) throw ArgumentError.value(projectId, "projectId", "must not be empty");
  }

  static bool _isBackgroundState({required LifecycleState state}) => switch (state) {
    LifecycleState.detached || LifecycleState.hidden || LifecycleState.paused => true,
    LifecycleState.resumed || LifecycleState.inactive => false,
  };

  @override
  Future<void> onDispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _subscriptions.dispose();
    } on Object catch (_) {
      logw("project view subscription cleanup failed");
    }
    _listClaim = null;
    _detailClaim = null;
    _detailTransitionProjectId = null;
    _route = null;
    _latestWideListPaneClaim = null;
    _visibleWideListPaneClaim = null;
    _backgrounded = false;
    _recomputeDeclaration();
    await _sendTail;
  }
}

sealed class const _ProjectViewClaimState({required final ProjectViewClaim claim, required final String projectId});

final class const _ProjectViewClaimPending({required super.claim, required super.projectId})
    extends _ProjectViewClaimState;

final class const _ProjectViewClaimReady({required super.claim, required super.projectId})
    extends _ProjectViewClaimState;

final class const _ProjectViewClaimFailed({required super.claim, required super.projectId})
    extends _ProjectViewClaimState;
