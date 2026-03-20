#!/usr/bin/env node

"use strict";

var path = require("path");
var child_process = require("child_process");

var PLATFORM_PACKAGES = {
  "darwin arm64": "@sesori/bridge-darwin-arm64",
  "darwin x64":   "@sesori/bridge-darwin-x64",
  "linux x64":    "@sesori/bridge-linux-x64",
  "linux arm64":  "@sesori/bridge-linux-arm64",
  "win32 x64":    "@sesori/bridge-win32-x64",
};

var key = process.platform + " " + process.arch;
var pkgName = PLATFORM_PACKAGES[key];

if (!pkgName) {
  console.error(
    "sesori-bridge: Unsupported platform: " + process.platform + " " + process.arch + "\n" +
    "Supported platforms: " + Object.keys(PLATFORM_PACKAGES).join(", ") + "\n" +
    "You can install the correct package manually:\n" +
    "  npm install " + Object.values(PLATFORM_PACKAGES).join("\n  npm install ")
  );
  process.exit(1);
}

var pkgDir;
try {
  pkgDir = path.dirname(require.resolve(pkgName + "/package.json"));
} catch (e) {
  console.error(
    "sesori-bridge: Failed to find platform package '" + pkgName + "'.\n" +
    "Try installing it manually:\n" +
    "  npm install " + pkgName
  );
  process.exit(1);
}

var binaryName = "sesori-bridge" + (process.platform === "win32" ? ".exe" : "");
var binaryPath = path.join(pkgDir, "bin", binaryName);

try {
  child_process.execFileSync(binaryPath, process.argv.slice(2), { stdio: "inherit" });
} catch (e) {
  process.exit(e.status || 1);
}
