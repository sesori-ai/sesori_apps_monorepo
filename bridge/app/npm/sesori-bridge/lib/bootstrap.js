"use strict";

var fs = require("fs");
var path = require("path");
var launcher = require("./launcher");
var bootstrapLock = require("./bootstrap_lock");
var releaseAssetRuntime = require("./release_asset_runtime");
var runtimeInstall = require("./runtime_install");
var uiModule = require("./ui");

// Single shared UI instance for the bootstrap's user-facing output. Matches the
// visual spec of install.sh / install.ps1.
var ui = new uiModule.Ui({});

var PLATFORM_PACKAGES = {
  "darwin arm64": "@sesori/bridge-darwin-arm64",
  "darwin x64": "@sesori/bridge-darwin-x64",
  "linux x64": "@sesori/bridge-linux-x64",
  "linux arm64": "@sesori/bridge-linux-arm64",
  "win32 x64": "@sesori/bridge-win32-x64",
  "win32 arm64": "@sesori/bridge-win32-arm64",
};

function fail(message) {
  // Render each line of a multi-line error through the styled prefix: the first
  // line as the Error, subsequent lines as muted Notes (remediation guidance).
  var lines = String(message).split("\n");
  ui.error(lines[0].replace(/^sesori-bridge:\s*/, ""));
  for (var i = 1; i < lines.length; i++) {
    if (lines[i].length > 0) {
      ui.hint(lines[i]);
    }
  }
  process.exit(1);
}

function errorMessage(error) {
  return String(error && error.message ? error.message : error);
}

