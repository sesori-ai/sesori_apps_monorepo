#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

# Sesori Bridge CLI - Windows Installer
# Usage: irm https://raw.githubusercontent.com/sesori-ai/sesori_apps_monorepo/main/install.ps1 | iex

# ── Presentation layer ────────────────────────────────────────────────────────
# Shared visual spec, kept byte-for-byte equivalent with install.sh and the npm
# bootstrap. Color and Unicode are opt-out: we degrade to plain ASCII whenever
# the environment can't be trusted to render them.
$Script:TotalSteps = 4
$ESC = [char]27

# ┌─ PALETTE ────────────────────────────────────────────────────────────────────
# │ Edit these ANSI codes in ONE place to retheme the installer. Init-Style copies
# │ them into the $C_* variables only when color is enabled (otherwise the $C_*
# │ variables stay empty for plain output).
# │ 256-color codes: brand blue #1472FF ≈ 39 (bright) / 25 (deep).
# └──────────────────────────────────────────────────────────────────────────────
$PALETTE_RESET     = "$ESC[0m"
$PALETTE_BANNER    = "$ESC[0;2m"        # SESORI wordmark — faded grey
$PALETTE_BRAND     = "$ESC[38;5;39m"    # accents: step counter, command, progress
$PALETTE_BRAND_DIM = "$ESC[38;5;25m"
$PALETTE_GREEN     = "$ESC[38;5;42m"    # success
$PALETTE_YELLOW    = "$ESC[38;5;214m"   # warning
$PALETTE_RED       = "$ESC[38;5;203m"   # error
$PALETTE_DIM       = "$ESC[0;2m"        # secondary / muted text
$PALETTE_BOLD      = "$ESC[1m"

# Active palette (empty unless color is enabled). Assigned by Init-Style.
$Script:C_RESET = ''
$Script:C_BANNER = ''
$Script:C_BRAND = ''
$Script:C_BRAND_DIM = ''
$Script:C_GREEN = ''
$Script:C_YELLOW = ''
$Script:C_RED = ''
$Script:C_DIM = ''
$Script:C_BOLD = ''

# Glyphs. Unicode where safe, ASCII otherwise. Populated by Init-Style.
$Script:G_CHECK = ''
$Script:G_WARN = ''
$Script:G_CROSS = ''
$Script:G_ARROW = ''
$Script:G_BAR_FULL = ''
$Script:G_BAR_EMPTY = ''

$Script:UseColor = $false
$Script:UseUnicode = $false
$Script:PanelWidth = 52

# Color is emitted unless NO_COLOR is set, output is redirected, or TERM=dumb.
# FORCE_COLOR forces it on. On Windows a console host generally supports ANSI
# (Windows Terminal, PowerShell 5.1+, conhost on Win10+), so a TTY is the signal.
function Test-ShouldUseColor {
    if ($env:FORCE_COLOR) { return $true }
    if ($env:NO_COLOR) { return $false }
    if ($env:TERM -eq 'dumb') { return $false }
    try {
        if ([System.Console]::IsOutputRedirected) { return $false }
    } catch {
        # IsOutputRedirected unavailable (rare hosts); fall through to enabled.
    }
    return $true
}

# Unicode glyphs are safe once the console output encoding is UTF-8, which we set
# in Init-Style. Legacy code pages (e.g. 437/1252) fall back to ASCII.
function Test-ShouldUseUnicode {
    if ($env:TERM -eq 'dumb') { return $false }
    try {
        if ([System.Console]::OutputEncoding.CodePage -eq 65001) { return $true }
    } catch {
        return $false
    }
    return $false
}

