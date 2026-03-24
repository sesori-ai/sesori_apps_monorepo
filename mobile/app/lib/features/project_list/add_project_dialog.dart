import "dart:async";

import "package:flutter/material.dart";
import "package:get_it/get_it.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../core/extensions/build_context_x.dart";

/// Shows the Add Project modal bottom sheet.
///
/// The [cubit] is passed explicitly so the dialog can call
/// `createProject` / `discoverProject` without relying on the
/// widget tree's BlocProvider (which lives in the parent screen).
Future<void> showAddProjectDialog(BuildContext context, ProjectListCubit cubit) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => AddProjectDialog(cubit: cubit),
  );
}

/// Modal dialog with two tabs: **Create New** and **Discover Existing**.
///
/// Both tabs share the same path-input + filesystem-suggestions UX.
/// The action button at the bottom calls the appropriate cubit method.
@visibleForTesting
class AddProjectDialog extends StatelessWidget {
  final ProjectListCubit cubit;

  const AddProjectDialog({required this.cubit, super.key});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;

    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            // Drag handle
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
            TabBar(
              tabs: [
                Tab(text: loc.createNewProject),
                Tab(text: loc.discoverExistingProject),
              ],
            ),
            SizedBox(
              height: 360,
              child: TabBarView(
                children: [
                  _ProjectTab(
                    cubit: cubit,
                    isCreate: true,
                  ),
                  _ProjectTab(
                    cubit: cubit,
                    isCreate: false,
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

class _ProjectTab extends StatefulWidget {
  final ProjectListCubit cubit;
  final bool isCreate;

  const _ProjectTab({required this.cubit, required this.isCreate});

  @override
  State<_ProjectTab> createState() => _ProjectTabState();
}

class _ProjectTabState extends State<_ProjectTab> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<FilesystemSuggestion> _suggestions = [];
  bool _loading = false;
  bool _actionLoading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    _debounce?.cancel();
    if (text.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _fetchSuggestions(text);
    });
  }

  Future<void> _fetchSuggestions(String prefix) async {
    setState(() => _loading = true);
    final response = await GetIt.instance<ProjectService>().getFilesystemSuggestions(prefix: prefix);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _suggestions = switch (response) {
        SuccessResponse(:final data) => data,
        ErrorResponse() => [],
      };
    });
  }

  Future<void> _onAction() async {
    final path = _controller.text.trim();
    if (path.isEmpty) return;

    setState(() => _actionLoading = true);

    final bool success;
    if (widget.isCreate) {
      success = await widget.cubit.createProject(path: path);
    } else {
      success = await widget.cubit.discoverProject(path: path);
    }

    if (!mounted) return;
    setState(() => _actionLoading = false);

    final loc = context.loc;
    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.isCreate ? loc.projectCreated : loc.projectDiscovered)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.isCreate ? loc.projectCreateFailed : loc.projectDiscoverFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            onChanged: _onTextChanged,
            decoration: InputDecoration(
              hintText: loc.projectPathHint,
              prefixIcon: const Icon(Icons.folder_open),
              border: const OutlineInputBorder(),
              suffixIcon: _loading ? const _CompactSpinner() : null,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _suggestions.isEmpty
                ? const SizedBox.shrink()
                : ListView.builder(
                    itemCount: _suggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = _suggestions[index];
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.folder,
                          color: theme.colorScheme.primary,
                        ),
                        title: Row(
                          children: [
                            Flexible(child: Text(suggestion.name, overflow: TextOverflow.ellipsis)),
                            if (suggestion.isGitRepo) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.commit, size: 16, color: theme.colorScheme.tertiary),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          suggestion.path,
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          _controller.text = suggestion.path;
                          _controller.selection = TextSelection.fromPosition(
                            TextPosition(offset: suggestion.path.length),
                          );
                          setState(() => _suggestions = []);
                          // Trigger a new suggestions fetch from the selected path
                          _onTextChanged(suggestion.path);
                        },
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _actionLoading ? null : _onAction,
            child: _actionLoading
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _CompactSpinner(color: Colors.white),
                      const SizedBox(width: 8),
                      Text(widget.isCreate ? loc.creatingProject : loc.discoveringProject),
                    ],
                  )
                : Text(widget.isCreate ? loc.createProjectButton : loc.discoverProjectButton),
          ),
        ],
      ),
    );
  }
}

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
