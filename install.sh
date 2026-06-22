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

# ── Presentation layer ───────────────────────────────────────────────────────
# Shared visual spec (kept byte-for-byte equivalent across install.sh,
# install.ps1, and the npm bootstrap). Color and Unicode are opt-out: we degrade
# to plain ASCII whenever the environment can't be trusted to render them.
TOTAL_STEPS=4

# ┌─ PALETTE ───────────────────────────────────────────────────────────────────
# │ Edit these ANSI codes in ONE place to retheme the installer. They are the raw
# │ escape sequences; init_style() copies them into the C_* variables only when
# │ color is enabled (otherwise the C_* variables stay empty for plain output).
# │ 256-color codes: brand blue #1472FF ≈ 39 (bright) / 25 (deep).
# └──────────────────────────────────────────────────────────────────────────────
PALETTE_RESET=$'\033[0m'
PALETTE_BANNER=$'\033[0;2m'       # SESORI wordmark — faded grey; large enough to read without color
PALETTE_BRAND=$'\033[38;5;39m'    # accents: step counter, command, progress bar
PALETTE_BRAND_DIM=$'\033[38;5;25m'
PALETTE_GREEN=$'\033[38;5;42m'    # success
PALETTE_YELLOW=$'\033[38;5;214m'  # warning
PALETTE_RED=$'\033[38;5;203m'     # error
PALETTE_DIM=$'\033[0;2m'          # secondary / muted text
PALETTE_BOLD=$'\033[1m'

# Active palette (empty unless color is enabled). Assigned by init_style().
C_RESET=""
C_BANNER=""
C_BRAND=""
C_BRAND_DIM=""
C_GREEN=""
C_YELLOW=""
C_RED=""
C_DIM=""
C_BOLD=""

# Glyphs. Unicode where safe, ASCII otherwise. Populated by init_style().
G_CHECK=""
G_WARN=""
G_CROSS=""
G_ARROW=""
G_BAR_FULL=""
G_BAR_EMPTY=""

USE_COLOR=false
USE_UNICODE=false

# Detect whether color should be emitted. Honors NO_COLOR (disable), FORCE_COLOR
# (force on), a non-TTY stdout (disable), and TERM=dumb/unset (disable).
should_use_color() {
    if [ -n "${FORCE_COLOR:-}" ]; then
        return 0
    fi
    if [ -n "${NO_COLOR:-}" ]; then
        return 1
    fi
    if [ ! -t 1 ]; then
        return 1
    fi
    case "${TERM:-}" in
        "" | dumb) return 1 ;;
    esac
    return 0
}

# Detect whether Unicode glyphs are safe to emit. Requires a UTF-8 locale; falls
# back to ASCII for C/POSIX/unset locales and dumb terminals.
should_use_unicode() {
    case "${TERM:-}" in
        dumb) return 1 ;;
    esac
    case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
        *[Uu][Tt][Ff]-8* | *[Uu][Tt][Ff]8*) return 0 ;;
    esac
    return 1
}

init_style() {
    if should_use_color; then
        USE_COLOR=true
        C_RESET="${PALETTE_RESET}"
        C_BANNER="${PALETTE_BANNER}"
        C_BRAND="${PALETTE_BRAND}"
        C_BRAND_DIM="${PALETTE_BRAND_DIM}"
        C_GREEN="${PALETTE_GREEN}"
        C_YELLOW="${PALETTE_YELLOW}"
        C_RED="${PALETTE_RED}"
        C_DIM="${PALETTE_DIM}"
        C_BOLD="${PALETTE_BOLD}"
    fi

    if should_use_unicode; then
        USE_UNICODE=true
        G_CHECK="✓"
        G_WARN="⚠"
        G_CROSS="✗"
        G_ARROW="➜"
        G_BAR_FULL="■"
        G_BAR_EMPTY="･"
    else
        G_CHECK="[OK]"
        G_WARN="!"
        G_CROSS="x"
        G_ARROW=">"
        G_BAR_FULL="#"
        G_BAR_EMPTY="."
    fi
}

