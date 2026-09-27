import "dart:math" as math;
import "dart:ui" show lerpDouble;

import "package:flutter/services.dart" show LogicalKeyboardKey;
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../widgets/list_search_field.dart";
import "prompt_search.dart";
import "widgets/prompt_day_header.dart";
import "widgets/prompt_spine_row.dart";

const double _kHeaderHeight = 52;

/// How long a search change takes to fold away the rows it filters out, bring
/// back the ones it lets in and grow the matches to show their excerpts.
const _kFilterDuration = Duration(milliseconds: 200);
const _kFilterCurve = Curves.easeOutCubic;

/// The Prompts screen: the session's loaded prompts in the transcript's order,
/// earlier above, grouped under their days, under a search field that narrows
/// them. It opens on [anchorMessageId]'s row, tinted, just below its day's
/// heading.
class const SessionPromptsView({
  super.key,
  required final TranscriptPromptList prompts,

  /// The prompt the reader was on when the screen opened; null or not listed
  /// opens at the newest end with nothing tinted.
  required final String? anchorMessageId,

  /// Caps the list's width, centred; null spans the pane.
  required final double? maxWidth,

  /// Loads the session's page before the earliest listed prompt; null once
  /// the session's start has loaded.
  required final VoidCallback? onLoadEarlier,

  /// Whether that page is loading, which disables [onLoadEarlier].
  required final bool isLoadingEarlier,

  /// Whether the search field takes the keyboard as the screen opens, as on a
  /// pointer surface, where typing is the quickest way in.
  required final bool autofocusSearch,
  required final void Function({required String messageId}) onPromptTap,
  required final VoidCallback onClose,
}) extends StatefulWidget {
  @override
  State<SessionPromptsView> createState() => _SessionPromptsViewState();
}

/// A run of prompts sharing one day, or every prompt when none has a time.
typedef _Group = ({DateTime? day, List<TranscriptPromptEntry> entries});

/// A prompt at one instant of a search change: how much of its row shows,
/// from 0 to 1, whether the search keeps it, and where the search found it.
typedef _Row = ({TranscriptPromptEntry entry, double shown, bool kept, Match? match});

/// A day's prompts at one instant, and how much of its heading shows.
typedef _ShownGroup = ({DateTime? day, double shown, List<_Row> rows});

/// The whole list at one instant: its groups, how far matching rows have
/// grown, and whether days head the rows at all.
typedef _Frame = ({List<_ShownGroup> groups, double grown, bool grouped});

/// Every prompt row's top and height in the scrolling list, and the list's
/// whole height.
typedef _Layout = ({Map<String, ({double top, double extent})> rows, double total});

/// The fixed heights the list is laid out from.
typedef _Extents = ({double row, double excerpt, double header, double loadEarlier, double trailing});

/// A search change still settling: how much of each row showed and how grown
/// the rows were as it began, and the search it replaced, whose excerpts the
/// rows it folds away keep until they are gone.
typedef _FilterChange = ({Map<String, double> shownFrom, double grownFrom, RegExp? previous});

/// The row a search change keeps in view: it moves from where it was on screen
/// to where the row the reader was on was, so the reader's place never jumps.
typedef _Hold = ({String messageId, double fromY, double toY});

class _SessionPromptsViewState() extends State<SessionPromptsView> with SingleTickerProviderStateMixin {
  ScrollController? _scrollController;

  /// What the search field holds.
  String _query = "";
  _FilterChange? _change;
  _Hold? _hold;

  /// Runs each search change from 0 to 1; it rests at 1.
  late final AnimationController _filter = AnimationController(vsync: this, duration: _kFilterDuration, value: 1)
    ..addListener(_settleFilter);

  /// The last build's extents, for the list's arithmetic between builds.
  _Extents? _extents;

  @override
  void dispose() {
    _filter.dispose();
    _scrollController?.dispose();
    super.dispose();
  }

  RegExp? get _search => promptSearchPattern(query: _query);

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
      list.entries.any((entry) => entry.messageId == widget.anchorMessageId) ? widget.anchorMessageId : null;

