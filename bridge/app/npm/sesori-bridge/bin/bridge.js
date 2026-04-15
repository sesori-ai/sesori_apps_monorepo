#!/usr/bin/env node

"use strict";

var bootstrap = require("../lib/bootstrap");

var PLATFORM_PACKAGES = bootstrap.PLATFORM_PACKAGES;

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

bootstrap.main({ pkgName: pkgName });