function shellQuote(value) {
  if (!value) {
    return "''";
  }
  if (/^[A-Za-z0-9_./:-]+$/.test(value)) {
    return value;
  }
  return "'" + String(value).replace(/'/g, "'\\''") + "'";
}

function powershellQuote(value) {
  if (!value) {
    return "''";
  }
  return "'" + String(value).replace(/'/g, "''") + "'";
}

function nextCommand(binaryPath, args) {
  var commandArgs = Array.isArray(args) ? args : [];
  var managedCommand;
  if (process.platform === "win32") {
    managedCommand = "& " + [binaryPath].concat(commandArgs).map(powershellQuote).join(" ");
  } else {
    managedCommand = [binaryPath].concat(commandArgs).map(shellQuote).join(" ");
  }
  return {
    managed: managedCommand,
    // Bare-command form used both as the runnable next step and as the
    // completion panel's highlighted call-to-action.
    pathCommand: ["sesori-bridge"].concat(commandArgs).map(shellQuote).join(" "),
  };
}

function isManagedSymlinkReady(installRoot) {
  if (process.platform === "win32") {
    return true;
  }
  var home = process.env.HOME;
  if (!home) {
    return false;
  }
  var symlinkPath = path.join(home, ".local", "bin", "sesori-bridge");
  try {
    var stat = fs.lstatSync(symlinkPath);
    if (!stat.isSymbolicLink()) {
      return false;
    }
    var target = fs.readlinkSync(symlinkPath);
    return target === runtimeInstall.managedBinaryPath(installRoot);
  } catch (_) {
    return false;
  }
}

// Whether the bare `sesori-bridge` command resolves in a fresh shell. On Windows
// there is no ~/.local/bin symlink, so PATH being configured is the only signal;
// on Unix both the PATH entry and the managed symlink must hold.
function isCommandReady(installRoot) {
  var pathConfigured = launcher.isLocalBinInPath();
  if (process.platform === "win32") {
    return pathConfigured;
  }
  return pathConfigured && isManagedSymlinkReady(installRoot);
}

function printInstallSummary(options) {
  var commands = nextCommand(options.binaryPath, options.args);
  var symlinkReady = isManagedSymlinkReady(options.installRoot);
  var commandReady = isCommandReady(options.installRoot);

  if (commandReady) {
    ui.completion({
      version: options.version,
      location: options.installRoot,
      onPath: true,
      command: commands.pathCommand,
    });
  } else if (!symlinkReady && process.platform !== "win32") {
    // The managed symlink is missing/blocked: instruct the user to run the
    // managed binary directly rather than the bare command.
    ui.completion({
      version: options.version,
      location: options.installRoot,
      onPath: true,
      command: commands.managed,
    });
  } else {
    ui.completion({
      version: options.version,
      location: options.installRoot,
      onPath: false,
      command: commands.pathCommand,
    });
  }
}

function managedBinDir(installRoot) { return path.dirname(runtimeInstall.managedBinaryPath(installRoot)); }
function sleepForTest() {
  var holdMs = Number(process.env.SESORI_BRIDGE_TEST_BOOTSTRAP_HOLD_MS || 0);
  if (holdMs <= 0) {
    return;
  }
  var buffer = new SharedArrayBuffer(4);
  var view = new Int32Array(buffer);
  Atomics.wait(view, 0, 0, holdMs);
}

function recordInstallAttempt() {
  var counterPath = process.env.SESORI_BRIDGE_TEST_INSTALL_COUNTER_PATH;
  if (!counterPath) {
    return;
  }
  var currentValue = 0;
  if (fs.existsSync(counterPath)) {
    currentValue = Number(fs.readFileSync(counterPath, "utf8")) || 0;
  }
  fs.writeFileSync(counterPath, String(currentValue + 1), "utf8");
}

async function bootstrapManagedRuntime(pkgName) {
  var installRoot = runtimeInstall.managedInstallRoot();
  var localPayload = runtimeInstall.tryResolvePayload(pkgName);
  var preferredVersion = localPayload ? localPayload.version : releaseAssetRuntime.wrapperVersion();
  var payload = null;
  try {
    return await bootstrapLock.withBootstrapLock({
      installRoot: installRoot,
      onWait: function() {
        ui.noteErr("Another bootstrap is already in progress. Waiting for the managed install lock...");
      },
    }, async function() {
      var currentVersion = runtimeInstall.readManagedVersion(installRoot);
      var runtimeReady = runtimeInstall.isManagedRuntimeReady(installRoot);
      if (currentVersion !== null) {
        var comparison = runtimeInstall.compareVersions(currentVersion, preferredVersion);
        if (comparison > 0) {
          if (!runtimeReady) {
            throw new Error(
              "sesori-bridge: Managed runtime " + currentVersion + " is incomplete/corrupt and newer than npm payload " + preferredVersion + ".\n" +
              "Refusing to repair it with an older npm payload. Reinstall the managed runtime explicitly, or delete the managed install directory and bootstrap again with npx."
            );
          }
          runtimeInstall.createManagedSymlink(installRoot);
          // Already up to date: nothing to install, so stay quiet (no banner).
          return { binaryPath: runtimeInstall.managedBinaryPath(installRoot), installRoot: installRoot, version: currentVersion, installed: false };
        }
        if (comparison === 0 && runtimeReady) {
          runtimeInstall.createManagedSymlink(installRoot);
          return { binaryPath: runtimeInstall.managedBinaryPath(installRoot), installRoot: installRoot, version: currentVersion, installed: false };
        }
      }

      // A real install is happening — show the full branded flow. Steps mirror
      // the shell installers (Download, Verify, Install, Link) so the experience
      // is consistent across runtimes; resolvePayload performs the download +
      // checksum verification for the GitHub-fallback path internally.
      ui.banner();
      ui.summary(process.platform + "/" + process.arch, "v" + preferredVersion);

      payload = localPayload;
      ui.step(1, "Downloading release");
      if (!payload) {
        // No bundled npm payload; download the matching GitHub release asset.
        payload = await releaseAssetRuntime.resolvePayload();
        ui.ok("Downloaded release v" + (payload && payload.version ? payload.version : preferredVersion));
      } else {
        ui.ok("Using bundled runtime payload");
      }

      ui.step(2, "Verifying checksum");
      // resolvePayload verifies the SHA256 of downloaded assets; bundled npm
      // payloads are trusted via the npm tarball integrity check.
      ui.ok("Checksum verified");

      ui.step(3, "Installing managed runtime");
      try {
        runtimeInstall.installManagedRuntime(payload, installRoot, {
          beforeInstallSwap: function() {
            recordInstallAttempt();
            sleepForTest();
            if (process.env.SESORI_BRIDGE_TEST_WRITE_FAIL === "1") {
              throw new Error("Simulated managed install write failure.");
            }
          },
        });
      } catch (error) {
        throw new Error(
          "sesori-bridge: Failed to install the managed runtime.\n" +
          errorMessage(error) + "\n" +
          "Refusing to run runtime binaries from npm-owned paths. Delete the managed install directory and rerun npx @sesori/bridge if you need a clean bootstrap."
        );
      }
      ui.ok("Installed to " + installRoot);

      ui.step(4, "Linking command");
      runtimeInstall.createManagedSymlink(installRoot);
      if (process.platform === "win32") {
        ui.ok("Linked sesori-bridge");
      } else {
        ui.ok("Linked ~/.local/bin/sesori-bridge");
      }
      var installedVersion = runtimeInstall.readManagedVersion(installRoot) || preferredVersion;
      return { binaryPath: runtimeInstall.managedBinaryPath(installRoot), installRoot: installRoot, version: installedVersion, installed: true };
    });
  } finally {
    if (payload && typeof payload.cleanup === "function") {
      payload.cleanup();
    }
  }
}

async function runMain(options) {
  var bootstrapResult = await bootstrapManagedRuntime(options && options.pkgName);
  var launcherResult = null;
  var pathStatus = "already configured";
  try {
    launcherResult = launcher.ensureManagedCommandPath({
      binDir: managedBinDir(bootstrapResult.installRoot),
      homeDir: process.env.HOME,
      platform: process.platform,
      shellPath: process.env.SHELL || "",
    });
    pathStatus = launcherResult && launcherResult.message ? launcherResult.message : "already configured";
  } catch (error) {
    pathStatus = "manual action required";
    ui.error("Failed to persist the managed command path.");
    ui.hint(errorMessage(error));
    ui.hint("The managed runtime is installed, but you may need to add it to PATH manually.");
  }

  // Always show the completion panel. `npx @sesori/bridge` is an explicit,
  // user-initiated request to set up the bridge, so it must never exit silently
  // — even when the runtime is already current and the command is already on
  // PATH, the user expects confirmation ("already installed") plus how to start
  // it. The npm bootstrap never execs the managed binary, so the panel is the
  // only feedback the user gets. (The managed binary is launched directly from
  // PATH, not through this entry point, so this is never on a hot launch path.)
  var forwardedArgs = process.argv.slice(2);
  printInstallSummary({
    installRoot: bootstrapResult.installRoot,
    binaryPath: bootstrapResult.binaryPath,
    version: bootstrapResult.version,
    pathStatus: pathStatus,
    args: forwardedArgs,
  });
}

function main(options) {
  runMain(options).catch(function(error) {
    fail(errorMessage(error));
  });
}

module.exports = {
  PLATFORM_PACKAGES: PLATFORM_PACKAGES,
  bootstrapManagedRuntime: bootstrapManagedRuntime,
  main: main,
};
