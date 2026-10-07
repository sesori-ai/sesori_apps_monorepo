import "dart:async";
import "dart:math" as math;
import "dart:ui" show lerpDouble;

import "package:flutter/foundation.dart" show setEquals;
import "package:flutter/services.dart" show LogicalKeyboardKey;
import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart" show SessionPromptExcerpt;
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../widgets/list_search_field.dart";
import "../session_detail/session_detail_presentation_scope.dart";
import "widgets/prompt_day_header.dart";
import "widgets/prompt_spine_row.dart";

const double _kHeaderHeight = 52;

/// The text button's own padding at normal text size, kept at every size so
/// the control's height can be measured from its label.
const _kLoadEarlierPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);

/// How long a search change takes to fold away the rows it filters out, bring
/// back the ones it lets in and grow the matches to show their excerpts.
const _kFilterDuration = Duration(milliseconds: 200);
const _kFilterCurve = Curves.easeOutCubic;

/// How long a tapped unloaded prompt loads before its row shows a spinner, so
/// a quick load shows none.
const _kFarTapSpinnerDelay = Duration(milliseconds: 150);

/// The Prompts screen: the session's prompts in the transcript's order,
/// earlier above, grouped under their days, under a search field that narrows
/// them. It opens on [anchorMessageId]'s row, tinted, just below its day's
/// heading. A tap on a prompt the transcript has not loaded yet loads up to it
/// while the screen stays, then moves there like any other tap.
///
/// Search runs through a [PromptSearchCubit] the screen owns, which asks the
/// bridge for prompts whose whole text matches through the
/// [SessionDetailPresentationScope]'s session repository.
class const SessionPromptsView({
  super.key,
  required final String sessionId,
  required final TranscriptPromptList prompts,

  /// The prompt the reader was on when the screen opened; null or not listed
  /// opens at the newest end with nothing tinted.
  required final String? anchorMessageId,

  /// Caps the list's width, centred; null spans the pane.
  required final double? maxWidth,

  /// Loads the session's page before the earliest listed prompt; null once
  /// the session's start has loaded or [prompts] lists every prompt.
  required final VoidCallback? onLoadEarlier,

  /// Whether that page is loading or the transcript is refreshing, either of
  /// which disables [onLoadEarlier].
  required final bool isLoadEarlierBusy,

  /// Whether the search field takes the keyboard as the screen opens, as on a
  /// pointer surface, where typing is the quickest way in.
  required final bool autofocusSearch,

  /// Moves the transcript to a loaded prompt and closes the screen.
  required final void Function({required String messageId}) onPromptTap,

  /// Loads the transcript up to the unloaded prompt [messageId] at [seq].
  required final Future<LoadThroughOutcome> Function({required String messageId, required int seq}) onLoadThrough,
  required final VoidCallback onClose,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => PromptSearchCubit(
      sessionRepository: SessionDetailPresentationScope.read(context).sessionRepository(),
      sessionId: sessionId,
      prompts: prompts,
    ),
    child: _PromptsList(view: this),
  );
}

class const _PromptsList({required final SessionPromptsView view}) extends StatefulWidget {
  @override
  State<_PromptsList> createState() => _PromptsListState();
}

/// A run of prompts sharing one day, or every prompt when none has a time.
typedef _Group = ({DateTime? day, List<TranscriptPromptEntry> entries});

/// A prompt at one instant of a search change: how much of its row shows,
/// from 0 to 1, whether the search keeps it, and the words around its match.
typedef _Row = ({TranscriptPromptEntry entry, double shown, bool kept, SessionPromptExcerpt? match});

/// A day's prompts at one instant, and how much of its heading shows.
typedef _ShownGroup = ({DateTime? day, double shown, List<_Row> rows});

/// The whole list at one instant: its groups, how far matching rows have
/// grown, and whether days head the rows at all.
typedef _Frame = ({List<_ShownGroup> groups, double grown, bool grouped});

/// Every prompt row's top and height in the scrolling list, where each day
/// starts and ends with how tall its pinned heading is, and the list's whole
/// height.
typedef _Layout = ({
  Map<String, ({double top, double extent})> rows,
  List<({double start, double end, double header})> groups,
  double total,
});

/// The fixed heights the list is laid out from.
typedef _Extents = ({double row, double excerpt, double header, double loadEarlier, double trailing});

