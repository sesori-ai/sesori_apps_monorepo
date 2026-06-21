#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

# Sesori Bridge CLI - Windows Installer
# Usage: irm https://raw.githubusercontent.com/sesori-ai/sesori_apps_monorepo/main/install.ps1 | iex

$RepoOwner  = 'sesori-ai'
$RepoName   = 'sesori_apps_monorepo'
$RepoBase   = "https://github.com/$RepoOwner/$RepoName"
$ReleasesApiUrl = "https://api.github.com/repos/$RepoOwner/$RepoName/releases"
# Fallback-only knobs: scanning recent releases is a cold path used only when the
# latest release lacks this platform's asset. Kept small because the release
# pipeline prunes internal pre-releases to a single rolling object.
$ReleasesPerPage = 30
$ReleasesMaxPages = 3
$BinaryName = 'sesori-bridge.exe'
$InstallRoot = Join-Path $env:LOCALAPPDATA 'sesori'
$BinDir      = Join-Path $InstallRoot 'bin'
$ManagedManifest = Join-Path $InstallRoot '.managed-runtime.json'

# ── Architecture detection ────────────────────────────────────────────────────
$arch = $null

function Resolve-OsArchitecture {
    if ($env:PROCESSOR_ARCHITEW6432) {
        return $env:PROCESSOR_ARCHITEW6432
    }

    # PROCESSOR_ARCHITECTURE is non-localized, whereas Win32_OperatingSystem.OSArchitecture
    # returns localizable strings on non-English Windows (e.g. "ARM 64-bit Processor").
    # Prefer the environment variable so ARM64 machines are never rejected because of localization.
    if ($env:PROCESSOR_ARCHITECTURE) {
        return $env:PROCESSOR_ARCHITECTURE
    }

    try {
        $osArch = (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).OSArchitecture
        if ($osArch) {
            return $osArch
        }
    } catch {
        # CIM unavailable; return $null and let the caller reject the unknown architecture.
    }

    return $null
}

$detectedOsArchitecture = Resolve-OsArchitecture
switch ($detectedOsArchitecture) {
    '64-bit' { $arch = 'x64' }
    'AMD64'  { $arch = 'x64' }
    'X64'    { $arch = 'x64' }
    'ARM64'  { $arch = 'arm64' }
    'ARM 64-bit Processor' { $arch = 'arm64' }
    default  { $arch = $null }
}

if ($arch -notin @('x64', 'arm64')) {
    Write-Error "Unsupported architecture '$detectedOsArchitecture'. Only x64 (AMD64) and arm64 are supported on Windows."
    exit 1
}

$ArchiveName   = "sesori-bridge-windows-$arch.zip"
# Returns the Location header of the first (non-followed) redirect for $Url, or
# $null. Used to learn the version from GitHub's latest -> versioned-download
# redirect without downloading the asset body.
function Get-RedirectLocation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    $request = [System.Net.WebRequest]::Create($Url)
    $request.Method = 'HEAD'
    $request.AllowAutoRedirect = $false
    $request.UserAgent = 'sesori-bridge-installer'
    try {
        $response = $request.GetResponse()
        try {
            return $response.Headers['Location']
        } finally {
            $response.Close()
        }
    } catch [System.Net.WebException] {
        $errorResponse = $_.Exception.Response
        if ($errorResponse) {
            try {
                return $errorResponse.Headers['Location']
            } finally {
                $errorResponse.Close()
            }
        }
        return $null
    }
}

# Returns $true when a HEAD request to $Url (following redirects) resolves to 200.
function Test-RemoteAssetExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    try {
        $response = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing -Headers @{ 'User-Agent' = 'sesori-bridge-installer' }
        return $response.StatusCode -eq 200
    } catch {
        return $false
    }
}

# Resolver (primary): GitHub serves an always-latest static asset at
# releases/latest/download/<file>, redirecting through the versioned download
# path. Read the version from that redirect, confirm the asset exists, and
# publish the resolution contract. Returns $null when the latest release does not
# carry this platform's asset, so the coordinator can fall back to a scan.
function Resolve-BridgeReleaseViaLatest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArchiveName
    )

    $latestAssetUrl = "$RepoBase/releases/latest/download/$ArchiveName"
    $location = Get-RedirectLocation -Url $latestAssetUrl
    if (-not $location -or $location -notmatch 'releases/download/(v[0-9]+\.[0-9]+\.[0-9]+)/') {
        return $null
    }

    $tagName = $Matches[1]
    $assetUrl = "$RepoBase/releases/download/$tagName/$ArchiveName"
    $checksumsUrl = "$RepoBase/releases/download/$tagName/checksums.txt"
    # Require both the archive and checksums.txt. During a partial publish the
    # archive can exist without checksums; without this the installer would fail
    # the later checksum download instead of falling back to an older release.
    if (-not (Test-RemoteAssetExists -Url $assetUrl) -or -not (Test-RemoteAssetExists -Url $checksumsUrl)) {
        return $null
    }

    return [pscustomobject]@{
        Version = $tagName.Substring(1)
        TagName = $tagName
        AssetUrl = $assetUrl
        ChecksumsUrl = $checksumsUrl
    }
}

