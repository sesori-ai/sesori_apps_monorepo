#!/bin/bash
set -euo pipefail

# Sesori Bridge CLI installer
# Installs sesori-bridge to ~/.sesori/bin/

INSTALL_DIR="${HOME}/.sesori"
BIN_DIR="${INSTALL_DIR}/bin"
BINARY="${BIN_DIR}/sesori-bridge"
MANAGED_MANIFEST="${INSTALL_DIR}/.managed-runtime.json"
GITHUB_REPO="sesori-ai/sesori_apps_monorepo"
GITHUB_RELEASES_API_URL="https://api.github.com/repos/${GITHUB_REPO}/releases"
GITHUB_RELEASES_PER_PAGE=100
GITHUB_RELEASES_MAX_PAGES=10

TMPDIR_WORK=""
cleanup() {
    if [ -n "${TMPDIR_WORK}" ] && [ -d "${TMPDIR_WORK}" ]; then
        rm -rf "${TMPDIR_WORK}"
    fi
}
trap cleanup EXIT

detect_os() {
    local raw_os
    raw_os="$(uname -s)"
    case "${raw_os}" in
        Darwin) echo "macos" ;;
        Linux)  echo "linux" ;;
        *)
            echo "Unsupported operating system: ${raw_os}" >&2
            echo "Sesori Bridge supports macOS and Linux only." >&2
            exit 1
            ;;
    esac
}

detect_arch() {
    local raw_arch
    raw_arch="$(uname -m)"
    case "${raw_arch}" in
        x86_64)          echo "x64" ;;
        aarch64 | arm64) echo "arm64" ;;
        *)
            echo "Unsupported architecture: ${raw_arch}" >&2
            echo "Sesori Bridge supports x86_64 and arm64 only." >&2
            exit 1
            ;;
    esac
}

download() {
    local url="${1}"
    local dest="${2}"
    if command -v curl > /dev/null 2>&1; then
        curl -fsSL "${url}" -o "${dest}"
    elif command -v wget > /dev/null 2>&1; then
        wget -qO "${dest}" "${url}"
    else
        echo "Neither curl nor wget found. Please install one and retry." >&2
        exit 1
    fi
}

fetch_text() {
    local url="${1}"
    if command -v curl > /dev/null 2>&1; then
        curl -fsSL -H "Accept: application/vnd.github+json" -H "User-Agent: sesori-bridge-installer" "${url}"
    elif command -v wget > /dev/null 2>&1; then
        wget -qO - --header="Accept: application/vnd.github+json" --header="User-Agent: sesori-bridge-installer" "${url}"
    else
        echo "Neither curl nor wget found. Please install one and retry." >&2
        exit 1
    fi
}

resolve_release_contract() {
    local filename="${1}"
    if ! command -v python3 > /dev/null 2>&1; then
        echo "python3 is required to resolve the latest bridge release." >&2
        exit 1
    fi
    local releases_json='[]'
    local page_json
    local page
    for page in $(seq 1 "${GITHUB_RELEASES_MAX_PAGES}"); do
        page_json="$(fetch_text "${GITHUB_RELEASES_API_URL}?per_page=${GITHUB_RELEASES_PER_PAGE}&page=${page}")"
        releases_json="$(RELEASES_JSON="${releases_json}" PAGE_JSON="${page_json}" python3 -c '
import json, os

releases = json.loads(os.environ["RELEASES_JSON"])
page = json.loads(os.environ["PAGE_JSON"])
if not isinstance(releases, list) or not isinstance(page, list):
    raise SystemExit(1)
print(json.dumps(releases + page))
')" || {
            echo "Unexpected release metadata returned by GitHub." >&2
            exit 1
        }
        if [ "$(PAGE_JSON="${page_json}" python3 -c 'import json, os; page = json.loads(os.environ["PAGE_JSON"]); print(len(page))')" -lt "${GITHUB_RELEASES_PER_PAGE}" ]; then
            break
        fi
    done
    local resolved
resolved="$(RELEASES_JSON="${releases_json}" python3 -c '
import json, os, sys
from functools import cmp_to_key
import re

STABLE_VERSION_RE = re.compile(r"^\d+\.\d+\.\d+$")

def compare_versions(a: str, b: str) -> int:
    def split_pre(v: str):
        if "-" in v:
            core, pre = v.split("-", 1)
        else:
            core, pre = v, None
        return core, pre

    def parse_core(v: str):
        return [int(part) for part in v.split(".")]

    a_core, a_pre = split_pre(a)
    b_core, b_pre = split_pre(b)
    a_parts = parse_core(a_core)
    b_parts = parse_core(b_core)

    for left, right in zip(a_parts, b_parts):
        if left != right:
            return 1 if left > right else -1

    if len(a_parts) != len(b_parts):
        return 1 if len(a_parts) > len(b_parts) else -1

    if a_pre is None and b_pre is None:
        return 0
    if a_pre is None:
        return 1
    if b_pre is None:
        return -1
    return 0

def is_valid_stable_version(v: str) -> bool:
    return bool(STABLE_VERSION_RE.match(v))

filename = sys.argv[1]
releases = json.loads(os.environ["RELEASES_JSON"])
eligible = []
for release in releases:
    tag_name = release.get("tag_name", "")
    if not tag_name.startswith("bridge-v"):
        continue
    if release.get("draft") or release.get("prerelease"):
        continue
    version = tag_name.replace("bridge-v", "", 1)
    if not is_valid_stable_version(version):
        continue
    assets = {
        asset.get("name"): asset.get("browser_download_url")
        for asset in release.get("assets", [])
    }
    asset_url = assets.get(filename)
    checksums_url = assets.get("checksums.txt")
    if asset_url and checksums_url:
        eligible.append((version, tag_name, asset_url, checksums_url))

