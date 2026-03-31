import 'package:sesori_dart_core/src/utils/diff/language_detector.dart';
import 'package:test/test.dart';

void main() {
  group('detectLanguage', () {
    test('detects Dart files', () {
      expect(detectLanguage(filePath: 'src/main.dart'), equals('dart'));
    });

    test('detects TypeScript files', () {
      expect(detectLanguage(filePath: 'src/index.ts'), equals('typescript'));
    });

    test('detects TSX files as TypeScript', () {
      expect(detectLanguage(filePath: 'app/page.tsx'), equals('typescript'));
    });

    test('detects JavaScript files', () {
      expect(detectLanguage(filePath: 'main.js'), equals('javascript'));
    });

    test('detects JSX files as JavaScript', () {
      expect(detectLanguage(filePath: 'app.jsx'), equals('javascript'));
    });

    test('detects Python files', () {
      expect(detectLanguage(filePath: 'script.py'), equals('python'));
    });

    test('detects Go files', () {
      expect(detectLanguage(filePath: 'main.go'), equals('go'));
    });

    test('detects Java files', () {
      expect(detectLanguage(filePath: 'Main.java'), equals('java'));
    });

    test('detects Kotlin files', () {
      expect(detectLanguage(filePath: 'Main.kt'), equals('kotlin'));
    });

    test('detects Gradle Kotlin files', () {
      expect(detectLanguage(filePath: 'build.gradle.kts'), equals('kotlin'));
    });

    test('detects Swift files', () {
      expect(detectLanguage(filePath: 'app.swift'), equals('swift'));
    });

    test('detects Rust files', () {
      expect(detectLanguage(filePath: 'lib.rs'), equals('rust'));
    });

    test('detects HTML files', () {
      expect(detectLanguage(filePath: 'index.html'), equals('html'));
    });

    test('detects CSS files', () {
      expect(detectLanguage(filePath: 'style.css'), equals('css'));
    });

    test('detects JSON files', () {
      expect(detectLanguage(filePath: 'data.json'), equals('json'));
    });

    test('detects YAML files', () {
      expect(detectLanguage(filePath: 'config.yaml'), equals('yaml'));
    });

    test('detects YML files as YAML', () {
      expect(detectLanguage(filePath: 'config.yml'), equals('yaml'));
    });

    test('detects SQL files', () {
      expect(detectLanguage(filePath: 'query.sql'), equals('sql'));
    });

    test('returns null for unsupported extensions', () {
      expect(detectLanguage(filePath: 'README.md'), isNull);
    });

    test('handles dots in directory names', () {
      expect(detectLanguage(filePath: 'path.with.dots/file.py'), equals('python'));
    });

    test('returns null for files without extension', () {
      expect(detectLanguage(filePath: 'no_extension'), isNull);
    });
  });
}
