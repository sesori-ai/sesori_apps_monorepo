import "dart:math";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";

import "models/diff_file_view_model.dart";
import "models/diff_view_model_builder.dart";
import "widgets/diff_error_view.dart";
import "widgets/diff_file_content_sliver.dart";
import "widgets/diff_file_header_delegate.dart";
import "widgets/diff_file_list.dart";

/// A desktop page's own header over the diffs, given the page title and the
/// "3 files changed  +7 −2" summary (null until files load).
typedef SessionDiffsHeaderBuilder = Widget Function({
  required BuildContext context,
  required String title,
  required String? summary,
});

/// How the product shell frames the diffs.
sealed class const SessionDiffsChrome();

/// A phone page: a glass bar over every file, one pinned header per file with
/// its diff expandable underneath.
class const SessionDiffsGlassBar({
  required final VoidCallback? onBack,
  required final Widget? banner,
}) extends SessionDiffsChrome;

/// A wide page under the shell's own header: the file list on the left and
/// the selected file's diff on the right.
class const SessionDiffsSplit({required final SessionDiffsHeaderBuilder headerBuilder}) extends SessionDiffsChrome;

/// Shared diff viewer. Owns the view models, the phone layout's expand/collapse
/// state and scroll compensation, and the split layout's selection, while the
/// product shell owns navigation, banner and header policy.
class const SessionDiffsView({
  super.key,
  required final SessionDiffsChrome chrome,
}) extends StatefulWidget {
  @override
  State<SessionDiffsView> createState() => _SessionDiffsViewState();
}

class _SessionDiffsViewState() extends State<SessionDiffsView> {
  List<DiffFileViewModel>? _viewModels;
  Set<int> _expandedFileIndices = <int>{};
  bool _isComputing = false;
  Object? _computeError;
  List<FileDiff>? _lastFiles;
  int _computeToken = 0;
  Brightness? _lastBrightness;

  /// The split's file, by path so a refresh stays on it while it is still
  /// changed; null, or a path no longer changed, selects the first file.
  String? _selectedFile;

  /// Number of view-model computations started; lets regression tests assert
  /// that theme-brightness changes trigger a recompute.
  @visibleForTesting
  int get recomputeCount => _computeToken;

  /// Stable [GlobalKey]s attached to each file's header [SizedBox] so the
  /// post-frame scroll adjustment can find the collapsed file's header.
  /// Keys are created lazily as files are rendered.
  final Map<int, GlobalKey> _headerKeys = <int, GlobalKey>{};