/// A search change still settling: how much of each row showed and how grown
/// the rows were as it began, and the match each row showed then, which the
/// rows it folds away keep until they are gone, also through a change that
/// replaces it before it settles.
typedef _FilterChange = ({
  Map<String, double> shownFrom,
  double grownFrom,
  Map<String, SessionPromptExcerpt> matchesFrom,
});

/// The row a search change keeps in view: it moves from where it was on screen
/// to where the row the reader was on was, so the reader's place never jumps.
typedef _Hold = ({String messageId, double fromY, double toY});

/// The row the reader was on and its y on screen.
typedef _Place = ({String messageId, double y});

/// The unloaded prompt a tap is loading up to, and whether the load has run
/// long enough for its row to show a spinner.
typedef _FarTap = ({String messageId, bool showsSpinner});

class _PromptsListState() extends State<_PromptsList> with SingleTickerProviderStateMixin {
  ScrollController? _scrollController;

  /// The search the rows show, which the cubit's latest state replaces.
  PromptSearchState _search = const PromptSearchIdle(query: "");
  late final StreamSubscription<PromptSearchState> _searches;
  _FilterChange? _change;
  _Hold? _hold;

  /// Where the reader was when a search left no rows, so the search that
  /// brings rows back returns them to that place.
  _Place? _parked;

  /// Runs each search change from 0 to 1; it rests at 1.
  late final AnimationController _filter = AnimationController(vsync: this, duration: _kFilterDuration, value: 1)
    ..addListener(_settleFilter);

  /// The last build's extents, for the list's arithmetic between builds.
  _Extents? _extents;

  /// Counts taps on rows; a far tap's load lands only while its tap is still
  /// the latest, and closing the screen drops it with the screen.
  int _taps = 0;

  /// The unloaded prompt the latest tap is loading, while it loads.
  _FarTap? _farTap;
  Timer? _farTapSpinner;

