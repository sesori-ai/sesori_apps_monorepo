#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'macOS QA MCP setup error: %s\n' "$1" >&2
  exit 64
}

require_command() {
  local command_name="$1"
  command -v "$command_name" >/dev/null 2>&1 || fail "${command_name} is not installed or not on PATH"
}

case "${1:-}" in
  check)
    require_command peekaboo
    require_command agent-device
    peekaboo --version
    printf 'agent-device %s\n' "$(agent-device --version)"
    ;;
  peekaboo)
    require_command peekaboo
    exec peekaboo mcp --no-remote
    ;;
  agent-device)
    require_command agent-device
    export AGENT_DEVICE_NO_UPDATE_NOTIFIER=1
    exec agent-device mcp
    ;;
  *)
    printf 'Usage: %s check|peekaboo|agent-device\n' "$0" >&2
    exit 64
    ;;
esac
