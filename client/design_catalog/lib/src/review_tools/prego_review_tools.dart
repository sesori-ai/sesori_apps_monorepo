import "package:flutter/widgets.dart";
import "package:widgetbook/widgetbook.dart";

import "../prego_catalog_inspector.dart";
import "models/prego_annotation.dart";
import "presentation/prego_annotation_layer.dart";
import "presentation/prego_measurement_layer.dart";
import "repositories/prego_annotation_repository.dart";
import "storage/prego_annotation_storage.dart";

enum PregoReviewMode() {
  interact,
  inspect,
  measure,
  annotate;
}

final class PregoReviewToolsAddon({PregoAnnotationRepository? repository}) extends WidgetbookAddon<PregoReviewMode> {
  this : super(name: "Review tools");

  final PregoAnnotationRepository repository =
      repository ?? PregoAnnotationRepository(storage: PregoAnnotationStorage.forPlatform());

  @override
  List<Field<PregoReviewMode>> get fields => [
    ObjectDropdownField<PregoReviewMode>(
      name: "mode",
      values: PregoReviewMode.values,
      initialValue: PregoReviewMode.interact,
      labelBuilder: _modeLabel,
    ),
  ];

  @override
  PregoReviewMode valueFromQueryGroup(Map<String, String> group) =>
      valueOf<PregoReviewMode>("mode", group) ?? PregoReviewMode.interact;

  @override
  Widget buildUseCase(BuildContext context, Widget child, PregoReviewMode setting) {
    final state = WidgetbookState.of(context);
    final viewportGroup = FieldCodec.decodeQueryGroup(state.queryParams["viewport"]);
    final scope = PregoAnnotationScope(
      useCasePath: state.path ?? "unknown-use-case",
      viewportName: viewportGroup["name"] ?? "None",
    );
    return PregoReviewToolsScope(
      mode: setting,
      annotationScope: scope,
      repository: repository,
      child: setting == PregoReviewMode.inspect ? PregoCatalogInspector(child: child) : child,
    );
  }
}

class const PregoReviewToolsScope({
  required final PregoReviewMode mode,
  required final PregoAnnotationScope annotationScope,
  required final PregoAnnotationRepository repository,
  required super.child,
  super.key,
}) extends InheritedWidget {
  static PregoReviewToolsScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PregoReviewToolsScope>();
    if (scope == null) throw StateError("PregoReviewToolsScope is missing above the review surface");
    return scope;
  }

  @override
  bool updateShouldNotify(PregoReviewToolsScope oldWidget) =>
      mode != oldWidget.mode || annotationScope != oldWidget.annotationScope || repository != oldWidget.repository;
}

Widget buildPregoReviewSurface(BuildContext context, {required Widget child}) {
  final tools = PregoReviewToolsScope.of(context);
  // This key is the sole transition owner. Changing tool, use case, or viewport
  // discards transient drags/editors; saved annotations reload for the new scope.
  final key = ValueKey("${tools.annotationScope.identity}:${tools.mode.name}");
  return switch (tools.mode) {
    PregoReviewMode.interact || PregoReviewMode.inspect => KeyedSubtree(key: key, child: child),
    PregoReviewMode.measure => PregoMeasurementLayer(key: key, child: child),
    PregoReviewMode.annotate => PregoAnnotationLayer(
      key: key,
      scope: tools.annotationScope,
      repository: tools.repository,
      child: child,
    ),
  };
}

String _modeLabel(PregoReviewMode mode) => switch (mode) {
  PregoReviewMode.interact => "Interact",
  PregoReviewMode.inspect => "Inspect",
  PregoReviewMode.measure => "Measure",
  PregoReviewMode.annotate => "Annotate",
};
