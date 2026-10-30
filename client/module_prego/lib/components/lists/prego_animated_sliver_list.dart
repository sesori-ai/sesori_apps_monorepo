import "package:flutter/rendering.dart";
import "package:material_ui/material_ui.dart";

import "../../motion/prego_reduced_motion.dart";

/// How long a row of a [PregoAnimatedSliverList] takes to open or close.
const Duration pregoAnimatedListItemDuration = Duration(milliseconds: 260);

/// A sliver list that reconciles keyed [items] and animates rows as they enter
/// or leave.
///
/// The caller owns the source list. This widget keeps only the presentation
/// snapshot it needs so a removed row can collapse and fade instead of
/// disappearing between state emissions. Only rows on screen animate; rows
/// that enter or leave off screen do so at once, so an update costs one pass
/// over the items plus a handful of animations however long the list is.
///
/// Scrolled past its top, the list keeps the rows on screen where they stand:
/// rows that arrive or leave above the screen, such as one moving to the top,
/// change nothing under the user's eyes.
class const PregoAnimatedSliverList<T>({
  super.key,

  /// The items currently present in the source list.
  required final List<T> items,

  /// Returns the stable, unique identity of an item across list updates.
  required final Key Function(T item) itemKey,

  /// Builds an item at its current index.
  required final Widget Function(BuildContext context, int index, T item) itemBuilder,
}) extends StatefulWidget {
  @override
  State<PregoAnimatedSliverList<T>> createState() => _PregoAnimatedSliverListState<T>();
}

class _PregoAnimatedSliverListState<T>() extends State<PregoAnimatedSliverList<T>> with TickerProviderStateMixin {
  /// Every row the sliver shows, in order: the source items plus the rows
  /// still closing after they left.
  var _entries = <_Entry<T>>[];

  /// Where each row sits in [_entries], so a moved row keeps its element.
  var _indexByKey = <_PregoAnimatedSliverItemKey, int>{};

  /// Row motions an update started, run once its frame has painted.
  final _motionsAfterFrame = <({_RowMotion motion, bool opening})>[];

  @override
  void initState() {
    super.initState();
    final keys = _keysOf(widget);
    _setEntries([
      for (final (index, item) in widget.items.indexed)
        _ShownEntry(key: _PregoAnimatedSliverItemKey((keys[index], 0)), item: item, sourceIndex: index, entering: null),
    ]);
  }

