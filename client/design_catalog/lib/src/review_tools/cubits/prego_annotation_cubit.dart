import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";

import "../models/prego_annotation.dart";
import "../repositories/prego_annotation_repository.dart";

sealed class const PregoAnnotationEditor();

final class const PregoAnnotationEditorClosed() extends PregoAnnotationEditor;

final class const PregoAnnotationDraftEditor({
  required final PregoAnnotationAnchor anchor,
  required final String body,
  required final String? validationError,
}) extends PregoAnnotationEditor;

final class const PregoAnnotationExistingEditor({
  required final String annotationId,
  required final String body,
  required final String? validationError,
}) extends PregoAnnotationEditor;

sealed class const PregoAnnotationImportEditor();

final class const PregoAnnotationImportInput({
  required final String encoded,
  required final String? validationError,
}) extends PregoAnnotationImportEditor;

final class const PregoAnnotationImportPreview({
  required final String encoded,
  required final PregoAnnotationDocument document,
}) extends PregoAnnotationImportEditor;

final class const PregoAnnotationImportReplaceFailed({
  required final String encoded,
  required final PregoAnnotationDocument document,
  required final String message,
}) extends PregoAnnotationImportEditor;

sealed class const PregoAnnotationState({required final PregoAnnotationScope scope});

final class const PregoAnnotationLoading({required super.scope}) extends PregoAnnotationState;

final class const PregoAnnotationLoadFailed({
  required super.scope,
  required final String message,
  required final PregoAnnotationImportEditor? importEditor,
}) extends PregoAnnotationState;

sealed class const PregoAnnotationReadyState({
  required super.scope,
  required final PregoAnnotationDocument document,
  required final PregoAnnotationEditor editor,
}) extends PregoAnnotationState;

final class const PregoAnnotationReady({
  required super.scope,
  required super.document,
  required super.editor,
}) extends PregoAnnotationReadyState;

final class const PregoAnnotationSaveFailed({
  required super.scope,
  required super.document,
  required super.editor,
  required final String message,
}) extends PregoAnnotationReadyState;

