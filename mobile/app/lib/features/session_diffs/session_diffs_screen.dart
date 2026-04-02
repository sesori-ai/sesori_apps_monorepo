import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../core/di/injection.dart";
import "models/diff_file_view_model.dart";
import "models/diff_list_builder.dart";
import "models/diff_list_item.dart";
import "models/diff_view_model_builder.dart";
import "widgets/diff_file_widget.dart";
import "widgets/diff_hunk_widget.dart";
import "widgets/diff_line_widget.dart";

class SessionDiffsScreen extends StatelessWidget {
  final String projectId;
  final String sessionId;

  const SessionDiffsScreen({
    super.key,
    required this.projectId,
    required this.sessionId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DiffCubit(
        service: getIt<SessionService>(),
        sessionId: sessionId,
      ),
      child: const _SessionDiffsBody(),
    );
  }
}

class _SessionDiffsBody extends StatefulWidget {
  const _SessionDiffsBody();

  @override
  State<_SessionDiffsBody> createState() => _SessionDiffsBodyState();
}

class _SessionDiffsBodyState extends State<_SessionDiffsBody> {
  List<DiffFileViewModel>? _viewModels;
  Set<int> _expandedFileIndices = <int>{};
  List<DiffListItem> _flatItems = const [];
  bool _isComputing = false;
  Object? _computeError;
  List<FileDiff>? _lastFiles;
  int _computeToken = 0;
  Brightness? _lastBrightness;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: BlocBuilder<DiffCubit, DiffState>(
          buildWhen: (prev, curr) => _getStats(prev) != _getStats(curr),
          builder: (context, state) {
            final (fileCount, additions, deletions) = _getStats(state);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("File Changes"),
                if (fileCount > 0)
                  Text(
                    "$fileCount file${fileCount == 1 ? '' : 's'} changed  +$additions -$deletions",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            );
          },
        ),
      ),
      body: BlocBuilder<DiffCubit, DiffState>(
        buildWhen: (prev, curr) =>
            prev.runtimeType != curr.runtimeType ||
            (prev is DiffStateLoaded && curr is DiffStateLoaded && !identical(prev.files, curr.files)),
        builder: (context, state) => switch (state) {
          DiffStateLoading() => const Center(child: CircularProgressIndicator()),
          DiffStateFailed(:final error) => _buildErrorState(context, error),
          DiffStateLoaded(:final files) when files.isEmpty => const Center(
            child: Text("No file changes in this session"),
          ),
          DiffStateLoaded(:final files) => _buildLoadedState(context, files),
        },
      ),
    );
  }

  static (int, int, int) _getStats(DiffState state) {
    if (state is! DiffStateLoaded) return (0, 0, 0);
    var adds = 0;
    var dels = 0;
    for (final f in state.files) {
      if (f is FileDiffContent) {
        adds += f.additions;
        dels += f.deletions;
      }
    }
    return (state.files.length, adds, dels);
  }

  Widget _buildLoadedState(BuildContext context, List<FileDiff> files) {
    _maybeComputeViewModels(files: files);
    if (_isComputing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_computeError != null) {
      return Center(child: Text("Error computing diffs: $_computeError"));
    }

    return ListView.builder(
      itemCount: _flatItems.length,
      itemBuilder: (context, index) {
        final item = _flatItems[index];
        return switch (item) {
          DiffListFileHeader() => DiffFileWidget(
            viewModel: item.viewModel,
            isExpanded: item.isExpanded,
            onToggle: () => _toggleFile(item.fileIndex),
          ),
          DiffListHunkHeader() => DiffHunkWidget(viewModel: item.viewModel),
          DiffListLine() => DiffLineWidget(viewModel: item.viewModel),
          DiffListSkipPlaceholder() => _buildSkippedPlaceholder(item.reason),
        };
      },
    );
  }

  void _maybeComputeViewModels({required List<FileDiff> files}) {
    final brightness = Theme.of(context).brightness;
    if (identical(files, _lastFiles) && brightness == _lastBrightness) {
      return;
    }
    _lastFiles = files;
    _lastBrightness = brightness;

    // Defer computation to avoid setState() during build.
    Future.microtask(() {
      if (mounted) _computeViewModels(files: files);
    });
  }

  Future<void> _computeViewModels({required List<FileDiff> files}) async {
    final token = ++_computeToken;
    setState(() {
      _isComputing = true;
      _computeError = null;
      _viewModels = null;
      _expandedFileIndices = <int>{};
      _flatItems = const [];
    });

    try {
      final viewModels = await DiffViewModelBuilder.build(
        files,
        brightness: Theme.of(context).brightness,
      );
      if (!mounted || token != _computeToken) {
        return;
      }
      final expanded = <int>{};
      for (var i = 0; i < viewModels.length; i++) {
        if (viewModels[i].isExpanded) {
          expanded.add(i);
        }
      }

      final flatItems = buildFlatList(
        viewModels: viewModels,
        expandedFileIndices: expanded,
      );

      setState(() {
        _viewModels = viewModels;
        _expandedFileIndices = expanded;
        _flatItems = flatItems;
        _isComputing = false;
      });
    } catch (error) {
      if (!mounted || token != _computeToken) {
        return;
      }
      setState(() {
        _computeError = error;
        _isComputing = false;
      });
    }
  }

  void _toggleFile(int fileIndex) {
    final viewModels = _viewModels;
    if (viewModels == null) {
      return;
    }
    final expanded = Set<int>.from(_expandedFileIndices);
    if (expanded.contains(fileIndex)) {
      expanded.remove(fileIndex);
    } else {
      expanded.add(fileIndex);
    }

    setState(() {
      _expandedFileIndices = expanded;
      _flatItems = buildFlatList(
        viewModels: viewModels,
        expandedFileIndices: expanded,
      );
    });
  }

  Widget _buildSkippedPlaceholder(FileDiffSkipReason reason) {
    final message = switch (reason) {
      FileDiffSkipReason.binary => "Binary file changed",
      FileDiffSkipReason.tooLarge => "File diff too large to display",
      FileDiffSkipReason.readError => "Could not read file",
    };
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        message,
        style: const TextStyle(
          color: Colors.grey,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("Error: $error"),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.read<DiffCubit>().refresh(),
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }
}
