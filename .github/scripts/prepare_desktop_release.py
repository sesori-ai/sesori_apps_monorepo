#!/usr/bin/env python3
"""Prepare macOS release metadata from trusted qualification/shared-release artifacts.

Offline consistency checks only: never sign, publish, install, or claim ship readiness.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re


ARCHITECTURES = ("arm64", "x64")
CHANNELS = ("stable", "internal")
PRODUCER_WORKFLOWS = {".github/workflows/desktop-qualification.yml",
                      ".github/workflows/release-all-platforms.yml", ".github/workflows/submit-release.yml"}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def read_json(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), f"Expected JSON object: {path}")
    return value


def sha256(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def prepare(*, root: Path, source_sha: str, channel: str, tooling_sha: str,
            repository: str, run_id: int, current_run_id: int | None, output: Path) -> dict:
    require(bool(re.fullmatch(r"[0-9a-f]{40}", source_sha)), "Expected immutable source SHA")
    require(bool(re.fullmatch(r"[0-9a-f]{40}", tooling_sha)), "Expected immutable tooling SHA")
    require(channel in CHANNELS, "Unknown release channel")
    require(repository == "sesori-ai/sesori_apps_monorepo", "Unexpected producer repository")
    run = read_json(root / "run.json")
    require(run.get("id") == run_id and run_id > 0, "Wrong packaging run")
    require(run.get("repository", {}).get("full_name") == repository, "Wrong run repository")
    producer = run.get("path")
    require(producer in PRODUCER_WORKFLOWS, "Wrong producer workflow")
    require(run.get("event") == "workflow_dispatch" and run.get("head_branch") == "main",
            "Select a main-only manually dispatched producer")
    require(isinstance(run.get("head_sha"), str) and bool(re.fullmatch(r"[0-9a-f]{40}", run["head_sha"])),
            "Expected immutable producer workflow SHA")
    # A shared finalizer runs after its native build dependency, before its own run completes.
    own_finalizer = (run_id == current_run_id and run.get("head_sha") == tooling_sha
                     and producer != ".github/workflows/desktop-qualification.yml"
                     and run.get("status") == "in_progress" and run.get("conclusion") is None)
    require(run.get("conclusion") == "success" or own_finalizer, "Select a successful producer or its own finalizer")
    # Production and private qualification may rebuild an older main-ancestor product source.
    # Their sealed identity/compiled defines and producer-side ancestry guard bind that source.
    if producer == ".github/workflows/release-all-platforms.yml":
        require(run.get("head_sha") == source_sha, "Run source differs from selected source")
    records = []
    common = None
    for arch in ARCHITECTURES:
        packages = root / f"desktop-macos-packages-{arch}"
        evidence = root / f"desktop-macos-evidence-{arch}"
        bundle = evidence / "desktop-bundle"
        packaging = evidence / "desktop-macos-packaging"
        identity = read_json(packaging / "desktop-bundle.json")
        require(identity.get("os") == "macos" and identity.get("architecture") == arch,
                f"Wrong bundle target: {arch}")
        require(identity.get("sourceSha") == source_sha, f"Wrong bundle source: {arch}")
        version, build = identity.get("version"), identity.get("buildNumber")
        require(isinstance(version, str) and bool(re.fullmatch(r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)", version)),
                "Expected clean three-part release version")
        require(type(build) is int and build > 0, "Expected positive build number")
        if common is None:
            common = {"version": version, "buildNumber": build, "sourceSha": source_sha}
        require(common == {"version": version, "buildNumber": build, "sourceSha": source_sha},
                "Architecture release identities differ")
        defines = dict(line.split("=", 1) for line in (bundle / "dart-defines.env").read_text().splitlines())
        require(json.loads(defines["SESORI_DESKTOP_BUNDLE_IDENTITY"]) == identity,
                "Compiled identity differs from sealed bundle")
        require(defines["SESORI_DESKTOP_RELEASE_CHANNEL"] == channel, "Cannot relabel compiled channel")
        patch = bundle / "build-source-changes.patch"
        require(patch.exists() and patch.stat().st_size == 0, "Missing clean-source evidence or modified source")
        report = read_json(packaging / "packaging.json")
        require(report.get("packagerSourceSha") == source_sha and report.get("architecture") == arch,
                "Wrong packaging provenance")
        require(report.get("zip") == report.get("dmg") and bool(report.get("zip", {}).get("binaries")),
                "Missing or differing archive inventories")
        for kind in ("app", "dmg"):
            require(read_json(packaging / f"{kind}-notarization.json").get("status") == "Accepted",
                    f"Missing accepted {kind} notarization")
        expected_names = {f"Sesori-macos-{arch}.{suffix}" for suffix in ("zip", "dmg")}
        require(set(report.get("artifacts", {})) == expected_names, "Unexpected artifact inventory")
        for name in sorted(expected_names):
            digest = sha256(packages / name)
            require(digest == report["artifacts"][name], f"Artifact digest mismatch: {name}")
            records.append({**common, "channel": channel, "platform": "macos", "architecture": arch,
                            "name": name, "sha256": digest,
                            "evidenceArtifact": evidence.name})
    tag = f"v{common['version']}"
    if channel == "internal":
        tag += f"-internal.{common['buildNumber']}"
    metadata = {"schemaVersion": 1, **common, "channel": channel, "platform": "macos",
                "tag": tag, "preparationSourceSha": tooling_sha, "producerWorkflowSha": run["head_sha"],
                "packagingRun": run_id, "repository": repository, "artifacts": records,
                "proofBoundary": "Artifact consistency only; not independent signature verification, "
                                 "interactive/minimum-OS QA, or publication approval"}
    output.mkdir(parents=True)  # Fresh output only; do not overwrite a previous preparation.
    (output / "desktop-release.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    (output / "checksums.txt").write_text("".join(f"{row['sha256']}  {row['name']}\n" for row in records),
                                          encoding="utf-8")
    return metadata


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--tooling-sha", required=True)
    parser.add_argument("--channel", choices=CHANNELS, required=True)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--run-id", type=int, required=True)
    parser.add_argument("--output", type=Path, required=True)
    prepare(**vars(parser.parse_args()), current_run_id=int(os.environ.get("GITHUB_RUN_ID", "0")) or None)


if __name__ == "__main__":
    main()
