#!/usr/bin/env bash
set -euo pipefail

readonly peekaboo_expected_version="4.2.2"
readonly agent_device_expected_version="0.20.10"

fail() {
  printf 'macOS QA MCP setup error: %s\n' "$1" >&2
  exit 64
}

require_command() {
  local command_name="$1"
  command -v "$command_name" >/dev/null 2>&1 || fail "${command_name} is not installed or not on PATH"
}

peekaboo_version() {
  local output
  local product
  local version
  output="$(peekaboo --version)"
  read -r product version _ <<<"$output"
  [[ "$product" == "Peekaboo" && -n "$version" ]] || fail "could not parse Peekaboo version from: $output"
  printf '%s\n' "$version"
}

agent_device_version() {
  local output
  local version
  output="$(agent-device --version)"
  read -r version _ <<<"$output"
  [[ -n "$version" ]] || fail "could not parse agent-device version"
  printf '%s\n' "$version"
}

verify_peekaboo() {
  local actual_version
  require_command peekaboo
  actual_version="$(peekaboo_version)"
  [[ "$actual_version" == "$peekaboo_expected_version" ]] || \
    fail "expected Peekaboo ${peekaboo_expected_version}, found ${actual_version}"
}

verify_agent_device() {
  local actual_version
  require_command agent-device
  actual_version="$(agent_device_version)"
  [[ "$actual_version" == "$agent_device_expected_version" ]] || \
    fail "expected agent-device ${agent_device_expected_version}, found ${actual_version}"
}

case "${1:-}" in
  check)
    verify_peekaboo
    verify_agent_device
    printf 'Peekaboo %s\nagent-device %s\n' \
      "$peekaboo_expected_version" \
      "$agent_device_expected_version"
    ;;
  peekaboo)
    verify_peekaboo
    exec peekaboo mcp --no-remote
    ;;
  agent-device)
    verify_agent_device
    export AGENT_DEVICE_NO_UPDATE_NOTIFIER=1
    exec agent-device mcp
    ;;
  *)
    printf 'Usage: %s check|peekaboo|agent-device\n' "$0" >&2
    exit 64
    ;;
esac
