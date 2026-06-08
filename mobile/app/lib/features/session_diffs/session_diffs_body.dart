import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_zyra/module_zyra.dart";

import "../../core/extensions/build_context_x.dart";
import "models/diff_file_view_model.dart";
import "models/diff_view_model_builder.dart";
import "widgets/diff_file_header_delegate.dart";
import "widgets/diff_hunk_widget.dart";
import "widgets/diff_line_widget.dart";
import "widgets/diff_skipped_placeholder.dart";

class SessionDiffsBody extends StatefulWidget {
  const SessionDiffsBody({super.key});

  @override
  State<SessionDiffsBody> createState() => _SessionDiffsBodyState();
}

class _SessionDiffsBodyState extends State<SessionDiffsBody> {
  List<DiffFileViewModel>? _viewModels;
  Set<int> _expandedFileIndices = <int>{};
  bool _isComputing = false;
  Object? _computeError;
  List<FileDiff>? _lastFiles;
  int _computeToken = 0;
  Brightness? _lastBrightness;

  /// Stable [GlobalKey]s attached to each file's header [SizedBox] so the
  /// post-frame scroll adjustment can find the next file's header after a
  /// collapse. Keys are created lazily as files are rendered.
  final Map<int, GlobalKey> _headerKeys = <int, GlobalKey>{};

