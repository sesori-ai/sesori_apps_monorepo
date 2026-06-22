#!/bin/bash
set -euo pipefail

# Sesori Bridge CLI installer
# Installs sesori-bridge to ~/.local/share/sesori/ and creates a symlink in ~/.local/bin/

INSTALL_DIR="${HOME}/.local/share/sesori"
BINARY="${INSTALL_DIR}/bin/sesori-bridge"
SYMLINK_DIR="${HOME}/.local/bin"
SYMLINK="${SYMLINK_DIR}/sesori-bridge"
MANAGED_MANIFEST="${INSTALL_DIR}/.managed-runtime.json"
GITHUB_REPO="sesori-ai/sesori_apps_monorepo"
# Base hosts are overridable for GitHub Enterprise or testing (see Bun/uv installers).
GITHUB="${GITHUB:-https://github.com}"
GITHUB_API="${GITHUB_API:-https://api.github.com}"
# Fallback-only knobs: scanning recent releases is a cold path used only when the
# latest release is missing this platform's asset. Kept small because the release
# pipeline prunes internal pre-releases to a single rolling object.
GITHUB_RELEASES_API_URL="${GITHUB_API}/repos/${GITHUB_REPO}/releases"
GITHUB_RELEASES_PER_PAGE=30
GITHUB_RELEASES_MAX_PAGES=3

# Populated by resolve_release(): the version (without leading "v") and the
# archive/checksums download URLs for the release being installed.
RESOLVED_VERSION=""
RESOLVED_ARCHIVE_URL=""
RESOLVED_CHECKSUMS_URL=""