  @override
  void didUpdateWidget(PregoAnimatedSliverList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    final nextKeys = _keysOf(widget);
    final nextIndexByKey = {for (final (index, key) in nextKeys.indexed) key: index};
    final shown = _shownRows();
    final animates = !prefersReducedMotion(context);
    // A row that leaves is checked at its old index.
    bool landsOnScreen(int index) => animates && shown != null && shown.contains(index);

    // Pair each retained row with its entry. A row that left closes where it
    // was when that is on screen and goes at once otherwise; a closing row
    // holds its place after the retained row before it.
    final retained = <Key, _ShownEntry<T>>{};
    final leading = <_Entry<T>>[];
    final closingAfter = <Key, List<_Entry<T>>>{};
    Key? previousRetained;
    // The newest copy of each row still on its way out, so one that returns
    // gets a key of its own and the two never share an element.
    final generations = <Key, int>{};
    // A row on screen that moves up past the row before it, as one updated
    // moves to the top, closes where it was, and a copy of it takes its new
    // place, so the rows below close up instead of jumping.
    bool movesUp({required int index, required Key itemKey}) =>
        landsOnScreen(index) &&
        switch ((nextIndexByKey[itemKey], nextIndexByKey[previousRetained])) {
          (final to?, final before?) => to < before,
          _ => false,
        };
    for (final (index, entry) in _entries.indexed) {
      final (itemKey, generation) = entry.key.value;
      final _Entry<T> closing;
      switch (entry) {
        case _ShownEntry<T>() when nextIndexByKey.containsKey(itemKey) && !movesUp(index: index, itemKey: itemKey):
          retained[itemKey] = entry;
          previousRetained = itemKey;
          continue;
        case _ShownEntry<T>(:final entering):
          // A row that never got to open has nothing on screen to close.
          if (!landsOnScreen(index) || (entering != null && entering.controller.value == 0)) {
            entering?.dispose();
            continue;
          }
          closing = _LeavingEntry(
            key: entry.key,
            item: entry.item,
            sourceIndex: entry.sourceIndex,
            itemBuilder: oldWidget.itemBuilder,
            leaving: _runAfterFrame(motion: entering ?? _startMotion(key: entry.key, from: 1), opening: false),
          );
        case _LeavingEntry<T>():
          closing = entry;
      }
      final group = switch (previousRetained) {
        final Key key => closingAfter.putIfAbsent(key, () => []),
        null => leading,
      };
      group.add(closing);
      generations.update(itemKey, (newest) => generation > newest ? generation : newest, ifAbsent: () => generation);
    }

    final entries = [...leading];
    final arrivals = <int>[];
    for (final (index, item) in widget.items.indexed) {
      final itemKey = nextKeys[index];
      switch (retained[itemKey]) {
        case final kept?:
          entries.add(_ShownEntry(key: kept.key, item: item, sourceIndex: index, entering: kept.entering));
        case null:
          final key = _PregoAnimatedSliverItemKey((itemKey, (generations[itemKey] ?? -1) + 1));
          arrivals.add(entries.length);
          entries.add(_ShownEntry(key: key, item: item, sourceIndex: index, entering: null));
      }
      entries.addAll(closingAfter[itemKey] ?? const []);
    }
    _setEntries(entries);

    // A scrolled list keeps its first visible row where it stands, so what
    // the update puts or takes away before that row lands or goes above the
    // screen, and the rows on it hold still. At its top, the list instead
    // keeps its indices in place, so a row arriving first opens in view.
    final anchorIndex = _indexByKey[shown?.anchor];
    if ((context.findRenderObject(), shown, anchorIndex) case (
      final _RenderPregoAnimatedSliverList sliver,
      final shown?,
      final index?,
    )) {
      sliver.keepRow(index: index, offset: shown.firstOffset);
    }
    if (shown == null || !animates) return;
    for (final index in arrivals) {
      if (entries[index] case _ShownEntry<T>(:final key, :final item, :final sourceIndex)) {
        // A row that enters is checked at its new index: in a kept list,
        // after the row kept in place; otherwise at its index in the items,
        // where it stands once the rows closing before it have gone.
        final onScreen = switch (anchorIndex) {
          final anchorIndex? => index >= anchorIndex && index < anchorIndex + shown.count,
          null => shown.contains(sourceIndex),
        };
        if (!onScreen) continue;
        final entering = _runAfterFrame(motion: _startMotion(key: key, from: 0), opening: true);
        entries[index] = _ShownEntry(key: key, item: item, sourceIndex: sourceIndex, entering: entering);
      }
    }
  }

  /// The rows the list's visible extent showed as an update arrived, so their
  /// entry or exit is worth animating, and the first of them to keep in place.
  ///
  /// An animated row enters at zero height, so all of them fit in the first
  /// frame after a filter change and the list would build every one at once.
  /// Rows outside the visible extent enter at full size instead and build
  /// lazily as they scroll in, and leave at once instead of each ticking a
  /// transition nobody sees. Rows are tap targets, so none is shorter than
  /// [kMinInteractiveDimension], which bounds how many the extent can show.
  /// The window is therefore an upper bound: taller rows leave some off-screen
  /// rows in it, and those still animate.
  _ShownRows? _shownRows() {
    final sliver = context.findRenderObject();
    // A list that is not laid out, such as one kept offstage, shows no rows.
    if (sliver is! _RenderPregoAnimatedSliverList || sliver.geometry == null) return null;

    final constraints = sliver.constraints;
    // The last built row starting at or above the top edge is the first one
    // visible.
    var first = 0;
    var firstOffset = 0.0;
    for (var child = sliver.firstChild; child != null; child = sliver.childAfter(child)) {
      final offset = sliver.childScrollOffset(child) ?? 0;
      if (offset > constraints.scrollOffset) break;
      first = sliver.indexOf(child);
      firstOffset = offset;
    }
    return _ShownRows(
      first: first,
      // Unbounded inside a shrink-wrapped list, so every row there animates.
      count: constraints.remainingPaintExtent / kMinInteractiveDimension,
      firstOffset: firstOffset,
      // Only a list scrolled past its top has rows above the screen.
      anchor: constraints.scrollOffset > 0 && first < _entries.length ? _entries[first].key : null,
    );
  }

