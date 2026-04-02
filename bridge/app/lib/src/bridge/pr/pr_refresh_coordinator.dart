import "dart:async";

import "package:sesori_shared/sesori_shared.dart";

import "../worktree_service.dart";
import "gh_cli_service.dart";
import "pr_sync_service.dart";
import "remote_detection.dart";

class PrRefreshCoordinator {
  final GhCliService _ghCli;
  final PrSyncService _prSyncService;
  final ProcessRunner _processRunner;
  final void Function(SesoriSseEvent) _emitBridgeEvent;

  bool? _ghAvailable;
  bool? _ghAuthenticated;
  final Map<String, bool> _hasGitHubRemoteCache = <String, bool>{};

  PrRefreshCoordinator({
    required GhCliService ghCli,
    required PrSyncService prSyncService,
    required ProcessRunner processRunner,
    required void Function(SesoriSseEvent) emitBridgeEvent,
  }) : _ghCli = ghCli,
       _prSyncService = prSyncService,
       _processRunner = processRunner,
       _emitBridgeEvent = emitBridgeEvent;

  Future<void> onSessionListRequested({
    required String projectId,
    required String projectPath,
  }) async {
    final ghAvailable = await _getGhAvailable();
    final ghAuthenticated = await _getGhAuthenticated();
    if (!ghAvailable || !ghAuthenticated) {
      return;
    }

    final hasRemote = await _hasGitHubRemote(projectPath: projectPath);
    if (!hasRemote) {
      return;
    }

    _prSyncService.triggerRefreshForProject(projectId: projectId, projectPath: projectPath);
  }

  void onPrDataChanged({required String projectId}) {
    _emitBridgeEvent(SesoriSseEvent.sessionsUpdated(projectID: projectId));
  }

  Future<bool> _getGhAvailable() async {
    final cached = _ghAvailable;
    if (cached != null) {
      return cached;
    }
    final result = await _ghCli.isAvailable();
    _ghAvailable = result;
    return result;
  }

  Future<bool> _getGhAuthenticated() async {
    final cached = _ghAuthenticated;
    if (cached != null) {
      return cached;
    }
    final result = await _ghCli.isAuthenticated();
    _ghAuthenticated = result;
    return result;
  }

  Future<bool> _hasGitHubRemote({required String projectPath}) async {
    final cached = _hasGitHubRemoteCache[projectPath];
    if (cached != null) {
      return cached;
    }

    final result = await hasGitHubRemote(
      processRunner: _processRunner,
      projectPath: projectPath,
    );
    _hasGitHubRemoteCache[projectPath] = result;
    return result;
  }
}