# Resolver (fallback): used only when the latest release lacks this platform's
# asset. Scans recent releases and selects the newest stable one carrying both
# the asset and checksums.txt. Returns $null when none qualifies.
function Resolve-BridgeReleaseViaScan {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArchiveName
    )

    $releases = @()
    for ($page = 1; $page -le $ReleasesMaxPages; $page++) {
        $pageReleases = Invoke-RestMethod -Uri "${ReleasesApiUrl}?per_page=$ReleasesPerPage&page=$page" -Headers @{
            'Accept' = 'application/vnd.github+json'
            'User-Agent' = 'sesori-bridge-installer'
        }
        $releases += $pageReleases
        if ($pageReleases.Count -lt $ReleasesPerPage) {
            break
        }
    }

    $eligible = @()
    foreach ($release in $releases) {
        $tagName = [string]$release.tag_name
        if ($tagName.StartsWith('v')) {
            $versionText = $tagName.Substring(1)
        } else {
            continue
        }
        if ($release.draft -or $release.prerelease) {
            continue
        }
        $parsedVersion = $null
        if (-not [version]::TryParse($versionText, [ref]$parsedVersion)) {
            continue
        }

        $asset = $release.assets | Where-Object { $_.name -eq $ArchiveName } | Select-Object -First 1
        $checksums = $release.assets | Where-Object { $_.name -eq 'checksums.txt' } | Select-Object -First 1
        if ($asset -and $checksums) {
            $eligible += [pscustomobject]@{
                Version = $parsedVersion
                TagName = $tagName
                AssetUrl = $asset.browser_download_url
                ChecksumsUrl = $checksums.browser_download_url
            }
        }
    }

    if ($eligible.Count -gt 0) {
        return $eligible | Sort-Object Version -Descending | Select-Object -First 1
    }

    return $null
}

# Coordinator: resolves the release to install via two peer strategies that
# return the same shape (Version/TagName/AssetUrl/ChecksumsUrl). The
# always-latest path is tried first; the older-release scan is the fallback.
function Resolve-BridgeRelease {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArchiveName
    )

    $release = Resolve-BridgeReleaseViaLatest -ArchiveName $ArchiveName
    if (-not $release) {
        $release = Resolve-BridgeReleaseViaScan -ArchiveName $ArchiveName
    }
    return $release
}

$Release = Resolve-BridgeRelease -ArchiveName $ArchiveName
if (-not $Release -and $arch -eq 'arm64') {
    Write-Warning "No native arm64 bridge release found yet; falling back to the x64 build (runs under emulation on Windows arm64). Re-run this installer after a native arm64 release to switch to the native build."
    $arch = 'x64'
    $ArchiveName = "sesori-bridge-windows-$arch.zip"
    $Release = Resolve-BridgeRelease -ArchiveName $ArchiveName
}
if (-not $Release) {
    Write-Error "Could not resolve a published bridge release for $ArchiveName."
    exit 1
}
$AssetUrl = $Release.AssetUrl
$ChecksumsUrl = $Release.ChecksumsUrl

# ── Temp files ────────────────────────────────────────────────────────────────
$TempDir       = Join-Path ([System.IO.Path]::GetTempPath()) "sesori-install-$([System.Guid]::NewGuid().ToString('N'))"
$TempZip       = Join-Path $TempDir $ArchiveName
$TempChecksums = Join-Path $TempDir 'checksums.txt'

Write-Host "Sesori Bridge installer" -ForegroundColor Cyan
Write-Host "=======================" -ForegroundColor Cyan
Write-Host "Platform     : windows/$arch"
Write-Host "Release      : $($Release.TagName)"
Write-Host "Install root : $InstallRoot"
Write-Host ""

