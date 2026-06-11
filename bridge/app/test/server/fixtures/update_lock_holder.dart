import 'dart:convert';
import 'dart:io';

/// Test fixture: holds the exclusive advisory lock `RuntimeFileApi.updateFile`
/// uses (byte 0–1 of the sidecar passed as the only argument) until a line
/// arrives on stdin. Prints "locked" once the lock is held.
Future<void> main(List<String> args) async {
  final lockFile = await File(args.single).open(mode: FileMode.append);
  await lockFile.lock(FileLock.blockingExclusive, 0, 1);
  stdout.writeln('locked');
  await stdout.flush();

  await stdin.transform(utf8.decoder).transform(const LineSplitter()).first;

  await lockFile.unlock(0, 1);
  await lockFile.close();
}
