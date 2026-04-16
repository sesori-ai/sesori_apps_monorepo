"use strict";

var fs = require("fs");
var path = require("path");
var child_process = require("child_process");

function unixManagedBinDir() { return "$HOME/.sesori/bin"; }
function fishManagedBinDir() { return '"$HOME/.sesori/bin"'; }

function unixPathFile(homeDir, shellName) {
  if (shellName === "bash") {
    return path.join(homeDir, ".bashrc");
  }
  if (shellName === "zsh") {
    return path.join(homeDir, ".zshrc");
  }
  return path.join(homeDir, ".profile");
}

function ensureLine(filePath, line) {
  var existing = fs.existsSync(filePath) ? fs.readFileSync(filePath, "utf8") : "";
  var normalized = existing.replace(/\r\n/g, "\n");
  if (normalized.indexOf(line) !== -1) {
    return false;
  }
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  var prefix = normalized.length > 0 && !/\n$/.test(normalized) ? "\n" : "";
  fs.writeFileSync(filePath, existing + prefix + line + "\n", "utf8");
  return true;
}

function ensureUnixPathEntry(homeDir, shellPath) {
  var shellName = path.basename(shellPath || "");
  var changed = false;
  var messages = [];

  if (shellName === "fish") {
    var fishConfig = path.join(homeDir, ".config", "fish", "config.fish");
    if (ensureLine(fishConfig, "fish_add_path " + fishManagedBinDir())) {
      changed = true;
      messages.push("Persisted ~/.sesori/bin in " + fishConfig + ".");
    }
  } else {
    var exportLine = 'export PATH="' + unixManagedBinDir() + ':$PATH"';
    var rcFile = unixPathFile(homeDir, shellName);
    if (ensureLine(rcFile, exportLine)) {
      changed = true;
      messages.push("Persisted ~/.sesori/bin in " + rcFile + ".");
    }
  }

  return {
    changed: changed,
    message: changed ? messages.join("\n") : null,
  };
}

function ensureWindowsPathEntry(binDir) {
  var command = [
    "$binDir = [System.IO.Path]::GetFullPath('" + binDir.replace(/'/g, "''") + "')",
    "$userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')",
    "$entries = @()",
    "if ($userPath) { $entries = $userPath.Split(';') | Where-Object { $_ } }",
    "$existing = $entries | Where-Object { $_.TrimEnd('\\') -ieq $binDir.TrimEnd('\\') }",
    "if ($existing) { Write-Output 'UNCHANGED'; exit 0 }",
    "$newPath = if ($userPath) { $binDir + ';' + $userPath } else { $binDir }",
    "[Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')",
    "Write-Output 'UPDATED'",
  ].join("; ");
  var result = child_process.spawnSync(
    "powershell.exe",
    ["-NoProfile", "-NonInteractive", "-Command", command],
    { stdio: ["ignore", "pipe", "pipe"] }
  );
  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    throw new Error(String(result.stderr || result.stdout || "Unknown PowerShell failure."));
  }
  return {
    changed: String(result.stdout || "").indexOf("UPDATED") !== -1,
    message: String(result.stdout || "").indexOf("UPDATED") !== -1
      ? "Persisted %LOCALAPPDATA%\\sesori\\bin in the user PATH."
      : null,
  };
}

function ensureManagedCommandPath(options) {
  if (options.platform === "win32") {
    return ensureWindowsPathEntry(options.binDir);
  }
  return ensureUnixPathEntry(options.homeDir, options.shellPath);
}

module.exports = {
  ensureManagedCommandPath: ensureManagedCommandPath,
};
