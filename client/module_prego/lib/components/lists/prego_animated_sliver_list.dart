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
    final nextKeySet = nextKeys.toSet();
    final landsOnScreen = prefersReducedMotion(context) ? (int _) => false : _landsOnScreen();

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
    for (final (index, entry) in _entries.indexed) {
      final (itemKey, generation) = entry.key.value;
      final _Entry<T> closing;
      switch (entry) {
        case _ShownEntry<T>() when nextKeySet.contains(itemKey):
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
            leaving: (entering ?? _startMotion(key: entry.key, from: 1))..controller.reverse(),
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
    for (final (index, item) in widget.items.indexed) {
      final itemKey = nextKeys[index];
      switch (retained[itemKey]) {
        case final kept?:
          entries.add(_ShownEntry(key: kept.key, item: item, sourceIndex: index, entering: kept.entering));
        case null:
          final key = _PregoAnimatedSliverItemKey((itemKey, (generations[itemKey] ?? -1) + 1));
          final entering = landsOnScreen(index) ? (_startMotion(key: key, from: 0)..controller.forward()) : null;
          entries.add(_ShownEntry(key: key, item: item, sourceIndex: index, entering: entering));
      }
      entries.addAll(closingAfter[itemKey] ?? const []);
    }
    _setEntries(entries);
  }

  /// Whether a row at an index lands in the list's visible extent, so its
  /// entry or exit is worth animating. A row that leaves is checked at its
  /// old index and one that enters at its new one: the sliver keeps each
  /// laid-out offset with its index, so the indices on screen stay the same.
  ///
  /// An animated row enters at zero height, so all of them fit in the first
  /// frame after a filter change and the list would build every one at once.
  /// Rows outside the visible extent enter at full size instead and build
  /// lazily as they scroll in, and leave at once instead of each ticking a
  /// transition nobody sees. Rows are tap targets, so none is shorter than
  /// [kMinInteractiveDimension], which bounds how many the extent can show.
  /// The window is therefore an upper bound: taller rows leave some off-screen
  /// rows in it, and those still animate.
  bool Function(int index) _landsOnScreen() {
    final sliver = context.findRenderObject();
    // A list that is not laid out, such as one kept offstage, shows no rows.
    if (sliver is! RenderSliverMultiBoxAdaptor || sliver.geometry == null) return (_) => false;

    final constraints = sliver.constraints;
    // The last built row starting at or above the top edge is the first one
    // visible.
    var firstVisible = 0;
    for (var child = sliver.firstChild; child != null; child = sliver.childAfter(child)) {
      if ((sliver.childScrollOffset(child) ?? 0) > constraints.scrollOffset) break;
      firstVisible = sliver.indexOf(child);
    }
    // Unbounded inside a shrink-wrapped list, so every row there animates.
    final visibleRows = constraints.remainingPaintExtent / kMinInteractiveDimension;
    return (index) => index >= firstVisible && index < firstVisible + visibleRows;
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
    return SliverList(
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
