import "dart:math" as math;

import "package:flutter/material.dart";
import "package:get_it/get_it.dart";
import "package:go_router/go_router.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/constants.dart";
import "../../core/extensions/build_context_x.dart";

/// Shows the Add Project modal bottom sheet.
///
/// The [cubit] is passed explicitly so the dialog can call
/// `createProject` / `discoverProject` without relying on the
/// widget tree's BlocProvider (which lives in the parent screen).
// ignore: no_slop_linter/prefer_required_named_parameters, shared helper signature used by tests
Future<void> showAddProjectDialog(BuildContext context, ProjectListCubit cubit) {
  return showPregoBottomSheet<void>(
    context: context,
    title: context.loc.addProject,
    // Full-bleed body; the banner, browser tiles, and actions pad themselves.
    contentPadding: EdgeInsetsDirectional.zero,
    builder: (_) => AddProjectDialog(cubit: cubit),
  );
}

/// Single-view dialog with a directory browser and two actions:
/// - **Open as Project** — discovers the currently browsed directory
/// - **Create New Project** — creates `{currentDir}/{name}` from a name input
@visibleForTesting
class AddProjectDialog extends StatefulWidget {
  final ProjectListCubit cubit;

  const AddProjectDialog({required this.cubit, super.key});

  @override
  State<AddProjectDialog> createState() => _AddProjectDialogState();
}

class _AddProjectDialogState extends State<AddProjectDialog> {
  final TextEditingController _nameController = TextEditingController();
  final GlobalKey<_DirectoryBrowserState> _browserKey = GlobalKey<_DirectoryBrowserState>();
  String _browsingPath = "";
  bool _actionLoading = false;

  void _dismissDialog() {
    context.pop();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _onOpen() async {
    if (_browsingPath.isEmpty) return;
    setState(() => _actionLoading = true);

    final outcome = await widget.cubit.discoverProject(path: _browsingPath);

    if (!mounted) return;
    setState(() => _actionLoading = false);

    final loc = context.loc;
    switch (outcome) {
      case AddProjectOutcome.success:
        _dismissDialog();
        _showSnackBar(loc.projectDiscovered);
      case AddProjectOutcome.permissionDenied:
        _showSnackBar(loc.addProjectPermissionDenied);
      case AddProjectOutcome.otherError:
        _showSnackBar(loc.projectDiscoverFailed);
    }
  }

  Future<void> _onCreate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _browsingPath.isEmpty) return;

    final fullPath = "$_browsingPath/$name";
    setState(() => _actionLoading = true);

    final outcome = await widget.cubit.createProject(path: fullPath);

    if (!mounted) return;
    setState(() => _actionLoading = false);

    final loc = context.loc;
    switch (outcome) {
      case AddProjectOutcome.success:
        _dismissDialog();
        _showSnackBar(loc.projectCreated);
      case AddProjectOutcome.permissionDenied:
        _showSnackBar(loc.addProjectPermissionDenied);
      case AddProjectOutcome.otherError:
        _showSnackBar(loc.projectCreateFailed);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: kSnackBarDuration),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final screenHeight = MediaQuery.heightOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    // The body hosts its own scroll view (the directory browser), so it needs
    // a bounded height. Shrink above the keyboard (the sheet re-adds the
    // keyboard inset below the body) so the name field stays visible while
    // typing.
    final height = math.max(screenHeight * 0.7 - keyboard, screenHeight * 0.3);

