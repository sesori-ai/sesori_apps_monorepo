import "package:flutter_test/flutter_test.dart";
import "package:sesori_design_catalog/src/review_tools/models/prego_annotation.dart";
import "package:sesori_design_catalog/src/review_tools/repositories/prego_annotation_repository.dart";
import "package:sesori_design_catalog/src/review_tools/storage/prego_annotation_storage.dart";

void main() {
  const scope = PregoAnnotationScope(
    useCasePath: "prego/solid-button/playground",
    viewportName: "iPhone 16 Pro",
  );
  const otherScope = PregoAnnotationScope(
    useCasePath: "prego/solid-button/playground",
    viewportName: "Google Pixel 10 Pro",
  );

  test("round-trips canvas and element annotations in a scope-keyed document", () async {
    final values = <String, String>{};
    final repository = _repository(values);
    final document = PregoAnnotationDocument(
      scope: scope,
      annotations: [
        const PregoAnnotation(
          id: "canvas-note",
          body: "Check the overall balance",
          resolved: false,
          anchor: PregoCanvasAnnotationAnchor(normalizedX: 0.25, normalizedY: 0.75),
        ),
        PregoAnnotation(
          id: "button-note",
          body: "Verify this spacing",
          resolved: true,
          anchor: PregoElementAnnotationAnchor(
            targetPath: [0, 2, 1],
            relativeX: 0.5,
            relativeY: 0.4,
            fallbackX: 0.6,
            fallbackY: 0.7,
          ),
        ),
      ],
    );

    await repository.replace(document: document);
    final loaded = await repository.load(scope: scope);
    final unrelated = await repository.load(scope: otherScope);

    expect(values, hasLength(1));
    expect(loaded.scope, scope);
    expect(loaded.annotations, hasLength(2));
    expect(loaded.annotations.first.body, "Check the overall balance");
    expect(loaded.annotations.first.anchor, isA<PregoCanvasAnnotationAnchor>());
    final element = loaded.annotations.last.anchor as PregoElementAnnotationAnchor;
    expect(element.targetPath, [0, 2, 1]);
    expect(element.relativeX, 0.5);
    expect(loaded.annotations.last.resolved, isTrue);
    expect(unrelated.annotations, isEmpty);
  });

  test("leaves corrupted storage unchanged and reports the recovery path", () async {
    final values = <String, String>{};
    final repository = _repository(values);
    await repository.replace(document: PregoAnnotationDocument.empty(scope: scope));
    final key = values.keys.single;
    values[key] = "{not-json";

    await expectLater(
      repository.load(scope: scope),
      throwsA(
        isA<PregoAnnotationRepositoryException>().having(
          (error) => error.message,
          "message",
          "Stored annotation data is invalid and was left unchanged.",
        ),
      ),
    );
    expect(values[key], "{not-json");
  });

  test("rejects malformed and mismatched imports without writing storage", () {
    final values = <String, String>{};
    final repository = _repository(values);
    final otherDocument = PregoAnnotationDocument.empty(scope: otherScope);

    expect(
      () => repository.validateImport(
        scope: scope,
        encoded: repository.exportJson(document: otherDocument),
      ),
      throwsA(
        isA<PregoAnnotationRepositoryException>().having(
          (error) => error.message,
          "message",
          "That JSON belongs to a different component or viewport.",
        ),
      ),
    );
    expect(
      () => repository.validateImport(scope: scope, encoded: "[]"),
      throwsA(
        isA<PregoAnnotationRepositoryException>().having(
          (error) => error.message,
          "message",
          "That JSON is not a valid annotation document.",
        ),
      ),
    );
    expect(values, isEmpty);
  });

  test("wraps storage read and write failures with their original causes", () async {
    final readCause = StateError("read blocked");
    final writeCause = StateError("write blocked");
    final readRepository = PregoAnnotationRepository(
      storage: PregoAnnotationStorage.test(
        read: (_) async => throw readCause,
        write: (_, _) async {},
      ),
    );
    final writeRepository = PregoAnnotationRepository(
      storage: PregoAnnotationStorage.test(
        read: (_) async => null,
        write: (_, _) async => throw writeCause,
      ),
    );

    await expectLater(
      readRepository.load(scope: scope),
      throwsA(
        isA<PregoAnnotationRepositoryException>()
            .having((error) => error.message, "message", "Could not load local annotations.")
            .having((error) => error.cause, "cause", same(readCause)),
      ),
    );
    await expectLater(
      writeRepository.replace(document: PregoAnnotationDocument.empty(scope: scope)),
      throwsA(
        isA<PregoAnnotationRepositoryException>()
            .having((error) => error.message, "message", "Could not save annotations in this browser.")
            .having((error) => error.cause, "cause", same(writeCause)),
      ),
    );
  });
}

PregoAnnotationRepository _repository(Map<String, String> values) => PregoAnnotationRepository(
  storage: PregoAnnotationStorage.test(
    read: (key) async => values[key],
    write: (key, value) async => values[key] = value,
  ),
);
