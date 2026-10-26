# install-windows.ps1 -- one-click, non-admin Windows dev toolchain
#
# Installs (portable / per-user, no UAC):
#   CMake 4.1.2, Ninja 1.13.2, Git 2.56.0 (MinGit), Node.js 24.22.1 LTS,
#   Python 3.12.10, and optionally MinGW-w64 GCC 16.2.0.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File install\install-windows.ps1
#   powershell -ExecutionPolicy Bypass -File install\install-windows.ps1 -Proxy auto
#   powershell -ExecutionPolicy Bypass -File install\install-windows.ps1 -WithMinGW -Proxy auto
#
# Notes:
#   * Default install root is C:\Tools; falls back to %LOCALAPPDATA%\Tools when
#     C:\Tools is not writable.
#   * Idempotent: already-installed components are skipped unless -Force.
#   * -Proxy accepts 'auto' (read WinINET settings), 'none', or a URL such as
#     http://127.0.0.1:7890. It is only used for downloads.
#   * No machine-wide changes: user PATH, user pip.ini, user .npmrc only.

[CmdletBinding()]
param(
    [string]$InstallRoot = 'C:\Tools',
    [string]$Proxy = 'auto',
    [switch]$WithMinGW,
    [switch]$Force,
    [switch]$KeepArchives
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$V = @{
    CMake  = '4.1.2'
    Ninja  = '1.13.2'
    Git    = '2.56.0'
    Node   = '24.22.1'
    Python = '3.12.10'
    MinGW  = '16.2.0'
}

function Write-Step([string]$Message) {
    Write-Host ''
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Ok([string]$Message) {
    Write-Host "    [ok] $Message" -ForegroundColor Green
}

function Write-Warn([string]$Message) {
    Write-Host "    [warn] $Message" -ForegroundColor Yellow
}

function Resolve-Proxy {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value) -or $Value -eq 'none') { return $null }
    if ($Value -ne 'auto') { return $Value }
    $settings = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
    if (-not $settings -or $settings.ProxyEnable -ne 1 -or -not $settings.ProxyServer) { return $null }
    $server = [string]$settings.ProxyServer
    # WinINET may store "http=host:port;https=host:port" or a bare "host:port".
    if ($server -match '(?i)(?:^|;)https?=([^;]+)') {
        $server = $Matches[1]
    } elseif ($server -match '(?i)(?:^|;)http=([^;]+)') {
        $server = $Matches[1]
    } else {
        $server = ($server -split ';')[0]
    }
    if ($server -notmatch '^https?://') { $server = 'http://' + $server }
    return $server
}

$script:ProxyUrl = Resolve-Proxy $Proxy

function Invoke-Download {
    param(
        [string[]]$Urls,
        [string]$Dest,
        [long]$MinBytes = 10000
    )
    if ((Test-Path $Dest) -and -not $Force -and (Get-Item $Dest).Length -ge $MinBytes) {
        Write-Ok "archive cached: $(Split-Path $Dest -Leaf)"
        return
    }
    $dir = Split-Path $Dest -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    foreach ($url in $Urls) {
        try {
            Write-Host "    downloading $(Split-Path $Dest -Leaf)" -ForegroundColor DarkGray
            Write-Host "      $url" -ForegroundColor DarkGray
            $curlArgs = @('-L', '--fail', '--retry', '2', '--connect-timeout', '20', '--max-time', '900', '-o', $Dest, $url)
            if ($script:ProxyUrl) { $curlArgs = @('-x', $script:ProxyUrl) + $curlArgs }
            & curl.exe @curlArgs
            if ($LASTEXITCODE -eq 0 -and (Test-Path $Dest) -and (Get-Item $Dest).Length -ge $MinBytes) {
                $mb = [math]::Round((Get-Item $Dest).Length / 1MB, 1)
                Write-Ok "downloaded ${mb} MB"
                return
            }
            Write-Warn "download failed (exit $LASTEXITCODE), trying next source"
        } catch {
            Write-Warn "download error: $($_.Exception.Message)"
        }
    }
    throw "All download sources failed for $(Split-Path $Dest -Leaf)"
}

