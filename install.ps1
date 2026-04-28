#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

# Sesori Bridge CLI - Windows Installer
# Usage: irm https://raw.githubusercontent.com/sesori-ai/sesori_apps_monorepo/main/install.ps1 | iex

$RepoOwner  = 'sesori-ai'
$RepoName   = 'sesori_apps_monorepo'
$ReleasesApiUrl = "https://api.github.com/repos/$RepoOwner/$RepoName/releases"
$ReleasesPerPage = 100
$ReleasesMaxPages = 10
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

    try {
        $osArch = (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).OSArchitecture
        if ($osArch) {
            return $osArch
        }
    } catch {
        # Fall back to environment-based detection below.
    }

    return $env:PROCESSOR_ARCHITECTURE
}

$detectedOsArchitecture = Resolve-OsArchitecture
switch ($detectedOsArchitecture) {
    '64-bit' { $arch = 'x64' }
    'AMD64'  { $arch = 'x64' }
    'X64'    { $arch = 'x64' }
    default  { $arch = $null }
}

if ($arch -ne 'x64') {
    Write-Error "Unsupported architecture '$detectedOsArchitecture'. Only x64 (AMD64) is supported on Windows."
    exit 1
}

$ArchiveName   = "sesori-bridge-windows-$arch.zip"
function Resolve-BridgeRelease {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArchiveName
    )

    $releases = @()
    for ($page = 1; $page -le $ReleasesMaxPages; $page++) {
        $pageReleases = Invoke-RestMethod -Uri "$ReleasesApiUrl?per_page=$ReleasesPerPage&page=$page" -Headers @{
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
        if (-not $tagName.StartsWith('bridge-v')) {
            continue
        }
        if ($release.draft -or $release.prerelease) {
            continue
        }

        $versionText = $tagName.Substring(8)
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

    throw "Could not resolve a published bridge release for $ArchiveName."
}

$Release = Resolve-BridgeRelease -ArchiveName $ArchiveName
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

    $managedManifestJson = @{ version = $Release.TagName.Substring(8) } | ConvertTo-Json -Compress
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
        $newPath = ($pathEntries + $BinDir) -join ';'
        [Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')
        Write-Host "PATH: persisted $BinDir in the user PATH." -ForegroundColor Green
    } else {
        Write-Host "PATH: already configured." -ForegroundColor Green
    }

    # Also update the current session PATH so --version works immediately
    if ($env:PATH -notlike "*$BinDir*") {
        $env:PATH = "$env:PATH;$BinDir"
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

    if ($sesoriAvailable) {
        Write-Host "sesori-bridge is available in this terminal." -ForegroundColor Green
        Write-Host ""
        Write-Host "Next steps" -ForegroundColor Cyan
        Write-Host "----------" -ForegroundColor Cyan
        Write-Host "Start the bridge:"
        Write-Host "   sesori-bridge"
    } else {
        Write-Host "Next steps" -ForegroundColor Cyan
        Write-Host "----------" -ForegroundColor Cyan
        Write-Host "1. Start the bridge:"
        Write-Host "   sesori-bridge"
        Write-Host ""
        Write-Host "2. If 'sesori-bridge' is not available in this shell yet, run:" -ForegroundColor Cyan
        Write-Host "   & \"$BinaryPath\""
    }

} finally {
    # ── Cleanup temp files ────────────────────────────────────────────────────
    if (Test-Path $TempDir) {
        Remove-Item -Recurse -Force -Path $TempDir -ErrorAction SilentlyContinue
    }
}
