---
name: address-pr-comments
description: Address unresolved inline PR review comments on a GitHub pull request. Fetches unresolved comments, assesses validity (with extra scrutiny for AI/bot reviewers), implements fixes, leaves a reply on every comment thread, and commits changes. Use when the user asks to address PR comments, resolve review feedback, implement requested changes, or handle PR review threads.
---

# address-pr-comments (Claude Code shim)

This is the Claude Code entry point for the shared `address-pr-comments` skill. The full procedure — core rules, validity assessment, AI/bot scrutiny, commit/push ordering, reply formats, and edge cases — is **not duplicated here**. It lives in one canonical file.

**Read `.opencode/skills/address-pr-comments/SKILL.md` now and follow it in full.** (Path is relative to the repository root, which is the Claude Code working directory.)

## Path resolution

The canonical file uses paths relative to its own directory, `.opencode/skills/address-pr-comments/`. Claude Code runs `bash` from the repo root, so resolve its two script references against that directory:

| Canonical file says | Run from repo root |
| --- | --- |
| `../pr-inline-comments/scripts/fetch.sh` | `.opencode/skills/pr-inline-comments/scripts/fetch.sh` |
| `./scripts/reply.sh` | `.claude/skills/address-pr-comments/scripts/reply.sh` |

The `reply.sh` in this skill's `scripts/` is a thin wrapper that `exec`s the canonical `.opencode/skills/address-pr-comments/scripts/reply.sh`, so either path runs identical code. The fetch script is shared directly with no wrapper.

For resolving natural-language `--since` time windows into ISO 8601, the canonical file points at `.opencode/skills/pr-inline-comments/SKILL.md` — follow that section as written.
