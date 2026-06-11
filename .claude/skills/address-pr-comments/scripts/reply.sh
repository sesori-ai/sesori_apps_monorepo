#!/usr/bin/env bash
# Thin wrapper around the shared OpenCode reply.sh. The real logic (arg parsing,
# [Sesori reply] prefixing, gh API call) lives there, so it stays a single
# source of truth across harnesses. All arguments are forwarded verbatim.
set -euo pipefail
# Resolve the repo root from this script's own location (the directory layout is
# static) rather than `git rev-parse`, so it works without a git subprocess and
# survives strict ownership rules in CI/containers.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/../../../../.opencode/skills/address-pr-comments/scripts/reply.sh" "$@"
