"use strict";

var fs = require("fs");
var path = require("path");
var child_process = require("child_process");

function unixManagedBinDir() { return "$HOME/.local/bin"; }
function fishManagedBinDir() { return '"$HOME/.local/bin"'; }

function sourceHint(filePath, shellName) {
  if (shellName === "fish") {
    return "Run `source " + filePath + "` or open a new terminal.";
  }
  return "Run `source " + filePath + "` or open a new terminal.";
}

function unixPathFiles(homeDir, shellName) {
  if (shellName === "bash") {
    return [path.join(homeDir, ".bashrc"), path.join(homeDir, ".profile")];
  }
  if (shellName === "zsh") {
    return [path.join(homeDir, ".zshrc"), path.join(homeDir, ".zprofile")];
  }
  return [path.join(homeDir, ".profile")];
}

function joinWithAnd(values) {
  if (values.length === 1) {
    return values[0];
  }
  if (values.length === 2) {
    return values[0] + " and " + values[1];
  }
  return values.slice(0, -1).join(", ") + ", and " + values[values.length - 1];
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

function isLocalBinInPath() {
  var pathEnv = process.env.PATH || "";
  var home = process.env.HOME || "";
  var localBin = path.join(home, ".local", "bin");
  var separator = process.platform === "win32" ? ";" : ":";
  var entries = pathEnv.split(separator);
  for (var i = 0; i < entries.length; i++) {
    if (path.resolve(entries[i]) === path.resolve(localBin)) {
      return true;
    }
  }
  return false;
}

function ensureUnixPathEntry(homeDir, shellPath) {
  var shellName = path.basename(shellPath || "");

  if (isLocalBinInPath()) {
    return {
      changed: false,
      message: "PATH: ~/.local/bin is already in your PATH.",
    };
  }

  var changed = false;
  var messages = [];

  if (shellName === "fish") {
    var fishConfig = path.join(homeDir, ".config", "fish", "config.fish");
    if (ensureLine(fishConfig, "fish_add_path " + fishManagedBinDir())) {
      changed = true;
      messages.push("Persisted ~/.local/bin in " + fishConfig + ". " + sourceHint(fishConfig, shellName));
    }
  } else {
    var exportLine = 'export PATH="' + unixManagedBinDir() + ':$PATH"';
    var rcFiles = unixPathFiles(homeDir, shellName);
    var updatedFiles = [];
    rcFiles.forEach(function(filePath) {
      if (ensureLine(filePath, exportLine)) {
        changed = true;
        updatedFiles.push(filePath);
      }
    });
    if (updatedFiles.length > 0) {
      messages.push(
        "Persisted ~/.local/bin in " + joinWithAnd(updatedFiles) + ". " + sourceHint(updatedFiles[0], shellName)
      );
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
  isLocalBinInPath: isLocalBinInPath,
};
