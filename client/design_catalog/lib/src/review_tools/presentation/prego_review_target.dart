import "package:flutter/rendering.dart";

final class PregoReviewTarget({
  required final RenderBox renderBox,
  required final String label,
  required final int depth,
  required List<int> path,
}) {
  final List<int> path = List.unmodifiable(path);

  Rect rectIn({required RenderBox root}) => MatrixUtils.transformRect(
    renderBox.getTransformTo(root),
    Offset.zero & renderBox.size,
  );
}

final class const PregoReviewTargetResolver();

extension PregoReviewTargetResolverOperations on PregoReviewTargetResolver {
  List<PregoReviewTarget> findAt({
    required RenderObject contentRoot,
    required Offset globalPosition,
  }) {
    final candidates = <PregoReviewTarget>[];
    _visit(
      object: contentRoot,
      depth: 0,
      path: <int>[],
      onTarget: (target) {
        if (_containsGlobalPosition(box: target.renderBox, globalPosition: globalPosition)) {
          candidates.add(target);
        }
      },
    );
    candidates.sort(_compareTargets);
    return candidates;
  }

  List<PregoReviewTarget> collect({required RenderObject contentRoot}) {
    final candidates = <PregoReviewTarget>[];
    _visit(object: contentRoot, depth: 0, path: <int>[], onTarget: candidates.add);
    return candidates;
  }

  PregoReviewTarget? resolvePath({required RenderObject contentRoot, required List<int> path}) {
    RenderObject current = contentRoot;
    var depth = 0;
    for (final targetIndex in path) {
      if (_hidesSubtree(current)) return null;
      RenderObject? next;
      var index = 0;
      current.visitChildren((child) {
        if (index == targetIndex) next = child;
        index += 1;
      });
      final resolvedNext = next;
      if (resolvedNext == null) return null;
      current = resolvedNext;
      depth += 1;
    }
    if (_hidesSubtree(current)) return null;
    if (current case final RenderBox box when box.attached && box.hasSize && !box.size.isEmpty) {
      final label = _labelFor(box);
      if (label != null) return PregoReviewTarget(renderBox: box, label: label, depth: depth, path: path);
    }
    return null;
  }

  bool sameTargets({required List<PregoReviewTarget> first, required List<PregoReviewTarget> second}) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index += 1) {
      if (!identical(first[index].renderBox, second[index].renderBox)) return false;
    }
    return true;
  }

  void _visit({
    required RenderObject object,
    required int depth,
    required List<int> path,
    required ValueChanged<PregoReviewTarget> onTarget,
  }) {
    if (_hidesSubtree(object)) return;
    if (object case final RenderBox box when box.attached && box.hasSize && !box.size.isEmpty) {
      final label = _labelFor(box);
      if (label != null) {
        onTarget(PregoReviewTarget(renderBox: box, label: label, depth: depth, path: path));
      }
    }
    var childIndex = 0;
    object.visitChildren((child) {
      path.add(childIndex);
      _visit(object: child, depth: depth + 1, path: path, onTarget: onTarget);
      path.removeLast();
      childIndex += 1;
    });
  }

  bool _hidesSubtree(RenderObject object) => switch (object) {
    RenderOffstage(:final offstage) => offstage,
    RenderOpacity(:final opacity) => opacity == 0,
    _ => false,
  };

  // Comparator is a Dart collection callback and therefore has a positional signature.
  // ignore: no_slop_linter/prefer_required_named_parameters
  int _compareTargets(PregoReviewTarget first, PregoReviewTarget second) {
    final area = (first.renderBox.size.width * first.renderBox.size.height).compareTo(
      second.renderBox.size.width * second.renderBox.size.height,
    );
    return area != 0 ? area : second.depth.compareTo(first.depth);
  }

  bool _containsGlobalPosition({required RenderBox box, required Offset globalPosition}) {
    try {
      return (Offset.zero & box.size).contains(box.globalToLocal(globalPosition));
    } on Object {
      return false;
    }
  }

  String? _labelFor(RenderBox box) => switch (box) {
    RenderParagraph() => "Text",
    RenderSemanticsAnnotations() => "Semantic element",
    RenderSemanticsGestureHandler() => "Interactive element",
    RenderDecoratedBox() => "Decoration",
    RenderPadding() => "Padding",
    RenderConstrainedBox() => "Constraints",
    RenderFlex(:final direction) => direction == Axis.horizontal ? "Row" : "Column",
    RenderOpacity() => "Opacity",
    RenderClipRRect() => "Rounded clip",
    RenderPhysicalModel() => "Physical surface",
    _ => null,
  };
}
