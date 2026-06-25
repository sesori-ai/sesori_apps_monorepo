import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/extensions/build_context_x.dart";
import "models/diff_file_view_model.dart";
import "models/diff_view_model_builder.dart";
import "widgets/diff_error_view.dart";
import "widgets/diff_file_content_sliver.dart";
import "widgets/diff_file_header_delegate.dart";

/// Scrollable body of the diff viewer: one pinned sticky header per file
/// with expandable diff content underneath. Owns the expand/collapse state
/// and the post-collapse scroll compensation.
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

  /// Number of view-model computations started; lets regression tests assert
  /// that theme-brightness changes trigger a recompute.
  @visibleForTesting
  int get recomputeCount => _computeToken;

  /// Stable [GlobalKey]s attached to each file's header [SizedBox] so the
  /// post-frame scroll adjustment can find the collapsed file's header.
  /// Keys are created lazily as files are rendered.
  final Map<int, GlobalKey> _headerKeys = <int, GlobalKey>{};

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DiffCubit, DiffState>(
      buildWhen: (prev, curr) =>
          prev.runtimeType != curr.runtimeType ||
          (prev is DiffStateLoaded && curr is DiffStateLoaded && !identical(prev.files, curr.files)),
      builder: (context, state) {
        final (fileCount, additions, deletions) = _statsOf(state);
        return PregoGlassScaffold(
          title: context.loc.diffFileChangesTitle,
          subtitle: fileCount > 0 ? context.loc.diffFilesChangedCount(fileCount, additions, deletions) : null,
          // The diff viewer's pinned per-file headers must pin directly below
          // the bar, so the body cannot scroll behind a transparent bar.
          extendBodyBehindBar: false,
          slivers: _buildContentSlivers(context: context, state: state),
        );
      },
    );
  }

  List<Widget> _buildContentSlivers({required BuildContext context, required DiffState state}) {
    return switch (state) {
      DiffStateLoading() => const [
        SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator())),
      ],
      DiffStateFailed(:final error) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: DiffErrorView(error: error, onRetry: () => context.read<DiffCubit>().refresh()),
        ),
      ],
      DiffStateLoaded(:final files) when files.isEmpty => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: Text(context.loc.diffNoFileChanges)),
        ),
      ],
      DiffStateLoaded(:final files) => _buildLoadedSlivers(context: context, files: files),
    };
  }

  List<Widget> _buildLoadedSlivers({required BuildContext context, required List<FileDiff> files}) {
    _maybeComputeViewModels(files: files);
    if (_computeError case final computeError?) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: DiffErrorView(error: computeError, onRetry: () => context.read<DiffCubit>().refresh()),
        ),
      ];
    }

    final viewModels = _viewModels;
    if (_isComputing || viewModels == null) {
      return const [
        SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator())),
      ];
    }
    return _buildSlivers(viewModels: viewModels);
  }

  /// Aggregates the changed-file count and total additions/deletions for the
  /// bar subtitle. Returns zeros for any non-loaded state.
  static (int fileCount, int additions, int deletions) _statsOf(DiffState state) {
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
              DiffFileContentSliver(viewModel: viewModels[i])
            else
              const SliverToBoxAdapter(child: SizedBox.shrink()),
          ],
        ),
    ];
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
    if (headerBox is! RenderBox || !headerBox.attached) return false;
    final scrollable = Scrollable.maybeOf(headerContext);
    if (scrollable == null) return false;
    final scrollableBox = scrollable.context.findRenderObject();
    if (scrollableBox is! RenderBox || !scrollableBox.attached) return false;
    // Offset of the header's top edge in the scrollable's coordinate space.
    // The scrollable is a render ancestor of the header (it was found by
    // walking up from the header's context), so the conversion is direct.
    final headerTopInScrollable = headerBox.localToGlobal(Offset.zero, ancestor: scrollableBox).dy;
    return headerTopInScrollable.abs() < 1.0;
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
}