# Wrap ${2} in color ${1} (and the reset), or pass it through when color is off.
paint() {
    if [ "${USE_COLOR}" = true ]; then
        printf '%s%s%s' "${1}" "${2}" "${C_RESET}"
    else
        printf '%s' "${2}"
    fi
}

# The SESORI wordmark, in deep brand blue, printed as the header. Kept calm
# (deep blue, not the bright accent) so it frames the install without shouting.
print_banner() {
    local b="${C_BANNER}"
    local r="${C_RESET}"
    if [ "${USE_COLOR}" != true ]; then
        b=""
        r=""
    fi
    printf '\n'
    if [ "${USE_UNICODE}" = true ]; then
        printf '%s ███████╗███████╗███████╗ ██████╗ ██████╗ ██╗%s\n' "${b}" "${r}"
        printf '%s ██╔════╝██╔════╝██╔════╝██╔═══██╗██╔══██╗██║%s\n' "${b}" "${r}"
        printf '%s ███████╗█████╗  ███████╗██║   ██║██████╔╝██║%s\n' "${b}" "${r}"
        printf '%s ╚════██║██╔══╝  ╚════██║██║   ██║██╔══██╗██║%s\n' "${b}" "${r}"
        printf '%s ███████║███████╗███████║╚██████╔╝██║  ██║██║%s\n' "${b}" "${r}"
        printf '%s ╚══════╝╚══════╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝%s\n' "${b}" "${r}"
    else
        printf '%s  ____  _____ ____   ___  ____  ___ %s\n' "${b}" "${r}"
        printf '%s / ___|| ____/ ___| / _ \\|  _ \\|_ _|%s\n' "${b}" "${r}"
        printf '%s \\___ \\|  _| \\___ \\| | | | |_) || | %s\n' "${b}" "${r}"
        printf '%s  ___) | |___ ___) | |_| |  _ < | | %s\n' "${b}" "${r}"
        printf '%s |____/|_____|____/ \\___/|_| \\_\\___|%s\n' "${b}" "${r}"
    fi
    printf '\n'
    printf '  %s\n' "$(paint "${C_DIM}" "Installing the Sesori Bridge — connect AI coding sessions to your phone")"
    printf '\n'
}

# A "[n/N] message" step header in brand blue.
step() {
    local n="${1}"
    local message="${2}"
    printf '%s %s\n' "$(paint "${C_BRAND}" "[${n}/${TOTAL_STEPS}]")" "${message}"
}

# A green success line with a check glyph, used to confirm a completed step.
ok() {
    printf '      %s %s\n' "$(paint "${C_GREEN}" "${G_CHECK}")" "$(paint "${C_DIM}" "${1}")"
}

# A muted, indented note under a step.
note() {
    printf '      %s\n' "$(paint "${C_DIM}" "${1}")"
}

# Error / warning / note prefixes. Errors go to stderr; warnings too, since they
# accompany a degraded outcome the user must see even when stdout is redirected.
err() {
    printf '%s %s\n' "$(paint "${C_RED}" "${G_CROSS} Error:")" "${1}" >&2
}

warn() {
    printf '%s %s\n' "$(paint "${C_YELLOW}" "${G_WARN} Warning:")" "${1}" >&2
}

hint() {
    printf '%s %s\n' "$(paint "${C_BRAND}" "${G_ARROW} Note:")" "${1}" >&2
}

# Box-drawing helpers for a panel. Unicode by default, ASCII when Unicode is
# unsafe. PANEL_WIDTH is the inner width (between the borders). The border color
# is passed in (${1}) so the same panel can frame different kinds of content.
PANEL_WIDTH=56

panel_top() {
    local border="${1:-${C_BRAND}}"
    if [ "${USE_UNICODE}" = true ]; then
        printf '  %s┌%s┐%s\n' "${border}" "$(repeat_char '─' "${PANEL_WIDTH}")" "${C_RESET}"
    else
        printf '  %s+%s+%s\n' "${border}" "$(repeat_char '-' "${PANEL_WIDTH}")" "${C_RESET}"
    fi
}