    // Transparent Material so the browser tiles' ink paints on top of the
    // sheet surface instead of behind it on the modal's transparent Material.
    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            const _FilesystemAccessBanner(),
            Expanded(
              child: _DirectoryBrowser(
                key: _browserKey,
                cubit: widget.cubit,
                onPathChanged: (path) => setState(() => _browsingPath = path),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton(
                    onPressed: _actionLoading || _browsingPath.isEmpty ? null : _onOpen,
                    child: _actionLoading
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const _CompactSpinner(),
                              const SizedBox(width: 8),
                              Text(loc.discoveringProject),
                            ],
                          )
                        : Text(loc.openAsProject),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              hintText: loc.projectNameHint,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: _actionLoading || _nameController.text.trim().isEmpty || _browsingPath.isEmpty
                              ? null
                              : _onCreate,
                          child: _actionLoading
                              ? const _CompactSpinner(color: Colors.white)
                              : Text(loc.createProjectButton),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Directory Browser
// ---------------------------------------------------------------------------

class _DirectoryBrowser extends StatefulWidget {
  final ProjectListCubit cubit;
  final ValueChanged<String>? onPathChanged;

  const _DirectoryBrowser({required this.cubit, this.onPathChanged, super.key});

  @override
  State<_DirectoryBrowser> createState() => _DirectoryBrowserState();
}

class _DirectoryBrowserState extends State<_DirectoryBrowser> {
  String _currentPath = "";
  List<FilesystemSuggestion> _entries = [];
  bool _loading = false;
  bool _hasError = false;
  bool _permissionDenied = false;

  String get currentPath => _currentPath;

  @override
  void initState() {
    super.initState();
    _fetchEntries();
  }

  Future<void> _fetchEntries() async {
    setState(() {
      _loading = true;
      _hasError = false;
      _permissionDenied = false;
    });

    final outcome = await widget.cubit.fetchFilesystemSuggestions(
      prefix: _currentPath.isEmpty ? null : _currentPath,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      switch (outcome) {
        case FilesystemSuggestionsSuccess(:final suggestions):
          _entries = suggestions.data;
          _hasError = false;
          _permissionDenied = false;
        case FilesystemSuggestionsPermissionDenied():
          _entries = [];
          _hasError = true;
          _permissionDenied = true;
        case FilesystemSuggestionsError():
          _entries = [];
          _hasError = true;
          _permissionDenied = false;
      }
    });
  }

  void _navigateInto({required String path}) {
    setState(() => _currentPath = path);
    widget.onPathChanged?.call(path);
    _fetchEntries();
  }

  void _navigateUp() {
    if (_currentPath.isEmpty) return;
    final lastSlash = _currentPath.lastIndexOf("/");
    final parent = lastSlash > 0 ? _currentPath.substring(0, lastSlash) : "/";
    setState(() => _currentPath = parent);
    widget.onPathChanged?.call(parent);
    _fetchEntries();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Breadcrumb header with back button
        if (_currentPath.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, end: 16, top: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _navigateUp,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _currentPath,
                    style: prego.textTheme.textXs.regular.copyWith(
                      color: prego.colors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        // Directory listing
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _hasError
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _permissionDenied ? Icons.lock_outline : Icons.error_outline,
                          size: 48,
                          color: prego.colors.fgErrorPrimary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _permissionDenied ? loc.fetchDirectoryPermissionDenied : loc.fetchDirectoryFailed,
                          textAlign: TextAlign.center,
                          style: prego.textTheme.textSm.regular.copyWith(
                            color: prego.colors.fgErrorPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _fetchEntries,
                          icon: const Icon(Icons.refresh),
                          label: Text(loc.fetchDirectoryRetry),
                        ),
                        if (_currentPath.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _navigateUp,
                            icon: const Icon(Icons.arrow_back),
                            label: Text(loc.fetchDirectoryGoBack),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : _entries.isEmpty
              ? Center(
                  child: Text(
                    loc.emptyDirectory,
                    style: prego.textTheme.textSm.regular.copyWith(
                      color: prego.colors.textSecondary,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    return _DirectoryTile(
                      entry: entry,
                      onTap: () => _navigateInto(path: entry.path),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _DirectoryTile extends StatelessWidget {
  final FilesystemSuggestion entry;
  final VoidCallback onTap;

  const _DirectoryTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;

    return ListTile(
      leading: Icon(Icons.folder, color: prego.colors.bgBrandSolid),
      title: Row(
        children: [
          Flexible(child: Text(entry.name, overflow: TextOverflow.ellipsis)),
          if (entry.isGitRepo) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: prego.colors.bgSurface1,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                loc.gitRepoBadge,
                style: prego.textTheme.textXs.medium.copyWith(
                  color: prego.colors.textPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// Inline warning shown at the top of the Add Project sheet when the bridge
/// reported degraded host filesystem access (e.g. macOS Full Disk Access not
/// granted to the terminal running the bridge). It is scoped to this sheet —
/// where the user is browsing directories — rather than shown app-wide, since
/// it is only actionable here.
class _FilesystemAccessBanner extends StatelessWidget {
  const _FilesystemAccessBanner();

  @override
  Widget build(BuildContext context) {
    final connectionService = GetIt.instance<ConnectionService>();
    return StreamBuilder<ConnectionStatus>(
      stream: connectionService.status,
      initialData: connectionService.currentStatus,
      builder: (context, snapshot) {
        final status = snapshot.data;
        final degraded = status is ConnectionConnected && (status.health.filesystemAccessDegraded ?? false);
        if (!degraded) return const SizedBox.shrink();

        final loc = context.loc;
        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
          // Purely informational: the connection is healthy, but the bridge's
          // host process lacks permission to read some directories. The user
          // resolves this on their Mac, so there is no in-app action here.
          child: PregoInlineAlertsNotifications(
            type: PregoInlineAlertsNotificationsType.warning,
            title: loc.filesystemAccessDegradedTitle,
            supportingText: loc.filesystemAccessDegradedBody,
            icon: TablerRegular.folder_x,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Shared
// ---------------------------------------------------------------------------

class _CompactSpinner extends StatelessWidget {
  final Color? color;

  const _CompactSpinner({this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: color,
      ),
    );
  }
}
