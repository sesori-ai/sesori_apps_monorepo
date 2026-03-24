import 'package:sesori_dart_core/src/utils/diff/language_detector.dart';
import 'package:test/test.dart';

void main() {
  group('detectLanguage', () {
    test('detects Dart files', () {
      expect(detectLanguage('src/main.dart'), equals('dart'));
    });

    test('detects TypeScript files', () {
      expect(detectLanguage('src/index.ts'), equals('typescript'));
    });

    test('detects TSX files as TypeScript', () {
      expect(detectLanguage('app/page.tsx'), equals('typescript'));
    });

    test('detects JavaScript files', () {
      expect(detectLanguage('main.js'), equals('javascript'));
    });

    test('detects JSX files as JavaScript', () {
      expect(detectLanguage('app.jsx'), equals('javascript'));
    });

    test('detects Python files', () {
      expect(detectLanguage('script.py'), equals('python'));
    });

    test('detects Go files', () {
      expect(detectLanguage('main.go'), equals('go'));
    });

    test('detects Java files', () {
      expect(detectLanguage('Main.java'), equals('java'));
    });

    test('detects Kotlin files', () {
      expect(detectLanguage('Main.kt'), equals('kotlin'));
    });

    test('detects Gradle Kotlin files', () {
      expect(detectLanguage('build.gradle.kts'), equals('kotlin'));
    });

    test('detects Swift files', () {
      expect(detectLanguage('app.swift'), equals('swift'));
    });

    test('detects Rust files', () {
      expect(detectLanguage('lib.rs'), equals('rust'));
    });

    test('detects HTML files', () {
      expect(detectLanguage('index.html'), equals('html'));
    });

    test('detects CSS files', () {
      expect(detectLanguage('style.css'), equals('css'));
    });

    test('detects JSON files', () {
      expect(detectLanguage('data.json'), equals('json'));
    });

    test('detects YAML files', () {
      expect(detectLanguage('config.yaml'), equals('yaml'));
    });

    test('detects YML files as YAML', () {
      expect(detectLanguage('config.yml'), equals('yaml'));
    });

    test('detects SQL files', () {
      expect(detectLanguage('query.sql'), equals('sql'));
    });

    test('returns null for unsupported extensions', () {
      expect(detectLanguage('README.md'), isNull);
    });

    test('handles dots in directory names', () {
      expect(detectLanguage('path.with.dots/file.py'), equals('python'));
    });

    test('returns null for files without extension', () {
      expect(detectLanguage('no_extension'), isNull);
    });
  });
}