panel_bottom() {
    local border="${1:-${C_BRAND}}"
    if [ "${USE_UNICODE}" = true ]; then
        printf '  %s└%s┘%s\n' "${border}" "$(repeat_char '─' "${PANEL_WIDTH}")" "${C_RESET}"
    else
        printf '  %s+%s+%s\n' "${border}" "$(repeat_char '-' "${PANEL_WIDTH}")" "${C_RESET}"
    fi
}

# A single panel row. ${1} is the content, ${2} (optional) a color applied to the
# content, ${3} (optional) the border color. Content longer than the inner width
# is truncated with an ellipsis so the right border stays aligned.
panel_row() {
    local content="${1}"
    local content_color="${2:-}"
    local border="${3:-${C_BRAND}}"
    local bar="|"
    [ "${USE_UNICODE}" = true ] && bar="│"

    local inner=$(( PANEL_WIDTH - 2 ))
    if [ "${#content}" -gt "${inner}" ]; then
        content="${content:0:$(( inner - 1 ))}…"
        [ "${USE_UNICODE}" = true ] || content="${content:0:$(( inner - 3 ))}..."
    fi
    local pad=$(( inner - ${#content} ))
    [ "${pad}" -lt 0 ] && pad=0
    local spaces
    spaces="$(printf '%*s' "${pad}" '')"
    printf '  %s%s%s %s%s %s%s%s\n' \
        "${border}" "${bar}" "${C_RESET}" \
        "$(paint "${content_color}" "${content}")" \
        "${spaces}" \
        "${border}" "${bar}" "${C_RESET}"
}

# A panel row that highlights a runnable command plus a muted inline comment,
# e.g. "sesori-bridge   # Start the bridge". Width/padding are computed from the
# PLAIN text (command + gap + comment) so the colored escapes don't skew the
# border alignment. ${3} is the border color.
panel_command_row() {
    local command="${1}"
    local comment="${2}"
    local border="${3:-${C_BRAND}}"
    local bar="|"
    [ "${USE_UNICODE}" = true ] && bar="│"

    local gap="   "
    local inner=$(( PANEL_WIDTH - 2 ))
    local ellipsis="..."
    [ "${USE_UNICODE}" = true ] && ellipsis="…"

    # Drop the comment if command + gap + comment overflows; truncate the command
    # itself only as a last resort, so the right border stays aligned.
    if [ $(( ${#command} + ${#gap} + ${#comment} )) -gt "${inner}" ]; then
        comment=""
    fi
    if [ "${#command}" -gt "${inner}" ]; then
        command="${command:0:$(( inner - ${#ellipsis} ))}${ellipsis}"
    fi

    local plain="${command}"
    [ -n "${comment}" ] && plain="${command}${gap}${comment}"
    local pad=$(( inner - ${#plain} ))
    [ "${pad}" -lt 0 ] && pad=0
    local spaces
    spaces="$(printf '%*s' "${pad}" '')"

    if [ -n "${comment}" ]; then
        printf '  %s%s%s %s%s%s%s %s%s%s\n' \
            "${border}" "${bar}" "${C_RESET}" \
            "$(paint "${C_BRAND}${C_BOLD}" "${command}")" \
            "${gap}" \
            "$(paint "${C_DIM}" "${comment}")" \
            "${spaces}" \
            "${border}" "${bar}" "${C_RESET}"
    else
        printf '  %s%s%s %s%s %s%s%s\n' \
            "${border}" "${bar}" "${C_RESET}" \
            "$(paint "${C_BRAND}${C_BOLD}" "${command}")" \
            "${spaces}" \
            "${border}" "${bar}" "${C_RESET}"
    fi
}

# A panel row with an emphasized middle segment: "${1}<bold ${2}>${3}". The
# prefix and suffix render in the default color; the middle is brand-blue/bold so
# a hard-requirement phrase (e.g. "new terminal") stands out. Width is computed
# from the plain concatenation so the border stays aligned. ${4} is border color.
panel_emphasis_row() {
    local prefix="${1}"
    local emphasis="${2}"
    local suffix="${3}"
    local border="${4:-${C_BRAND}}"
    local bar="|"
    [ "${USE_UNICODE}" = true ] && bar="│"

    local plain="${prefix}${emphasis}${suffix}"
    local inner=$(( PANEL_WIDTH - 2 ))
    local pad=$(( inner - ${#plain} ))
    [ "${pad}" -lt 0 ] && pad=0
    local spaces
    spaces="$(printf '%*s' "${pad}" '')"

    printf '  %s%s%s %s%s%s%s %s%s%s\n' \
        "${border}" "${bar}" "${C_RESET}" \
        "${prefix}" \
        "$(paint "${C_BRAND}${C_BOLD}" "${emphasis}")" \
        "${suffix}" \
        "${spaces}" \
        "${border}" "${bar}" "${C_RESET}"
}

repeat_char() {
    local ch="${1}"
    local count="${2}"
    local out
    out="$(printf '%*s' "${count}" '')"
    printf '%s' "${out// /${ch}}"
}

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
            err "Unsupported operating system: ${raw_os}"
            hint "Sesori Bridge supports macOS and Linux only."
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
            err "Unsupported architecture: ${raw_arch}"
            hint "Sesori Bridge supports x86_64 and arm64 only."
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
        err "Neither curl nor wget found. Please install one and retry."
        exit 1
    fi
}

# Render a single progress-bar frame: a brand-blue ■/･ bar plus a percentage.
# Drawn in place (carriage return, no newline) on the controlling terminal.
render_progress() {
    local bytes="${1}"
    local total="${2}"
    [ "${total}" -gt 0 ] || return 0

    local width=32
    local percent=$(( bytes * 100 / total ))
    [ "${percent}" -gt 100 ] && percent=100
    local on=$(( percent * width / 100 ))
    local off=$(( width - on ))

    local filled empty
    filled="$(printf '%*s' "${on}" '')"
    filled="${filled// /${G_BAR_FULL}}"
    empty="$(printf '%*s' "${off}" '')"
    empty="${empty// /${G_BAR_EMPTY}}"

    if [ "${USE_COLOR}" = true ]; then
        printf '\r      %s%s%s%s %3d%%' "${C_BRAND}" "${filled}" "${C_DIM}" "${empty}" "${percent}" >&4
        printf '%s' "${C_RESET}" >&4
    else
        printf '\r      %s%s %3d%%' "${filled}" "${empty}" "${percent}" >&4
    fi
}

# Download with a live progress bar. Prefers curl (trace-parsed byte counts for a
# branded bar); falls back to wget's native --show-progress; and to a plain
# download with a static note when neither a TTY nor curl is available.
download_with_progress() {
    local url="${1}"
    local dest="${2}"

    # Only animate on an interactive terminal; otherwise keep logs clean.
    if [ ! -t 1 ] || [ "${USE_COLOR}" != true ]; then
        note "Downloading release..."
        download "${url}" "${dest}"
        return $?
    fi

    if command -v curl > /dev/null 2>&1; then
        download_with_progress_curl "${url}" "${dest}"
        return $?
    fi

    if command -v wget > /dev/null 2>&1; then
        # wget renders its own progress bar on stderr; let it through.
        wget --show-progress -qO "${dest}" "${url}"
        return $?
    fi

    err "Neither curl nor wget found. Please install one and retry."
    exit 1
}

# curl-backed progress: parse curl's --trace-ascii stream for content-length and
# received-data events, accumulate bytes, and redraw the bar. Mirrors the
# approach used by the opencode installer.
download_with_progress_curl() {
    local url="${1}"
    local dest="${2}"

    local tmp_dir="${TMPDIR:-/tmp}"
    local tracefile="${tmp_dir}/sesori_install_$$.trace"
    rm -f "${tracefile}"
    if ! mkfifo "${tracefile}" 2>/dev/null; then
        # No FIFO support — fall back to a plain download.
        download "${url}" "${dest}"
        return $?
    fi

    # fd 4 mirrors stdout for the in-place bar; hide the cursor while it animates.
    exec 4>&1
    printf '\033[?25l' >&4

    curl --trace-ascii "${tracefile}" -fsSL -o "${dest}" "${url}" &
    local curl_pid=$!

    # --trace-ascii emits a hex/ASCII dump of the WHOLE payload (millions of lines
    # for a binary). Pre-filter with grep so the bash loop only sees the handful of
    # content-length / recv-data lines, and parse with bash's built-in regex so we
    # never fork tr/sed per line.
    local total=0 bytes=0
    while IFS= read -r line; do
        if [[ "${line}" =~ [Cc]ontent-[Ll]ength:[[:space:]]*([0-9]+) ]]; then
            total="${BASH_REMATCH[1]}"
            bytes=0
        elif [[ "${line}" =~ [Rr]ecv[[:space:]]data,[[:space:]]*([0-9]+)[[:space:]]bytes ]]; then
            if [ "${total}" -gt 0 ]; then
                bytes=$(( bytes + BASH_REMATCH[1] ))
                render_progress "${bytes}" "${total}"
            fi
        fi
    done < <(grep -E -i '^0000: content-length:|^<= recv data' "${tracefile}" 2>/dev/null || true)

    # Capture curl's exit status WITHOUT tripping errexit, so the terminal-state
    # cleanup below always runs even when the download fails (network error, 404,
    # interrupted transfer). Otherwise a failed install would leave the cursor
    # hidden and fd 4 open.
    local status=0
    wait "${curl_pid}" || status=$?

    rm -f "${tracefile}"
    # Restore cursor, end the bar line, and release fd 4.
    printf '\n' >&4
    printf '\033[?25h' >&4
    exec 4>&-
    return ${status}
}

fetch_text() {
    local url="${1}"
    if command -v curl > /dev/null 2>&1; then
        curl -fsSL -H "Accept: application/vnd.github+json" -H "User-Agent: sesori-bridge-installer" "${url}"
    elif command -v wget > /dev/null 2>&1; then
        wget -qO - --header="Accept: application/vnd.github+json" --header="User-Agent: sesori-bridge-installer" "${url}"
    else
        err "Neither curl nor wget found. Please install one and retry."
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
        err "Neither curl nor wget found. Please install one and retry."
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
        err "The latest release is missing ${filename}, and resolving an older release requires python3, which was not found."
        hint "Install python3 and retry, or report this at https://github.com/${GITHUB_REPO}/issues."
        exit 1
    fi

    TMPDIR_RELEASES="$(mktemp -d)"
    local page page_file page_count
    local page_files=()
    for page in $(seq 1 "${GITHUB_RELEASES_MAX_PAGES}"); do
        page_file="${TMPDIR_RELEASES}/releases-page-${page}.json"
        if ! fetch_text "${GITHUB_RELEASES_API_URL}?per_page=${GITHUB_RELEASES_PER_PAGE}&page=${page}" > "${page_file}"; then
            err "Unexpected release metadata returned by GitHub."
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
            err "Unexpected release metadata returned by GitHub."
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
        err "Could not resolve a published bridge release for ${filename}."
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
        err "Could not find checksum for ${filename} in checksums.txt"
        exit 1
    fi

    local actual_digest
    actual_digest="$(sha256_file "${archive}" "${os}")"

    if [ "${actual_digest}" != "${expected_digest}" ]; then
        err "SHA256 checksum mismatch for ${filename}"
        printf '        %s %s\n' "$(paint "${C_DIM}" "Expected:")" "${expected_digest}" >&2
        printf '        %s %s\n' "$(paint "${C_DIM}" "Got:     ")" "${actual_digest}" >&2
        hint "Download may be corrupted. Aborting."
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
        ok "~/.local/bin is already in your PATH"
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
                ok "Added ~/.local/bin to your PATH in ${rc_file}"
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
        ok "Added ~/.local/bin to your PATH in ${joined_files}"
        note "Run 'source ${updated_files[0]}' or open a new terminal to use it."
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
    ok "Linked ${link}"
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
                warn "Another sesori-bridge was found at ${existing}"
                hint "It may shadow the newly installed version."
                ;;
        esac
    fi
}

main() {
    init_style

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

    print_banner
    printf '  %s %s\n' "$(paint "${C_DIM}" "Platform")" "$(paint "${C_BOLD}" "${os}/${arch}")"
    printf '  %s  %s\n' "$(paint "${C_DIM}" "Version")" "$(paint "${C_BOLD}" "${release_label}")"
    printf '\n'

    step 1 "Downloading release"

    TMPDIR_WORK="$(mktemp -d)"
    local archive="${TMPDIR_WORK}/${filename}"
    local checksums="${TMPDIR_WORK}/checksums.txt"

    download_with_progress "${RESOLVED_ARCHIVE_URL}" "${archive}"
    download "${RESOLVED_CHECKSUMS_URL}" "${checksums}"
    ok "Downloaded ${filename}"

    step 2 "Verifying checksum"
    verify_checksum "${archive}" "${checksums}" "${filename}" "${os}"
    ok "Checksum verified"

    step 3 "Installing managed runtime"
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
        err "Could not determine the installed bridge version."
        exit 1
    fi
    printf '{"version":"%s"}\n' "${resolved_version}" > "${MANAGED_MANIFEST}"
    ok "Installed to ${INSTALL_DIR}"

    step 4 "Linking command"
    create_symlink "${BINARY}" "${SYMLINK}"

    check_conflicts
    add_to_path "${SYMLINK_DIR}"

    print_completion "${resolved_version}"
}

# Completion output: a quiet, plain success confirmation followed by a boxed
# "Next steps" call-to-action. The box is intentionally on the NEXT STEPS (not the
# success line), so the user's attention lands on what to do next. The runnable
# command is highlighted; the inline hint is muted.
print_completion() {
    local installed_version="${1}"

    # Prefer a ~-relative path so the location reads cleanly.
    local short_dir="${INSTALL_DIR}"
    case "${INSTALL_DIR}" in
        "${HOME}"/*) short_dir="~${INSTALL_DIR#"${HOME}"}" ;;
    esac

    # Plain (unboxed) success confirmation — present but understated. Only the
    # tick is green; the text stays default-colored so it doesn't compete with
    # the boxed call-to-action below.
    printf '\n'
    printf '%s %s\n' \
        "$(paint "${C_GREEN}" "${G_CHECK}")" \
        "Sesori Bridge v${installed_version} installed"
    printf '%s %s\n' \
        "$(paint "${C_DIM}" "Location")" \
        "$(paint "${C_DIM}" "${short_dir}")"
    printf '\n'

    local resolved_binary
    resolved_binary="$(command -v sesori-bridge 2>/dev/null || true)"
    local on_path=false
    if [ -n "${resolved_binary}" ] && { [ "${resolved_binary}" = "${BINARY}" ] || [ "${resolved_binary}" = "${SYMLINK}" ]; }; then
        on_path=true
    fi

    # Boxed "Next steps" call-to-action, framed in brand blue. A runnable command
    # must stay intact (copy/paste-able): if it fits a panel row we keep the boxed
    # layout, otherwise we print the full, un-truncated command on its own line
    # below the box rather than ellipsizing it.
    local command="sesori-bridge"
    local comment="# Start the bridge"
    local gap="   "
    local inner=$(( PANEL_WIDTH - 2 ))
    local fits_in_box=true
    [ $(( ${#command} + ${#gap} + ${#comment} )) -gt "${inner}" ] && fits_in_box=false

    panel_top "${C_BRAND}"
    panel_row "Next steps" "${C_BOLD}" "${C_BRAND}"
    panel_row "" "" "${C_BRAND}"
    if [ "${on_path}" != true ]; then
        # "new terminal" is a hard requirement, so emphasize it rather than mute
        # the whole line — a faded instruction gets skipped.
        panel_emphasis_row "In a " "new terminal" " window, run:" "${C_BRAND}"
        [ "${fits_in_box}" = true ] && panel_row "" "" "${C_BRAND}"
    fi
    if [ "${fits_in_box}" = true ]; then
        panel_command_row "${command}" "${comment}" "${C_BRAND}"
    fi
    panel_bottom "${C_BRAND}"

    if [ "${fits_in_box}" != true ]; then
        printf '\n'
        printf '    %s\n' "$(paint "${C_BRAND}${C_BOLD}" "${command}")"
    fi
    printf '\n'
}

main
