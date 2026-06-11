import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_zyra/module_zyra.dart";

import "../../core/di/injection.dart";
import "../../core/extensions/build_context_x.dart";
import "models/diff_file_view_model.dart";
import "models/diff_view_model_builder.dart";
import "widgets/diff_file_header_delegate.dart";
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
        sessionRepository: getIt<SessionRepository>(),
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
  bool _isComputing = false;
  Object? _computeError;
  List<FileDiff>? _lastFiles;
  int _computeToken = 0;
  Brightness? _lastBrightness;

  /// Stable [GlobalKey]s attached to each file's header [SizedBox] so the
  /// post-frame scroll adjustment can find the next file's header after a
  /// collapse. Keys are created lazily as files are rendered.
  final Map<int, GlobalKey> _headerKeys = <int, GlobalKey>{};

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
      body: BlocBuilder<DiffCubit, DiffState>(
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
    _maybeComputeViewModels(files: files);
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
      return SliverToBoxAdapter(child: _buildSkippedPlaceholder(skipReason));
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
    if (identical(files, _lastFiles) && brightness == _lastBrightness) return;
    final preserveExpansion = identical(files, _lastFiles);
    _lastFiles = files;
    _lastBrightness = brightness;

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
    // Check whether the collapsed file's header is currently pinned at the
    // top of the viewport BEFORE triggering the rebuild. After the body
    // shrinks, the layout shifts and a later header can take over the
    // pinned slot, so the post-collapse check would lie.
    final headerKey = _headerKeys[fileIndex];
    final wasPinnedAtTop = wasExpanded && headerKey != null && _isHeaderPinnedAtTop(headerKey);
    setState(() => _expandedFileIndices = expanded);
    if (wasExpanded && wasPinnedAtTop) {
      // After the sliver rebuilds with file `fileIndex` collapsed (body
      // shrunk to zero), realign the viewport so the collapsed header stays
      // at the top and the next file becomes visible just below it.
      _scheduleScrollCompensation(collapsedIndex: fileIndex);
    }
  }

  /// Returns true if the header identified by [headerKey] is currently
  /// painted at the top of its enclosing scroll viewport. This is true both
  /// for headers at their natural position (e.g. the first file with no
  /// scroll) and for headers held there by a pinned
  /// [SliverPersistentHeader]. It is false for headers scrolled past the
  /// top — even if those headers would be pinned in isolation, a later
  /// pinned header has already taken over the pinned slot.
  bool _isHeaderPinnedAtTop(GlobalKey headerKey) {
    final headerContext = headerKey.currentContext;
    if (headerContext == null) return false;
    final headerBox = headerContext.findRenderObject();
    if (headerBox is! RenderBox) return false;
    final scrollable = Scrollable.maybeOf(headerContext);
    if (scrollable == null) return false;
    final scrollableBox = scrollable.context.findRenderObject();
    if (scrollableBox is! RenderBox) return false;
    final headerTop = headerBox.localToGlobal(Offset.zero).dy;
    final scrollableTop = scrollableBox.localToGlobal(Offset.zero).dy;
    return (headerTop - scrollableTop).abs() < 1.0;
  }

  /// Schedules a post-frame adjustment that realigns the viewport so the
  /// collapsed file's own header stays at the top, with the next file
  /// visible just below it. The caller must have already verified (before
  /// the rebuild) that the header was pinned at the top — we cannot
  /// re-check after the collapse because the layout has shifted.
  void _scheduleScrollCompensation({required int collapsedIndex}) {
    final currentKey = _headerKeys[collapsedIndex];
    if (currentKey == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = currentKey.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(context, alignment: 0.0, duration: Duration.zero);
    });
  }

  Widget _buildSkippedPlaceholder(FileDiffSkipReason reason) {
    final loc = context.loc;
    final message = switch (reason) {
      FileDiffSkipReason.binary => loc.diffBinaryFileChanged,
      FileDiffSkipReason.tooLarge => loc.diffFileTooLarge,
      FileDiffSkipReason.readError => loc.diffCouldNotReadFile,
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
