#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

# Sesori Bridge CLI - Windows Installer
# Usage: irm https://raw.githubusercontent.com/sesori-ai/sesori_apps_monorepo/main/install.ps1 | iex

$RepoOwner  = 'sesori-ai'
$RepoName   = 'sesori_apps_monorepo'
$ReleasesApiUrl = "https://api.github.com/repos/$RepoOwner/$RepoName/releases?per_page=100"
$BinaryName = 'sesori-bridge.exe'
$InstallRoot = Join-Path $env:LOCALAPPDATA 'sesori'
$BinDir      = Join-Path $InstallRoot 'bin'

# ── Architecture detection ────────────────────────────────────────────────────
$arch = $null
try {
    $procArch = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture
    switch ($procArch.ToString()) {
        'X64'   { $arch = 'x64' }
        'Amd64' { $arch = 'x64' }
        default { $arch = $null }
    }
} catch {
    # Fallback for older PowerShell / .NET versions
    switch ($env:PROCESSOR_ARCHITECTURE) {
        'AMD64' { $arch = 'x64' }
        'X64'   { $arch = 'x64' }
        default { $arch = $null }
    }
}

if ($arch -ne 'x64') {
    Write-Error "Unsupported architecture '$($env:PROCESSOR_ARCHITECTURE)'. Only x64 (AMD64) is supported on Windows."
    exit 1
}

$ArchiveName   = "sesori-bridge-windows-$arch.zip"
function Resolve-BridgeRelease {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArchiveName
    )

    $releases = Invoke-RestMethod -Uri $ReleasesApiUrl -Headers @{
        'Accept' = 'application/vnd.github+json'
        'User-Agent' = 'sesori-bridge-installer'
    }

    $eligible = @()
    foreach ($release in $releases) {
        if (-not $release.tag_name.StartsWith('bridge-v')) {
            continue
        }
        if ($release.draft -or $release.prerelease) {
            continue
        }

        $asset = $release.assets | Where-Object { $_.name -eq $ArchiveName } | Select-Object -First 1
        $checksums = $release.assets | Where-Object { $_.name -eq 'checksums.txt' } | Select-Object -First 1
        if ($asset -and $checksums) {
            $eligible += [pscustomobject]@{
                Version = [version]($release.tag_name.Substring(8))
                TagName = $release.tag_name
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

Write-Host "Sesori Bridge CLI Installer" -ForegroundColor Cyan
Write-Host "Architecture : $arch"
Write-Host "Release      : $($Release.TagName)"
Write-Host "Install root : $InstallRoot"
Write-Host ""

try {
    # ── Create temp directory ─────────────────────────────────────────────────
    New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

    # ── Download archive ──────────────────────────────────────────────────────
    Write-Host "Downloading $ArchiveName ..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $AssetUrl -OutFile $TempZip -UseBasicParsing

    # ── Download checksums ────────────────────────────────────────────────────
    Write-Host "Downloading checksums.txt ..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $ChecksumsUrl -OutFile $TempChecksums -UseBasicParsing

    # ── Verify SHA256 ─────────────────────────────────────────────────────────
    Write-Host "Verifying checksum ..." -ForegroundColor Yellow

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
    Write-Host "Extracting to $InstallRoot ..." -ForegroundColor Yellow
    Expand-Archive -Path $TempZip -DestinationPath $InstallRoot -Force

    # ── Verify binary ─────────────────────────────────────────────────────────
    $BinaryPath = Join-Path $BinDir $BinaryName
    if (-not (Test-Path $BinaryPath)) {
        Write-Error "Expected binary not found at '$BinaryPath' after extraction. Check archive structure."
        exit 1
    }

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
        Write-Host "Added $BinDir to user PATH." -ForegroundColor Green
        Write-Host "Open a new terminal to use sesori-bridge." -ForegroundColor Cyan
    } else {
        Write-Host "$BinDir is already in user PATH." -ForegroundColor Green
    }

    # Also update the current session PATH so --version works immediately
    if ($env:PATH -notlike "*$BinDir*") {
        $env:PATH = "$env:PATH;$BinDir"
    }

    # ── Print version ─────────────────────────────────────────────────────────
    Write-Host ""
    Write-Host "Installation complete!" -ForegroundColor Green
    Write-Host "Running: sesori-bridge --version" -ForegroundColor Cyan
    & $BinaryPath --version

} finally {
    # ── Cleanup temp files ────────────────────────────────────────────────────
    if (Test-Path $TempDir) {
        Remove-Item -Recurse -Force -Path $TempDir -ErrorAction SilentlyContinue
    }
}
