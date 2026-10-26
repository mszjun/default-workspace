---
name: dev-env-bootstrap
description: Verify, repair, or replicate the Windows + WSL Ubuntu C++/Python/Node toolchain maintained by the devkit repository. Use from any workspace when tools are missing, versions look wrong, or a new machine needs setup.
whenToUse: The user asks to check or prepare the development environment, install cmake/g++/git/node/python, or diagnose a tool that "is not recognized". Works in any project directory.
---

# Dev environment bootstrap

## Locate the devkit

`<devkit>` is the toolchain repository, not the current project. Resolve it in order:

1. `$env:DSH_DEVKIT` (PowerShell) / `$DSH_DEVKIT` (bash);
2. the file `%USERPROFILE%\.dsh\devkit.path` (`~/.dsh/devkit.path`), written by
   `toolchain/install-skills.ps1`;
3. otherwise ask the user for the devkit path; never guess.

Verify with `Test-Path "<devkit>\README.md"`. If missing, stop and ask the user to clone the
devkit and run `toolchain\install-skills.ps1`; never guess a path.

## Procedure

1. Detect platform: Windows (`$env:OS -eq 'Windows_NT'`), WSL (`uname -a` contains
   `microsoft-standard-WSL2`), or native Linux.

2. Verify before installing:

   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass -Force
   & "<devkit>\toolchain\verify.ps1"
   ```

   ```bash
   bash "<devkit>/toolchain/versions-ubuntu.sh"
   ```

   Path translation: `C:\x\y` → `/mnt/c/x/y` when running inside WSL.

3. Install only what is missing or wrong. Both installers are idempotent:

   ```powershell
   powershell -ExecutionPolicy Bypass -File "<devkit>\install\install-windows.ps1" -Proxy auto
   # add -WithMinGW only when the user explicitly wants Windows g++
   ```

   ```bash
   sudo bash "<devkit>/install/install-ubuntu.sh"
   ```

   If the system proxy is disabled (`ProxyEnable=0`) and GitHub is slow, pass
   `-Proxy http://127.0.0.1:7890`. Node/Git use npmmirror and Python uses the Huawei mirror.

4. Re-run verification and report a matrix (component, version, path). Do not claim success
   without command output.

## Rules

- Windows installs are per-user (portable zips, `%LOCALAPPDATA%` Python, user PATH). Never
  install machine-wide or request elevation.
- `cl.exe` must not be added to the global PATH; enter the MSVC environment through
  `<devkit>\toolchain\devshell.ps1`.
- Do not install Visual Studio, vcpkg, Docker, or LLVM unless the user asks.
- Do not modify the target project; this skill is environment-only.
- Windows and WSL do not share named shared memory or other kernel objects. Keep a
  multi-process pipeline on one side of the boundary.

## Troubleshooting

| Symptom | Action |
|---|---|
| `cl.exe` not recognized | `. "<devkit>\toolchain\devshell.ps1"` (leading dot) |
| PowerShell blocks `.ps1` | `Set-ExecutionPolicy -Scope Process Bypass -Force` |
| Downloads time out | check proxy, pass `-Proxy http://host:port`; mirrors cover Node/Git/Python |
| CMake picks MinGW unexpectedly | default devshell is MSVC; `-Gcc` only when intended |
| WSL localhost proxy warning | harmless; mirrors are used instead of the proxy |
| Python packages missing on Ubuntu | use `~/.venvs/dev/bin/python`, not system `python3` |
