"use strict";

var fs = require("fs");
var path = require("path");

var lockPath = process.env.SESORI_BRIDGE_BOOTSTRAP_LOCK_PATH;
var parentPid = Number(process.env.SESORI_BRIDGE_BOOTSTRAP_LOCK_PARENT_PID || 0);
var heartbeatIntervalMs = Number(process.env.SESORI_BRIDGE_BOOTSTRAP_LOCK_HEARTBEAT_INTERVAL_MS || 1000);
var heartbeatPath = lockPath ? path.join(lockPath, "heartbeat") : null;

function parentIsAlive() {
  if (!parentPid) {
    return false;
  }
  try {
    process.kill(parentPid, 0);
    return true;
  } catch (_) {
    return false;
  }
}

function writeHeartbeat() {
  if (!heartbeatPath) {
    process.exit(1);
  }
  if (!parentIsAlive()) {
    process.exit(0);
  }
  try {
    fs.writeFileSync(heartbeatPath, String(Date.now()), "utf8");
  } catch (_) {
    process.exit(0);
  }
}

process.on("SIGTERM", function() {
  process.exit(0);
});

writeHeartbeat();
setInterval(writeHeartbeat, heartbeatIntervalMs);
