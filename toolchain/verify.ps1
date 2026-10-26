# verify.ps1 -- toolchain self-check for Windows + WSL Ubuntu
#
# Usage:
#   .\toolchain\verify.ps1                # check both sides
#   .\toolchain\verify.ps1 -SkipUbuntu    # Windows only
#
# Exit code 0 = everything required is present.

[CmdletBinding()]
param(
    [switch]$SkipUbuntu
)

$ErrorActionPreference = 'Continue'
$failed = 0

function Report([string]$Name, [bool]$Ok, [string]$Detail) {
    if ($Ok) {
        Write-Host ("  [ OK ] {0,-10} {1}" -f $Name, $Detail) -ForegroundColor Green
    } else {
        Write-Host ("  [FAIL] {0,-10} {1}" -f $Name, $Detail) -ForegroundColor Red
        $script:failed++
    }
}

Write-Host ''
Write-Host 'Windows toolchain' -ForegroundColor Cyan

# MSVC needs vcvars; reuse devshell.
$devshell = Join-Path $PSScriptRoot 'devshell.ps1'
try {
    . $devshell -Quiet
} catch {
    Report 'vcvars' $false $_.Exception.Message
}

$vsWhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$vsPath = if (Test-Path $vsWhere) { & $vsWhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath } else { $null }
Report 'VS' ([bool]$vsPath) ($(if ($vsPath) { $vsPath } else { 'not found' }))

$cl = Get-Command cl.exe -ErrorAction SilentlyContinue
$clVer = if ($cl) { (& cmd /c "cl 2>&1" | Select-String 'Version' | Select-Object -First 1).Line } else { 'not found' }
Report 'cl' ([bool]$cl) $clVer

foreach ($tool in @('cmake', 'ninja', 'git', 'node', 'npm', 'python')) {
    $cmd = Get-Command $tool -ErrorAction SilentlyContinue
    if ($cmd) {
        $ver = switch ($tool) {
            'cmake'  { (& cmake --version | Select-Object -First 1) }
            'ninja'  { (& ninja --version) }
            'git'    { (& git --version) }
            'node'   { (& node --version) }
            'npm'    { (& npm --version) }
            'python' { (& python --version 2>&1) }
        }
        Report $tool $true "$ver"
    } else {
        Report $tool $false 'not found'
    }
}

$gxx = 'C:\Tools\mingw64\bin\g++.exe'
if (Test-Path $gxx) {
    Report 'g++' $true (& $gxx --version | Select-Object -First 1)
} else {
    Report 'g++' $false 'MinGW-w64 not found'
}

if (-not $SkipUbuntu) {
    Write-Host ''
    Write-Host 'Ubuntu (WSL2)' -ForegroundColor Cyan
    $winScript = Join-Path $PSScriptRoot 'versions-ubuntu.sh'
    # C:\x\y -> /mnt/c/x/y, so the check works wherever the repo is cloned.
    $drive = $winScript.Substring(0, 1).ToLowerInvariant()
    $script = '/mnt/' + $drive + ($winScript.Substring(2) -replace '\\', '/')
    $out = & cmd /c "wsl.exe -d Ubuntu -- bash `"$script`" 2>&1"
    $clean = @($out | Where-Object { $_ -notmatch 'localhost|NAT|wsl:' })
    if ($LASTEXITCODE -eq 0 -or $clean.Count -gt 5) {
        foreach ($line in $clean) { Write-Host "  $line" -ForegroundColor DarkGray }
        Report 'ubuntu' $true 'versions printed above'
    } else {
        Report 'ubuntu' $false 'WSL command failed'
    }
}

Write-Host ''
if ($failed -eq 0) {
    Write-Host 'ALL CHECKS PASSED' -ForegroundColor Green
    exit 0
} else {
    Write-Host "$failed CHECK(S) FAILED" -ForegroundColor Red
    exit 1
}