final class PregoAnnotationCubit({
  required PregoAnnotationRepository repository,
  required final PregoAnnotationScope scope,
}) extends Cubit<PregoAnnotationState> {
  this : super(PregoAnnotationLoading(scope: scope)) {
    unawaited(load());
  }

  final PregoAnnotationRepository _repository = repository;
  var _nextId = 0;

  Future<void> load() async {
    final scope = state.scope;
    emit(PregoAnnotationLoading(scope: scope));
    try {
      final document = await _repository.load(scope: scope);
      if (isClosed || state.scope != scope) return;
      emit(
        PregoAnnotationReady(
          scope: scope,
          document: document,
          editor: const PregoAnnotationEditorClosed(),
        ),
      );
    } on PregoAnnotationRepositoryException catch (error) {
      if (isClosed || state.scope != scope) return;
      emit(PregoAnnotationLoadFailed(scope: scope, message: error.message, importEditor: null));
    }
  }

  void startDraft({required PregoAnnotationAnchor anchor}) {
    final ready = _ready;
    if (ready == null) return;
    _emitReady(
      document: ready.document,
      editor: PregoAnnotationDraftEditor(anchor: anchor, body: "", validationError: null),
    );
  }

  void edit({required String annotationId}) {
    final ready = _ready;
    if (ready == null) return;
    final annotation = ready.document.annotations.where((item) => item.id == annotationId).firstOrNull;
    if (annotation == null) return;
    _emitReady(
      document: ready.document,
      editor: PregoAnnotationExistingEditor(
        annotationId: annotation.id,
        body: annotation.body,
        validationError: null,
      ),
    );
  }

  void updateEditorBody({required String body}) {
    final ready = _ready;
    if (ready == null) return;
    final editor = switch (ready.editor) {
      PregoAnnotationDraftEditor(:final anchor) => PregoAnnotationDraftEditor(
        anchor: anchor,
        body: body,
        validationError: null,
      ),
      PregoAnnotationExistingEditor(:final annotationId) => PregoAnnotationExistingEditor(
        annotationId: annotationId,
        body: body,
        validationError: null,
      ),
      PregoAnnotationEditorClosed() => null,
    };
    if (editor != null) _emitReady(document: ready.document, editor: editor);
  }

  void closeEditor() {
    final ready = _ready;
    if (ready == null) return;
    _emitReady(document: ready.document, editor: const PregoAnnotationEditorClosed());
  }

  Future<void> saveEditor() async {
    final ready = _ready;
    if (ready == null) return;
    final body = switch (ready.editor) {
      PregoAnnotationDraftEditor(:final body) || PregoAnnotationExistingEditor(:final body) => body.trim(),
      PregoAnnotationEditorClosed() => null,
    };
    if (body == null) return;
    if (body.isEmpty) {
      final editor = switch (ready.editor) {
        PregoAnnotationDraftEditor(:final anchor) => PregoAnnotationDraftEditor(
          anchor: anchor,
          body: "",
          validationError: "Write a note before saving.",
        ),
        PregoAnnotationExistingEditor(:final annotationId) => PregoAnnotationExistingEditor(
          annotationId: annotationId,
          body: "",
          validationError: "Write a note before saving.",
        ),
        PregoAnnotationEditorClosed() => throw StateError("Closed editor cannot be saved"),
      };
      _emitReady(document: ready.document, editor: editor);
      return;
    }

    final annotations = [...ready.document.annotations];
    switch (ready.editor) {
      case PregoAnnotationDraftEditor(:final anchor):
        annotations.add(
          PregoAnnotation(
            id: _createId(),
            body: body,
            resolved: false,
            anchor: anchor,
          ),
        );
      case PregoAnnotationExistingEditor(:final annotationId):
        final index = annotations.indexWhere((annotation) => annotation.id == annotationId);
        if (index < 0) return;
        annotations[index] = annotations[index].withBody(body: body);
      case PregoAnnotationEditorClosed():
        return;
    }
    await _persist(
      previous: ready,
      next: ready.document.replaceAnnotations(annotations: annotations),
      successEditor: const PregoAnnotationEditorClosed(),
    );
  }

  Future<void> toggleResolved({required String annotationId}) async {
    final ready = _ready;
    if (ready == null) return;
    final editedEditor = switch (ready.editor) {
      final PregoAnnotationExistingEditor editor when editor.annotationId == annotationId => editor,
      PregoAnnotationDraftEditor() || PregoAnnotationExistingEditor() || PregoAnnotationEditorClosed() => null,
    };
    final editedBody = editedEditor?.body.trim();
    if (editedEditor case final editor? when editor.body.trim().isEmpty) {
      _emitReady(
        document: ready.document,
        editor: PregoAnnotationExistingEditor(
          annotationId: editor.annotationId,
          body: editor.body,
          validationError: "Write a note before saving.",
        ),
      );
      return;
    }
    final annotations = [
      for (final annotation in ready.document.annotations)
        annotation.id == annotationId
            ? (editedBody == null ? annotation : annotation.withBody(body: editedBody)).withResolved(
                resolved: !annotation.resolved,
              )
            : annotation,
    ];
    await _persist(
      previous: ready,
      next: ready.document.replaceAnnotations(annotations: annotations),
      successEditor: ready.editor,
    );
  }

  Future<void> delete({required String annotationId}) async {
    final ready = _ready;
    if (ready == null) return;
    final annotations = ready.document.annotations.where((annotation) => annotation.id != annotationId).toList();
    if (annotations.length == ready.document.annotations.length) return;
    await _persist(
      previous: ready,
      next: ready.document.replaceAnnotations(annotations: annotations),
      successEditor: const PregoAnnotationEditorClosed(),
    );
  }

  String? exportJson() {
    final ready = _ready;
    return ready == null ? null : _repository.exportJson(document: ready.document);
  }

  void startImport() {
    const importEditor = PregoAnnotationImportInput(encoded: "", validationError: null);
    switch (state) {
      case final PregoAnnotationReadyState ready:
        emit(PregoAnnotationImporting.fromReady(ready: ready, importEditor: importEditor));
      case final PregoAnnotationLoadFailed failed:
        emit(
          PregoAnnotationLoadFailed(
            scope: failed.scope,
            message: failed.message,
            importEditor: importEditor,
          ),
        );
      case PregoAnnotationLoading():
        break;
    }
  }

  void updateImportJson({required String encoded}) {
    final importEditor = PregoAnnotationImportInput(encoded: encoded, validationError: null);
    switch (state) {
      case final PregoAnnotationImporting importing:
        emit(PregoAnnotationImporting.fromReady(ready: importing, importEditor: importEditor));
      case final PregoAnnotationLoadFailed failed when failed.importEditor != null:
        emit(
          PregoAnnotationLoadFailed(
            scope: failed.scope,
            message: failed.message,
            importEditor: importEditor,
          ),
        );
      case PregoAnnotationLoading() ||
          PregoAnnotationLoadFailed() ||
          PregoAnnotationReady() ||
          PregoAnnotationSaveFailed():
        break;
    }
  }

  void validateImport() {
    final importEditor = _importEditor;
    if (importEditor is! PregoAnnotationImportInput) return;
    try {
      final document = _repository.validateImport(scope: state.scope, encoded: importEditor.encoded);
      _replaceImportEditor(
        PregoAnnotationImportPreview(
          encoded: importEditor.encoded,
          document: document,
        ),
      );
    } on PregoAnnotationRepositoryException catch (error) {
      _replaceImportEditor(PregoAnnotationImportInput(encoded: importEditor.encoded, validationError: error.message));
    }
  }

  Future<void> replaceImport() async {
    final importEditor = _importEditor;
    final String encoded;
    final PregoAnnotationDocument document;
    switch (importEditor) {
      case PregoAnnotationImportPreview(encoded: final value, document: final valueDocument) ||
          PregoAnnotationImportReplaceFailed(encoded: final value, document: final valueDocument):
        encoded = value;
        document = valueDocument;
      case PregoAnnotationImportInput() || null:
        return;
    }
    try {
      // This is the annotation repository persistence API, not GoRouter navigation.
      // ignore: no_slop_linter/avoid_raw_go_router
      await _repository.replace(document: document);
      if (isClosed) return;
      emit(
        PregoAnnotationReady(
          scope: state.scope,
          document: document,
          editor: const PregoAnnotationEditorClosed(),
        ),
      );
    } on PregoAnnotationRepositoryException catch (error) {
      if (isClosed) return;
      if (state case final PregoAnnotationImporting importing) {
        emit(
          PregoAnnotationImporting.fromReady(
            ready: importing,
            importEditor: PregoAnnotationImportReplaceFailed(
              encoded: encoded,
              document: document,
              message: error.message,
            ),
          ),
        );
      } else {
        emit(
          PregoAnnotationLoadFailed(
            scope: state.scope,
            message: error.message,
            importEditor: PregoAnnotationImportReplaceFailed(
              encoded: encoded,
              document: document,
              message: error.message,
            ),
          ),
        );
      }
    }
  }

  void cancelImport() {
    switch (state) {
      case final PregoAnnotationImporting importing:
        emit(
          PregoAnnotationReady(
            scope: importing.scope,
            document: importing.document,
            editor: const PregoAnnotationEditorClosed(),
          ),
        );
      case final PregoAnnotationLoadFailed failed:
        emit(PregoAnnotationLoadFailed(scope: failed.scope, message: failed.message, importEditor: null));
      case PregoAnnotationLoading() || PregoAnnotationReady() || PregoAnnotationSaveFailed():
        break;
    }
  }

  PregoAnnotationReadyState? get _ready => switch (state) {
    final PregoAnnotationReady ready => ready,
    final PregoAnnotationSaveFailed ready => ready,
    PregoAnnotationLoading() || PregoAnnotationLoadFailed() || PregoAnnotationImporting() => null,
  };

  PregoAnnotationImportEditor? get _importEditor => switch (state) {
    PregoAnnotationImporting(:final importEditor) => importEditor,
    PregoAnnotationLoadFailed(:final importEditor) => importEditor,
    PregoAnnotationLoading() || PregoAnnotationReady() || PregoAnnotationSaveFailed() => null,
  };

  void _replaceImportEditor(PregoAnnotationImportEditor importEditor) {
    switch (state) {
      case final PregoAnnotationImporting importing:
        emit(PregoAnnotationImporting.fromReady(ready: importing, importEditor: importEditor));
      case final PregoAnnotationLoadFailed failed:
        emit(
          PregoAnnotationLoadFailed(
            scope: failed.scope,
            message: failed.message,
            importEditor: importEditor,
          ),
        );
      case PregoAnnotationLoading() || PregoAnnotationReady() || PregoAnnotationSaveFailed():
        break;
    }
  }

  void _emitReady({required PregoAnnotationDocument document, required PregoAnnotationEditor editor}) {
    emit(PregoAnnotationReady(scope: state.scope, document: document, editor: editor));
  }

  Future<void> _persist({
    required PregoAnnotationReadyState previous,
    required PregoAnnotationDocument next,
    required PregoAnnotationEditor successEditor,
  }) async {
    try {
      // This is the annotation repository persistence API, not GoRouter navigation.
      // ignore: no_slop_linter/avoid_raw_go_router
      await _repository.replace(document: next);
      if (isClosed || state.scope != next.scope) return;
      emit(PregoAnnotationReady(scope: next.scope, document: next, editor: successEditor));
    } on PregoAnnotationRepositoryException catch (error) {
      if (isClosed || state.scope != previous.scope) return;
      emit(
        PregoAnnotationSaveFailed(
          scope: previous.scope,
          document: previous.document,
          editor: previous.editor,
          message: error.message,
        ),
      );
    }
  }

  String _createId() => "${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${_nextId++}";
}

final class const PregoAnnotationImporting({
  required super.scope,
  required super.document,
  required super.editor,
  required final PregoAnnotationImportEditor importEditor,
}) extends PregoAnnotationReadyState {
  factory fromReady({
    required PregoAnnotationReadyState ready,
    required PregoAnnotationImportEditor importEditor,
  }) => PregoAnnotationImporting(
    scope: ready.scope,
    document: ready.document,
    editor: const PregoAnnotationEditorClosed(),
    importEditor: importEditor,
  );
}
