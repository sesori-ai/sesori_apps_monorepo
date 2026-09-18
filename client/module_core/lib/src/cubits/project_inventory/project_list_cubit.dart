import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../foundation/models/product_analytics/product_analytics_event.dart";
import "../../services/models/add_project_outcome.dart";
import "../../services/models/project_list_state.dart";
import "../../services/project_inventory_service.dart";

/// Presentation adapter; its route/cockpit owns the inventory service lifetime.
class ProjectListCubit({required final ProjectInventoryService _inventoryService}) extends Cubit<ProjectListState> {
  late final StreamSubscription<ProjectListState> _subscription;

  this : super(_inventoryService.state) {
    _subscription = _inventoryService.stateStream.skip(1).listen(emit);
  }

  Future<void> loadProjects() => _inventoryService.loadProjects();
  Future<void> retryLoadProjects() => _inventoryService.retryLoadProjects();
  Future<void> reconnectBridge() => _inventoryService.reconnectBridge();
  Future<bool> refreshProjects() => _inventoryService.refreshProjects();

  Future<bool> hideProject({required String projectId}) => _inventoryService.hideProject(projectId: projectId);

  Future<bool> renameProject({required String projectId, required String name}) =>
      _inventoryService.renameProject(projectId: projectId, name: name);

  Future<AddProjectOutcome> createProject({required String parentPath, required String name}) =>
      _inventoryService.createProject(parentPath: parentPath, name: name);

  Future<CreateDirectoryOutcome> createDirectory({required String parentPath, required String name}) =>
      _inventoryService.createDirectory(parentPath: parentPath, name: name);

  Future<OpenProjectOutcome> discoverProject({required String path, required OpenProjectGitAction gitAction}) =>
      _inventoryService.discoverProject(path: path, gitAction: gitAction);

  Future<FilesystemSuggestionsOutcome> fetchFilesystemSuggestions({required String? prefix}) =>
      _inventoryService.fetchFilesystemSuggestions(prefix: prefix);

  String? parentHostPath({required String path}) => _inventoryService.parentHostPath(path: path);

  void startCatalogScan() => _inventoryService.startCatalogScan();
  void cancelCatalogScan() => _inventoryService.cancelCatalogScan();
  void dismissCatalogScan() => _inventoryService.dismissCatalogScan();

  void reportNeedHelpMenuOpened({required OnboardingSurface surface}) =>
      _inventoryService.reportNeedHelpMenuOpened(surface: surface);

  void reportSupportLinkOpened({required SupportChannel channel, required OnboardingSurface surface}) =>
      _inventoryService.reportSupportLinkOpened(channel: channel, surface: surface);

  void reportWhyBridgeOpened({required OnboardingSurface surface}) =>
      _inventoryService.reportWhyBridgeOpened(surface: surface);

  void reportInstallCommandCopied({
    required BridgeInstallMethod method,
    required BridgeInstallOs os,
    required OnboardingSurface surface,
  }) => _inventoryService.reportInstallCommandCopied(method: method, os: os, surface: surface);

  void reportInstallCommandShared({
    required BridgeInstallMethod method,
    required BridgeInstallOs os,
    required OnboardingSurface surface,
  }) => _inventoryService.reportInstallCommandShared(method: method, os: os, surface: surface);

  void reportRunCommandCopied({required OnboardingSurface surface}) =>
      _inventoryService.reportRunCommandCopied(surface: surface);

  void reportRunCommandShared({required OnboardingSurface surface}) =>
      _inventoryService.reportRunCommandShared(surface: surface);

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