TMPDIR_WORK=""
TMPDIR_RELEASES=""
cleanup() {
    if [ -n "${TMPDIR_WORK}" ] && [ -d "${TMPDIR_WORK}" ]; then
        rm -rf "${TMPDIR_WORK}"
    fi
    if [ -n "${TMPDIR_RELEASES}" ] && [ -d "${TMPDIR_RELEASES}" ]; then
        rm -rf "${TMPDIR_RELEASES}"
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

# Emits the HTTP response headers (including any redirect hops) for a HEAD
# request to ${url}, and returns non-zero if the URL ultimately 404s/errors.
# Used to learn the resolved version from GitHub's latest -> versioned-download
# redirect without downloading the asset body.
fetch_redirect_headers() {
    local url="${1}"
    if command -v curl > /dev/null 2>&1; then
        curl -fsSL -I -H "User-Agent: sesori-bridge-installer" "${url}"
    elif command -v wget > /dev/null 2>&1; then
        wget -S --spider --header="User-Agent: sesori-bridge-installer" "${url}" 2>&1
    else
        echo "Neither curl nor wget found. Please install one and retry." >&2
        exit 1
    fi
}

# Pure transformation: reads HTTP header text on stdin and prints the X.Y.Z
# version embedded in a GitHub "releases/download/vX.Y.Z/" redirect Location.
parse_version_from_headers() {
    sed -nE 's#.*/releases/download/v([0-9]+\.[0-9]+\.[0-9]+)/.*#\1#p' | head -n 1
}

# Reads HTTP header text on stdin; succeeds only if the FINAL HTTP status is 2xx.
# Some older curl builds (< 7.76.0) exit 0 on a 404 HEAD when combining -I with
# -f, so the exit code alone cannot confirm an asset exists. We inspect the last
# status line specifically (not any 2xx line) so an intermediate 2xx — e.g. an
# HTTP proxy's "200 Connection established" before a final 404 — is not misread
# as success. POSIX awk keeps this portable across BSD (macOS) and GNU awk.
headers_indicate_success() {
    awk 'toupper($1) ~ /^HTTP\// { status = $2 } END { exit (status ~ /^2[0-9][0-9]$/) ? 0 : 1 }'
}

# Returns 0 when a HEAD to ${1} ultimately resolves to a 2xx response.
remote_asset_exists() {
    local headers
    headers="$(fetch_redirect_headers "${1}")" || return 1
    printf '%s\n' "${headers}" | headers_indicate_success
}

# Resolver (primary): GitHub serves an always-latest static asset at
# releases/latest/download/<file>, redirecting through the versioned download
# path. Probe it to confirm the archive AND checksums.txt both exist and to learn
# the version, then publish the resolution contract. Returns non-zero when the
# latest release does not carry a complete asset set for this platform, so the
# caller can fall back to a scan of older releases.
resolve_release_via_latest() {
    local filename="${1}"
    local latest_base="${GITHUB}/${GITHUB_REPO}/releases/latest/download"

    local headers
    headers="$(fetch_redirect_headers "${latest_base}/${filename}")" || return 1
    # Confirm the archive itself resolved (not just an intermediate redirect).
    printf '%s\n' "${headers}" | headers_indicate_success || return 1

    # checksums.txt is a separate release asset; during a partial publish the
    # archive can exist without it. Require both so we fall back to a complete
    # older release instead of failing the later checksum download.
    remote_asset_exists "${latest_base}/checksums.txt" || return 1

    local version
    version="$(printf '%s\n' "${headers}" | parse_version_from_headers)"

    if [ -n "${version}" ]; then
        RESOLVED_VERSION="${version}"
        RESOLVED_ARCHIVE_URL="${GITHUB}/${GITHUB_REPO}/releases/download/v${version}/${filename}"
        RESOLVED_CHECKSUMS_URL="${GITHUB}/${GITHUB_REPO}/releases/download/v${version}/checksums.txt"
    else
        # The asset exists but the version was not parseable from the redirect;
        # download via the always-latest URLs and resolve the version from the
        # installed binary after extraction.
        RESOLVED_VERSION=""
        RESOLVED_ARCHIVE_URL="${latest_base}/${filename}"
        RESOLVED_CHECKSUMS_URL="${latest_base}/checksums.txt"
    fi
    return 0
}

# Resolver (fallback): used only when the latest release lacks this platform's
# asset. Pages recent releases into temp FILES (never argv/env, to avoid the
# Linux MAX_ARG_STRLEN limit that broke the previous implementation) and selects
# the newest stable release that carries both the asset and checksums.txt.
resolve_release_via_scan() {
    local filename="${1}"
    if ! command -v python3 > /dev/null 2>&1; then
        echo "The latest release is missing ${filename}, and resolving an older release requires python3, which was not found." >&2
        echo "Install python3 and retry, or report this at https://github.com/${GITHUB_REPO}/issues." >&2
        exit 1
    fi

    TMPDIR_RELEASES="$(mktemp -d)"
    local page page_file page_count
    local page_files=()
    for page in $(seq 1 "${GITHUB_RELEASES_MAX_PAGES}"); do
        page_file="${TMPDIR_RELEASES}/releases-page-${page}.json"
        if ! fetch_text "${GITHUB_RELEASES_API_URL}?per_page=${GITHUB_RELEASES_PER_PAGE}&page=${page}" > "${page_file}"; then
            echo "Unexpected release metadata returned by GitHub." >&2
            exit 1
        fi
        page_count="$(python3 -c '
import json, sys

with open(sys.argv[1], encoding="utf-8") as handle:
    page = json.load(handle)
if not isinstance(page, list):
    raise SystemExit(1)
print(len(page))
' "${page_file}")" || {
            echo "Unexpected release metadata returned by GitHub." >&2
            exit 1
        }
        page_files+=("${page_file}")
        if [ "${page_count}" -lt "${GITHUB_RELEASES_PER_PAGE}" ]; then
            break
        fi
    done

    local tag
    tag="$(python3 -c '
import json, sys
from functools import cmp_to_key
import re

STABLE_VERSION_RE = re.compile(r"^\d+\.\d+\.\d+$")

def compare_versions(a: str, b: str) -> int:
    a_parts = [int(part) for part in a.split(".")]
    b_parts = [int(part) for part in b.split(".")]
    for left, right in zip(a_parts, b_parts):
        if left != right:
            return 1 if left > right else -1
    if len(a_parts) != len(b_parts):
        return 1 if len(a_parts) > len(b_parts) else -1
    return 0

def is_valid_stable_version(v: str) -> bool:
    return bool(STABLE_VERSION_RE.match(v))

filename = sys.argv[1]
releases = []
for path in sys.argv[2:]:
    with open(path, encoding="utf-8") as handle:
        releases.extend(json.load(handle))

eligible = []
for release in releases:
    tag_name = release.get("tag_name", "")
    if tag_name.startswith("v"):
        version = tag_name.replace("v", "", 1)
    else:
        continue
    if release.get("draft") or release.get("prerelease"):
        continue
    if not is_valid_stable_version(version):
        continue
    asset_names = {asset.get("name") for asset in release.get("assets", [])}
    if filename in asset_names and "checksums.txt" in asset_names:
        eligible.append((version, tag_name))

if eligible:
    eligible.sort(key=cmp_to_key(lambda left, right: compare_versions(left[0], right[0])), reverse=True)
    print(eligible[0][1])
    sys.exit(0)
sys.exit(1)
' "${filename}" "${page_files[@]}")" || {
        echo "Could not resolve a published bridge release for ${filename}." >&2
        exit 1
    }

    RESOLVED_VERSION="${tag#v}"
    RESOLVED_ARCHIVE_URL="${GITHUB}/${GITHUB_REPO}/releases/download/${tag}/${filename}"
    RESOLVED_CHECKSUMS_URL="${GITHUB}/${GITHUB_REPO}/releases/download/${tag}/checksums.txt"
    return 0
}