  /// [list] as the current search change stands. Day groups stay the runs the
  /// whole list has, so filtering never merges two of them.
  _Frame _frameOf({required TranscriptPromptList list}) {
    final search = _search;
    final change = _change;
    final progress = _kFilterCurve.transform(_filter.value);
    _Row rowOf(TranscriptPromptEntry entry) {
      final text = entry.fullText;
      final match = text == null ? null : search?.firstMatch(text);
      final kept = search == null || match != null;
      final to = kept ? 1.0 : 0.0;
      final shown = lerpDouble(change?.shownFrom[entry.messageId] ?? to, to, progress) ?? to;
      final previousMatch = text == null ? null : change?.previous?.firstMatch(text);
      return (entry: entry, shown: shown, kept: kept, match: match ?? previousMatch);
    }

    final groups = <_ShownGroup>[];
    for (final group in _groupsOf(list: list)) {
      final rows = group.entries.map(rowOf).toList();
      groups.add((day: group.day, shown: rows.map((row) => row.shown).fold(0.0, math.max), rows: rows));
    }
    final grownTo = search == null ? 0.0 : 1.0;
    final grown = lerpDouble(change?.grownFrom ?? grownTo, grownTo, progress) ?? grownTo;
    return (groups: groups, grown: grown, grouped: list.hasTimes);
  }

  static _Layout _layoutOf({required _Frame frame, required bool loadsEarlier, required _Extents extents}) {
    var top = loadsEarlier ? extents.loadEarlier : 0.0;
    final rows = <String, ({double top, double extent})>{};
    for (final group in frame.groups) {
      if (frame.grouped) top += extents.header * group.shown;
      for (final row in group.rows) {
        final extent = _rowExtent(row: row, frame: frame, extents: extents);
        rows[row.entry.messageId] = (top: top, extent: extent);
        top += extent;
      }
    }
    return (rows: rows, total: top + extents.trailing);
  }

  static double _rowExtent({required _Row row, required _Frame frame, required _Extents extents}) =>
      row.shown * (extents.row + frame.grown * extents.excerpt);

  /// The row the reader is on: the tinted one while any of it is on screen,
  /// else the first one reaching below the top edge.
  static String? _readerRow({
    required _Layout layout,
    required ScrollPosition position,
    required String? highlightedId,
  }) {
    bool reachesBelow(({double top, double extent}) row) => row.extent > 0 && row.top + row.extent > position.pixels;
    final highlighted = layout.rows[highlightedId];
    if (highlightedId != null &&
        highlighted != null &&
        reachesBelow(highlighted) &&
        highlighted.top < position.pixels + position.viewportDimension) {
      return highlightedId;
    }
    return layout.rows.entries.where((row) => reachesBelow(row.value)).firstOrNull?.key;
  }