if eligible:
    eligible.sort(key=cmp_to_key(lambda left, right: compare_versions(left[0], right[0])), reverse=True)
    _, tag_name, asset_url, checksums_url = eligible[0]
    print(tag_name)
    print(asset_url)
    print(checksums_url)
    sys.exit(0)
sys.exit(1)
' "${filename}")" || {
        echo "Could not resolve a published bridge release for ${filename}." >&2
        exit 1
    }
    set -- ${resolved}
    if [ "$#" -ne 3 ]; then
        echo "Unexpected release metadata returned by GitHub." >&2
        exit 1
    fi
    RESOLVED_RELEASE_TAG="${1}"
    RESOLVED_ARCHIVE_URL="${2}"
    RESOLVED_CHECKSUMS_URL="${3}"
}

sha256_file() {
    local file="${1}"
    local os="${2}"
    if [ "${os}" = "macos" ]; then
        shasum -a 256 "${file}" | awk '{print $1}'
    else
        sha256sum "${file}" | awk '{print $1}'
    fi
}

verify_checksum() {
    local archive="${1}"
    local checksums_file="${2}"
    local filename="${3}"
    local os="${4}"

    local expected_digest
    expected_digest="$(awk -v name="${filename}" '$2 == name || $2 == "*" name { print $1; exit }' "${checksums_file}")"

    if [ -z "${expected_digest}" ]; then
        echo "Could not find checksum for ${filename} in checksums.txt" >&2
        exit 1
    fi

    local actual_digest
    actual_digest="$(sha256_file "${archive}" "${os}")"

    if [ "${actual_digest}" != "${expected_digest}" ]; then
        echo "SHA256 checksum mismatch for ${filename}" >&2
        echo "  Expected: ${expected_digest}" >&2
        echo "  Got:      ${actual_digest}" >&2
        echo "Download may be corrupted. Aborting." >&2
        exit 1
    fi
}

add_to_path() {
    local bin_dir="${1}"

    local shell_name
    shell_name="$(basename "${SHELL:-}")"

    local rc_file
    case "${shell_name}" in
        bash) rc_file="${HOME}/.bashrc" ;;
        zsh)  rc_file="${HOME}/.zshrc" ;;
        fish)
            rc_file="${HOME}/.config/fish/config.fish"
            mkdir -p "$(dirname "${rc_file}")"
            if ! grep -qF 'fish_add_path "$HOME/.sesori/bin"' "${rc_file}" 2>/dev/null; then
                echo 'fish_add_path "$HOME/.sesori/bin"' >> "${rc_file}"
                echo "PATH: persisted ~/.sesori/bin in ${rc_file}."
            fi
            return 0
            ;;
        *) rc_file="${HOME}/.profile" ;;
    esac

    local export_line='export PATH="$HOME/.sesori/bin:$PATH"'
    if ! grep -qF "${export_line}" "${rc_file}" 2>/dev/null; then
        echo "${export_line}" >> "${rc_file}"
        echo "PATH: persisted ~/.sesori/bin in ${rc_file}."
    fi
}

check_conflicts() {
    local existing
    existing="$(command -v sesori-bridge 2>/dev/null || true)"
    if [ -n "${existing}" ]; then
        case "${existing}" in
            "${INSTALL_DIR}"/*) : ;;
            *)
                echo "Warning: another sesori-bridge found at ${existing}" >&2
                echo "It may shadow the newly installed version." >&2
                ;;
        esac
    fi
}

main() {
    local os arch filename archive_url checksums_url

    os="$(detect_os)"
    arch="$(detect_arch)"
    filename="sesori-bridge-${os}-${arch}.tar.gz"
    resolve_release_contract "${filename}"
    archive_url="${RESOLVED_ARCHIVE_URL}"
    checksums_url="${RESOLVED_CHECKSUMS_URL}"

    echo "Sesori Bridge installer"
    echo "======================="
    echo "Platform     : ${os}/${arch}"
    echo "Release      : ${RESOLVED_RELEASE_TAG}"
    echo "Install root : ${INSTALL_DIR}"
    echo ""
    echo "[1/3] Downloading release assets..."

    TMPDIR_WORK="$(mktemp -d)"
    local archive="${TMPDIR_WORK}/${filename}"
    local checksums="${TMPDIR_WORK}/checksums.txt"

    download "${archive_url}" "${archive}"
    download "${checksums_url}" "${checksums}"

    echo "[2/3] Verifying checksum..."
    verify_checksum "${archive}" "${checksums}" "${filename}" "${os}"
    echo "Checksum OK."

    echo "[3/3] Installing managed runtime..."
    mkdir -p "${BIN_DIR}"
    tar -xzf "${archive}" -C "${INSTALL_DIR}"

    chmod +x "${BINARY}"
    printf '{"version":"%s"}\n' "${RESOLVED_RELEASE_TAG#bridge-v}" > "${MANAGED_MANIFEST}"

    if [ "${os}" = "macos" ]; then
        xattr -dr com.apple.quarantine "${BINARY}" 2>/dev/null || true
    fi

    check_conflicts
    add_to_path "${BIN_DIR}"

    echo ""
    echo "Sesori Bridge install complete"
    echo "============================"
    echo "Managed binary : ${BINARY}"
    echo ""
    echo "Next step"
    echo "---------"
    echo "sesori-bridge"
    echo ""
    echo "If sesori-bridge is not available in this shell yet, open a new terminal or run:"
    echo "${BINARY}"
}

main