# Coordinator: resolves the release to install via two peer strategies that
# publish the same contract (RESOLVED_VERSION / RESOLVED_ARCHIVE_URL /
# RESOLVED_CHECKSUMS_URL). The always-latest path is tried first; the
# older-release scan is the fallback.
resolve_release() {
    local filename="${1}"
    if resolve_release_via_latest "${filename}"; then
        return 0
    fi
    resolve_release_via_scan "${filename}"
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

is_local_bin_in_path() {
    case ":${PATH}:" in
        *:"${HOME}/.local/bin":*)
            return 0
            ;;
    esac
    return 1
}

add_to_path() {
    local bin_dir="${1}"

    if is_local_bin_in_path; then
        echo "PATH: ~/.local/bin is already in your PATH."
        return 0
    fi

    local shell_name
    shell_name="$(basename "${SHELL:-}")"

    local rc_files=()
    case "${shell_name}" in
        bash) rc_files=("${HOME}/.bashrc" "${HOME}/.profile") ;;
        zsh)  rc_files=("${HOME}/.zshrc" "${HOME}/.zprofile") ;;
        fish)
            local rc_file="${HOME}/.config/fish/config.fish"
            mkdir -p "$(dirname "${rc_file}")"
            if ! grep -qF 'fish_add_path "$HOME/.local/bin"' "${rc_file}" 2>/dev/null; then
                echo 'fish_add_path "$HOME/.local/bin"' >> "${rc_file}"
                echo "PATH: persisted ~/.local/bin in ${rc_file}."
            fi
            return 0
            ;;
        *) rc_files=("${HOME}/.profile") ;;
    esac

    local export_line='export PATH="$HOME/.local/bin:$PATH"'
    local updated_files=()
    local rc_file
    for rc_file in "${rc_files[@]}"; do
        if ! grep -qF "${export_line}" "${rc_file}" 2>/dev/null; then
            echo "${export_line}" >> "${rc_file}"
            updated_files+=("${rc_file}")
        fi
    done

    if [ ${#updated_files[@]} -gt 0 ]; then
        local joined_files="${updated_files[0]}"
        local index
        for (( index=1; index<${#updated_files[@]}; index++ )); do
            if [ ${index} -eq $((${#updated_files[@]} - 1)) ]; then
                joined_files+=" and ${updated_files[index]}"
            else
                joined_files+=", ${updated_files[index]}"
            fi
        done
        echo "PATH: persisted ~/.local/bin in ${joined_files}. Run 'source ${updated_files[0]}' or open a new terminal."
    fi
}

create_symlink() {
    local target="${1}"
    local link="${2}"

    mkdir -p "$(dirname "${link}")"

    if [ -L "${link}" ]; then
        rm "${link}"
    elif [ -e "${link}" ]; then
        rm -f "${link}"
    fi

    ln -s "${target}" "${link}"
    echo "Symlink: ${link} -> ${target}"
    return 0
}

check_conflicts() {
    local existing
    existing="$(command -v sesori-bridge 2>/dev/null || true)"
    if [ -n "${existing}" ]; then
        case "${existing}" in
            "${INSTALL_DIR}"/*) : ;;
            "${SYMLINK}") : ;;
            *)
                echo "Warning: another sesori-bridge found at ${existing}" >&2
                echo "It may shadow the newly installed version." >&2
                ;;
        esac
    fi
}

main() {
    local os arch filename

    os="$(detect_os)"
    arch="$(detect_arch)"
    filename="sesori-bridge-${os}-${arch}.tar.gz"
    resolve_release "${filename}"

    local release_label
    if [ -n "${RESOLVED_VERSION}" ]; then
        release_label="v${RESOLVED_VERSION}"
    else
        release_label="latest"
    fi

    echo "Sesori Bridge installer"
    echo "======================="
    echo "Platform     : ${os}/${arch}"
    echo "Release      : ${release_label}"
    echo "Install root : ${INSTALL_DIR}"
    echo "Symlink      : ${SYMLINK}"
    echo ""
    echo "[1/4] Downloading release assets..."

    TMPDIR_WORK="$(mktemp -d)"
    local archive="${TMPDIR_WORK}/${filename}"
    local checksums="${TMPDIR_WORK}/checksums.txt"

    download "${RESOLVED_ARCHIVE_URL}" "${archive}"
    download "${RESOLVED_CHECKSUMS_URL}" "${checksums}"

    echo "[2/4] Verifying checksum..."
    verify_checksum "${archive}" "${checksums}" "${filename}" "${os}"
    echo "Checksum OK."

    echo "[3/4] Installing managed runtime..."
    mkdir -p "${INSTALL_DIR}"
    tar -xzf "${archive}" -C "${INSTALL_DIR}"

    chmod +x "${BINARY}"

    if [ "${os}" = "macos" ]; then
        xattr -dr com.apple.quarantine "${INSTALL_DIR}" 2>/dev/null || true
        xattr -dr com.apple.provenance "${INSTALL_DIR}" 2>/dev/null || true
    fi

    # The version comes from the resolved release; if the redirect could not be
    # parsed (rare), fall back to the freshly installed binary. Quarantine xattrs
    # are stripped above first so the binary can run on macOS.
    local resolved_version="${RESOLVED_VERSION}"
    if [ -z "${resolved_version}" ]; then
        resolved_version="$("${BINARY}" --version 2>/dev/null | head -n 1 | tr -d '[:space:]')"
    fi
    if [ -z "${resolved_version}" ]; then
        echo "Could not determine the installed bridge version." >&2
        exit 1
    fi
    printf '{"version":"%s"}\n' "${resolved_version}" > "${MANAGED_MANIFEST}"

    echo "[4/4] Creating symlink..."
    create_symlink "${BINARY}" "${SYMLINK}"

    check_conflicts
    add_to_path "${SYMLINK_DIR}"

    echo ""
    echo "Sesori Bridge install complete"
    echo "============================"
    echo "Managed binary : ${BINARY}"
    echo "Symlink        : ${SYMLINK}"
    echo ""

    local resolved_binary
    resolved_binary="$(command -v sesori-bridge 2>/dev/null || true)"
    if [ -n "${resolved_binary}" ] && { [ "${resolved_binary}" = "${BINARY}" ] || [ "${resolved_binary}" = "${SYMLINK}" ]; }; then
        echo "sesori-bridge is available in this terminal."
        echo ""
        echo "Next steps"
        echo "----------"
        echo "Start the bridge:"
        echo "   sesori-bridge"
    else
        echo "Next steps"
        echo "----------"
        echo "1. Open a new terminal"
        echo "2. Run the bridge:"
        echo "   sesori-bridge"
    fi
}

main
