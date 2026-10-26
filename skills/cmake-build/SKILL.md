---
name: cmake-build
description: Configure, build, and test a CMake project with the devkit toolchain on Windows (MSVC or MinGW) or WSL Ubuntu, including presets, compile_commands.json, and sanitizer builds. Use when asked to build, compile, run tests, or diagnose a build failure.
whenToUse: The user asks to build/compile the current project, run ctest, fix a CMake or linker error, or produce a Debug/Release binary. Works in any workspace.
---

# CMake build

## Locate the devkit

Resolve `<devkit>` in order:

1. `$env:DSH_DEVKIT` / `$DSH_DEVKIT`;
2. `%USERPROFILE%\.dsh\devkit.path` (`~/.dsh/devkit.path`), written by
   `toolchain/install-skills.ps1`;
3. ask the user for the path; never guess.

## Step 1: inspect the project

- Require `CMakeLists.txt` at the project root (`git rev-parse --show-toplevel` or cwd).
- Prefer `CMakePresets.json` when present: `cmake --list-presets`, then `cmake --preset <name>`.
- Otherwise choose: `Debug` for iteration, `Release` for benchmarks/perf.
- Never delete `build/` or edit sources without the user's confirmation.

## Step 2a: Windows (MSVC, default)

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
. "<devkit>\toolchain\devshell.ps1" -Quiet    # leading dot: injects vcvars64

cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
cmake --build build --parallel
ctest --test-dir build --output-on-failure
```

MinGW instead of MSVC (only when asked):

```powershell
. "<devkit>\toolchain\devshell.ps1" -Gcc -Quiet
cmake -S . -B build-gcc -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build-gcc --parallel
ctest --test-dir build-gcc --output-on-failure
```

Do not add `cl.exe` to PATH; always enter through `devshell.ps1`.

## Step 2b: WSL Ubuntu / native Linux

```bash
cmake -S . -B build-linux -G Ninja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
cmake --build build-linux --parallel
ctest --test-dir build-linux --output-on-failure
```

When the project lives on `/mnt/c`, keep the build directory on the Linux side
(e.g. `~/build/<project>`) if I/O is slow; adjust paths accordingly.

## Step 3: handle failures

1. Show the **first** compiler/linker error with file:line, not the whole log.
2. Re-run the failing target with `cmake --build <dir> --target <t> --verbose` only if needed.
3. Classify: missing dependency, stale cache, toolchain mismatch, code error.
4. For a stale cache, propose `rm -rf build` (Windows: `Remove-Item build -Recurse -Force`)
   and ask before deleting.
5. Do not edit source to make it compile unless the user asked for a fix; report the cause first.

## Optional variants

- Sanitizers (Linux): `-DCMAKE_BUILD_TYPE=Debug -DCMAKE_CXX_FLAGS="-fsanitize=address,undefined -fno-omit-frame-pointer"` and matching linker flags.
- Coverage: `-DCMAKE_CXX_FLAGS="--coverage"` plus `gcovr`/`llvm-cov`.
- Multi-config generators (Visual Studio): use `--config Release` instead of `CMAKE_BUILD_TYPE`.

## Rules

- Report the exact commands, build directory, and test summary (passed/failed/skipped).
- Do not commit build artifacts; `build*/` must be gitignored.
- If the project has no tests, say so instead of claiming `ctest` passed.
- Keep warnings-as-errors enabled when the project configures it; never disable `/WX` or `-Werror` to get green.