  /// Why the last far tap could not move to its prompt, shown over the list's
  /// foot until the next tap.
  String? _farTapError;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<PromptSearchCubit>();
    // Each event shows the cubit's latest state, so a queued older event never brings back a search already replaced.
    _searches = cubit.stream.listen((_) => _showSearch(cubit.state));
  }

  @override
  void dispose() {
    unawaited(_searches.cancel());
    _farTapSpinner?.cancel();
    _filter.dispose();
    _scrollController?.dispose();
    super.dispose();
  }

  void _tapPrompt({required TranscriptPromptEntry entry}) {
    switch (entry.source) {
      case TranscriptPromptLoaded():
        _taps++;
        _farTapSpinner?.cancel();
        setState(() {
          _farTap = null;
          _farTapError = null;
        });
        _view.onPromptTap(messageId: entry.messageId);
      case TranscriptPromptUnloaded(:final seq):
        // Another tap on the prompt already loading waits for that load.
        if (_farTap?.messageId != entry.messageId) unawaited(_loadThrough(messageId: entry.messageId, seq: seq));
    }
  }

  /// Loads up to the unloaded prompt [messageId] with the screen still up,
  /// then moves to it unless another tap took over meanwhile.
  Future<void> _loadThrough({required String messageId, required int seq}) async {
    final tap = ++_taps;
    _farTapSpinner?.cancel();
    setState(() {
      _farTap = (messageId: messageId, showsSpinner: false);
      _farTapError = null;
    });
    // Every later tap, the load landing and dispose cancel it first.
    _farTapSpinner = Timer(
      _kFarTapSpinnerDelay,
      () => setState(() => _farTap = (messageId: messageId, showsSpinner: true)),
    );
    final outcome = await _view.onLoadThrough(messageId: messageId, seq: seq);
    if (!mounted || tap != _taps) return;
    _farTapSpinner?.cancel();
    final loc = context.loc;
    setState(() {
      _farTap = null;
      _farTapError = switch (outcome) {
        LoadThroughLoaded() => null,
        LoadThroughTargetMissing() => loc.transcriptPromptsGone,
        LoadThroughUnsupported() => loc.transcriptPromptsBridgeTooOld,
        LoadThroughFailed() => loc.transcriptPromptsOpenFailed,
        // A refresh replaced the transcript meanwhile; a second tap reads the new one.
        LoadThroughSuperseded() => loc.transcriptPromptsRefreshed,
      };
    });
    if (outcome is LoadThroughLoaded) _view.onPromptTap(messageId: messageId);
  }

  SessionPromptsView get _view => widget.view;

  static List<_Group> _groupsOf({required TranscriptPromptList list}) {
    if (!list.hasTimes) return [(day: null, entries: list.entries)];
    final groups = <_Group>[];
    for (final entry in list.entries) {
      if (groups.lastOrNull case final group? when group.day == entry.dayKey) {
        group.entries.add(entry);
      } else {
        groups.add((day: entry.dayKey, entries: [entry]));
      }
    }
    return groups;
  }

  String? _highlightedIn({required TranscriptPromptList list}) =>
      list.entries.any((entry) => entry.messageId == _view.anchorMessageId) ? _view.anchorMessageId : null;

  /// [list] as the current search change stands. Day groups stay the runs the
  /// whole list has, so filtering never merges two of them.
  _Frame _frameOf({required TranscriptPromptList list}) {
    final matches = _matchesOf(search: _search);
    final change = _change;
    final progress = _kFilterCurve.transform(_filter.value);
    _Row rowOf(TranscriptPromptEntry entry) {
      final match = matches?[entry.messageId];
      final kept = matches == null || match != null;
      final to = kept ? 1.0 : 0.0;
      final shown = lerpDouble(change?.shownFrom[entry.messageId] ?? to, to, progress) ?? to;
      return (entry: entry, shown: shown, kept: kept, match: match ?? change?.matchesFrom[entry.messageId]);
    }

    final groups = <_ShownGroup>[];
    for (final group in _groupsOf(list: list)) {
      final rows = group.entries.map(rowOf).toList();
      groups.add((day: group.day, shown: rows.map((row) => row.shown).fold(0.0, math.max), rows: rows));
    }
    final grownTo = matches == null ? 0.0 : 1.0;
    final grown = lerpDouble(change?.grownFrom ?? grownTo, grownTo, progress) ?? grownTo;
    return (groups: groups, grown: grown, grouped: list.hasTimes);
  }

  static _Layout _layoutOf({required _Frame frame, required bool loadsEarlier, required _Extents extents}) {
    var top = loadsEarlier ? extents.loadEarlier : 0.0;
    final rows = <String, ({double top, double extent})>{};
    final groups = <({double start, double end, double header})>[];
    for (final group in frame.groups) {
      final start = top;
      final header = frame.grouped ? extents.header * group.shown : 0.0;
      top += header;
      for (final row in group.rows) {
        final extent = _rowExtent(row: row, frame: frame, extents: extents);
        rows[row.entry.messageId] = (top: top, extent: extent);
        top += extent;
      }
      groups.add((start: start, end: top, header: header));
    }
    return (rows: rows, groups: groups, total: top + extents.trailing);
  }

  /// Where the rows start showing when the list is scrolled to [pixels]: below
  /// the pinned heading of the day running there, which rides up as that
  /// day's last row leaves.
  static double _visibleTop({required _Layout layout, required double pixels}) {
    final day = layout.groups.where((group) => group.start <= pixels && pixels < group.end).firstOrNull;
    return day == null ? pixels : pixels + math.min(day.header, day.end - pixels);
  }

  static double _rowExtent({required _Row row, required _Frame frame, required _Extents extents}) =>
      row.shown * (extents.row + frame.grown * extents.excerpt);

  /// The row the reader is on: the tinted one while any of it is on screen,
  /// else the first one reaching below the top edge. Rows hidden beneath the
  /// pinned day heading are not on screen.
  static String? _readerRow({
    required _Layout layout,
    required ScrollPosition position,
    required String? highlightedId,
  }) {
    final top = _visibleTop(layout: layout, pixels: position.pixels);
    bool reachesBelow(({double top, double extent}) row) => row.extent > 0 && row.top + row.extent > top;
    final highlighted = layout.rows[highlightedId];
    if (highlightedId != null &&
        highlighted != null &&
        reachesBelow(highlighted) &&
        highlighted.top < position.pixels + position.viewportDimension) {
      return highlightedId;
    }
    return layout.rows.entries.where((row) => reachesBelow(row.value)).firstOrNull?.key;
  }

  /// Lays a switch out at the incoming child's size, so a taller outgoing one
  /// fades out clipped rather than overflowing the measured end of the list.
  static Widget _sizedByIncoming({required Widget? current, required List<Widget> previous}) => Stack(
    alignment: Alignment.center,
    children: [
      for (final child in previous) Positioned(top: 0, left: 0, right: 0, child: child),
      ?current,
    ],
  );

  /// The matching prompts, or null while the field holds no search.
  static Map<String, SessionPromptExcerpt>? _matchesOf({required PromptSearchState search}) => switch (search) {
    PromptSearchIdle() => null,
    PromptSearchActive(:final matches) => matches,
  };

  /// Takes the cubit's latest search. A change in which prompts match folds
  /// rows away and brings others in, with the reader's row held in place, as
  /// the bridge's matches joining do.
  void _showSearch(PromptSearchState next) {
    final previous = _matchesOf(search: _search);
    final matches = _matchesOf(search: next);
    final before = _frameOf(list: _view.prompts);
    _search = next;
    if ((previous == null) == (matches == null) && setEquals(previous?.keys.toSet(), matches?.keys.toSet())) {
      setState(() {});
      return;
    }
    setState(() {
      _change = (
        shownFrom: {
          for (final group in before.groups)
            for (final row in group.rows) row.entry.messageId: row.shown,
        },
        grownFrom: before.grown,
        matchesFrom: {
          for (final group in before.groups)
            for (final row in group.rows) row.entry.messageId: ?row.match,
        },
      );
      _hold = _holdFor(before: before);
    });
    if (context.isReducedMotion) {
      _filter.value = 1;
    } else {
      _filter.forward(from: 0);
    }
  }

  /// The row to keep in view while the search change just begun settles: the
  /// row the reader is on when the search keeps it, else the next row it
  /// keeps, else the last one before it. With no row on screen, after a
  /// search that matched nothing, it is the place the reader left.
  _Hold? _holdFor({required _Frame before}) {
    final extents = _extents;
    final controller = _scrollController;
    if (extents == null || controller == null || !controller.hasClients) return null;
    final position = controller.position;
    final layout = _layoutOf(frame: before, loadsEarlier: _view.onLoadEarlier != null, extents: extents);
    final readerId = _readerRow(
      layout: layout,
      position: position,
      highlightedId: _highlightedIn(list: _view.prompts),
    );
    final readerTop = layout.rows[readerId]?.top;
    final onScreen = readerId != null && readerTop != null
        ? (messageId: readerId, y: readerTop - position.pixels)
        : null;
    final reader = onScreen ?? _parked;
    if (reader == null) return null;
    final rows = [
      for (final group in _frameOf(list: _view.prompts).groups) ...group.rows,
    ];
    final readerIndex = rows.indexWhere((row) => row.entry.messageId == reader.messageId);
    final anchor =
        rows.skip(readerIndex).where((row) => row.kept).firstOrNull ??
        rows.take(readerIndex).where((row) => row.kept).lastOrNull;
    final anchorTop = layout.rows[anchor?.entry.messageId]?.top;
    if (anchor == null || anchorTop == null) {
      _parked = reader;
      return null;
    }
    _parked = null;
    return (
      messageId: anchor.entry.messageId,
      // A row coming back from nothing unfolds in the reader's place.
      fromY: onScreen == null ? reader.y : anchorTop - position.pixels,
      toY: reader.y,
    );
  }

  /// Each frame of a search change: keeps the held row where it belongs, then
  /// rebuilds the rows at their new heights; the change ends at 1.
  void _settleFilter() {
    final extents = _extents;
    final controller = _scrollController;
    if (extents != null && controller != null && controller.hasClients) {
      final position = controller.position;
      final layout = _layoutOf(
        frame: _frameOf(list: _view.prompts),
        loadsEarlier: _view.onLoadEarlier != null,
        extents: extents,
      );
      final hold = _hold;
      final heldTop = layout.rows[hold?.messageId]?.top;
      final pixels = hold != null && heldTop != null
          ? heldTop - (lerpDouble(hold.fromY, hold.toY, _kFilterCurve.transform(_filter.value)) ?? hold.toY)
          : position.pixels;
      // Corrected before the rows lay out, so no frame shows them elsewhere.
      position.correctPixels(pixels.clamp(0.0, math.max(0.0, layout.total - position.viewportDimension)));
    }
    setState(() {
      if (_filter.value == 1) {
        _change = null;
        _hold = null;
      }
    });
  }

  /// Keeps the row the reader is on where it is when the list changes under
  /// it: earlier prompts arriving above it, or "Load earlier prompts" leaving.
  @override
  void didUpdateWidget(_PromptsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.view;
    final promptsChanged = !identical(old.prompts, _view.prompts);
    if (!promptsChanged && (old.onLoadEarlier == null) == (_view.onLoadEarlier == null)) return;
    final extents = _extents;
    final before = extents == null
        ? null
        : _layoutOf(
            frame: _frameOf(list: old.prompts),
            loadsEarlier: old.onLoadEarlier != null,
            extents: extents,
          );
    if (promptsChanged) {
      // The cubit matches the new list at once, so this build lays the rows out with it.
      final cubit = context.read<PromptSearchCubit>()..showPrompts(prompts: _view.prompts);
      _search = cubit.state;
    }
    final controller = _scrollController;
    if (extents == null || before == null || controller == null || !controller.hasClients) return;
    final position = controller.position;
    final after = _layoutOf(
      frame: _frameOf(list: _view.prompts),
      loadsEarlier: _view.onLoadEarlier != null,
      extents: extents,
    );
    final readerId = _readerRow(
      layout: before,
      position: position,
      highlightedId: _highlightedIn(list: old.prompts),
    );
    final beforeTop = before.rows[readerId]?.top;
    final afterTop = after.rows[readerId]?.top;
    if (beforeTop == null || afterTop == null) return;
    final maxOffset = math.max(0.0, after.total - position.viewportDimension);
    position.correctPixels((position.pixels + afterTop - beforeTop).clamp(0.0, maxOffset));
  }

  /// The offset that rests the anchored row just below its day's pinned
  /// heading; the newest end without one.
  static double _initialOffset({
    required _Layout layout,
    required bool grouped,
    required String? highlightedId,
    required double headerExtent,
    required double viewport,
  }) {
    final maxOffset = math.max(0.0, layout.total - viewport);
    return switch (layout.rows[highlightedId]?.top) {
      final top? => (top - (grouped ? headerExtent : 0)).clamp(0.0, maxOffset),
      null => maxOffset,
    };
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final padding = MediaQuery.paddingOf(context);
    final list = _view.prompts;
    final countStyle = prego.textTheme.textXs.regular.copyWith(color: prego.colors.textTertiary);
    final loadEarlier = _view.onLoadEarlier;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): _view.onClose,
      },
      // Holds the keyboard when the field does not, also once a click outside
      // has taken it from the field, so Escape lands here.
      child: FocusScope(
        autofocus: !_view.autofocusSearch,
        child: Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            children: [
              Container(
                // The field's own height, centred, unless larger text needs more.
                constraints: BoxConstraints(minHeight: padding.top + _kHeaderHeight),
                alignment: Alignment.center,
                padding: EdgeInsetsDirectional.only(top: padding.top, start: PregoSpacing.lg, end: PregoSpacing.sm),
                // As wide as the list's column, so the field sits over the rows.
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: _view.maxWidth ?? double.infinity),
                  child: Row(
                    children: [
                      Expanded(
                        child: ListSearchField(
                          query: _search.query,
                          hintText: loc.transcriptPromptsSearchHint,
                          autofocus: _view.autofocusSearch,
                          padding: EdgeInsets.zero,
                          onChanged: (query) => context.read<PromptSearchCubit>().search(query: query),
                        ),
                      ),
                      IconButton(
                        key: const Key("session-prompts-close"),
                        tooltip: loc.transcriptPromptsClose,
                        icon: const Icon(TablerRegular.x, size: PregoIconSize.md),
                        onPressed: _view.onClose,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: list.entries.isEmpty && loadEarlier == null
                          ? Center(child: Text(loc.transcriptPromptsEmpty, style: countStyle))
                          : LayoutBuilder(
                              builder: (context, constraints) => _buildList(
                                context: context,
                                constraints: constraints,
                                countStyle: countStyle,
                              ),
                            ),
                    ),
                    // Over the list's foot rather than in it, so nothing the
                    // reader is on moves when it shows.
                    PositionedDirectional(
                      start: PregoSpacing.lg,
                      end: PregoSpacing.lg,
                      bottom: padding.bottom + PregoSpacing.lg,
                      child: AnimatedSwitcher(
                        duration: _kFilterDuration,
                        child: switch (_farTapError) {
                          final error? => _FarTapError(key: ValueKey(error), message: error),
                          null => const SizedBox.shrink(),
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList({
    required BuildContext context,
    required BoxConstraints constraints,
    required TextStyle countStyle,
  }) {
    final loc = context.loc;
    final padding = MediaQuery.paddingOf(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final list = _view.prompts;
    final frame = _frameOf(list: list);
    final highlightedId = _highlightedIn(list: list);
    final loadEarlier = _view.onLoadEarlier;
    final matchCount = frame.groups.fold(0, (count, group) => count + group.rows.where((row) => row.kept).length);
    final count = switch (_search) {
      PromptSearchIdle() =>
        list.isIndexed ? loc.transcriptPromptsCount(list.promptCount) : loc.transcriptPromptsLoaded(list.promptCount),
      PromptSearchActive(:final earlier) => switch (earlier) {
        EarlierPromptSearch.listedOnly =>
          list.isIndexed ? loc.transcriptPromptsAllMatches(matchCount) : loc.transcriptPromptsMatches(matchCount),
        EarlierPromptSearch.pending || EarlierPromptSearch.done => loc.transcriptPromptsAllMatches(matchCount),
        EarlierPromptSearch.slow => loc.transcriptPromptsSearchingEarlier,
        EarlierPromptSearch.failed => loc.transcriptPromptsSearchEarlierFailed,
      },
    };
    final searchFailed = switch (_search) {
      PromptSearchIdle() => false,
      PromptSearchActive(:final earlier) => earlier == EarlierPromptSearch.failed,
    };
    // Room for Retry stays for the whole search of earlier prompts, so the
    // list's end never jumps as Retry comes and goes.
    final reservesRetry = switch (_search) {
      PromptSearchIdle() || PromptSearchActive(earlier: EarlierPromptSearch.listedOnly) => false,
      PromptSearchActive() => true,
    };
    final loadEarlierLabelStyle = Theme.of(context).textTheme.labelLarge;
    // Measured, as large text or a narrow screen can wrap the labels. Bold Text
    // and the platform's spacing overrides apply, as [Text] applies them.
    final typography = TextStyle(
      fontWeight: MediaQuery.boldTextOf(context) ? FontWeight.bold : null,
      height: MediaQuery.maybeLineHeightScaleFactorOverrideOf(context),
      letterSpacing: MediaQuery.maybeLetterSpacingOverrideOf(context),
      wordSpacing: MediaQuery.maybeWordSpacingOverrideOf(context),
    );
    double heightOf({required String text, required TextStyle? style, required double maxWidth}) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style?.merge(typography) ?? typography),
        textDirection: Directionality.of(context),
        textScaler: textScaler,
      )..layout(maxWidth: maxWidth);
      final height = painter.height;
      painter.dispose();
      return height;
    }

    double buttonExtent({required String label}) => math.max(
      kMinInteractiveDimension,
      heightOf(
            text: label,
            style: loadEarlierLabelStyle,
            maxWidth: math.max(0.0, constraints.maxWidth - _kLoadEarlierPadding.horizontal),
          ) +
          _kLoadEarlierPadding.vertical,
    );
    final retryExtent = buttonExtent(label: loc.transcriptPromptsSearchRetry);
    final extents = _extents = (
      row: promptRowExtent(textScaler: textScaler),
      excerpt: promptExcerptExtent(textScaler: textScaler),
      header: promptDayHeaderExtent(textScaler: textScaler),
      loadEarlier: buttonExtent(label: loc.transcriptPromptsLoadEarlier) + PregoSpacing.md * 2,
      trailing:
          heightOf(text: count, style: countStyle, maxWidth: constraints.maxWidth) +
          (reservesRetry ? retryExtent : 0) +
          PregoSpacing.xl * 2 +
          padding.bottom,
    );
    final scrollController = _scrollController ??= ScrollController(
      initialScrollOffset: _initialOffset(
        layout: _layoutOf(frame: frame, loadsEarlier: loadEarlier != null, extents: extents),
        grouped: frame.grouped,
        highlightedId: highlightedId,
        headerExtent: extents.header,
        viewport: constraints.maxHeight,
      ),
    );
    final maxWidth = _view.maxWidth;
    final inset = maxWidth == null ? 0.0 : math.max(0.0, (constraints.maxWidth - maxWidth) / 2);

    SliverVariedExtentList rows({required List<_Row> rows}) => SliverVariedExtentList.builder(
      itemCount: rows.length,
      itemExtentBuilder: (index, _) =>
          index < rows.length ? _rowExtent(row: rows[index], frame: frame, extents: extents) : null,
      itemBuilder: (context, index) {
        final row = rows[index];
        final spineRow = PromptSpineRow(
          entry: row.entry,
          showsTime: frame.grouped,
          highlighted: row.entry.messageId == highlightedId,
          excerpt: row.match,
          grown: frame.grown,
          loading: _farTap == (messageId: row.entry.messageId, showsSpinner: true),
          onTap: () => _tapPrompt(entry: row.entry),
        );
        return KeyedSubtree(
          key: ValueKey(row.entry.messageId),
          child: row.shown < 1 ? Opacity(opacity: row.shown, child: spineRow) : spineRow,
        );
      },
    );

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        if (loadEarlier != null)
          SliverToBoxAdapter(
            child: SizedBox(
              height: extents.loadEarlier,
              child: Center(
                child: TextButton(
                  key: const Key("session-prompts-load-earlier"),
                  // The label and padding the extent above is measured with.
                  style: ButtonStyle(
                    textStyle: WidgetStatePropertyAll(loadEarlierLabelStyle),
                    padding: const WidgetStatePropertyAll(_kLoadEarlierPadding),
                  ),
                  onPressed: _view.isLoadEarlierBusy ? null : loadEarlier,
                  child: Text(loc.transcriptPromptsLoadEarlier, textAlign: TextAlign.center),
                ),
              ),
            ),
          ),
        for (final group in frame.groups)
          // A row the search has folded away entirely is left out.
          if (group.rows.where((row) => row.shown > 0 || row.kept).toList() case final shownRows
              when shownRows.isNotEmpty)
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: inset),
              sliver: frame.grouped
                  ? SliverMainAxisGroup(
                      slivers: [
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: PromptDayHeaderDelegate(
                            label: switch (group.day) {
                              final day? => context.formatDayLabel(day: day),
                              null => loc.transcriptPromptsNoDate,
                            },
                            extent: extents.header,
                            shown: group.shown,
                          ),
                        ),
                        rows(rows: shownRows),
                      ],
                    )
                  : rows(rows: shownRows),
            ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: extents.trailing,
            child: Padding(
              padding: EdgeInsetsDirectional.only(bottom: padding.bottom),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Fades between counts, so the bridge's answer reads as one.
                    AnimatedSwitcher(
                      duration: _kFilterDuration,
                      layoutBuilder: (current, previous) => _sizedByIncoming(current: current, previous: previous),
                      child: Text(count, key: ValueKey(count), textAlign: TextAlign.center, style: countStyle),
                    ),
                    if (reservesRetry)
                      SizedBox(
                        height: retryExtent,
                        child: AnimatedSwitcher(
                          duration: _kFilterDuration,
                          layoutBuilder: (current, previous) => _sizedByIncoming(current: current, previous: previous),
                          child: searchFailed
                              ? TextButton(
                                  key: const Key("session-prompts-search-retry"),
                                  style: ButtonStyle(
                                    textStyle: WidgetStatePropertyAll(loadEarlierLabelStyle),
                                    padding: const WidgetStatePropertyAll(_kLoadEarlierPadding),
                                  ),
                                  onPressed: () => context.read<PromptSearchCubit>().retry(),
                                  child: Text(loc.transcriptPromptsSearchRetry, textAlign: TextAlign.center),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Why a far tap could not move to its prompt, announced as it shows. Taps and
/// drags pass through it to the rows beneath.
class const _FarTapError({super.key, required final String message}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final colors = prego.colors;
    return IgnorePointer(
      child: Center(
        child: Semantics(
          liveRegion: true,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.bgSecondary,
              border: Border.all(color: colors.borderSecondary),
              borderRadius: BorderRadius.circular(PregoRadius.lg),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.lg, vertical: PregoSpacing.md),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: prego.textTheme.textSm.regular.copyWith(color: colors.textSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
