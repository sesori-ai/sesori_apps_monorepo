import "dart:io";

import "package:sesori_bridge/src/foundation/filesystem_permission_validator.dart";
import "package:test/test.dart";

void main() {
  group("FilesystemPermissionValidator", () {
    const validator = FilesystemPermissionValidator();

    test("treats EPERM (1) as permission denied", () {
      const error = FileSystemException("x", "/p", OSError("Operation not permitted", 1));
      expect(validator.isPermissionDenied(error), isTrue);
    });

    test("treats EACCES (13) as permission denied", () {
      const error = FileSystemException("x", "/p", OSError("Permission denied", 13));
      expect(validator.isPermissionDenied(error), isTrue);
    });

    test("does not treat ENOENT (2) as permission denied", () {
      const error = FileSystemException("x", "/p", OSError("No such file or directory", 2));
      expect(validator.isPermissionDenied(error), isFalse);
    });

    test("falls back to message matching when errno is absent", () {
      const error = FileSystemException("Permission denied while reading", "/p");
      expect(validator.isPermissionDenied(error), isTrue);
    });

    test("returns false for an unrelated error with no errno", () {
      const error = FileSystemException("Directory listing failed", "/p");
      expect(validator.isPermissionDenied(error), isFalse);
    });

    test("recognizes missing files by errno and Windows message", () {
      const errno = FileSystemException("x", "/p", OSError("No such file or directory", 2));
      const message = FileSystemException("Cannot find the file specified", "/p");

      expect(validator.isFileMissing(errno), isTrue);
      expect(validator.isFileMissing(message), isTrue);
    });

    test("does not classify unrelated filesystem errors as missing", () {
      const error = FileSystemException("Directory listing failed", "/p", OSError("I/O error", 5));
      expect(validator.isFileMissing(error), isFalse);
    });
  });
}
