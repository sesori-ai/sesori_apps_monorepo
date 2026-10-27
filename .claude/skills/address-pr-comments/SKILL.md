---
name: address-pr-comments
description: Address unresolved inline PR review comments on a GitHub pull request. Fetches unresolved comments, assesses validity (with extra scrutiny for AI/bot reviewers), implements fixes, leaves a reply on every comment thread, and commits changes. Use when the user asks to address PR comments, resolve review feedback, implement requested changes, or handle PR review threads.
---

# address-pr-comments (Claude Code shim)

Read `.agents/skills/address-pr-comments/SKILL.md` now and follow it in full.

Its script paths are relative to `.agents/skills/address-pr-comments/`; Claude Code runs `bash` from the repository root, so run `.agents/skills/pr-inline-comments/scripts/fetch.sh` and `.agents/skills/address-pr-comments/scripts/reply.sh`.
