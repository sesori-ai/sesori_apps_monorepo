"use strict";

var child_process = require("child_process");
var crypto = require("crypto");
var fs = require("fs");
var http = require("http");
var https = require("https");
var os = require("os");
var path = require("path");

var WRAPPER_MANIFEST_PATH = path.join(__dirname, "..", "package.json");
var DEFAULT_REPO_SLUG = "sesori-ai/sesori_apps_monorepo";
var PLATFORM_ASSETS = {
  "darwin arm64": "sesori-bridge-macos-arm64.tar.gz",
  "darwin x64": "sesori-bridge-macos-x64.tar.gz",
  "linux x64": "sesori-bridge-linux-x64.tar.gz",
  "linux arm64": "sesori-bridge-linux-arm64.tar.gz",
  "win32 x64": "sesori-bridge-windows-x64.zip",
};

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function removeRecursive(filePath) {
  fs.rmSync(filePath, { force: true, recursive: true });
}

function wrapperManifest() {
  return readJson(WRAPPER_MANIFEST_PATH);
}

function currentPlatformKey() {
  return process.platform + " " + process.arch;
}

function currentAssetName() {
  var assetName = PLATFORM_ASSETS[currentPlatformKey()];
  if (!assetName) {
    throw new Error(
      "sesori-bridge: Unsupported platform for GitHub release bootstrap: " + currentPlatformKey() + "."
    );
  }
  return assetName;
}

function releaseTag(manifest) {
  var metadata = manifest.sesoriBridge || {};
  return metadata.releaseTag || ("bridge-v" + manifest.version);
}

function wrapperVersion() {
  return wrapperManifest().version;
}

function wrapperReleaseTag() {
  return releaseTag(wrapperManifest());
}

function repositorySlug(manifest) {
  var repository = manifest.repository && manifest.repository.url ? String(manifest.repository.url) : "";
  var match = repository.match(/github\.com[/:]([^/]+\/[^/.]+)(?:\.git)?$/);
  return match ? match[1] : DEFAULT_REPO_SLUG;
}

function releasesBaseUrl(manifest) {
  if (process.env.SESORI_BRIDGE_RELEASES_BASE_URL) {
    return process.env.SESORI_BRIDGE_RELEASES_BASE_URL.replace(/\/$/, "");
  }
  return "https://github.com/" + repositorySlug(manifest) + "/releases/download";
}

function downloadUrl(manifest, fileName) {
  return releasesBaseUrl(manifest) + "/" + releaseTag(manifest) + "/" + fileName;
}

function checksumFor(content, fileName) {
  var lines = content.split(/\r?\n/);
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim();
    if (!line) {
      continue;
    }
    var parts = line.split(/\s+/);
    if (parts.length < 2) {
      continue;
    }
    var candidate = parts.slice(1).join(" ").replace(/^\*/, "");
    if (candidate === fileName) {
      return parts[0];
    }
  }
  throw new Error("Missing checksum entry for " + fileName + ".");
}

function sha256File(filePath) {
  return new Promise(function(resolve, reject) {
    var hash = crypto.createHash("sha256");
    var stream = fs.createReadStream(filePath);
    stream.on("error", reject);
    stream.on("data", function(chunk) {
      hash.update(chunk);
    });
    stream.on("end", function() {
      resolve(hash.digest("hex"));
    });
  });
}

function downloadToFile(url, destinationPath, redirectsRemaining) {
  return new Promise(function(resolve, reject) {
    var client = url.indexOf("https://") === 0 ? https : http;
    var request = client.get(url, function(response) {
      if (
        response.statusCode >= 300 &&
        response.statusCode < 400 &&
        response.headers.location &&
        redirectsRemaining > 0
      ) {
        response.resume();
        downloadToFile(response.headers.location, destinationPath, redirectsRemaining - 1)
          .then(resolve, reject);
        return;
      }
      if (response.statusCode !== 200) {
        response.resume();
        reject(new Error("Unexpected HTTP " + response.statusCode + " for " + url + "."));
        return;
      }
      var file = fs.createWriteStream(destinationPath);
      file.on("error", function(error) {
        response.destroy(error);
      });
      response.on("error", reject);
      file.on("finish", function() {
        file.close(function(closeError) {
          if (closeError) {
            reject(closeError);
            return;
          }
          resolve();
        });
      });
      response.pipe(file);
    });
    request.on("error", reject);
  });
}

function extractArchive(archivePath, extractRoot) {
  fs.mkdirSync(extractRoot, { recursive: true });
  if (/\.zip$/i.test(archivePath)) {
    if (process.platform === "win32") {
      child_process.execFileSync(
        "powershell.exe",
        [
          "-NoProfile",
          "-Command",
          "Expand-Archive -LiteralPath $args[0] -DestinationPath $args[1] -Force",
          archivePath,
          extractRoot,
        ],
        { stdio: "pipe" }
      );
      return;
    }
    child_process.execFileSync("unzip", ["-q", archivePath, "-d", extractRoot], { stdio: "pipe" });
    return;
  }
  child_process.execFileSync("tar", ["-xzf", archivePath, "-C", extractRoot], { stdio: "pipe" });
}

function validateExtractedRuntime(runtimeRoot) {
  var binPath = path.join(runtimeRoot, "bin", process.platform === "win32" ? "sesori-bridge.exe" : "sesori-bridge");
  var libPath = path.join(runtimeRoot, "lib");
  if (!fs.existsSync(binPath) || !fs.existsSync(libPath)) {
    throw new Error("Bootstrap payload is incomplete. Expected archive contents with bin/ and lib/.");
  }
}

async function resolvePayload() {
  var manifest = wrapperManifest();
  var version = manifest.version;
  var tag = releaseTag(manifest);
  var assetName = currentAssetName();
  var tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), "sesori-bridge-release-"));
  var archivePath = path.join(tempRoot, assetName);
  var checksumPath = path.join(tempRoot, "checksums.txt");
  var extractRoot = path.join(tempRoot, "payload");
  try {
    await downloadToFile(downloadUrl(manifest, assetName), archivePath, 10);
    await downloadToFile(downloadUrl(manifest, "checksums.txt"), checksumPath, 10);
    var expected = checksumFor(fs.readFileSync(checksumPath, "utf8"), assetName);
    var actual = await sha256File(archivePath);
    if (actual !== expected) {
      throw new Error(
        "Checksum mismatch for " + assetName + ". Expected " + expected + ", got " + actual + "."
      );
    }
    extractArchive(archivePath, extractRoot);
    validateExtractedRuntime(extractRoot);
    return {
      runtimeBundlePath: extractRoot,
      version: version,
      cleanup: function() {
        removeRecursive(tempRoot);
      },
      releaseTag: tag,
      assetName: assetName,
    };
  } catch (error) {
    removeRecursive(tempRoot);
    throw new Error(
      "sesori-bridge: Failed to download managed runtime from GitHub release assets for " +
        tag + ".\n" +
        String(error && error.message ? error.message : error)
    );
  }
}

module.exports = {
  wrapperReleaseTag: wrapperReleaseTag,
  wrapperVersion: wrapperVersion,
  resolvePayload: resolvePayload,
};