  void _onSearch(String query) {
    final previous = _search;
    final before = _frameOf(list: widget.prompts);
    _query = query;
    final search = _search;
    if (search?.pattern == previous?.pattern) return;
    setState(() {
      _change = (
        shownFrom: {
          for (final group in before.groups)
            for (final row in group.rows) row.entry.messageId: row.shown,
        },
        grownFrom: before.grown,
        previous: previous,
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
  /// keeps, else the last one before it.
  _Hold? _holdFor({required _Frame before}) {
    final extents = _extents;
    final controller = _scrollController;
    if (extents == null || controller == null || !controller.hasClients) return null;
    final position = controller.position;
    final layout = _layoutOf(frame: before, loadsEarlier: widget.onLoadEarlier != null, extents: extents);
    final readerId = _readerRow(
      layout: layout,
      position: position,
      highlightedId: _highlightedIn(list: widget.prompts),
    );
    final readerTop = layout.rows[readerId]?.top;
    if (readerTop == null) return null;
    final rows = [
      for (final group in _frameOf(list: widget.prompts).groups) ...group.rows,
    ];
    final readerIndex = rows.indexWhere((row) => row.entry.messageId == readerId);
    final anchor =
        rows.skip(readerIndex).where((row) => row.kept).firstOrNull ??
        rows.take(readerIndex).where((row) => row.kept).lastOrNull;
    final anchorTop = layout.rows[anchor?.entry.messageId]?.top;
    if (anchor == null || anchorTop == null) return null;
    return (
      messageId: anchor.entry.messageId,
      fromY: anchorTop - position.pixels,
      toY: readerTop - position.pixels,
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
        frame: _frameOf(list: widget.prompts),
        loadsEarlier: widget.onLoadEarlier != null,
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
  void didUpdateWidget(SessionPromptsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final extents = _extents;
    final controller = _scrollController;
    final unchanged =
        identical(oldWidget.prompts, widget.prompts) &&
        (oldWidget.onLoadEarlier == null) == (widget.onLoadEarlier == null);
    if (unchanged || extents == null || controller == null || !controller.hasClients) return;
    final position = controller.position;
    final before = _layoutOf(
      frame: _frameOf(list: oldWidget.prompts),
      loadsEarlier: oldWidget.onLoadEarlier != null,
      extents: extents,
    );
    final after = _layoutOf(
      frame: _frameOf(list: widget.prompts),
      loadsEarlier: widget.onLoadEarlier != null,
      extents: extents,
    );
    final readerId = _readerRow(
      layout: before,
      position: position,
      highlightedId: _highlightedIn(list: oldWidget.prompts),
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
    final textScaler = MediaQuery.textScalerOf(context);
    final list = widget.prompts;
    final countStyle = prego.textTheme.textXs.regular.copyWith(color: prego.colors.textTertiary);
    final countExtent = textScaler.scale(12) * 18 / 12 + PregoSpacing.xl * 2;
    final extents = _extents = (
      row: promptRowExtent(textScaler: textScaler),
      excerpt: promptExcerptExtent(textScaler: textScaler),
      header: promptDayHeaderExtent(textScaler: textScaler),
      loadEarlier: math.max(kMinInteractiveDimension, textScaler.scale(14) * 20 / 14) + PregoSpacing.md * 2,
      trailing: countExtent + padding.bottom,
    );
    final loadEarlier = widget.onLoadEarlier;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
      },
      // Holds the keyboard when the field does not, so Escape lands here.
      child: Focus(
        autofocus: !widget.autofocusSearch,
        child: Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            children: [
              Container(
                // The field's own height, centred, unless larger text needs more.
                constraints: BoxConstraints(minHeight: padding.top + _kHeaderHeight),
                alignment: Alignment.center,
                padding: EdgeInsetsDirectional.only(top: padding.top, start: PregoSpacing.lg, end: PregoSpacing.sm),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: prego.colors.borderSecondary, width: 0.5)),
                ),
                // As wide as the list's column, so the field sits over the rows.
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: widget.maxWidth ?? double.infinity),
                  child: Row(
                    children: [
                      Expanded(
                        child: ListSearchField(
                          query: _query,
                          hintText: loc.transcriptPromptsSearchHint,
                          autofocus: widget.autofocusSearch,
                          padding: EdgeInsets.zero,
                          onChanged: _onSearch,
                        ),
                      ),
                      IconButton(
                        key: const Key("session-prompts-close"),
                        tooltip: loc.transcriptPromptsClose,
                        icon: const Icon(TablerRegular.x, size: PregoIconSize.md),
                        onPressed: widget.onClose,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: list.entries.isEmpty && loadEarlier == null
                    ? Center(child: Text(loc.transcriptPromptsEmpty, style: countStyle))
                    : LayoutBuilder(
                        builder: (context, constraints) => _buildList(
                          context: context,
                          constraints: constraints,
                          extents: extents,
                          countStyle: countStyle,
                        ),
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
    required _Extents extents,
    required TextStyle countStyle,
  }) {
    final loc = context.loc;
    final padding = MediaQuery.paddingOf(context);
    final list = widget.prompts;
    final frame = _frameOf(list: list);
    final highlightedId = _highlightedIn(list: list);
    final loadEarlier = widget.onLoadEarlier;
    final scrollController = _scrollController ??= ScrollController(
      initialScrollOffset: _initialOffset(
        layout: _layoutOf(frame: frame, loadsEarlier: loadEarlier != null, extents: extents),
        grouped: frame.grouped,
        highlightedId: highlightedId,
        headerExtent: extents.header,
        viewport: constraints.maxHeight,
      ),
    );
    final maxWidth = widget.maxWidth;
    final inset = maxWidth == null ? 0.0 : math.max(0.0, (constraints.maxWidth - maxWidth) / 2);
    final search = _search;
    final matchCount = frame.groups.fold(0, (count, group) => count + group.rows.where((row) => row.kept).length);

    SliverVariedExtentList rows({required List<_Row> rows}) => SliverVariedExtentList.builder(
      itemCount: rows.length,
      itemExtentBuilder: (index, _) =>
          index < rows.length ? _rowExtent(row: rows[index], frame: frame, extents: extents) : null,
      itemBuilder: (context, index) {
        final row = rows[index];
        final text = row.entry.fullText;
        final match = row.match;
        final spineRow = PromptSpineRow(
          entry: row.entry,
          showsTime: frame.grouped,
          highlighted: row.entry.messageId == highlightedId,
          excerpt: text == null || match == null ? null : promptExcerpt(text: text, match: match),
          grown: frame.grown,
          onTap: () => widget.onPromptTap(messageId: row.entry.messageId),
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
                  onPressed: widget.isLoadingEarlier ? null : loadEarlier,
                  child: Text(loc.transcriptPromptsLoadEarlier),
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
                child: Text(
                  search == null
                      ? loc.transcriptPromptsLoaded(list.promptCount)
                      : loc.transcriptPromptsMatches(matchCount),
                  style: countStyle,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
