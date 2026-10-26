# devshell.ps1 -- Windows developer shell entry point
#
# Imports the MSVC environment (cl.exe, INCLUDE, LIB, LIBPATH) into the current
# PowerShell session and puts the portable toolchain first on PATH.
#
# Usage (note the leading dot, so it affects the current session):
#   . .\toolchain\devshell.ps1              # MSVC (default, used for MSVC builds)
#   . .\toolchain\devshell.ps1 -Gcc       # MinGW-w64 g++ instead
#
# cl.exe is intentionally NOT on the global PATH: it needs the INCLUDE/LIB
# variables that vcvars64.bat sets, so adding the directory alone is not enough.

[CmdletBinding()]
param(
    [switch]$Quiet,
    [switch]$Gcc
)

$ErrorActionPreference = 'Stop'

$commonDirs = @(
    'C:\Tools\cmake\bin',
    'C:\Tools\ninja',
    'C:\Tools\git\cmd',
    'C:\Tools\node'
)

$pythonDirs = @(
    (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312'),
    (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312\Scripts')
) | Where-Object { Test-Path $_ }

$toolDirs = @($commonDirs) + @($pythonDirs)

if ($Gcc) {
    $mingw = 'C:\Tools\mingw64\bin'
    if (-not (Test-Path (Join-Path $mingw 'g++.exe'))) {
        throw "MinGW-w64 not found at $mingw"
    }
    $env:CC = Join-Path $mingw 'gcc.exe'
    $env:CXX = Join-Path $mingw 'g++.exe'
    $toolDirs = @($mingw) + $toolDirs
} else {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path $vswhere)) {
        throw "vswhere.exe not found; is Visual Studio installed with the C++ workload?"
    }
    $vsPath = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (-not $vsPath) {
        throw "No Visual Studio instance with the MSVC x64 toolset was found."
    }
    $vcvars = Join-Path $vsPath 'VC\Auxiliary\Build\vcvars64.bat'
    if (-not (Test-Path $vcvars)) {
        throw "vcvars64.bat not found: $vcvars"
    }
    # Import every variable that vcvars64.bat sets.
    $lines = & cmd.exe /c "`"$vcvars`" >nul 2>&1 && set"
    foreach ($line in $lines) {
        if ($line -match '^([^=]+)=(.*)$') {
            try { Set-Item -Path "Env:$($matches[1])" -Value $matches[2] -ErrorAction Stop } catch { }
        }
    }
    Remove-Item Env:CC -ErrorAction SilentlyContinue
    Remove-Item Env:CXX -ErrorAction SilentlyContinue
}

# Toolchain dirs first, then the rest of PATH with duplicates removed.
$current = @($env:PATH -split ';' | Where-Object { $_ -ne '' })
$merged = @($toolDirs) + @($current | Where-Object { $toolDirs -notcontains $_ })
$env:PATH = ($merged -join ';')

if (-not $Quiet) {
    Write-Host ''
    if ($Gcc) {
        Write-Host "  mode    : MinGW-w64 (g++)" -ForegroundColor Yellow
        Write-Host "  g++     : $(& g++ --version | Select-Object -First 1)" -ForegroundColor DarkGray
    } else {
        Write-Host "  mode    : MSVC (cl.exe)" -ForegroundColor Yellow
        Write-Host "  vs      : $vsPath" -ForegroundColor DarkGray
        Write-Host "  cl      : $((Get-Command cl.exe -ErrorAction SilentlyContinue).Source)" -ForegroundColor DarkGray
    }
    cmake --version | Select-Object -First 1 | ForEach-Object { Write-Host "  cmake   : $_" -ForegroundColor DarkGray }
    Write-Host "  ninja   : $(& ninja --version)" -ForegroundColor DarkGray
    Write-Host "  git     : $(& git --version)" -ForegroundColor DarkGray
    $py = Get-Command python.exe -ErrorAction SilentlyContinue
    if ($py) { Write-Host "  python  : $(& $py.Source --version 2>&1)" -ForegroundColor DarkGray }
    Write-Host ''
    Write-Host '  Windows toolchain ready' -ForegroundColor Green
    Write-Host ''
}
