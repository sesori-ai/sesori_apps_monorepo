import "dart:convert";
import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_shared/sesori_shared.dart";

import "../foundation/process_runner.dart";

/// Maximum file size to read (200 KB). Larger files are treated as too-large.
const maxFileContentBytes = 200 * 1024;

/// Binary file extensions — skip reading content for these.
const _binaryExtensions = <String>{
  // Images
  "png", "jpg", "jpeg", "gif", "ico", "webp", "bmp", "svg", "tiff",
  // Fonts
  "woff", "woff2", "ttf", "otf", "eot",
  // Archives
  "zip", "tar", "gz", "bz2", "xz", "7z", "rar",
  // Audio/video
  "mp3", "mp4", "wav", "ogg", "webm", "avi", "mov", "flac",
  // Documents
  "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx",
  // Compiled/binary
  "exe", "dll", "so", "dylib", "bin", "wasm", "class", "pyc",
  // Other
  "sqlite", "db",
};

/// Returns true if the file extension indicates a binary format.
bool _isBinaryExtension(String filePath) {
  final ext = filePath.contains(".") ? filePath.split(".").last.toLowerCase() : "";
  return _binaryExtensions.contains(ext);
}

sealed class FileReadResult {
  const FileReadResult({required this.exists});

  final bool exists;
}

final class FileContent extends FileReadResult {
  final String content;

  const FileContent({required this.content, required super.exists});
}

final class FileBinary extends FileReadResult {
  const FileBinary() : super(exists: true);
}

final class FileTooLarge extends FileReadResult {
  const FileTooLarge() : super(exists: true);
}

final class FileReadError extends FileReadResult {
  const FileReadError() : super(exists: false);
}

String decodeOutput(Object? out) {
  if (out is String) return out;
  if (out is List<int>) {
    try {
      return utf8.decode(out);
    } on FormatException {
      return utf8.decode(out, allowMalformed: true);
    }
  }
  return "";
}

Future<FileReadResult> readBefore({
  required ProcessRunner processRunner,
  required String worktreePath,
  required String baseBranch,
  required String file,
  required FileDiffStatus? status,
}) async {
  if (status == FileDiffStatus.added) return const FileContent(content: "", exists: false);
  if (_isBinaryExtension(file)) return const FileBinary();
  final result = await processRunner("git", ["show", "$baseBranch:$file"], workingDirectory: worktreePath);
  if (result.exitCode != 0) return const FileReadError();
  final stdout = decodeOutput(result.stdout);
  if (stdout.contains("\x00")) return const FileBinary();
  return FileContent(content: stdout, exists: true);
}

FileReadResult readAfter({
  required String worktreePath,
  required String file,
  required FileDiffStatus? status,
}) {
  if (status == FileDiffStatus.deleted) return const FileContent(content: "", exists: false);
  if (_isBinaryExtension(file)) return const FileBinary();
  final absoluteWorktreePath = p.normalize(p.absolute(worktreePath));
  final candidatePath = p.normalize(p.absolute(p.join(worktreePath, file)));
  if (candidatePath != absoluteWorktreePath && !p.isWithin(absoluteWorktreePath, candidatePath)) {
    return const FileReadError();
  }

  final entityType = FileSystemEntity.typeSync(candidatePath, followLinks: false);
  if (entityType == FileSystemEntityType.link || entityType == FileSystemEntityType.notFound) {
    return const FileContent(content: "", exists: false);
  }

  final fileOnDisk = File(candidatePath);
  if (!fileOnDisk.existsSync()) return const FileContent(content: "", exists: false);

  String resolvedPath;
  try {
    resolvedPath = p.normalize(fileOnDisk.resolveSymbolicLinksSync());
  } on FileSystemException {
    return const FileReadError();
  }
  final normalizedWorktreePath = p.normalize(Directory(worktreePath).resolveSymbolicLinksSync());
  if (resolvedPath != normalizedWorktreePath && !p.isWithin(normalizedWorktreePath, resolvedPath)) {
    return const FileReadError();
  }

  final fileSize = fileOnDisk.lengthSync();
  if (fileSize > maxFileContentBytes) return const FileTooLarge();

  try {
    final content = fileOnDisk.readAsStringSync();
    if (content.contains("\x00")) return const FileBinary();
    return FileContent(content: content, exists: true);
  } on FileSystemException {
    try {
      final bytes = fileOnDisk.readAsBytesSync();
      if (bytes.contains(0)) return const FileBinary();
    } on FileSystemException {
      return const FileReadError();
    }
    return const FileReadError();
  } on FormatException {
    return const FileBinary();
  }
}

String contentOrEmpty(FileReadResult result) => switch (result) {
  FileContent(:final content) => content,
  _ => "",
};
