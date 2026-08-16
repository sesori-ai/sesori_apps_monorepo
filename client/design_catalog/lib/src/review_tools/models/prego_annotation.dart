import "package:flutter/foundation.dart";

@immutable
final class const PregoAnnotationScope({
  required final String useCasePath,
  required final String viewportName,
}) {
  String get identity => "$useCasePath::$viewportName";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PregoAnnotationScope && useCasePath == other.useCasePath && viewportName == other.viewportName;

  @override
  int get hashCode => Object.hash(useCasePath, viewportName);
}

sealed class const PregoAnnotationAnchor();

final class const PregoCanvasAnnotationAnchor({
  required final double normalizedX,
  required final double normalizedY,
}) extends PregoAnnotationAnchor;

final class PregoElementAnnotationAnchor({
  required List<int> targetPath,
  required final double relativeX,
  required final double relativeY,
  required final double fallbackX,
  required final double fallbackY,
}) extends PregoAnnotationAnchor {
  final List<int> targetPath = List.unmodifiable(targetPath);
}

@immutable
final class const PregoAnnotation({
  required final String id,
  required final String body,
  required final bool resolved,
  required final PregoAnnotationAnchor anchor,
}) {
  PregoAnnotation withBody({required String body}) => PregoAnnotation(
    id: id,
    body: body,
    resolved: resolved,
    anchor: anchor,
  );

  PregoAnnotation withResolved({required bool resolved}) => PregoAnnotation(
    id: id,
    body: body,
    resolved: resolved,
    anchor: anchor,
  );
}

@immutable
final class PregoAnnotationDocument {
  // ignore: unnecessary_type_name_in_constructor, use_primary_constructors
  PregoAnnotationDocument({
    required this.scope,
    required List<PregoAnnotation> annotations,
  }) : annotations = List.unmodifiable(annotations);

  // ignore: unnecessary_type_name_in_constructor
  factory PregoAnnotationDocument.empty({required PregoAnnotationScope scope}) =>
      PregoAnnotationDocument(scope: scope, annotations: const []);

  final PregoAnnotationScope scope;
  final List<PregoAnnotation> annotations;

  PregoAnnotationDocument replaceAnnotations({required List<PregoAnnotation> annotations}) =>
      PregoAnnotationDocument(scope: scope, annotations: annotations);
}