  /// Opens or closes [motion] once the frame the update lands in has painted.
  /// Started during that frame, its clock would begin at the frame's start,
  /// so a long one, as a slow device's, would use the motion up before its
  /// first step shows and the row would snap open or shut.
  _RowMotion _runAfterFrame({required _RowMotion motion, required bool opening}) {
    if (_motionsAfterFrame.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final motions = [..._motionsAfterFrame];
        _motionsAfterFrame.clear();
        if (!mounted) return;
        for (final (:motion, :opening) in motions) {
          if (opening) {
            motion.controller.forward();
          } else {
            motion.controller.reverse();
          }
        }
      });
    }
    _motionsAfterFrame.add((motion: motion, opening: opening));
    return motion;
  }

  _RowMotion _startMotion({required _PregoAnimatedSliverItemKey key, required double from}) {
    final motion = _RowMotion(vsync: this, from: from);
    motion.controller.addStatusListener((status) => _onMotionStatus(key: key, motion: motion, status: status));
    return motion;
  }

  /// Settles a row that finished opening and drops one that finished closing.
  void _onMotionStatus({
    required _PregoAnimatedSliverItemKey key,
    required _RowMotion motion,
    required AnimationStatus status,
  }) {
    if (status.isAnimating) return;
    final index = _indexByKey[key];
    if (index == null) return;
    switch (_entries[index]) {
      case final _ShownEntry<T> shown when identical(shown.entering, motion) && status.isCompleted:
        setState(() {
          _entries[index] = _ShownEntry(
            key: shown.key,
            item: shown.item,
            sourceIndex: shown.sourceIndex,
            entering: null,
          );
        });
      case final _LeavingEntry<T> leaving when identical(leaving.leaving, motion) && status.isDismissed:
        setState(() => _setEntries([..._entries]..removeAt(index)));
      case _:
        return;
    }
    motion.dispose();
  }

  void _setEntries(List<_Entry<T>> entries) {
    _entries = entries;
    _indexByKey = {for (final (index, entry) in entries.indexed) entry.key: index};
  }

  @override
  void dispose() {
    for (final entry in _entries) {
      switch (entry) {
        case _ShownEntry(:final entering):
          entering?.dispose();
        case _LeavingEntry(:final leaving):
          leaving.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _PregoAnimatedSliverListView(
      delegate: SliverChildBuilderDelegate(
        (context, index) => switch (_entries[index]) {
          _ShownEntry(:final key, :final item, :final sourceIndex, :final entering) => _transition(
            key: key,
            animation: entering?.curve ?? kAlwaysCompleteAnimation,
            outgoing: false,
            child: widget.itemBuilder(context, sourceIndex, item),
          ),
          _LeavingEntry(:final key, :final item, :final sourceIndex, :final itemBuilder, :final leaving) => _transition(
            key: key,
            animation: leaving.curve,
            outgoing: true,
            child: itemBuilder(context, sourceIndex, item),
          ),
        },
        childCount: _entries.length,
        findChildIndexCallback: (key) => _indexByKey[key],
      ),
    );
  }

  List<Key> _keysOf(PregoAnimatedSliverList<T> source) {
    final keys = [for (final item in source.items) source.itemKey(item)];
    assert(() {
      final seen = <Key>{};
      for (final key in keys) {
        if (!seen.add(key)) {
          throw FlutterError("PregoAnimatedSliverList item keys must be unique. Duplicate key: ${key.toString()}");
        }
      }
      return true;
    }());
    return keys;
  }

  /// A leaving row keeps its live key and widget shape, so it updates the row
  /// already on screen instead of building a new one.
  Widget _transition({
    required Key key,
    required Animation<double> animation,
    required bool outgoing,
    required Widget child,
  }) {
    return SizeTransition(
      key: key,
      sizeFactor: animation,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: animation,
        child: ExcludeSemantics(
          excluding: outgoing,
          child: ExcludeFocus(
            excluding: outgoing,
            child: IgnorePointer(ignoring: outgoing, child: child),
          ),
        ),
      ),
    );
  }
}

