# install-skills.ps1 -- publish the devkit's DSH skills to the user-level catalog
#
# Copies skills\<name>\SKILL.md bundles into %USERPROFILE%\.dsh\skills and points
# DSH_DEVKIT at this repository, so every workspace (not just this one) can load
# dev-env-bootstrap / project-quality-gate / cmake-build.
#
# Usage:
#   .\toolchain\install-skills.ps1
#   .\toolchain\install-skills.ps1 -Devkit "D:\src\devkit"   # if moved
#   .\toolchain\install-skills.ps1 -WhatIf                    # preview only
#
# Re-running overwrites the installed copies; the repository remains the source
# of truth.

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$Devkit = (Split-Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Stop'

$source = Join-Path $Devkit 'skills'
if (-not (Test-Path $source)) {
    throw "skills directory not found: $source"
}

$destRoot = Join-Path $HOME '.dsh\skills'
if (-not (Test-Path $destRoot)) {
    if ($PSCmdlet.ShouldProcess($destRoot, 'Create directory')) {
        New-Item -ItemType Directory -Force $destRoot | Out-Null
    }
}

$skills = Get-ChildItem $source -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') }
if ($skills.Count -eq 0) {
    throw "no skill bundles found under $source"
}

foreach ($skill in $skills) {
    $target = Join-Path $destRoot $skill.Name
    if ($PSCmdlet.ShouldProcess($target, "Install skill $($skill.Name)")) {
        if (Test-Path $target) { Remove-Item $target -Recurse -Force }
        Copy-Item $skill.FullName $target -Recurse
        Write-Host ("  installed {0}" -f $skill.Name) -ForegroundColor Green
    }
}

if ($PSCmdlet.ShouldProcess('DSH_DEVKIT', 'Set user environment variable')) {
    [Environment]::SetEnvironmentVariable('DSH_DEVKIT', $Devkit, 'User')
    $env:DSH_DEVKIT = $Devkit

    # Fallback for sessions that started before the env var existed: the skills
    # read this file when DSH_DEVKIT is not visible in their process.
    $pathFile = Join-Path $HOME '.dsh\devkit.path'
    [IO.File]::WriteAllText($pathFile, $Devkit, [Text.UTF8Encoding]::new($false))

    Write-Host ("  DSH_DEVKIT = {0}" -f $Devkit) -ForegroundColor Green
    Write-Host ("  fallback   = {0}" -f $pathFile) -ForegroundColor DarkGray
}

Write-Host ''
Write-Host 'Skills are discovered from the filesystem automatically; no restart is required.' -ForegroundColor DarkGray
Write-Host 'Available in any workspace: dev-env-bootstrap, project-quality-gate, cmake-build.' -ForegroundColor Green
