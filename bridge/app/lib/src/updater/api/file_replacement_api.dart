import 'dart:io';

import 'package:path/path.dart' as p;

import '../../bridge/foundation/process_runner.dart';
import '../models/file_replacement_result.dart';
import '../models/pending_windows_update.dart';

class FileReplacementApi {
  final ProcessRunner _processRunner;

  FileReplacementApi({required ProcessRunner processRunner}) : _processRunner = processRunner;

  Future<FileReplacementResult> replaceInstalledFiles({
    required String installRoot,
    required String stagingPath,
  }) async {
    if (Platform.isWindows) {
      return replaceWindows(installRoot: installRoot, stagingPath: stagingPath);
    }
    final bool replaced = await replaceUnix(installRoot: installRoot, stagingPath: stagingPath);
    return replaced ? const FileReplacementResult.success() : const FileReplacementResult.failure();
  }

  Future<bool> replaceUnix({
    required String installRoot,
    required String stagingPath,
  }) async {
    const String binaryName = 'sesori-bridge';
    final File newBinary = File(p.join(stagingPath, 'bin', binaryName));
    final File targetBinary = File(p.join(installRoot, 'bin', binaryName));
    final File backupBinary = File(p.join(installRoot, 'bin', '.sesori-bridge.rollback'));
    final Directory newLibDir = Directory(p.join(stagingPath, 'lib'));
    final Directory targetLibDir = Directory(p.join(installRoot, 'lib'));
    final Directory backupLibDir = Directory(p.join(installRoot, '.lib.rollback'));

    if (!newBinary.existsSync()) {
      return false;
    }

    final ProcessResult chmodResult = await _processRunner.run('chmod', ['+x', newBinary.path]);
    if (chmodResult.exitCode != 0) {
      return false;
    }

    targetBinary.parent.createSync(recursive: true);
    _deleteIfExists(entity: backupBinary);
    _deleteIfExists(entity: backupLibDir);

    bool movedTargetBinary = false;
    bool movedNewBinary = false;
    bool movedTargetLib = false;
    bool movedNewLib = false;

    try {
      if (targetBinary.existsSync()) {
        targetBinary.renameSync(backupBinary.path);
        movedTargetBinary = true;
      }
      newBinary.renameSync(targetBinary.path);
      movedNewBinary = true;

      if (newLibDir.existsSync()) {
        if (targetLibDir.existsSync()) {
          targetLibDir.renameSync(backupLibDir.path);
          movedTargetLib = true;
        }
        newLibDir.renameSync(targetLibDir.path);
        movedNewLib = true;
      }

      _deleteIfExists(entity: backupBinary);
      _deleteIfExists(entity: backupLibDir);
      return true;
    } on Object {
      _rollbackUnixReplacement(
        targetBinary: targetBinary,
        newBinary: newBinary,
        backupBinary: backupBinary,
        targetLibDir: targetLibDir,
        newLibDir: newLibDir,
        backupLibDir: backupLibDir,
        movedTargetBinary: movedTargetBinary,
        movedNewBinary: movedNewBinary,
        movedTargetLib: movedTargetLib,
        movedNewLib: movedNewLib,
      );
      rethrow;
    }
  }

  Future<FileReplacementResult> replaceWindows({
    required String installRoot,
    required String stagingPath,
  }) async {
    const String binaryName = 'sesori-bridge.exe';
    final File newBinary = File(p.join(stagingPath, 'bin', binaryName));

    if (!newBinary.existsSync()) {
      return const FileReplacementResult.failure();
    }

    return FileReplacementResult.pending(
      pending: PendingWindowsUpdate(
        installRoot: installRoot,
        stagingPath: stagingPath,
        archivePath: p.join(installRoot, '.sesori-bridge-update.zip'),
        lockPath: p.join(installRoot, '.update.lock'),
      ),
    );
  }