/// The rows a list's visible extent showed: up to [count] of them from index
/// [first], laid out at [firstOffset], and that first row's [anchor] key while
/// the list is scrolled past its top.
final class const _ShownRows({
  required final int first,
  required final double count,
  required final double firstOffset,
  required final _PregoAnimatedSliverItemKey? anchor,
}) {
  bool contains(int index) => index >= first && index < first + count;
}

/// A [SliverList] whose rows can keep their place through an update.
class const _PregoAnimatedSliverListView({required super.delegate}) extends SliverList {
  @override
  _RenderPregoAnimatedSliverList createRenderObject(BuildContext context) => switch (context) {
    final SliverMultiBoxAdaptorElement element => _RenderPregoAnimatedSliverList(childManager: element),
    _ => throw StateError("A sliver list builds in its own SliverMultiBoxAdaptorElement."),
  };
}

/// A [RenderSliverList] that can keep one row where it stood.
///
/// The list's element moves a row to its new index but gives it the offset
/// laid out at that index, so rows inserted or removed above the screen shift
/// every row on it. The sliver lays out from its first row's offset, so giving
/// the kept row its own offset, and the rows laid out right above it theirs,
/// holds the screen still.
class _RenderPregoAnimatedSliverList({required super.childManager}) extends RenderSliverList {
  ({int index, double offset})? _kept;

  /// Lays out the row now at [index] at the scroll [offset] it had before.
  void keepRow({required int index, required double offset}) {
    _kept = (index: index, offset: offset);
    markNeedsLayout();
  }

  @override
  void performLayout() {
    if (_kept case (:final index, :final offset)) {
      _kept = null;
      _place(index: index, offset: offset);
    }
    super.performLayout();
  }

  void _place({required int index, required double offset}) {
    var kept = lastChild;
    while (kept != null && indexOf(kept) > index) {
      kept = childBefore(kept);
    }
    if (kept == null || indexOf(kept) != index) return;
    _setLayoutOffset(child: kept, offset: offset);
    // The unbroken run of laid-out rows above it stays stacked on it. The
    // rest lose their offset, so the sliver drops them and builds what it
    // needs above that run again.
    var above = offset;
    var nextIndex = index;
    var adjoining = true;
    for (var previous = childBefore(kept); previous != null; previous = childBefore(previous)) {
      adjoining =
          adjoining && indexOf(previous) == nextIndex - 1 && previous.hasSize && paintExtentOf(previous) <= above;
      nextIndex = indexOf(previous);
      if (adjoining) above -= paintExtentOf(previous);
      _setLayoutOffset(child: previous, offset: adjoining ? above : null);
    }
  }

  static void _setLayoutOffset({required RenderBox child, required double? offset}) {
    if (child.parentData case final SliverMultiBoxAdaptorParentData parentData) parentData.layoutOffset = offset;
  }
}

/// A row's open or close animation. Only rows on screen get one.
final class _RowMotion({required TickerProvider vsync, required double from}) {
  final AnimationController controller = AnimationController(
    vsync: vsync,
    duration: pregoAnimatedListItemDuration,
    value: from,
  );
  late final CurvedAnimation curve = CurvedAnimation(parent: controller, curve: Curves.easeInOutCubic);

  void dispose() {
    curve.dispose();
    controller.dispose();
  }
}

/// A row of the sliver: [item] at [sourceIndex] of the list that last held it.
sealed class const _Entry<T>({
  required final _PregoAnimatedSliverItemKey key,
  required final T item,
  required final int sourceIndex,
});

/// A row present in the source list, opening while [entering] runs.
final class const _ShownEntry<T>({
  required super.key,
  required super.item,
  required super.sourceIndex,
  required final _RowMotion? entering,
}) extends _Entry<T>;

/// A row that left the source list and stays until [leaving] closes it, built
/// as its last list built it.
final class const _LeavingEntry<T>({
  required super.key,
  required super.item,
  required super.sourceIndex,
  required final Widget Function(BuildContext context, int index, T item) itemBuilder,
  required final _RowMotion leaving,
}) extends _Entry<T>;

class const _PregoAnimatedSliverItemKey(super.value) extends ValueKey<(Key, int)>;
