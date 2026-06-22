#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

# ──────────────────────────────────────────────────────────────────────────────
# TEMPORARY pinned installer for Sesori Bridge build v1.1.2-internal.136 (Windows).
#
# This is a throwaway debugging aid, NOT a supported install path. It installs an
# exact pinned internal build (the win32-x64 binary committed alongside this
# script) into the same managed-runtime location the real installer/npm bootstrap
# use, so `sesori-bridge` on PATH resolves to build 136.
#
#   Install root : %LOCALAPPDATA%\sesori
#   Binary       : %LOCALAPPDATA%\sesori\bin\sesori-bridge.exe
#   Libraries    : %LOCALAPPDATA%\sesori\lib\
#   Manifest     : %LOCALAPPDATA%\sesori\.managed-runtime.json  ({"version":"1.1.2-internal.136"})
#
# The payload is fetched anonymously from raw.githubusercontent.com on the public
# repo (GitHub Actions artifacts are NOT anonymously downloadable, so the binary
# is committed to the branch instead).
#
# Only x64 is shipped here. After installing, `sesori-bridge --version` reports
# `1.1.2` (the internal `.136` suffix lives in the release tag/manifest, not in
# the compiled appVersion).
# ──────────────────────────────────────────────────────────────────────────────

# ── Pinned build coordinates ──────────────────────────────────────────────────
$RepoOwner   = 'sesori-ai'
$RepoName    = 'sesori_apps_monorepo'
$Branch      = 'sesori-bridge-session-7954da'
$PayloadPath = 'tool/tmp-bridge-136/payload'
$Version     = '1.1.2-internal.136'

$RawBase = "https://raw.githubusercontent.com/$RepoOwner/$RepoName/$Branch/$PayloadPath"

# Relative payload files to fetch (extend if a future build adds more libs).
$PayloadFiles = @(
    'bin/sesori-bridge.exe',
    'lib/sqlite3.dll'
)

# ── Expected SHA256 (integrity check; matches the committed payload) ───────────
$ExpectedHashes = @{
    'bin/sesori-bridge.exe' = '41a4e615932b93a7f8fb1914e0b4987083ecaccd2bb3ed67ff883788e7a3aa3d'
    'lib/sqlite3.dll'       = '563a01a5fbb929844df1a9f6a84f73f7a53b9b183ebda8cb8399d69567adff09'
}

# ── Install layout (mirrors the real managed runtime) ─────────────────────────
$InstallRoot     = Join-Path $env:LOCALAPPDATA 'sesori'
$BinDir          = Join-Path $InstallRoot 'bin'
$LibDir          = Join-Path $InstallRoot 'lib'
$BinaryPath      = Join-Path $BinDir 'sesori-bridge.exe'
$ManagedManifest = Join-Path $InstallRoot '.managed-runtime.json'

function Write-Note { param([string]$Message) Write-Host "  $Message" }
function Write-Fail {
    param([string]$Message)
    [Console]::Error.WriteLine("Error: $Message")
    exit 1
}

Write-Host ''
Write-Host "Sesori Bridge - pinned build $Version (Windows x64)"
Write-Host ''

# ── Guard: this pinned payload is x64 only ────────────────────────────────────
$archRaw = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
if ($archRaw -notin @('AMD64', 'x64', 'X64')) {
    Write-Note "Detected architecture: $archRaw"
    if ($archRaw -in @('ARM64')) {
        Write-Note 'This pinned installer ships only the x64 build. Windows on ARM64 can run it under emulation,'
        Write-Note 'but if you need the native arm64 build use a different payload.'
    } else {
        Write-Fail "Unsupported architecture '$archRaw'. This pinned installer only provides x64."
    }
}

# ── If another bridge is running, the swap of a loaded .exe will fail ──────────
$running = Get-Process -Name 'sesori-bridge' -ErrorAction SilentlyContinue
if ($running) {
    Write-Fail 'A sesori-bridge process is currently running. Close it (and any phone-connected session) and re-run this installer.'
}

$TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "sesori-bridge-136-$([System.Guid]::NewGuid().ToString('N'))"

try {
    New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

    # ── Download payload into a temp dir, verifying each file's checksum ───────
    Write-Host '[1/3] Downloading pinned build payload'
    foreach ($relative in $PayloadFiles) {
        $url = "$RawBase/$relative"
        $dest = Join-Path $TempDir ($relative -replace '/', '\')
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null

        try {
            Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -Headers @{ 'User-Agent' = 'sesori-bridge-pinned-installer' }
        } catch {
            Write-Fail "Failed to download '$relative' from $url`n$($_.Exception.Message)"
        }

        $expected = $ExpectedHashes[$relative]
        if ($expected) {
            $actual = (Get-FileHash -Path $dest -Algorithm SHA256).Hash.ToLower()
            if ($actual -ne $expected.ToLower()) {
                Write-Fail "SHA256 mismatch for '$relative'.`n  Expected: $expected`n  Got:      $actual"
            }
        }
        Write-Note "downloaded $relative"
    }

    # ── Lay out the managed runtime (clean bin/ and lib/, keep update state) ───
    Write-Host '[2/3] Installing managed runtime'

    # Remove any stale binary/lib swap residue from a previous in-place update so
    # the next launch's reconciliation starts clean against this pinned build.
    foreach ($residue in @(
        (Join-Path $BinDir '.sesori-bridge.old'),
        (Join-Path $InstallRoot '.lib.old'),
        (Join-Path $InstallRoot '.sesori-bridge-staging'),
        (Join-Path $InstallRoot '.sesori-bridge-update-attempt.json')
    )) {
        if (Test-Path $residue) { Remove-Item -Recurse -Force -Path $residue -ErrorAction SilentlyContinue }
    }

    New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
    New-Item -ItemType Directory -Force -Path $LibDir | Out-Null

    # Replace the binary and the lib contents with the pinned payload.
    Copy-Item -Force -Path (Join-Path $TempDir 'bin\sesori-bridge.exe') -Destination $BinaryPath
    Get-ChildItem -Path (Join-Path $TempDir 'lib') -File | ForEach-Object {
        Copy-Item -Force -Path $_.FullName -Destination (Join-Path $LibDir $_.Name)
    }

    if (-not (Test-Path $BinaryPath)) {
        Write-Fail "Binary not found at '$BinaryPath' after install."
    }

    # Write the managed-runtime manifest so the npm bootstrap recognizes this
    # version and will not clobber/downgrade the pinned build on a later `npx`.
    $manifestJson = @{ version = $Version } | ConvertTo-Json -Compress
    [System.IO.File]::WriteAllText($ManagedManifest, $manifestJson, [System.Text.UTF8Encoding]::new($false))
    Write-Note "installed to $InstallRoot"

    # ── Ensure the bin dir is on the user PATH + this session ─────────────────
    Write-Host '[3/3] Linking command'
    $currentPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
    $pathEntries = $currentPath -split ';' | Where-Object { $_ -ne '' }
    $alreadyInPath = $pathEntries | Where-Object { $_.TrimEnd('\') -ieq $BinDir.TrimEnd('\') }
    if (-not $alreadyInPath) {
        $newPath = ($BinDir + ';' + ($pathEntries -join ';'))
        [Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')
        Write-Note "added $BinDir to your user PATH"
    } else {
        Write-Note "$BinDir already on your user PATH"
    }
    if ($env:PATH -notlike "*$BinDir*") {
        $env:PATH = "$BinDir;$env:PATH"
    }

    Write-Host ''
    Write-Host "Done. Sesori Bridge pinned to $Version installed at $InstallRoot"
    Write-Host 'Open a NEW terminal, then run:  sesori-bridge --version'
    Write-Host ''
} finally {
    if (Test-Path $TempDir) {
        Remove-Item -Recurse -Force -Path $TempDir -ErrorAction SilentlyContinue
    }
}