  Future<String> createWindowsSwapScript({
    required PendingWindowsUpdate pending,
    required List<String> args,
  }) async {
    final String scriptPath = p.join(pending.installRoot, '.sesori-bridge-apply-update.ps1');
    final String escapedArgs = args.map((arg) => "'${escapePowerShellSingleQuoted(arg)}'").join(', ');
    final String script = [
      r"$ErrorActionPreference = 'Stop'",
      "\$installRoot = '${escapePowerShellSingleQuoted(pending.installRoot)}'",
      "\$stagingRoot = '${escapePowerShellSingleQuoted(pending.stagingPath)}'",
      "\$archivePath = '${escapePowerShellSingleQuoted(pending.archivePath)}'",
      "\$lockPath = '${escapePowerShellSingleQuoted(pending.lockPath)}'",
      r"$binaryPath = Join-Path $installRoot 'bin\sesori-bridge.exe'",
      r"$oldBinaryPath = Join-Path $installRoot 'bin\.sesori-bridge.old'",
      r"$newBinaryPath = Join-Path $stagingRoot 'bin\sesori-bridge.exe'",
      r"$newLibPath = Join-Path $stagingRoot 'lib'",
      r"$targetLibPath = Join-Path $installRoot 'lib'",
      'function Wait-ForUnlockedFile {',
      r'  param([string]$Path, [int]$TimeoutSeconds)',
      r'  if (-not (Test-Path $Path)) { return }',
      r'  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)',
      r'  while ($true) {',
      '    try {',
      r'      $stream = [System.IO.File]::Open(',
      r'        $Path,',
      '        [System.IO.FileMode]::Open,',
      '        [System.IO.FileAccess]::ReadWrite,',
      '        [System.IO.FileShare]::None',
      '      )',
      r'      $stream.Close()',
      '      return',
      '    } catch [System.IO.IOException] {',
      r'      if ((Get-Date) -ge $deadline) { throw }',
      '      Start-Sleep -Milliseconds 200',
      '    } catch [System.UnauthorizedAccessException] {',
      r'      if ((Get-Date) -ge $deadline) { throw }',
      '      Start-Sleep -Milliseconds 200',
      '    }',
      '  }',
      '}',
      '\$args = @($escapedArgs)',
      r'Wait-ForUnlockedFile -Path $binaryPath -TimeoutSeconds 30',
      r'if (Test-Path $binaryPath) { Move-Item -Force $binaryPath $oldBinaryPath }',
      r'Move-Item -Force $newBinaryPath $binaryPath',
      r'if (Test-Path $newLibPath) {',
      r'  if (Test-Path $targetLibPath) { Move-Item -Force $targetLibPath "$($targetLibPath).old" }',
      r'  Move-Item -Force $newLibPath $targetLibPath',
      r'  if (Test-Path "$($targetLibPath).old") { Remove-Item -Recurse -Force "$($targetLibPath).old" }',
      '}',
      r'if (Test-Path $oldBinaryPath) { Remove-Item -Force $oldBinaryPath }',
      r'Start-Process -FilePath $binaryPath -ArgumentList $args',
      r'if (Test-Path $archivePath) { Remove-Item -Force $archivePath }',
      r'if (Test-Path $stagingRoot) { Remove-Item -Recurse -Force $stagingRoot }',
      r'if (Test-Path $lockPath) { Remove-Item -Force $lockPath }',
      "Remove-Item -Force '${escapePowerShellSingleQuoted(scriptPath)}'",
    ].join('\n');
    await File(scriptPath).writeAsString(script);
    return scriptPath;
  }

  String escapePowerShellSingleQuoted(String value) {
    return value.replaceAll("'", "''");
  }

  void _rollbackUnixReplacement({
    required File targetBinary,
    required File newBinary,
    required File backupBinary,
    required Directory targetLibDir,
    required Directory newLibDir,
    required Directory backupLibDir,
    required bool movedTargetBinary,
    required bool movedNewBinary,
    required bool movedTargetLib,
    required bool movedNewLib,
  }) {
    try {
      if (movedNewLib && targetLibDir.existsSync()) {
        targetLibDir.renameSync(newLibDir.path);
      }
      if (movedTargetLib && backupLibDir.existsSync()) {
        backupLibDir.renameSync(targetLibDir.path);
      }
    } on Object {
      // Best-effort rollback.
    }

    try {
      if (movedNewBinary && targetBinary.existsSync()) {
        targetBinary.renameSync(newBinary.path);
      }
      if (movedTargetBinary && backupBinary.existsSync()) {
        backupBinary.renameSync(targetBinary.path);
      }
    } on Object {
      // Best-effort rollback.
    }
  }

  void _deleteIfExists({required FileSystemEntity entity}) {
    try {
      if (entity.existsSync()) {
        entity.deleteSync(recursive: true);
      }
    } on Object {
      // Best-effort cleanup.
    }
  }
}
