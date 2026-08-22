import "dart:io";

/// Owner-only permissions for bridge-private data. Windows has no chmod
/// equivalent here and relies on the account's profile directory instead.
const ownerOnlyDirectoryMode = "700";
const ownerOnlyFileMode = "600";

/// Creates [directory] if absent and restricts it to the current user.
Directory createHardenedDirectory({required String directoryPath}) {
  final directory = Directory(directoryPath);
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
  }
  hardenPathSync(targetPath: directory.path, mode: ownerOnlyDirectoryMode);
  return directory;
}

/// Creates [filePath] if absent and restricts it to the current user.
File createHardenedFile({required String filePath}) {
  final file = File(filePath);
  if (!file.existsSync()) {
    file.createSync();
  }
  hardenPathSync(targetPath: file.path, mode: ownerOnlyFileMode);
  return file;
}

void hardenPathSync({required String targetPath, required String mode}) {
  if (Platform.isWindows) return;
  final result = Process.runSync("chmod", [mode, targetPath]);
  if (result.exitCode != 0) {
    throw FileSystemException("Failed to set mode $mode", targetPath);
  }
}

Future<void> hardenPath({required String targetPath, required String mode}) async {
  if (Platform.isWindows) return;
  final result = await Process.run("chmod", [mode, targetPath]);
  if (result.exitCode != 0) {
    throw FileSystemException("Failed to set mode $mode", targetPath);
  }
}

Future<void> writeRestrictedFile({required String filePath, required String contents}) async {
  final directory = Directory(filePath).parent;
  await directory.create(recursive: true);
  await hardenPath(targetPath: directory.path, mode: ownerOnlyDirectoryMode);

  if (Platform.isWindows) {
    await File(filePath).writeAsString(contents);
    return;
  }

  final temporary = File("$filePath.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp");
  try {
    await temporary.writeAsString(contents);
    await hardenPath(targetPath: temporary.path, mode: ownerOnlyFileMode);
    await temporary.rename(filePath);
  } finally {
    if (temporary.existsSync()) temporary.deleteSync();
  }
}
