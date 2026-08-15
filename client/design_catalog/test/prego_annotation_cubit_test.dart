import "package:flutter_test/flutter_test.dart";
import "package:sesori_design_catalog/src/review_tools/cubits/prego_annotation_cubit.dart";
import "package:sesori_design_catalog/src/review_tools/models/prego_annotation.dart";
import "package:sesori_design_catalog/src/review_tools/repositories/prego_annotation_repository.dart";
import "package:sesori_design_catalog/src/review_tools/storage/prego_annotation_storage.dart";

void main() {
  const scope = PregoAnnotationScope(
    useCasePath: "prego/solid-button/playground",
    viewportName: "iPhone 16 Pro",
  );

  test("creates, edits, resolves, exports, and deletes a persisted annotation", () async {
    final values = <String, String>{};
    final repository = _repository(values);
    final cubit = PregoAnnotationCubit(repository: repository, scope: scope);
    addTearDown(cubit.close);
    await _ready(cubit);

    cubit.startDraft(
      anchor: const PregoCanvasAnnotationAnchor(normalizedX: 0.2, normalizedY: 0.8),
    );
    cubit.updateEditorBody(body: "  Check alignment  ");
    await cubit.saveEditor();

    var state = cubit.state as PregoAnnotationReadyState;
    expect(state.document.annotations, hasLength(1));
    final id = state.document.annotations.single.id;
    expect(state.document.annotations.single.body, "Check alignment");
    expect(cubit.exportJson(), contains("Check alignment"));

    cubit.edit(annotationId: id);
    cubit.updateEditorBody(body: "Updated note");
    await cubit.saveEditor();
    await cubit.toggleResolved(annotationId: id);
    state = cubit.state as PregoAnnotationReadyState;
    expect(state.document.annotations.single.body, "Updated note");
    expect(state.document.annotations.single.resolved, isTrue);

    await cubit.delete(annotationId: id);
    state = cubit.state as PregoAnnotationReadyState;
    expect(state.document.annotations, isEmpty);
    expect((await repository.load(scope: scope)).annotations, isEmpty);
  });

  test("keeps a draft open with validation and storage errors", () async {
    var failWrites = false;
    final repository = PregoAnnotationRepository(
      storage: PregoAnnotationStorage.test(
        read: (_) async => null,
        write: (_, _) async {
          if (failWrites) throw StateError("quota");
        },
      ),
    );
    final cubit = PregoAnnotationCubit(repository: repository, scope: scope);
    addTearDown(cubit.close);
    await _ready(cubit);
    cubit.startDraft(
      anchor: const PregoCanvasAnnotationAnchor(normalizedX: 0.4, normalizedY: 0.4),
    );

    await cubit.saveEditor();
    var state = cubit.state as PregoAnnotationReadyState;
    expect(
      state.editor,
      isA<PregoAnnotationDraftEditor>().having(
        (editor) => editor.validationError,
        "validationError",
        "Write a note before saving.",
      ),
    );

    cubit.updateEditorBody(body: "Keep this draft");
    failWrites = true;
    await cubit.saveEditor();
    state = cubit.state as PregoAnnotationReadyState;
    expect(state, isA<PregoAnnotationSaveFailed>());
    expect(state.document.annotations, isEmpty);
    expect(
      state.editor,
      isA<PregoAnnotationDraftEditor>().having((editor) => editor.body, "body", "Keep this draft"),
    );
  });

  test("imports a validated replacement after corrupted local storage", () async {
    var stored = "{broken";
    final repository = PregoAnnotationRepository(
      storage: PregoAnnotationStorage.test(
        read: (_) async => stored,
        write: (_, value) async => stored = value,
      ),
    );
    final replacement = PregoAnnotationDocument(
      scope: scope,
      annotations: const [
        PregoAnnotation(
          id: "replacement",
          body: "Portable note",
          resolved: false,
          anchor: PregoCanvasAnnotationAnchor(normalizedX: 0.5, normalizedY: 0.5),
        ),
      ],
    );
    final cubit = PregoAnnotationCubit(repository: repository, scope: scope);
    addTearDown(cubit.close);
    await cubit.stream.firstWhere((state) => state is PregoAnnotationLoadFailed);

    cubit.startImport();
    cubit.updateImportJson(encoded: repository.exportJson(document: replacement));
    cubit.validateImport();
    expect(
      cubit.state,
      isA<PregoAnnotationLoadFailed>().having(
        (state) => state.importEditor,
        "importEditor",
        isA<PregoAnnotationImportPreview>(),
      ),
    );
    await cubit.replaceImport();

    final ready = cubit.state as PregoAnnotationReadyState;
    expect(ready.document.annotations.single.body, "Portable note");
    expect(stored, contains("Portable note"));
  });
}

Future<PregoAnnotationReadyState> _ready(PregoAnnotationCubit cubit) async {
  final current = cubit.state;
  if (current is PregoAnnotationReadyState) return current;
  final state = await cubit.stream.firstWhere((state) => state is PregoAnnotationReadyState);
  if (state is PregoAnnotationReadyState) return state;
  throw StateError("Ready state filter returned another annotation state");
}

PregoAnnotationRepository _repository(Map<String, String> values) => PregoAnnotationRepository(
  storage: PregoAnnotationStorage.test(
    read: (key) async => values[key],
    write: (key, value) async => values[key] = value,
  ),
);