  bool _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      final state = context.read<DiffCubit>().state;
      if (state is DiffStateLoaded && state.files.isNotEmpty) {
        _maybeComputeViewModels(files: state.files);
      }
    }
  }

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
                Text(context.loc.diffFileChangesTitle),
                if (fileCount > 0)
                  Text(
                    context.loc.diffFilesChangedCount(
                      fileCount,
                      additions,
                      deletions,
                    ),
                    style: context.zyra.textTheme.textXs.regular,
                  ),
              ],
            );
          },
        ),
      ),
      body: BlocListener<DiffCubit, DiffState>(
        listenWhen: (prev, curr) =>
            prev.runtimeType != curr.runtimeType ||
            (prev is DiffStateLoaded && curr is DiffStateLoaded && !identical(prev.files, curr.files)),
        listener: (context, state) {
          if (state is DiffStateLoaded && state.files.isNotEmpty) {
            _maybeComputeViewModels(files: state.files);
          }
        },
        child: BlocBuilder<DiffCubit, DiffState>(
          buildWhen: (prev, curr) =>
              prev.runtimeType != curr.runtimeType ||
              (prev is DiffStateLoaded && curr is DiffStateLoaded && !identical(prev.files, curr.files)),
          builder: (context, state) => switch (state) {
            DiffStateLoading() => const Center(child: CircularProgressIndicator()),
            DiffStateFailed(:final error) => _buildErrorState(context: context, error: error),
            DiffStateLoaded(:final files) when files.isEmpty => Center(
              child: Text(context.loc.diffNoFileChanges),
            ),
            DiffStateLoaded(:final files) => _buildLoadedState(context: context, files: files),
          },
        ),
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

  Widget _buildLoadedState({required BuildContext context, required List<FileDiff> files}) {
    if (_computeError case final computeError?) {
      return _buildErrorState(context: context, error: computeError);
    }

    final viewModels = _viewModels;
    if (_isComputing || viewModels == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return CustomScrollView(slivers: _buildSlivers(viewModels: viewModels));
  }

  List<Widget> _buildSlivers({required List<DiffFileViewModel> viewModels}) {
    return [
      for (var i = 0; i < viewModels.length; i++)
        SliverMainAxisGroup(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: DiffFileHeaderDelegate(
                viewModel: viewModels[i],
                isExpanded: _expandedFileIndices.contains(i),
                onToggle: () => _toggleFile(i),
                headerKey: _headerKeys.putIfAbsent(i, GlobalKey.new),
              ),
            ),
            if (_expandedFileIndices.contains(i))
              _buildFileContentSliver(viewModels[i])
            else
              const SliverToBoxAdapter(child: SizedBox.shrink()),
          ],
        ),
    ];
  }

  Widget _buildFileContentSliver(DiffFileViewModel vm) {
    if (vm.skipReason case final skipReason?) {
      return SliverToBoxAdapter(child: DiffSkippedPlaceholder(reason: skipReason));
    }
    final childCount = vm.hunks.fold<int>(0, (sum, h) => sum + 1 + h.lines.length);
    return SliverList.builder(
      itemCount: childCount,
      itemBuilder: (context, index) {
        var remaining = index;
        for (final hunk in vm.hunks) {
          if (remaining == 0) return DiffHunkWidget(viewModel: hunk);
          remaining--;
          if (remaining < hunk.lines.length) {
            return DiffLineWidget(viewModel: hunk.lines[remaining]);
          }
          remaining -= hunk.lines.length;
        }
        return const SizedBox.shrink();
      },
    );
  }

  void _maybeComputeViewModels({required List<FileDiff> files}) {
    final brightness = Theme.of(context).brightness;
    if (identical(files, _lastFiles) && brightness == _lastBrightness && _computeError == null) return;
    final preserveExpansion = identical(files, _lastFiles);
    _lastFiles = files;
    _lastBrightness = brightness;
    _computeError = null;

    // Defer computation to avoid setState() during build.
    Future.microtask(() {
      if (mounted) {
        _computeViewModels(files: files, preserveExpansion: preserveExpansion);
      }
    });
  }

  Future<void> _computeViewModels({
    required List<FileDiff> files,
    required bool preserveExpansion,
  }) async {
    final token = ++_computeToken;
    setState(() {
      _isComputing = true;
      _computeError = null;
      _viewModels = null;
      // Drop stale GlobalKeys from the previous file list so they don't
      // accumulate when the user switches sessions or refreshes.
      _headerKeys.clear();
    });
    try {
      final viewModels = await DiffViewModelBuilder.build(
        files,
        brightness: Theme.of(context).brightness,
      );
      if (!mounted || token != _computeToken) return;
      final expanded = preserveExpansion
          ? Set<int>.from(_expandedFileIndices)
          : <int>{
              for (var i = 0; i < viewModels.length; i++) i,
            };

      setState(() {
        _viewModels = viewModels;
        _expandedFileIndices = expanded;
        _isComputing = false;
      });
    } catch (error) {
      if (!mounted || token != _computeToken) return;
      setState(() {
        _computeError = error;
        _isComputing = false;
      });
    }
  }

  void _toggleFile(int fileIndex) {
    final viewModels = _viewModels;
    if (viewModels == null) return;
    final expanded = Set<int>.from(_expandedFileIndices);
    final wasExpanded = expanded.contains(fileIndex);
    if (wasExpanded) {
      expanded.remove(fileIndex);
    } else {
      expanded.add(fileIndex);
    }
    setState(() => _expandedFileIndices = expanded);
    if (wasExpanded) {
      // After the sliver rebuilds with file `fileIndex` collapsed (body
      // shrunk to zero), jump the viewport so the next file's header sits
      // at the top — otherwise the user lands several files down for large
      // collapsed files.
      _scheduleScrollToNext(collapsedIndex: fileIndex, totalFiles: viewModels.length);
    }
  }

  /// Schedules a post-frame jump so the header at `collapsedIndex + 1` is
  /// aligned to the top of the viewport. No-op if the collapsed file is the
  /// last one (there is no "next file" to anchor to) or the key has not yet
  /// been attached to a rendered widget.
  void _scheduleScrollToNext({required int collapsedIndex, required int totalFiles}) {
    if (collapsedIndex + 1 >= totalFiles) return;
    final nextKey = _headerKeys[collapsedIndex + 1];
    if (nextKey == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = nextKey.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(context, alignment: 0.0, duration: Duration.zero);
    });
  }

  Widget _buildErrorState({required BuildContext context, required Object error}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(context.loc.diffErrorPrefix(error.toString())),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.read<DiffCubit>().refresh(),
            child: Text(context.loc.diffRetry),
          ),
        ],
      ),
    );
  }
}
