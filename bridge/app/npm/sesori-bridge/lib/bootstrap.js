"use strict";

var fs = require("fs");
var path = require("path");
var child_process = require("child_process");
var launcher = require("./launcher");
var bootstrapLock = require("./bootstrap_lock");
var runtimeInstall = require("./runtime_install");

var PLATFORM_PACKAGES = {
  "darwin arm64": "@sesori/bridge-darwin-arm64",
  "darwin x64": "@sesori/bridge-darwin-x64",
  "linux x64": "@sesori/bridge-linux-x64",
  "linux arm64": "@sesori/bridge-linux-arm64",
  "win32 x64": "@sesori/bridge-win32-x64",
};

function fail(message) {
  console.error(message);
  process.exit(1);
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

function bootstrapManagedRuntime(pkgName) {
  var payload = runtimeInstall.resolvePayload(pkgName);
  var installRoot = runtimeInstall.managedInstallRoot();
  return bootstrapLock.withBootstrapLock({
    installRoot: installRoot,
    onWait: function() {
      console.error("sesori-bridge: Another bootstrap is already in progress. Waiting for the managed install lock...");
    },
  }, function() {
    var currentVersion = runtimeInstall.readManagedVersion(installRoot);
    var runtimeReady = runtimeInstall.isManagedRuntimeReady(installRoot);
    if (currentVersion !== null) {
      var comparison = runtimeInstall.compareVersions(currentVersion, payload.version);
      if (comparison > 0) {
        if (!runtimeReady) {
          fail(
            "sesori-bridge: Managed runtime " + currentVersion + " is incomplete/corrupt and newer than npm payload " + payload.version + ".\n" +
            "Refusing to repair it with an older npm payload. Reinstall the managed runtime explicitly, or delete the managed install directory and bootstrap again with npx."
          );
        }
        return { binaryPath: runtimeInstall.managedBinaryPath(installRoot), installRoot: installRoot };
      }
      if (comparison === 0 && runtimeReady) {
        return { binaryPath: runtimeInstall.managedBinaryPath(installRoot), installRoot: installRoot };
      }
    }
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
      fail(
        "sesori-bridge: Failed to install the managed runtime.\n" +
        String(error && error.message ? error.message : error) + "\n" +
        "Refusing to run runtime binaries from npm-owned paths. Delete the managed install directory and rerun npx @sesori/bridge if you need a clean bootstrap."
      );
    }
    return { binaryPath: runtimeInstall.managedBinaryPath(installRoot), installRoot: installRoot };
  });
}

function spawnManagedRuntime(binaryPath, args) {
  var managedBinDir = path.dirname(binaryPath);
  var result = child_process.spawnSync(binaryPath, args, {
    env: Object.assign({}, process.env, { PATH: managedBinDir + path.delimiter + (process.env.PATH || "") }),
    stdio: "inherit",
  });
  if (result.error) {
    fail("sesori-bridge: Failed to launch managed runtime.\n" + result.error.message);
  }
  process.exit(result.status === null ? 1 : result.status);
}

function main(options) {
  var bootstrapResult = bootstrapManagedRuntime(options && options.pkgName);
  try {
    var launcherResult = launcher.ensureManagedCommandPath({
      binDir: managedBinDir(bootstrapResult.installRoot),
      homeDir: process.env.HOME,
      platform: process.platform,
      shellPath: process.env.SHELL || "",
    });
    if (launcherResult && launcherResult.message) {
      console.error(launcherResult.message);
    }
  } catch (error) {
    fail(
      "sesori-bridge: Failed to persist the managed command path.\n" +
      String(error && error.message ? error.message : error)
    );
  }
  spawnManagedRuntime(bootstrapResult.binaryPath, process.argv.slice(2));
}

module.exports = {
  PLATFORM_PACKAGES: PLATFORM_PACKAGES,
  bootstrapManagedRuntime: bootstrapManagedRuntime,
  main: main,
};
