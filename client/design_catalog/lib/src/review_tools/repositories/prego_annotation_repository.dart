// JSON decoding and retained exception causes are Object?-typed SDK boundaries.
// ignore_for_file: no_slop_linter/prefer_specific_type

import "dart:convert";

import "../models/prego_annotation.dart";
import "../storage/prego_annotation_storage.dart";

const _schemaVersion = 1;
const _storagePrefix = "sesori.design_catalog.annotations.v1";

final class PregoAnnotationRepository({required final PregoAnnotationStorage storage}) {
  Future<PregoAnnotationDocument> load({required PregoAnnotationScope scope}) async {
    final String? encoded;
    try {
      encoded = await storage.read(key: _storageKey(scope));
    } on Object catch (error) {
      throw PregoAnnotationRepositoryException(message: "Could not load local annotations.", cause: error);
    }
    if (encoded == null) return PregoAnnotationDocument.empty(scope: scope);
    try {
      return _decodeDocument(encoded: encoded, expectedScope: scope);
    } on Object catch (error) {
      throw PregoAnnotationRepositoryException(
        message: "Stored annotation data is invalid and was left unchanged.",
        cause: error,
      );
    }
  }

  Future<void> replace({required PregoAnnotationDocument document}) async {
    try {
      await storage.write(
        key: _storageKey(document.scope),
        value: exportJson(document: document),
      );
    } on Object catch (error) {
      throw PregoAnnotationRepositoryException(message: "Could not save annotations in this browser.", cause: error);
    }
  }

  String exportJson({required PregoAnnotationDocument document}) => const JsonEncoder.withIndent("  ").convert(
    {
      "schemaVersion": _schemaVersion,
      "scope": {"useCasePath": document.scope.useCasePath, "viewportName": document.scope.viewportName},
      "annotations": document.annotations.map(_annotationToJson).toList(),
    },
  );

  PregoAnnotationDocument validateImport({required PregoAnnotationScope scope, required String encoded}) {
    try {
      return _decodeDocument(encoded: encoded, expectedScope: scope);
    } on _PregoAnnotationScopeMismatch catch (error) {
      throw PregoAnnotationRepositoryException(
        message: "That JSON belongs to a different component or viewport.",
        cause: error,
      );
    } on Object catch (error) {
      throw PregoAnnotationRepositoryException(message: "That JSON is not a valid annotation document.", cause: error);
    }
  }

  String _storageKey(PregoAnnotationScope scope) =>
      "$_storagePrefix.${Uri.encodeComponent(scope.useCasePath)}.${Uri.encodeComponent(scope.viewportName)}";

  PregoAnnotationDocument _decodeDocument({
    required String encoded,
    required PregoAnnotationScope expectedScope,
  }) {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, Object?>) throw const FormatException("Document must be an object");
    if (decoded["schemaVersion"] != _schemaVersion) {
      throw const FormatException("Unsupported schema version");
    }
    final scopeJson = decoded["scope"];
    if (scopeJson is! Map<String, Object?>) throw const FormatException("Missing scope");
    final scope = PregoAnnotationScope(
      useCasePath: _requiredString(value: scopeJson, key: "useCasePath"),
      viewportName: _requiredString(value: scopeJson, key: "viewportName"),
    );
    if (scope != expectedScope) throw const _PregoAnnotationScopeMismatch();
    final annotationsJson = decoded["annotations"];
    if (annotationsJson is! List<Object?>) throw const FormatException("Missing annotations");
    final annotations = annotationsJson.map(_annotationFromJson).toList();
    if (annotations.map((annotation) => annotation.id).toSet().length != annotations.length) {
      throw const FormatException("Annotation identifiers must be unique");
    }
    return PregoAnnotationDocument(scope: scope, annotations: annotations);
  }

  Map<String, Object?> _annotationToJson(PregoAnnotation annotation) => {
    "id": annotation.id,
    "body": annotation.body,
    "resolved": annotation.resolved,
    "anchor": switch (annotation.anchor) {
      PregoCanvasAnnotationAnchor(:final normalizedX, :final normalizedY) => {
        "type": "canvas",
        "normalizedX": normalizedX,
        "normalizedY": normalizedY,
      },
      PregoElementAnnotationAnchor(
        :final targetPath,
        :final relativeX,
        :final relativeY,
        :final fallbackX,
        :final fallbackY,
      ) =>
        {
          "type": "element",
          "targetPath": targetPath,
          "relativeX": relativeX,
          "relativeY": relativeY,
          "fallbackX": fallbackX,
          "fallbackY": fallbackY,
        },
    },
  };

  PregoAnnotation _annotationFromJson(Object? value) {
    if (value is! Map<String, Object?>) throw const FormatException("Annotation must be an object");
    final body = _requiredString(value: value, key: "body").trim();
    if (body.isEmpty) throw const FormatException("Annotation body must not be empty");
    final resolved = value["resolved"];
    if (resolved is! bool) throw const FormatException("Annotation resolved state must be a boolean");
    final anchorJson = value["anchor"];
    if (anchorJson is! Map<String, Object?>) throw const FormatException("Annotation anchor is missing");
    return PregoAnnotation(
      id: _requiredString(value: value, key: "id"),
      body: body,
      resolved: resolved,
      anchor: _anchorFromJson(anchorJson),
    );
  }

  PregoAnnotationAnchor _anchorFromJson(Map<String, Object?> value) => switch (value["type"]) {
    "canvas" => PregoCanvasAnnotationAnchor(
      normalizedX: _normalizedDouble(value: value, key: "normalizedX"),
      normalizedY: _normalizedDouble(value: value, key: "normalizedY"),
    ),
    "element" => PregoElementAnnotationAnchor(
      targetPath: _targetPath(value["targetPath"]),
      relativeX: _normalizedDouble(value: value, key: "relativeX"),
      relativeY: _normalizedDouble(value: value, key: "relativeY"),
      fallbackX: _normalizedDouble(value: value, key: "fallbackX"),
      fallbackY: _normalizedDouble(value: value, key: "fallbackY"),
    ),
    _ => throw const FormatException("Unknown annotation anchor type"),
  };

  String _requiredString({required Map<String, Object?> value, required String key}) {
    final field = value[key];
    if (field is! String || field.isEmpty) throw FormatException("$key must be a non-empty string");
    return field;
  }

  double _normalizedDouble({required Map<String, Object?> value, required String key}) {
    final field = value[key];
    if (field is! num || !field.isFinite || field < 0 || field > 1) {
      throw FormatException("$key must be between 0 and 1");
    }
    return field.toDouble();
  }

  List<int> _targetPath(Object? value) {
    if (value is! List<Object?> || value.any((index) => index is! int || index < 0)) {
      throw const FormatException("targetPath must contain non-negative integers");
    }
    return value.cast<int>();
  }
}

final class const PregoAnnotationRepositoryException({
  required final String message,
  required final Object cause,
}) implements Exception;

final class const _PregoAnnotationScopeMismatch() implements Exception;
