#!/usr/bin/env node

"use strict";

var bootstrap = require("../lib/bootstrap");
var uiModule = require("../lib/ui");

var PLATFORM_PACKAGES = bootstrap.PLATFORM_PACKAGES;

var key = process.platform + " " + process.arch;
var pkgName = PLATFORM_PACKAGES[key];

if (!pkgName) {
  // Pass the current process streams/env explicitly so the message is emitted
  // through the same process object the caller sees (matters under test sandboxes
  // that intercept process.stderr/stdout).
  var ui = new uiModule.Ui({ stream: process.stdout, errStream: process.stderr, env: process.env });
  ui.error("Unsupported platform: " + process.platform + " " + process.arch);
  ui.hint("Supported platforms: " + Object.keys(PLATFORM_PACKAGES).join(", "));
  ui.hint("Install on a supported platform with:");
  ui.hint("  npx @sesori/bridge");
  process.exit(1);
}

bootstrap.main({ pkgName: pkgName });
