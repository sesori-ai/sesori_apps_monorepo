import 'package:flutter_test/flutter_test.dart';
import 'package:sesori_mobile/features/session_diffs/utils/binary_detector.dart';

void main() {
  group('isBinaryFile', () {
    test('returns true for PNG extension', () {
      expect(isBinaryFile('image.png', ''), isTrue);
    });

    test('returns true for JPG extension', () {
      expect(isBinaryFile('photo.jpg', ''), isTrue);
    });

    test('returns false for Dart text file', () {
      expect(isBinaryFile('main.dart', 'void main() {}'), isFalse);
    });

    test('returns true for BIN extension', () {
      expect(isBinaryFile('data.bin', ''), isTrue);
    });

    test('returns false for README markdown', () {
      expect(isBinaryFile('README.md', '# Hello'), isFalse);
    });

    test('returns true when content contains null byte', () {
      expect(isBinaryFile('data', 'hello\x00world'), isTrue);
    });

    test('returns false for clean text file without null bytes', () {
      expect(isBinaryFile('data.txt', 'clean text'), isFalse);
    });
  });
}
