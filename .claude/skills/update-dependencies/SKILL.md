---
name: update-dependencies
description: Weekly dependency update workflow for Sesori Apps Monorepo. Updates every pubspec.yaml across the bridge and mobile workspaces plus standalone packages, regenerates all lockfiles, re-resolves iOS/macOS SwiftPM native dependencies (Package.resolved), updates Fastlane/Gemfile versions, handles conflicts, and verifies via analyze/test/codegen.
---

# update-dependencies (Claude Code shim)

This is the Claude Code entry point for the shared `update-dependencies` skill. The full procedure — preflight discovery, environment-constraint alignment, per-workspace dependency bumps, build verification, SwiftPM native-dependency resolution, Fastlane/Gemfile updates, and commit hygiene — is **not duplicated here**. It lives in one canonical file.

**Read `.ai/skills/update-dependencies/SKILL.md` now and follow it in full.** (Path is relative to the repository root, which is the Claude Code working directory.)

## Path resolution

No remapping is needed. Every command in the canonical file already uses paths relative to the repository root (e.g. `find . -name pubspec.yaml`, `cd shared && make pub-get`, `cd mobile/app/ios`), which is exactly where Claude Code runs `bash`. Run them as written. There are no skill-local scripts to resolve.
