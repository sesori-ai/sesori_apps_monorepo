import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesori_mobile/features/session_diffs/utils/diff_highlighter.dart';

void main() {
  group('DiffHighlighter', () {
    // These tests run before initialization and rely on _initialized == false.
    // They must come first, before the setUpAll in the 'after initialization' group.
    test('highlightLine returns null before initialization', () {
      // Highlighter is not yet initialized at this point.
      final span = DiffHighlighter.highlightLine(content: 'void main() {}', language: 'dart');
      expect(span, isNull);
    });

    test('highlightLine with null language returns null (always, regardless of init)', () {
      expect(DiffHighlighter.highlightLine(content: 'some text', language: null), isNull);
    });

    group('after initialization', () {
      setUpAll(() async {
        TestWidgetsFlutterBinding.ensureInitialized();
        await DiffHighlighter.initialize();
      });

      test('initialize can be called multiple times without error', () async {
        // Should be idempotent — no throw on repeated calls
        await DiffHighlighter.initialize();
        await DiffHighlighter.initialize();
      });

      test('highlightLine with dart returns a non-null TextSpan', () {
        final span = DiffHighlighter.highlightLine(content: 'void main() {}', language: 'dart');
        expect(span, isNotNull);
        expect(span, isA<TextSpan>());
      });

      test('highlightLine with null language returns null', () {
        final span = DiffHighlighter.highlightLine(content: 'some text', language: null);
        expect(span, isNull);
      });

      test('highlightLine with unsupported language returns null (no crash)', () {
        final span = DiffHighlighter.highlightLine(content: 'some text', language: 'unsupported-xyz');
        expect(span, isNull);
      });
    });
  });
}