# Enable virtual-terminal (ANSI) processing on the console host. PowerShell 7 and
# Windows Terminal handle ANSI natively, but Windows PowerShell 5.1 on legacy
# conhost needs ENABLE_VIRTUAL_TERMINAL_PROCESSING (0x0004) set on the output
# handle, otherwise escape sequences print literally. Best-effort: failures fall
# back to plain output via the detection below.
function Enable-VirtualTerminal {
    if ($PSVersionTable.PSVersion.Major -ge 6) { return }  # PS7+ handles VT itself
    try {
        if (-not ('Sesori.NativeConsole' -as [type])) {
            Add-Type -Namespace 'Sesori' -Name 'NativeConsole' -MemberDefinition @'
[DllImport("kernel32.dll", SetLastError = true)]
public static extern IntPtr GetStdHandle(int nStdHandle);
[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
'@ -ErrorAction Stop
        }
        $handle = [Sesori.NativeConsole]::GetStdHandle(-11)  # STD_OUTPUT_HANDLE
        $mode = 0
        if ([Sesori.NativeConsole]::GetConsoleMode($handle, [ref]$mode)) {
            [void][Sesori.NativeConsole]::SetConsoleMode($handle, $mode -bor 0x0004)
        }
    } catch {
        # No console / unsupported host; detection below will disable color.
    }
}

function Init-Style {
    Enable-VirtualTerminal

    # Prefer UTF-8 output so the box-drawing/glyphs render on modern consoles.
    try {
        [System.Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    } catch {
        # Some hosts (ISE, redirected) reject this; we detect and fall back below.
    }

    if (Test-ShouldUseColor) {
        $Script:UseColor = $true
        $Script:C_RESET = $PALETTE_RESET
        $Script:C_BANNER = $PALETTE_BANNER
        $Script:C_BRAND = $PALETTE_BRAND
        $Script:C_BRAND_DIM = $PALETTE_BRAND_DIM
        $Script:C_GREEN = $PALETTE_GREEN
        $Script:C_YELLOW = $PALETTE_YELLOW
        $Script:C_RED = $PALETTE_RED
        $Script:C_DIM = $PALETTE_DIM
        $Script:C_BOLD = $PALETTE_BOLD
    }

    if (Test-ShouldUseUnicode) {
        $Script:UseUnicode = $true
        $Script:G_CHECK = [char]0x2713      # ✓
        $Script:G_WARN = [char]0x26A0       # ⚠
        $Script:G_CROSS = [char]0x2717      # ✗
        $Script:G_ARROW = [char]0x279C      # ➜
        $Script:G_BAR_FULL = [char]0x25A0   # ■
        $Script:G_BAR_EMPTY = [char]0xFF65  # ･
    } else {
        $Script:G_CHECK = '[OK]'
        $Script:G_WARN = '!'
        $Script:G_CROSS = 'x'
        $Script:G_ARROW = '>'
        $Script:G_BAR_FULL = '#'
        $Script:G_BAR_EMPTY = '.'
    }
}

# Wrap text in a color (and the reset), or pass it through when color is off.
function Use-Paint {
    param([string]$Color, [string]$Text)
    if ($Script:UseColor) { return "$Color$Text$($Script:C_RESET)" }
    return $Text
}

# Emit raw text honoring embedded ANSI. Write-Host keeps it on the console only
# (never the pipeline), matching the shell installers' stdout behavior.
function Write-Line {
    param([string]$Text = '')
    Write-Host $Text
}

# The SESORI wordmark, faded grey, printed as the header.
function Write-Banner {
    $b = $Script:C_BANNER
    $r = $Script:C_RESET
    if (-not $Script:UseColor) { $b = ''; $r = '' }

    Write-Line ''
    if ($Script:UseUnicode) {
        $lines = @(
            ' ███████╗███████╗███████╗ ██████╗ ██████╗ ██╗',
            ' ██╔════╝██╔════╝██╔════╝██╔═══██╗██╔══██╗██║',
            ' ███████╗█████╗  ███████╗██║   ██║██████╔╝██║',
            ' ╚════██║██╔══╝  ╚════██║██║   ██║██╔══██╗██║',
            ' ███████║███████╗███████║╚██████╔╝██║  ██║██║',
            ' ╚══════╝╚══════╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝'
        )
    } else {
        $lines = @(
            '  ____  _____ ____   ___  ____  ___ ',
            ' / ___|| ____/ ___| / _ \|  _ \|_ _|',
            ' \___ \|  _| \___ \| | | | |_) || | ',
            '  ___) | |___ ___) | |_| |  _ < | | ',
            ' |____/|_____|____/ \___/|_| \_\___|'
        )
    }
    foreach ($line in $lines) {
        Write-Line "$b$line$r"
    }
    Write-Line ''
    Write-Line ('  ' + (Use-Paint $Script:C_DIM 'Installing the Sesori Bridge — connect AI coding sessions to your phone'))
    Write-Line ''
}

# A "[n/N] message" step header in brand blue.
function Write-Step {
    param([int]$Number, [string]$Message)
    Write-Line ((Use-Paint $Script:C_BRAND "[$Number/$($Script:TotalSteps)]") + " $Message")
}

# A green success line with a check glyph, confirming a completed step.
function Write-Ok {
    param([string]$Message)
    Write-Line ('      ' + (Use-Paint $Script:C_GREEN $Script:G_CHECK) + ' ' + (Use-Paint $Script:C_DIM $Message))
}

# A muted, indented note under a step.
function Write-Note {
    param([string]$Message)
    Write-Line ('      ' + (Use-Paint $Script:C_DIM $Message))
}

# Error / warning / note prefixes. Errors and warnings go to stderr so they are
# visible even when stdout is redirected.
function Write-Err {
    param([string]$Message)
    [Console]::Error.WriteLine((Use-Paint $Script:C_RED "$($Script:G_CROSS) Error:") + " $Message")
}

function Write-Warn {
    param([string]$Message)
    [Console]::Error.WriteLine((Use-Paint $Script:C_YELLOW "$($Script:G_WARN) Warning:") + " $Message")
}

function Write-Hint {
    param([string]$Message)
    [Console]::Error.WriteLine((Use-Paint $Script:C_BRAND "$($Script:G_ARROW) Note:") + " $Message")
}

function Get-RepeatedChar {
    param([string]$Char, [int]$Count)
    if ($Count -le 0) { return '' }
    return ($Char * $Count)
}

# Box-drawing helpers for the "Next steps" panel. PanelWidth is the inner width
# (between the borders). Border color is passed in so the same panel can frame
# different kinds of content.
function Write-PanelTop {
    param([string]$Border = $Script:C_BRAND)
    if ($Script:UseUnicode) {
        $bar = [char]0x2500
        Write-Line ('  ' + $Border + [char]0x250C + (Get-RepeatedChar $bar $Script:PanelWidth) + [char]0x2510 + $Script:C_RESET)
    } else {
        Write-Line ('  ' + $Border + '+' + (Get-RepeatedChar '-' $Script:PanelWidth) + '+' + $Script:C_RESET)
    }
}

function Write-PanelBottom {
    param([string]$Border = $Script:C_BRAND)
    if ($Script:UseUnicode) {
        $bar = [char]0x2500
        Write-Line ('  ' + $Border + [char]0x2514 + (Get-RepeatedChar $bar $Script:PanelWidth) + [char]0x2518 + $Script:C_RESET)
    } else {
        Write-Line ('  ' + $Border + '+' + (Get-RepeatedChar '-' $Script:PanelWidth) + '+' + $Script:C_RESET)
    }
}

# A single panel row. Content longer than the inner width is truncated with an
# ellipsis so the right border stays aligned.
function Write-PanelRow {
    param([string]$Content = '', [string]$ContentColor = '', [string]$Border = $Script:C_BRAND)
    $bar = if ($Script:UseUnicode) { [char]0x2502 } else { '|' }
    $inner = $Script:PanelWidth - 2
    if ($Content.Length -gt $inner) {
        if ($Script:UseUnicode) {
            $Content = $Content.Substring(0, $inner - 1) + [char]0x2026
        } else {
            $Content = $Content.Substring(0, $inner - 3) + '...'
        }
    }
    $pad = $inner - $Content.Length
    if ($pad -lt 0) { $pad = 0 }
    $spaces = ' ' * $pad
    $painted = if ($ContentColor) { Use-Paint $ContentColor $Content } else { $Content }
    Write-Line ('  ' + $Border + $bar + $Script:C_RESET + ' ' + $painted + $spaces + ' ' + $Border + $bar + $Script:C_RESET)
}

# A panel row highlighting a runnable command plus a muted inline comment. Width
# is computed from the plain text so the colored escapes don't skew alignment.
function Write-PanelCommandRow {
    param([string]$Command, [string]$Comment, [string]$Border = $Script:C_BRAND)
    $bar = if ($Script:UseUnicode) { [char]0x2502 } else { '|' }
    $gap = '   '
    $plain = "$Command$gap$Comment"
    $inner = $Script:PanelWidth - 2
    $pad = $inner - $plain.Length
    if ($pad -lt 0) { $pad = 0 }
    $spaces = ' ' * $pad
    $painted = (Use-Paint ($Script:C_BRAND + $Script:C_BOLD) $Command) + $gap + (Use-Paint $Script:C_DIM $Comment)
    Write-Line ('  ' + $Border + $bar + $Script:C_RESET + ' ' + $painted + $spaces + ' ' + $Border + $bar + $Script:C_RESET)
}

# A panel row with an emphasized middle segment: "<prefix><bold emphasis><suffix>".
# The prefix/suffix render default-colored; the middle is brand-blue/bold so a
# hard-requirement phrase (e.g. "new terminal") stands out.
function Write-PanelEmphasisRow {
    param([string]$Prefix, [string]$Emphasis, [string]$Suffix, [string]$Border = $Script:C_BRAND)
    $bar = if ($Script:UseUnicode) { [char]0x2502 } else { '|' }
    $plain = "$Prefix$Emphasis$Suffix"
    $inner = $Script:PanelWidth - 2
    $pad = $inner - $plain.Length
    if ($pad -lt 0) { $pad = 0 }
    $spaces = ' ' * $pad
    $painted = $Prefix + (Use-Paint ($Script:C_BRAND + $Script:C_BOLD) $Emphasis) + $Suffix
    Write-Line ('  ' + $Border + $bar + $Script:C_RESET + ' ' + $painted + $spaces + ' ' + $Border + $bar + $Script:C_RESET)
}

Init-Style

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
    Write-Err "Unsupported architecture '$detectedOsArchitecture'."
    Write-Hint "Only x64 (AMD64) and arm64 are supported on Windows."
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
    Write-Warn "No native arm64 bridge release found yet; falling back to the x64 build (runs under emulation on Windows arm64). Re-run this installer after a native arm64 release to switch to the native build."
    $arch = 'x64'
    $ArchiveName = "sesori-bridge-windows-$arch.zip"
    $Release = Resolve-BridgeRelease -ArchiveName $ArchiveName
}
if (-not $Release) {
    Write-Err "Could not resolve a published bridge release for $ArchiveName."
    exit 1
}
$AssetUrl = $Release.AssetUrl
$ChecksumsUrl = $Release.ChecksumsUrl

# ── Temp files ────────────────────────────────────────────────────────────────
$TempDir       = Join-Path ([System.IO.Path]::GetTempPath()) "sesori-install-$([System.Guid]::NewGuid().ToString('N'))"
$TempZip       = Join-Path $TempDir $ArchiveName
$TempChecksums = Join-Path $TempDir 'checksums.txt'

Write-Banner
Write-Line ('  ' + (Use-Paint $Script:C_DIM 'Platform') + ' ' + (Use-Paint $Script:C_BOLD "windows/$arch"))
Write-Line ('  ' + (Use-Paint $Script:C_DIM 'Version ') + ' ' + (Use-Paint $Script:C_BOLD "$($Release.TagName)"))
Write-Line ''

try {
    # ── Create temp directory ─────────────────────────────────────────────────
    New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

    # ── Download archive ──────────────────────────────────────────────────────
    # Invoke-WebRequest renders its own native progress bar in the console host.
    Write-Step 1 'Downloading release'
    Invoke-WebRequest -Uri $AssetUrl -OutFile $TempZip -UseBasicParsing

    # ── Download checksums ────────────────────────────────────────────────────
    Invoke-WebRequest -Uri $ChecksumsUrl -OutFile $TempChecksums -UseBasicParsing
    Write-Ok "Downloaded $ArchiveName"

    # ── Verify SHA256 ─────────────────────────────────────────────────────────
    Write-Step 2 'Verifying checksum'

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
        Write-Err "Could not find checksum entry for '$ArchiveName' in checksums.txt."
        exit 1
    }

    if ($actualHash -ne $expectedHash) {
        Write-Err "SHA256 checksum mismatch for $ArchiveName"
        [Console]::Error.WriteLine('        ' + (Use-Paint $Script:C_DIM 'Expected:') + " $expectedHash")
        [Console]::Error.WriteLine('        ' + (Use-Paint $Script:C_DIM 'Got:     ') + " $actualHash")
        Write-Hint 'Download may be corrupted. Aborting.'
        exit 1
    }

    Write-Ok 'Checksum verified'

    # ── Create install directories ────────────────────────────────────────────
    New-Item -ItemType Directory -Force -Path $BinDir | Out-Null

    # ── Extract archive ───────────────────────────────────────────────────────
    Write-Step 3 'Installing managed runtime'
    Expand-Archive -Path $TempZip -DestinationPath $InstallRoot -Force

    # ── Verify binary ─────────────────────────────────────────────────────────
    $BinaryPath = Join-Path $BinDir $BinaryName
    if (-not (Test-Path $BinaryPath)) {
        Write-Err "Expected binary not found at '$BinaryPath' after extraction. Check archive structure."
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
    Write-Ok "Installed to $InstallRoot"

    # ── Check for conflicts in existing PATH ──────────────────────────────────
    $existingOnPath = Get-Command 'sesori-bridge' -ErrorAction SilentlyContinue
    if ($existingOnPath -and ($existingOnPath.Source -ne $BinaryPath)) {
        Write-Warn "Another sesori-bridge was found at '$($existingOnPath.Source)'."
        Write-Hint "It may shadow the newly installed version."
    }

    # ── Update user PATH ──────────────────────────────────────────────────────
    Write-Step 4 'Linking command'
    $currentPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
    $pathEntries = $currentPath -split ';' | Where-Object { $_ -ne '' }

    $alreadyInPath = $pathEntries | Where-Object { $_.TrimEnd('\') -ieq $BinDir.TrimEnd('\') }

    if (-not $alreadyInPath) {
        $newPath = ($BinDir + ';' + ($pathEntries -join ';'))
        [Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')
        Write-Ok "Added $BinDir to your PATH"
    } else {
        Write-Ok "$BinDir is already in your PATH"
    }

    # Also update the current session PATH so --version works immediately
    if ($env:PATH -notlike "*$BinDir*") {
        $env:PATH = "$BinDir;$env:PATH"
    }

    $resolvedVersionLabel = $resolvedVersion

    $sesoriAvailable = $null
    try {
        $sesoriAvailable = Get-Command 'sesori-bridge' -ErrorAction SilentlyContinue
    } catch {
        # Ignore
    }
    $onPath = ($sesoriAvailable -and ($sesoriAvailable.Source -ieq $BinaryPath))

    # ── Completion: quiet success line + boxed "Next steps" call-to-action ─────
    Write-Line ''
    Write-Line ((Use-Paint $Script:C_GREEN $Script:G_CHECK) + " Sesori Bridge v$resolvedVersionLabel installed")
    Write-Line ((Use-Paint $Script:C_DIM 'Location') + ' ' + (Use-Paint $Script:C_DIM $InstallRoot))
    Write-Line ''

    Write-PanelTop $Script:C_BRAND
    Write-PanelRow 'Next steps' $Script:C_BOLD $Script:C_BRAND
    Write-PanelRow '' '' $Script:C_BRAND
    if (-not $onPath) {
        Write-PanelEmphasisRow 'In a ' 'new terminal' ' window, run:' $Script:C_BRAND
        Write-PanelRow '' '' $Script:C_BRAND
    }
    Write-PanelCommandRow 'sesori-bridge' '# Start the bridge' $Script:C_BRAND
    Write-PanelBottom $Script:C_BRAND
    Write-Line ''

} finally {
    # ── Cleanup temp files ────────────────────────────────────────────────────
    if (Test-Path $TempDir) {
        Remove-Item -Recurse -Force -Path $TempDir -ErrorAction SilentlyContinue
    }
}
