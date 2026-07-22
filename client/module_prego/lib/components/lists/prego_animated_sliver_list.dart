import "package:flutter/material.dart";

import "../../motion/prego_reduced_motion.dart";

const Duration _itemTransitionDuration = Duration(milliseconds: 260);

/// A sliver list that reconciles keyed [items] and animates rows as they enter
/// or leave.
///
/// The caller owns the source list. This widget keeps only the presentation
/// snapshot needed by [SliverAnimatedList] so a removed row can collapse and
/// fade instead of disappearing between state emissions.
class PregoAnimatedSliverList<T> extends StatefulWidget {
  const PregoAnimatedSliverList({
    super.key,
    required this.items,
    required this.itemKey,
    required this.itemBuilder,
  });

  /// The items currently present in the source list.
  final List<T> items;

  /// Returns the stable, unique identity of an item across list updates.
  final Key Function(T item) itemKey;

  /// Builds an item at its current index.
  final Widget Function(BuildContext context, int index, T item) itemBuilder;

  @override
  State<PregoAnimatedSliverList<T>> createState() => _PregoAnimatedSliverListState<T>();
}

class _PregoAnimatedSliverListState<T> extends State<PregoAnimatedSliverList<T>> {
  final GlobalKey<SliverAnimatedListState> _listKey = GlobalKey<SliverAnimatedListState>();
  late List<_ListEntry<T>> _entries;

  @override
  void initState() {
    super.initState();
    _entries = _entriesFor(widget);
  }

  @override
  void didUpdateWidget(PregoAnimatedSliverList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    final nextEntries = _entriesFor(widget);
    final listState = _listKey.currentState;
    if (listState == null) {
      _entries = nextEntries;
      return;
    }

    final duration = prefersReducedMotion(context) ? Duration.zero : _itemTransitionDuration;
    final nextKeys = nextEntries.map((entry) => entry.key).toSet();

    // Remove from the end so each index still addresses the old list while it
    // is being shortened. The outgoing builder captures the old row snapshot.
    for (var index = _entries.length - 1; index >= 0; index--) {
      final entry = _entries[index];
      if (nextKeys.contains(entry.key)) continue;

      _entries.removeAt(index);
      final outgoingKey = UniqueKey();
      listState.removeItem(
        index,
        (context, animation) => _transition(
          key: outgoingKey,
          animation: animation,
          child: ExcludeSemantics(
            child: IgnorePointer(
              child: oldWidget.itemBuilder(context, index, entry.item),
            ),
          ),
        ),
        duration: duration,
      );
    }

    // Reorder retained entries before inserting new ones. The sliver's child
    // index callback relocates their keyed elements without losing row state.
    final retainedKeys = _entries.map((entry) => entry.key).toSet();
    _entries = [
      for (final entry in nextEntries)
        if (retainedKeys.contains(entry.key)) entry,
    ];

    for (var index = 0; index < nextEntries.length; index++) {
      final entry = nextEntries[index];
      if (retainedKeys.contains(entry.key)) continue;

      _entries.insert(index, entry);
      listState.insertItem(index, duration: duration);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SliverAnimatedList(
      key: _listKey,
      initialItemCount: _entries.length,
      findChildIndexCallback: (key) {
        if (key is! _PregoAnimatedSliverItemKey) return null;
        final index = _entries.indexWhere((entry) => entry.key == key.value);
        return index == -1 ? null : index;
      },
      itemBuilder: (context, index, animation) {
        final entry = _entries[index];
        return _transition(
          key: _PregoAnimatedSliverItemKey(entry.key),
          animation: animation,
          child: widget.itemBuilder(context, index, entry.item),
        );
      },
    );
  }

  List<_ListEntry<T>> _entriesFor(PregoAnimatedSliverList<T> source) {
    final entries = [for (final item in source.items) _ListEntry(key: source.itemKey(item), item: item)];
    assert(() {
      final keys = <Key>{};
      for (final entry in entries) {
        if (!keys.add(entry.key)) {
          throw FlutterError(
            "PregoAnimatedSliverList item keys must be unique. Duplicate key: ${entry.key.toString()}",
          );
        }
      }
      return true;
    }());
    return entries;
  }

  Widget _transition({required Key key, required Animation<double> animation, required Widget child}) {
    final curvedAnimation = CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic);
    return SizeTransition(
      key: key,
      sizeFactor: curvedAnimation,
      alignment: Alignment.topCenter,
      child: FadeTransition(opacity: curvedAnimation, child: child),
    );
  }
}

class _ListEntry<T> {
  const _ListEntry({required this.key, required this.item});

  final Key key;
  final T item;
}

class _PregoAnimatedSliverItemKey extends ValueKey<Key> {
  const _PregoAnimatedSliverItemKey(super.value);
}
