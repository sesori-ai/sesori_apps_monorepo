"use strict";

var fs = require("fs");
var path = require("path");
var child_process = require("child_process");

var LOCK_WAIT_MS = 100;
var LOCK_TIMEOUT_MS = Number(process.env.SESORI_BRIDGE_TEST_BOOTSTRAP_LOCK_TIMEOUT_MS || 30000);
var LOCK_STALE_MS = Number(process.env.SESORI_BRIDGE_TEST_BOOTSTRAP_LOCK_STALE_MS || 120000);
var HEARTBEAT_INTERVAL_MS = Math.max(100, Math.floor(LOCK_STALE_MS / 4));
var HEARTBEAT_FILE_NAME = "heartbeat";
var OWNER_FILE_NAME = "owner.json";

function sleep(milliseconds) {
  var buffer = new SharedArrayBuffer(4);
  var view = new Int32Array(buffer);
  Atomics.wait(view, 0, 0, milliseconds);
}

function removeRecursive(filePath) {
  fs.rmSync(filePath, { force: true, recursive: true });
}

function heartbeatPath(lockPath) {
  return path.join(lockPath, HEARTBEAT_FILE_NAME);
}

function ownerPath(lockPath) {
  return path.join(lockPath, OWNER_FILE_NAME);
}

function writeHeartbeat(lockPath) {
  fs.writeFileSync(heartbeatPath(lockPath), String(Date.now()), "utf8");
}

function startHeartbeat(lockPath) {
  writeHeartbeat(lockPath);
  var heartbeatProcess = child_process.spawn(
    process.execPath,
    [path.join(__dirname, "bootstrap_lock_heartbeat.js")],
    {
      detached: true,
      env: Object.assign({}, process.env, {
        SESORI_BRIDGE_BOOTSTRAP_LOCK_PATH: lockPath,
        SESORI_BRIDGE_BOOTSTRAP_LOCK_HEARTBEAT_INTERVAL_MS: String(HEARTBEAT_INTERVAL_MS),
        SESORI_BRIDGE_BOOTSTRAP_LOCK_PARENT_PID: String(process.pid),
      }),
      stdio: "ignore",
    }
  );
  heartbeatProcess.unref();
  return heartbeatProcess;
}

function stopHeartbeat(heartbeatProcess) {
  if (!heartbeatProcess || typeof heartbeatProcess.pid !== "number") {
    return;
  }
  try {
    process.kill(heartbeatProcess.pid, "SIGTERM");
  } catch (_) {}
}

function lockIsStale(lockPath) {
  var targetPaths = [heartbeatPath(lockPath), ownerPath(lockPath), lockPath];
  for (var i = 0; i < targetPaths.length; i++) {
    try {
      var stat = fs.statSync(targetPaths[i]);
      return Date.now() - stat.mtimeMs > LOCK_STALE_MS;
    } catch (_) {}
  }
  return false;
}

function acquireLock(lockPath, options) {
  var deadline = Date.now() + LOCK_TIMEOUT_MS;
  var didReportWait = false;

  while (true) {
    try {
      fs.mkdirSync(lockPath);
      fs.writeFileSync(
        ownerPath(lockPath),
        JSON.stringify({ pid: process.pid, createdAt: new Date().toISOString() }),
        "utf8"
      );
      return startHeartbeat(lockPath);
    } catch (error) {
      if (!error || error.code !== "EEXIST") {
        throw error;
      }
      if (!didReportWait && options && typeof options.onWait === "function") {
        options.onWait(lockPath);
        didReportWait = true;
      }
      if (lockIsStale(lockPath)) {
        removeRecursive(lockPath);
        continue;
      }
      if (Date.now() >= deadline) {
        throw new Error(
          "Timed out waiting for the bootstrap lock at " + lockPath + ". " +
          "Another sesori-bridge bootstrap may be stuck; remove the lock and try again."
        );
      }
      sleep(LOCK_WAIT_MS);
    }
  }
}

function withBootstrapLock(options, callback) {
  var lockPath = path.join(path.dirname(options.installRoot), ".sesori-bootstrap.lock");
  fs.mkdirSync(path.dirname(options.installRoot), { recursive: true });
  var heartbeatProcess = acquireLock(lockPath, options);
  var callbackResult;
  try {
    callbackResult = callback();
  } finally {
    if (!callbackResult || typeof callbackResult.then !== "function") {
      stopHeartbeat(heartbeatProcess);
      removeRecursive(lockPath);
    }
  }
  if (callbackResult && typeof callbackResult.then === "function") {
    return callbackResult.finally(function() {
      stopHeartbeat(heartbeatProcess);
      removeRecursive(lockPath);
    });
  }
  return callbackResult;
}

module.exports = {
  withBootstrapLock: withBootstrapLock,
};
