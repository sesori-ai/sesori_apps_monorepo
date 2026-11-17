---
name: update-dependencies
description: Recurring repo maintenance run for the Sesori Apps Monorepo. Brings every dependency, toolchain, CI action and image up to date — Dart pubspecs and lockfiles, Flutter/Dart SDK, iOS/macOS SwiftPM, Fastlane/Gemfiles, the Android Gradle toolchain (AGP, Gradle wrapper, Kotlin/Google plugins, JDK), GitHub Actions and the toolchains/runners they install, Docker base images, Node packages, `.tool-versions` and pinned tool versions in scripts. Use for "maintenance", "update deps", "dependency update", "refresh toolchains/CI", "bump actions/Docker/Node" and similar requests.
---

# update-dependencies (Claude Code shim)

This is the Claude Code entry point for the shared `update-dependencies` skill, the recurring maintenance run. The full procedure is **not duplicated here**. It lives in one canonical file.

**Read `.agents/skills/update-dependencies/SKILL.md` now and follow it in full.** The path is relative to the repository root, which is the Claude Code working directory.

Every command in the canonical file uses paths relative to the repository root, so run them as written. There are no skill-local scripts.