function Expand-ZipTo {
    param(
        [string]$Zip,
        [string]$Dest
    )
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ('devx_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force $tmp | Out-Null
    $tar = Get-Command tar.exe -ErrorAction SilentlyContinue
    $extracted = $false
    if ($tar) {
        & tar.exe -xf $Zip -C $tmp 2>$null
        if ($LASTEXITCODE -eq 0) { $extracted = $true }
    }
    if (-not $extracted) {
        Expand-Archive -Path $Zip -DestinationPath $tmp -Force
    }
    if (Test-Path $Dest) { Remove-Item $Dest -Recurse -Force }
    New-Item -ItemType Directory -Force $Dest | Out-Null
    $inner = Get-ChildItem $tmp -Directory | Select-Object -First 1
    if ($inner) {
        Copy-Item (Join-Path $inner.FullName '*') $Dest -Recurse -Force
    } else {
        Copy-Item (Join-Path $tmp '*') $Dest -Recurse -Force
    }
    Remove-Item $tmp -Recurse -Force
}

function Add-UserPath {
    param([string[]]$Dirs)
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not $userPath) { $userPath = '' }
    $parts = @($userPath -split ';' | Where-Object { $_ -ne '' })
    $added = @()
    foreach ($d in $Dirs) {
        if (-not (Test-Path $d)) { continue }
        $norm = $d.TrimEnd('\')
        if ($parts -notcontains $norm) {
            $parts += $norm
            $added += $norm
        }
    }
    if ($added.Count -gt 0) {
        [Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User')
        Write-Ok "PATH += $($added -join ', ')"
    } else {
        Write-Ok 'PATH already up to date'
    }
    $env:PATH = (@($Dirs) + @($env:PATH -split ';' | Where-Object { $_ -ne '' } | Where-Object { $Dirs -notcontains $_ })) -join ';'
}

# ---------------------------------------------------------------------------
# Install root
# ---------------------------------------------------------------------------
try {
    New-Item -ItemType Directory -Force $InstallRoot | Out-Null
    $probe = Join-Path $InstallRoot ('.write_probe_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType File -Force $probe | Out-Null
    Remove-Item $probe -Force
} catch {
    $fallback = Join-Path $env:LOCALAPPDATA 'Tools'
    Write-Warn "$InstallRoot is not writable, falling back to $fallback"
    $InstallRoot = $fallback
    New-Item -ItemType Directory -Force $InstallRoot | Out-Null
}

$dl = Join-Path $InstallRoot 'dl'
New-Item -ItemType Directory -Force $dl | Out-Null

Write-Host ''
Write-Host 'dev toolchain installer (Windows)' -ForegroundColor White
Write-Host "  install root : $InstallRoot"
Write-Host "  proxy        : $(if ($script:ProxyUrl) { $script:ProxyUrl } else { 'none' })"
Write-Host "  MinGW        : $(if ($WithMinGW) { 'yes' } else { 'no (use -WithMinGW)' })"

# ---------------------------------------------------------------------------
# CMake
# ---------------------------------------------------------------------------
Write-Step "CMake $($V.CMake)"
$cmakeDir = Join-Path $InstallRoot 'cmake'
$cmakeExe = Join-Path $cmakeDir 'bin\cmake.exe'
if ((Test-Path $cmakeExe) -and -not $Force) {
    Write-Ok "already installed: $(& $cmakeExe --version | Select-Object -First 1)"
} else {
    $zip = Join-Path $dl 'cmake.zip'
    Invoke-Download -Urls @(
        "https://cmake.org/files/v4.1/cmake-$($V.CMake)-windows-x86_64.zip",
        "https://github.com/Kitware/CMake/releases/download/v$($V.CMake)/cmake-$($V.CMake)-windows-x86_64.zip"
    ) -Dest $zip -MinBytes 1000000
    Expand-ZipTo -Zip $zip -Dest $cmakeDir
    Write-Ok "installed: $(& $cmakeExe --version | Select-Object -First 1)"
}

# ---------------------------------------------------------------------------
# Ninja
# ---------------------------------------------------------------------------
Write-Step "Ninja $($V.Ninja)"
$ninjaDir = Join-Path $InstallRoot 'ninja'
$ninjaExe = Join-Path $ninjaDir 'ninja.exe'
if ((Test-Path $ninjaExe) -and -not $Force) {
    Write-Ok "already installed: $(& $ninjaExe --version)"
} else {
    $zip = Join-Path $dl 'ninja.zip'
    Invoke-Download -Urls @(
        "https://github.com/ninja-build/ninja/releases/download/v$($V.Ninja)/ninja-win.zip"
    ) -Dest $zip -MinBytes 100000
    Expand-ZipTo -Zip $zip -Dest $ninjaDir
    Write-Ok "installed: $(& $ninjaExe --version)"
}

# ---------------------------------------------------------------------------
# Git (MinGit, portable)
# ---------------------------------------------------------------------------
Write-Step "Git $($V.Git) (MinGit)"
$gitDir = Join-Path $InstallRoot 'git'
$gitExe = Join-Path $gitDir 'cmd\git.exe'
if ((Test-Path $gitExe) -and -not $Force) {
    Write-Ok "already installed: $(& $gitExe --version)"
} else {
    $zip = Join-Path $dl 'mingit.zip'
    Invoke-Download -Urls @(
        "https://registry.npmmirror.com/-/binary/git-for-windows/v$($V.Git).windows.3/MinGit-$($V.Git).3-64-bit.zip",
        "https://github.com/git-for-windows/git/releases/download/v$($V.Git).windows.3/MinGit-$($V.Git).3-64-bit.zip"
    ) -Dest $zip -MinBytes 1000000
    Expand-ZipTo -Zip $zip -Dest $gitDir
    Write-Ok "installed: $(& $gitExe --version)"
}

# ---------------------------------------------------------------------------
# Node.js LTS (portable zip)
# ---------------------------------------------------------------------------
Write-Step "Node.js $($V.Node) LTS"
$nodeDir = Join-Path $InstallRoot 'node'
$nodeExe = Join-Path $nodeDir 'node.exe'
if ((Test-Path $nodeExe) -and -not $Force) {
    Write-Ok "already installed: $(& $nodeExe --version)"
} else {
    $zip = Join-Path $dl 'node.zip'
    Invoke-Download -Urls @(
        "https://npmmirror.com/mirrors/node/v$($V.Node)/node-v$($V.Node)-win-x64.zip",
        "https://nodejs.org/dist/v$($V.Node)/node-v$($V.Node)-win-x64.zip"
    ) -Dest $zip -MinBytes 1000000
    Expand-ZipTo -Zip $zip -Dest $nodeDir
    Write-Ok "installed: $(& $nodeExe --version)"
}

# ---------------------------------------------------------------------------
# Python (per-user silent install)
# ---------------------------------------------------------------------------
Write-Step "Python $($V.Python)"
$pyDir = Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312'
$pyExe = Join-Path $pyDir 'python.exe'
if ((Test-Path $pyExe) -and -not $Force) {
    Write-Ok "already installed: $(& $pyExe --version)"
} else {
    $exe = Join-Path $dl 'python-installer.exe'
    Invoke-Download -Urls @(
        "https://mirrors.huaweicloud.com/python/$($V.Python)/python-$($V.Python)-amd64.exe",
        "https://www.python.org/ftp/python/$($V.Python)/python-$($V.Python)-amd64.exe"
    ) -Dest $exe -MinBytes 10000000
    Write-Host '    running silent per-user install...' -ForegroundColor DarkGray
    $p = Start-Process -FilePath $exe -ArgumentList @(
        '/quiet', 'InstallAllUsers=0', 'PrependPath=1', 'Include_pip=1',
        'Include_test=0', 'Include_launcher=1', 'InstallLauncherAllUsers=0', 'Include_doc=0'
    ) -Wait -PassThru
    if ($p.ExitCode -ne 0) { throw "Python installer failed with exit code $($p.ExitCode)" }
    Write-Ok "installed: $(& $pyExe --version)"
}

# ---------------------------------------------------------------------------
# MinGW-w64 (optional)
# ---------------------------------------------------------------------------
if ($WithMinGW) {
    Write-Step "MinGW-w64 GCC $($V.MinGW) (optional)"
    $mingwDir = Join-Path $InstallRoot 'mingw64'
    $gxx = Join-Path $mingwDir 'bin\g++.exe'
    if ((Test-Path $gxx) -and -not $Force) {
        Write-Ok "already installed: $(& $gxx --version | Select-Object -First 1)"
    } else {
        $zip = Join-Path $dl 'winlibs.zip'
        Invoke-Download -Urls @(
            "https://github.com/brechtsanders/winlibs_mingw/releases/download/16.2.0posix-23.1.3-14.0.0-ucrt-r3/winlibs-x86_64-posix-seh-gcc-$($V.MinGW)-mingw-w64ucrt-14.0.0-r3.zip"
        ) -Dest $zip -MinBytes 10000000
        Expand-ZipTo -Zip $zip -Dest $mingwDir
        Write-Ok "installed: $(& $gxx --version | Select-Object -First 1)"
    }
}

# ---------------------------------------------------------------------------
# PATH + package registries
# ---------------------------------------------------------------------------
Write-Step 'User PATH'
$pathDirs = @(
    (Join-Path $InstallRoot 'cmake\bin'),
    (Join-Path $InstallRoot 'ninja'),
    (Join-Path $InstallRoot 'git\cmd'),
    (Join-Path $InstallRoot 'node'),
    $pyDir,
    (Join-Path $pyDir 'Scripts')
)
if ($WithMinGW) { $pathDirs += (Join-Path $InstallRoot 'mingw64\bin') }
Add-UserPath -Dirs $pathDirs

Write-Step 'Package registries (mirrors)'
$npm = Join-Path $nodeDir 'npm.cmd'
if (Test-Path $npm) {
    & $npm config set registry https://registry.npmmirror.com 2>$null
    Write-Ok "npm registry: $(& $npm config get registry)"
}
if (Test-Path $pyExe) {
    & $pyExe -m pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/ 2>$null | Out-Null
    & $pyExe -m pip config set global.trusted-host mirrors.aliyun.com 2>$null | Out-Null
    Write-Ok 'pip index: https://mirrors.aliyun.com/pypi/simple/'
}

Write-Step 'PowerShell execution policy'
$policy = Get-ExecutionPolicy -Scope CurrentUser
if ($policy -in @('RemoteSigned', 'Unrestricted', 'Bypass')) {
    Write-Ok "CurrentUser = $policy (already permissive)"
} else {
    try {
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop
        Write-Ok 'CurrentUser = RemoteSigned'
    } catch {
        Write-Warn "could not set execution policy: $($_.Exception.Message)"
        Write-Warn 'run manually: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned'
    }
}

if (-not $KeepArchives) {
    Remove-Item $dl -Recurse -Force -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host 'Installed versions' -ForegroundColor White
Write-Host ("  cmake  : " + (& $cmakeExe --version | Select-Object -First 1))
Write-Host ("  ninja  : " + (& $ninjaExe --version))
Write-Host ("  git    : " + (& $gitExe --version))
Write-Host ("  node   : " + (& $nodeExe --version))
Write-Host ("  npm    : " + (& $npm --version))
Write-Host ("  python : " + (& $pyExe --version))
if ($WithMinGW) {
    Write-Host ("  g++    : " + (& (Join-Path $InstallRoot 'mingw64\bin\g++.exe') --version | Select-Object -First 1))
}
Write-Host ''
Write-Host 'Open a NEW terminal, then run: . .\toolchain\devshell.ps1' -ForegroundColor Green
Write-Host 'INSTALL_WINDOWS=DONE' -ForegroundColor Green