  /// Keys on each file's sliver group. Unlike a header, which is built only
  /// near the viewport, the group is laid out even far offscreen, so the
  /// file list can scroll to any file.
  final Map<int, GlobalKey> _fileKeys = <int, GlobalKey>{};

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DiffCubit, DiffState>(
      buildWhen: (prev, curr) =>
          prev.runtimeType != curr.runtimeType ||
          (prev is DiffStateLoaded && curr is DiffStateLoaded && !identical(prev.files, curr.files)),
      builder: (context, state) {
        final (fileCount, additions, deletions) = _statsOf(state);
        final title = context.loc.diffFileChangesTitle;
        final summary = fileCount > 0
            ? _summary(files: context.loc.diffFilesChangedCount(fileCount), additions: additions, deletions: deletions)
            : null;
        final placeholder = _placeholderSliver(context: context, state: state);
        final viewModels = _viewModels;
        return PregoReadableSelectionArea(
          preserveEmptyLines: true,
          child: switch (widget.chrome) {
            SessionDiffsGlassBar(:final onBack, :final banner) => PregoGlassScaffold(
              title: title,
              titleMode: PregoTopNavigationTitleMode.inline,
              subtitleText: summary,
              onBack: onBack,
              banner: banner,
              // The diff viewer's pinned per-file headers must pin directly below
              // the bar, so the body cannot scroll behind a transparent bar.
              extendBodyBehindBar: false,
              slivers: switch ((placeholder, viewModels)) {
                (final placeholder?, _) => [placeholder],
                (null, final viewModels?) => _buildSlivers(viewModels: viewModels),
                (null, null) => const [],
              },
            ),
            SessionDiffsSplit(:final headerBuilder) => Material(
              color: context.prego.colors.bgSurface1,
              child: Column(
                children: [
                  // The page's navigation stays out of copied diffs.
                  SelectionContainer.disabled(
                    child: headerBuilder(context: context, title: title, summary: summary),
                  ),
                  Expanded(
                    child: switch ((placeholder, viewModels)) {
                      (final placeholder?, _) => CustomScrollView(slivers: [placeholder]),
                      (null, final viewModels?) => _buildSplit(viewModels: viewModels),
                      (null, null) => const SizedBox.shrink(),
                    },
                  ),
                ],
              ),
            ),
          },
        );
      },
    );
  }

  /// "3 files changed  +7 −2", leaving out a side whose count is zero.
  static String _summary({required String files, required int additions, required int deletions}) {
    final counts = [if (additions > 0) "+$additions", if (deletions > 0) "−$deletions"].join(" ");
    return counts.isEmpty ? files : "$files  $counts";
  }

  /// The loading, failure or empty state shown instead of the files; null
  /// once their view models are ready.
  Widget? _placeholderSliver({required BuildContext context, required DiffState state}) {
    Widget fill(Widget child) => SliverFillRemaining(hasScrollBody: false, child: child);
    const loading = Center(child: PregoActivityIndicator(color: null));
    void retry() => context.read<DiffCubit>().refresh();
    switch (state) {
      case DiffStateLoading():
        return fill(loading);
      case DiffStateFailed(:final error):
        return fill(DiffErrorView(error: error, onRetry: retry));
      case DiffStateLoaded(:final files) when files.isEmpty:
        return fill(Center(child: Text(context.loc.diffNoFileChanges)));
      case DiffStateLoaded(:final files):
        _maybeComputeViewModels(files: files);
        if (_computeError case final computeError?) return fill(DiffErrorView(error: computeError, onRetry: retry));
        if (_isComputing || _viewModels == null) return fill(loading);
        return null;
    }
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
      // One file needs no index.
      if (viewModels.length > 1)
        SliverPadding(
          padding: const EdgeInsets.all(PregoSpacing.md),
          sliver: SliverToBoxAdapter(
            child: SelectionContainer.disabled(
              child: DiffFileList(viewModels: viewModels, selectedIndex: null, onSelect: _jumpToFile),
            ),
          ),
        ),
      for (var i = 0; i < viewModels.length; i++)
        SliverMainAxisGroup(
          key: _fileKeys.putIfAbsent(i, GlobalKey.new),
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

  Widget _buildSplit({required List<DiffFileViewModel> viewModels}) {
    final colors = context.prego.colors;
    final selectedIndex = max(0, viewModels.indexWhere((vm) => vm.fileDiff.file == _selectedFile));
    final selected = viewModels[selectedIndex];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 300,
          child: SelectionContainer.disabled(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(PregoSpacing.md),
              child: DiffFileList(
                viewModels: viewModels,
                selectedIndex: selectedIndex,
                onSelect: (index) => setState(() => _selectedFile = viewModels[index].fileDiff.file),
              ),
            ),
          ),
        ),
        VerticalDivider(width: 1, thickness: 1, color: colors.borderSecondary),
        Expanded(
          child: CustomScrollView(
            // A new file starts at its top.
            key: ValueKey(selected.fileDiff.file),
            slivers: [
              SliverToBoxAdapter(child: _SelectedFileHeader(viewModel: selected)),
              DiffFileContentSliver(viewModel: selected),
            ],
          ),
        ),
      ],
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
      _fileKeys.clear();
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
        // A file no longer changed drops its selection, so it cannot come back selected later.
        if (!viewModels.any((vm) => vm.fileDiff.file == _selectedFile)) _selectedFile = null;
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
      _scheduleScrollToHeader(fileIndex: fileIndex);
    }
  }

  /// Opens the file if it is collapsed and scrolls its header to the top.
  void _jumpToFile(int fileIndex) {
    if (!_expandedFileIndices.contains(fileIndex)) {
      setState(() => _expandedFileIndices = {..._expandedFileIndices, fileIndex});
    }
    _scheduleScrollToHeader(fileIndex: fileIndex);
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

  /// Schedules a post-frame scroll that brings the file's header to the top:
  /// after a collapse it keeps the collapsed header in place with the next
  /// file just below it, and after a jump from the file list it shows that
  /// file from its start. A collapse caller must have already verified (before the rebuild)
  /// that the header was pinned at the top, since the layout then shifts.
  void _scheduleScrollToHeader({required int fileIndex}) {
    final currentKey = _fileKeys[fileIndex];
    if (currentKey == null) return;
    void reveal({required bool settle}) => WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = currentKey.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(context, alignment: 0.0, duration: Duration.zero);
      // Diff bodies far from the viewport report estimated heights until they
      // are built, so the first reveal can land short; once the jump builds
      // them, a second reveal lands exactly.
      if (!settle) {
        WidgetsBinding.instance.scheduleFrame();
        reveal(settle: true);
      }
    });
    reveal(settle: false);
  }
}

/// The selected file's full path above its diff; its row in the list carries the counts, which
/// would not fit beside a long path in a narrow pane with large text.
class const _SelectedFileHeader({required final DiffFileViewModel viewModel}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final code = prego.textTheme.code;
    return SelectionContainer.disabled(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.md, vertical: PregoSpacing.sm),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: prego.colors.borderSecondary)),
        ),
        child: Row(
          spacing: PregoSpacing.sm,
          children: [
            DiffStatusLetter(status: viewModel.status),
            Expanded(
              child: Text(
                viewModel.fileDiff.file,
                style: code.copyWith(fontWeight: FontWeight.w500, color: prego.colors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
