import 'package:flutter_test/flutter_test.dart';
import 'package:sesori_mobile/features/session_diffs/utils/binary_detector.dart';

void main() {
  group('isBinaryFile', () {
    test('returns true for PNG extension', () {
      expect(isBinaryFile(filePath: 'image.png', content: ''), isTrue);
    });

    test('returns true for JPG extension', () {
      expect(isBinaryFile(filePath: 'photo.jpg', content: ''), isTrue);
    });

    test('returns false for Dart text file', () {
      expect(isBinaryFile(filePath: 'main.dart', content: 'void main() {}'), isFalse);
    });

    test('returns true for BIN extension', () {
      expect(isBinaryFile(filePath: 'data.bin', content: ''), isTrue);
    });

    test('returns false for README markdown', () {
      expect(isBinaryFile(filePath: 'README.md', content: '# Hello'), isFalse);
    });

    test('returns true when content contains null byte', () {
      expect(isBinaryFile(filePath: 'data', content: 'hello\x00world'), isTrue);
    });

    test('returns false for clean text file without null bytes', () {
      expect(isBinaryFile(filePath: 'data.txt', content: 'clean text'), isFalse);
    });
  });
}
