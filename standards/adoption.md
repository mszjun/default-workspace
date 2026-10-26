# 规范接入指南

目标：新项目 10 分钟内具备格式化、lint、类型检查、测试、提交门禁与 CI；存量项目按优先级渐进。

## 1. 新项目（推荐路径）

### 1.1 复制模板

Windows（PowerShell，在仓库根目录执行）：

```powershell
$std = "C:\path\to\devkit\standards\templates"
Copy-Item "$std\.clang-format" .
Copy-Item "$std\.clang-tidy" .
Copy-Item "$std\.editorconfig" .
Copy-Item "$std\.pre-commit-config.yaml" .
Copy-Item "$std\gitmessage" .gitmessage
Copy-Item "$std\PULL_REQUEST_TEMPLATE.md" .github\  # 先 New-Item -ItemType Directory .github
Copy-Item "$std\commitlint.config.cjs" .
```

Ubuntu / WSL：

```bash
STD=/mnt/c/path/to/devkit/standards/templates
cp "$STD/.clang-format" "$STD/.clang-tidy" "$STD/.editorconfig" "$STD/.pre-commit-config.yaml" .
cp "$STD/gitmessage" .gitmessage
mkdir -p .github && cp "$STD/PULL_REQUEST_TEMPLATE.md" .github/
cp "$STD/commitlint.config.cjs" .
```

Python 项目额外复制 `pyproject.toml`（按项目改 `name` / 依赖）；C++ 项目按需保留 clang 配置。

### 1.2 初始化本地仓库

```bash
git init -b main
git config commit.template .gitmessage
git config core.autocrlf input        # Linux/macOS；Windows 可用 true
git add -A && git commit -m "chore: bootstrap project"
```

### 1.3 安装提交门禁

```bash
python -m pip install pre-commit   # 或 uv tool install pre-commit
pre-commit install
pre-commit run --all-files          # 首次全量格式化
```

提交信息校验（需要 Node）：

```bash
npm install -D @commitlint/cli @commitlint/config-conventional
npx commitlint --from HEAD~1 --to HEAD
```

可选：在 `.git/hooks/commit-msg` 中调用 commitlint，或交给 CI（推荐 CI，避免每人装 Node）。

### 1.4 接入 CI

```bash
mkdir -p .github/workflows
cp "$STD/ci/github-actions.yml" .github/workflows/ci.yml
```

按项目调整：C++ 的构建目录、Python 的包名、是否启用 sanitizer。GitLab 用户把 job 改写成
`.gitlab-ci.yml` 即可，检查项保持一致。

### 1.5 分支保护

`main` 至少开启：

- 禁止直接 push / force push；
- 必需检查：`cpp`、`python`、`commitlint`（按项目裁剪）；
- 至少 1 个 approval；
- 合并前要求分支与 base 同步。

## 2. 存量项目（渐进路径）

按“先止血、再治理”的顺序，避免一次性大改导致 review 灾难：

1. **第 1 周**：加 `.editorconfig`、`.gitignore`、`README` 的构建/测试说明；`main` 加保护。
2. **第 2 周**：接入 formatter（clang-format / ruff format），单独一个 `style:` 提交做全量格式化，
   并把该提交加入 `.git-blame-ignore-revs`。
3. **第 3 周**：接入 lint（clang-tidy / ruff check），先只对**新增/修改文件**生效，避免历史告警淹没。
4. **第 4 周**：接入 mypy（Python）/ sanitizer（C++），从核心模块开始。
5. **持续**：新代码必须全绿；历史代码按模块逐步清零，每个 PR 顺手修本文件的告警。
6. **提交规范**：先对 PR 标题启用 commitlint（Squash 后即提交信息），再要求每个 commit 合规。

## 3. 新项目 Definition of Done

- [ ] `README.md`：用途、构建、运行、测试、目录结构
- [ ] `CONTRIBUTING.md`：链接本规范、提交流程
- [ ] `.gitignore` / `.editorconfig` / 格式化与 lint 配置
- [ ] CI 全绿：build、test、lint、commitlint
- [ ] 至少一个真实测试与一个失败路径测试
- [ ] 依赖锁定，许可证清单
- [ ] `main` 分支保护与 PR 模板
- [ ] 版本号与 `CHANGELOG.md`（若对外发布）

## 4. 常见问题

**Q：历史代码格式化会产生巨大 diff，怎么办？**
单独提交 `style: apply clang-format`，在 `.git-blame-ignore-revs` 写入该 commit SHA，
GitHub/GitLab 的 blame 会跳过它；业务 PR 不带格式化改动。

**Q：clang-tidy 在 CI 上太慢？**
只用 `CMAKE_EXPORT_COMPILE_COMMANDS=ON` 生成编译数据库，对变更文件跑检查；全量检查放 nightly。

**Q：团队不接受 100 列 / 4 空格？**
格式问题一次性在 `.clang-format` 里定，评审不再讨论；规范可以改，但要改配置文件而不是口头例外。

**Q：为什么 commitlint 放在 CI 而不是本地 hook？**
本地 hook 可被 `--no-verify` 绕过，且要求每人装 Node；CI 是唯一可信门禁，本地 hook 只做即时反馈。

**Q：单仓库多语言（C++ + Python）怎么放？**
根目录放通用文件（`.editorconfig`、`.gitignore`、PR 模板），`cpp/` 与 `python/` 子目录各放语言配置；
CI 用 path filter 分别触发。
