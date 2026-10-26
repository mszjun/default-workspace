---
name: project-quality-gate
description: "Audit the current project against the devkit engineering standards and report violations: clang-format/clang-tidy, ruff/mypy/pytest, and Conventional Commits. Use before committing, in review, or when asked to check code quality or style compliance."
whenToUse: "The user asks to check code standards, run lint/format/type checks, review a diff for compliance, or verify commit messages follow the convention. Works in any workspace."
---

# Project quality gate

## Locate the devkit

Resolve `<devkit>` in order:

1. `$env:DSH_DEVKIT` / `$DSH_DEVKIT`;
2. `%USERPROFILE%\.dsh\devkit.path` (`~/.dsh/devkit.path`), written by
   `toolchain/install-skills.ps1`;
3. ask the user for the path; never guess.

Confirm `<devkit>/standards/README.md` exists before proceeding.

The standards themselves live in `<devkit>/standards/`:
`cpp.md`, `python.md`, `git.md`. Consult the relevant section when explaining a finding;
do not restate the whole standard in the answer.

## Step 1: identify the project

- Project root = `git rev-parse --show-toplevel`, otherwise the current directory.
- Inventory: `CMakeLists.txt`, `pyproject.toml`, `*.hpp/*.cpp`, `src/**/*.py`, `tests/`.
- Check tool configs: `.clang-format`, `.clang-tidy`, `pyproject.toml` (`[tool.ruff]`,
  `[tool.mypy]`), `.pre-commit-config.yaml`, `commitlint.config.cjs`.

If configs are missing, **report it and offer** to copy from `<devkit>/standards/templates/`.
Do not add or reformat files without the user's agreement.

## Step 2: run checks (read-only first)

C++ (files from `git ls-files '*.h' '*.hpp' '*.cc' '*.cpp'`, or a directory walk outside git):

```powershell
# Windows: clang-format is usually available through WSL; otherwise skip with a note.
wsl.exe -d Ubuntu -- bash -lc 'cd /mnt/c/path/to/project && clang-format --dry-run --Werror $(git ls-files "*.h" "*.hpp" "*.cc" "*.cpp")'
```

```bash
# Linux / WSL
clang-format --dry-run --Werror $(git ls-files '*.h' '*.hpp' '*.cc' '*.cpp')
```

- `clang-tidy` only when `build/compile_commands.json` exists: `clang-tidy -p build <changed files>`.
- Build/test is the job of the `cmake-build` skill; do not duplicate it here unless asked.

Python:

```bash
ruff check .
ruff format --check .
mypy src            # or the package directory named in pyproject
pytest -q           # skip only if the user asked for static checks only
```

Windows equivalents use the devkit Python (`python` on PATH, or
`%LOCALAPPDATA%\Programs\Python\Python312\python.exe`) with `-m ruff`, `-m mypy`, `-m pytest`.
Inside WSL use `~/.venvs/dev/bin/python -m ...`.

Git history (branch commits):

```bash
git log --format='%s' origin/main..HEAD
git log -1 --format='%B'
```

Validate each subject against:

```
^(feat|fix|perf|refactor|docs|test|build|ci|style|chore|revert)(\([a-z0-9._-]+\))?!?: .{1,100}$
```

Flag: missing type, unknown type, uppercase type, trailing period, subject > 100 chars,
`wip`/`update`/`fix bug` style messages, and behavior changes without a test.

## Step 3: report

Group findings by severity and include the exact command that produced them:

| Severity | Meaning |
|---|---|
| blocker | broken build, failing tests, secrets in tree, std violations that risk correctness |
| major | format/lint/type errors, non-conventional commits, missing tests for new public API |
| minor | weak naming, missing docstrings/docs, oversized PR |
| nit | preference, not worth blocking |

End with: passed checks, failed checks, skipped checks (and why), and the minimal next action.

## Step 4: fixes (only after confirmation)

- Safe: `clang-format -i`, `ruff check --fix`, `ruff format`.
- Never auto-fix logic, types, or tests without approval.
- Formatting fixes must be a separate `style:` commit, not mixed with behavior changes.
- After fixing, re-run the same command and report the delta.

## Rules

- Do not modify the project to make checks pass unless the user asked for fixes.
- Do not disable rules, add `# noqa`/`// NOLINT` or weaken configs to get green.
- Do not install project dependencies silently; ask first.
- If a tool is missing, report it and point to the `dev-env-bootstrap` skill.