try {
    # ── Create temp directory ─────────────────────────────────────────────────
    New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

    # ── Download archive ──────────────────────────────────────────────────────
    Write-Host "[1/3] Downloading release assets..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $AssetUrl -OutFile $TempZip -UseBasicParsing

    # ── Download checksums ────────────────────────────────────────────────────
    Invoke-WebRequest -Uri $ChecksumsUrl -OutFile $TempChecksums -UseBasicParsing

    # ── Verify SHA256 ─────────────────────────────────────────────────────────
    Write-Host "[2/3] Verifying checksum..." -ForegroundColor Yellow

    $actualHash = (Get-FileHash -Path $TempZip -Algorithm SHA256).Hash.ToLower()

    $expectedHash = $null
    Get-Content $TempChecksums | ForEach-Object {
        $line = $_.Trim()
        if ($line -match '^([a-fA-F0-9]{64})\s+\*?(.+)$') {
            $hashPart = $Matches[1].ToLower()
            $filePart = $Matches[2].Trim()
            if ($filePart -eq $ArchiveName) {
                $expectedHash = $hashPart
            }
        }
    }

    if ($null -eq $expectedHash) {
        Write-Error "Could not find checksum entry for '$ArchiveName' in checksums.txt."
        exit 1
    }

    if ($actualHash -ne $expectedHash) {
        Write-Error "SHA256 mismatch!`n  Expected : $expectedHash`n  Actual   : $actualHash`nAborting install."
        exit 1
    }

    Write-Host "Checksum OK ($actualHash)" -ForegroundColor Green

    # ── Create install directories ────────────────────────────────────────────
    New-Item -ItemType Directory -Force -Path $BinDir | Out-Null

    # ── Extract archive ───────────────────────────────────────────────────────
    Write-Host "[3/3] Installing managed runtime..." -ForegroundColor Yellow
    Expand-Archive -Path $TempZip -DestinationPath $InstallRoot -Force

    # ── Verify binary ─────────────────────────────────────────────────────────
    $BinaryPath = Join-Path $BinDir $BinaryName
    if (-not (Test-Path $BinaryPath)) {
        Write-Error "Expected binary not found at '$BinaryPath' after extraction. Check archive structure."
        exit 1
    }

    $resolvedVersion = $Release.TagName
    if ($resolvedVersion.StartsWith('v')) {
        $resolvedVersion = $resolvedVersion.Substring(1)
    }
    $managedManifestJson = @{ version = $resolvedVersion } | ConvertTo-Json -Compress
    [System.IO.File]::WriteAllText(
        $ManagedManifest,
        $managedManifestJson,
        [System.Text.UTF8Encoding]::new($false)
    )

    # ── Check for conflicts in existing PATH ──────────────────────────────────
    $existingOnPath = Get-Command 'sesori-bridge' -ErrorAction SilentlyContinue
    if ($existingOnPath -and ($existingOnPath.Source -ne $BinaryPath)) {
        Write-Warning "Another sesori-bridge was found at '$($existingOnPath.Source)'. It may conflict with this install."
    }

    # ── Update user PATH ──────────────────────────────────────────────────────
    $currentPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
    $pathEntries = $currentPath -split ';' | Where-Object { $_ -ne '' }

    $alreadyInPath = $pathEntries | Where-Object { $_.TrimEnd('\') -ieq $BinDir.TrimEnd('\') }

    if (-not $alreadyInPath) {
        $newPath = ($BinDir + ';' + ($pathEntries -join ';'))
        [Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')
        Write-Host "PATH: persisted $BinDir in the user PATH." -ForegroundColor Green
    } else {
        Write-Host "PATH: already configured." -ForegroundColor Green
    }

    # Also update the current session PATH so --version works immediately
    if ($env:PATH -notlike "*$BinDir*") {
        $env:PATH = "$BinDir;$env:PATH"
    }

    Write-Host ""
    Write-Host "Sesori Bridge install complete" -ForegroundColor Green
    Write-Host "============================" -ForegroundColor Green
    Write-Host "Managed binary : $BinaryPath"
    Write-Host ""

    $sesoriAvailable = $null
    try {
        $sesoriAvailable = Get-Command 'sesori-bridge' -ErrorAction SilentlyContinue
    } catch {
        # Ignore
    }

    if ($sesoriAvailable -and ($sesoriAvailable.Source -ieq $BinaryPath)) {
        Write-Host "sesori-bridge is available in this terminal." -ForegroundColor Green
        Write-Host ""
        Write-Host "Next steps" -ForegroundColor Cyan
        Write-Host "----------" -ForegroundColor Cyan
        Write-Host "Start the bridge:"
        Write-Host "   sesori-bridge"
    } else {
        Write-Host "Next steps" -ForegroundColor Cyan
        Write-Host "----------" -ForegroundColor Cyan
        Write-Host "1. Open a new terminal"
        Write-Host "2. Run the bridge:"
        Write-Host "   sesori-bridge"
    }

} finally {
    # ── Cleanup temp files ────────────────────────────────────────────────────
    if (Test-Path $TempDir) {
        Remove-Item -Recurse -Force -Path $TempDir -ErrorAction SilentlyContinue
    }
}
