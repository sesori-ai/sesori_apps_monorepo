"use strict";

var fs = require("fs");
var os = require("os");
var path = require("path");

function fail(message) {
  console.error(message);
  process.exit(1);
}

function readJson(filePath) { return JSON.parse(fs.readFileSync(filePath, "utf8")); }
function exists(filePath) { return fs.existsSync(filePath); }

function managedInstallRoot() {
  if (process.platform === "win32") {
    var localAppData = process.env.LOCALAPPDATA;
    if (!localAppData) {
      fail("sesori-bridge: LOCALAPPDATA must be set to bootstrap the managed runtime.");
    }
    return path.join(localAppData, "sesori");
  }
  var home = process.env.HOME;
  if (!home) {
    fail("sesori-bridge: HOME must be set to bootstrap the managed runtime.");
  }
  return path.join(home, ".sesori");
}

function managedBinaryPath(installRoot) {
  return path.join(installRoot, "bin", process.platform === "win32" ? "sesori-bridge.exe" : "sesori-bridge");
}

function managedManifestPath(installRoot) { return path.join(installRoot, ".managed-runtime.json"); }
function managedLibPath(installRoot) { return path.join(installRoot, "lib"); }

function isManagedRuntimeReady(installRoot) {
  return exists(managedBinaryPath(installRoot)) && exists(managedLibPath(installRoot));
}

function readManagedVersion(installRoot) {
  var manifestPath = managedManifestPath(installRoot);
  if (!exists(manifestPath)) {
    return null;
  }
  try {
    var manifest = readJson(manifestPath);
    return typeof manifest.version === "string" ? manifest.version : null;
  } catch (_) {
    return null;
  }
}

function splitVersion(version) {
  var index = version.indexOf("-");
  return {
    core: index === -1 ? version : version.slice(0, index),
    prerelease: index === -1 ? null : version.slice(index + 1),
  };
}

function parseCore(version) {
  return splitVersion(version).core.split(".").map(function(part) { return Number(part); });
}

function compareVersions(left, right) {
  var leftParts = parseCore(left);
  var rightParts = parseCore(right);
  var length = Math.max(leftParts.length, rightParts.length);
  for (var i = 0; i < length; i++) {
    var leftValue = leftParts[i] || 0;
    var rightValue = rightParts[i] || 0;
    if (leftValue !== rightValue) {
      return leftValue > rightValue ? 1 : -1;
    }
  }
  var leftPre = splitVersion(left).prerelease;
  var rightPre = splitVersion(right).prerelease;
  if (leftPre === rightPre) { return 0; }
  if (leftPre === null) { return 1; }
  if (rightPre === null) { return -1; }
  return leftPre > rightPre ? 1 : -1;
}

function removeRecursive(filePath) {
  fs.rmSync(filePath, { force: true, recursive: true });
}

function copyRecursive(sourcePath, targetPath) {
  var stat = fs.statSync(sourcePath);
  if (stat.isDirectory()) {
    fs.mkdirSync(targetPath, { recursive: true });
    fs.readdirSync(sourcePath).forEach(function(entry) {
      copyRecursive(path.join(sourcePath, entry), path.join(targetPath, entry));
    });
    return;
  }
  fs.mkdirSync(path.dirname(targetPath), { recursive: true });
  fs.copyFileSync(sourcePath, targetPath);
  fs.chmodSync(targetPath, stat.mode);
}

function resolvePayload(pkgName) {
  var packageRoot;
  try {
    packageRoot = path.dirname(require.resolve(pkgName + "/package.json"));
  } catch (_) {
    fail(
      "sesori-bridge: Failed to find platform package '" + pkgName + "'.\n" +
      "Try installing it manually:\n  npm install " + pkgName
    );
  }
  var manifest = readJson(path.join(packageRoot, "package.json"));
  return {
    runtimeBundlePath: path.join(
      packageRoot,
      manifest.sesoriBridge && manifest.sesoriBridge.runtimeBundlePath
        ? manifest.sesoriBridge.runtimeBundlePath
        : path.join("lib", "runtime")
    ),
    version: manifest.version,
  };
}

function writeManagedManifest(installRoot, version) {
  fs.writeFileSync(managedManifestPath(installRoot), JSON.stringify({ version: version }) + os.EOL, "utf8");
}

function installManagedRuntime(payload, installRoot, options) {
  var parentRoot = path.dirname(installRoot);
  var stageRoot = path.join(parentRoot, ".sesori-stage-" + process.pid);
  var backupRoot = path.join(parentRoot, ".sesori-backup-" + process.pid);
  removeRecursive(stageRoot);
  removeRecursive(backupRoot);
  fs.mkdirSync(parentRoot, { recursive: true });
  copyRecursive(payload.runtimeBundlePath, stageRoot);
  writeManagedManifest(stageRoot, payload.version);
  if (!isManagedRuntimeReady(stageRoot)) {
    throw new Error("Bootstrap payload is incomplete. Expected lib/runtime/{bin,lib}.");
  }
  if (options && typeof options.beforeInstallSwap === "function") {
    options.beforeInstallSwap();
  }
  var hadExistingInstall = exists(installRoot);
  try {
    if (hadExistingInstall) {
      fs.renameSync(installRoot, backupRoot);
    }
    fs.renameSync(stageRoot, installRoot);
    removeRecursive(backupRoot);
  } catch (error) {
    if (!exists(installRoot) && exists(backupRoot)) {
      fs.renameSync(backupRoot, installRoot);
    }
    removeRecursive(stageRoot);
    throw error;
  }
}

module.exports = {
  compareVersions: compareVersions,
  installManagedRuntime: installManagedRuntime,
  managedBinaryPath: managedBinaryPath,
  managedInstallRoot: managedInstallRoot,
  readManagedVersion: readManagedVersion,
  resolvePayload: resolvePayload,
  isManagedRuntimeReady: isManagedRuntimeReady,
};
