"use strict";

var fs = require("fs");
var path = require("path");
var child_process = require("child_process");
var launcher = require("./launcher");
var bootstrapLock = require("./bootstrap_lock");
var releaseAssetRuntime = require("./release_asset_runtime");
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

function errorMessage(error) {
  return String(error && error.message ? error.message : error);
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
        console.error("sesori-bridge: Another bootstrap is already in progress. Waiting for the managed install lock...");
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
          return { binaryPath: runtimeInstall.managedBinaryPath(installRoot), installRoot: installRoot };
        }
        if (comparison === 0 && runtimeReady) {
          return { binaryPath: runtimeInstall.managedBinaryPath(installRoot), installRoot: installRoot };
        }
      }
      payload = localPayload;
      if (!payload) {
        payload = await releaseAssetRuntime.resolvePayload();
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
        throw new Error(
          "sesori-bridge: Failed to install the managed runtime.\n" +
          errorMessage(error) + "\n" +
          "Refusing to run runtime binaries from npm-owned paths. Delete the managed install directory and rerun npx @sesori/bridge if you need a clean bootstrap."
        );
      }
      return { binaryPath: runtimeInstall.managedBinaryPath(installRoot), installRoot: installRoot };
    });
  } finally {
    if (payload && typeof payload.cleanup === "function") {
      payload.cleanup();
    }
  }
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

async function runMain(options) {
  var bootstrapResult = await bootstrapManagedRuntime(options && options.pkgName);
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
    console.error(
      "sesori-bridge: Failed to persist the managed command path.\n" +
      errorMessage(error) + "\n" +
      "Continuing with the managed runtime for this launch."
    );
  }
  spawnManagedRuntime(bootstrapResult.binaryPath, process.argv.slice(2));
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
