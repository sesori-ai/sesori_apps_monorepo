import "package:flutter/material.dart";
import "package:get_it/get_it.dart";
import "package:go_router/go_router.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../core/constants.dart";
import "../../core/extensions/build_context_x.dart";

/// Shows the Add Project modal bottom sheet.
///
/// The [cubit] is passed explicitly so the dialog can call
/// `createProject` / `discoverProject` without relying on the
/// widget tree's BlocProvider (which lives in the parent screen).
// ignore: no_slop_linter/prefer_required_named_parameters, shared helper signature used by tests
Future<void> showAddProjectDialog(BuildContext context, ProjectListCubit cubit) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
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

    final success = await widget.cubit.discoverProject(path: _browsingPath);

    if (!mounted) return;
    setState(() => _actionLoading = false);

    final loc = context.loc;
    if (success) {
      _dismissDialog();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.projectDiscovered),
          duration: kSnackBarDuration,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.projectDiscoverFailed),
          duration: kSnackBarDuration,
        ),
      );
    }
  }

  Future<void> _onCreate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _browsingPath.isEmpty) return;

    final fullPath = "$_browsingPath/$name";
    setState(() => _actionLoading = true);

    final success = await widget.cubit.createProject(path: fullPath);

    if (!mounted) return;
    setState(() => _actionLoading = false);

    final loc = context.loc;
    if (success) {
      _dismissDialog();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.projectCreated),
          duration: kSnackBarDuration,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.projectCreateFailed),
          duration: kSnackBarDuration,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return SizedBox(
      height: screenHeight * 0.7,
      child: Padding(
        padding: EdgeInsetsDirectional.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(loc.addProject, style: Theme.of(context).textTheme.titleMedium),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _DirectoryBrowser(
                key: _browserKey,
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
  final ValueChanged<String>? onPathChanged;

  const _DirectoryBrowser({this.onPathChanged, super.key});

  @override
  State<_DirectoryBrowser> createState() => _DirectoryBrowserState();
}

class _DirectoryBrowserState extends State<_DirectoryBrowser> {
  String _currentPath = "";
  List<FilesystemSuggestion> _entries = [];
  bool _loading = false;
  bool _hasError = false;

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
    });

    final response = await GetIt.instance<ProjectService>().getFilesystemSuggestions(
      prefix: _currentPath.isEmpty ? null : _currentPath,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      switch (response) {
        case SuccessResponse(:final data):
          _entries = data.data;
          _hasError = false;
        case ErrorResponse():
          _entries = [];
          _hasError = true;
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
    final theme = Theme.of(context);

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
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
                  child: Text(
                    loc.fetchDirectoryFailed,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                )
              : _entries.isEmpty
              ? Center(
                  child: Text(
                    loc.emptyDirectory,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
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
    final theme = Theme.of(context);
    final loc = context.loc;

    return ListTile(
      leading: Icon(Icons.folder, color: theme.colorScheme.primary),
      title: Row(
        children: [
          Flexible(child: Text(entry.name, overflow: TextOverflow.ellipsis)),
          if (entry.isGitRepo) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                loc.gitRepoBadge,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
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
