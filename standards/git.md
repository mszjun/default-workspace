# Git 协作规范

适用范围：本工作区所有仓库。提交信息基于 [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/)，
版本号基于 [SemVer 2.0.0](https://semver.org/)，分支模型参考 [Alibaba AoneFlow](https://www.alibabacloud.com/blog/594903)
与 trunk-based 实践。

## 1. 分支模型

每个仓库**必须**在 README 中声明采用哪一种，默认 A。

### A. Trunk-based（默认，适合单人/小团队、持续部署）

- `main` 永远可发布；受保护，禁止直接 push。
- 功能分支从 `main` 拉出，生命周期 ≤ 3 天；过大需求拆成多个可独立合并的小 PR。
- 合并方式：Squash merge（保持 `main` 线性、一条提交一个语义）。
- 发布用 annotated tag，不在分支上长期堆叠。

### B. AoneFlow（适合多环境、多版本并行发布）

阿里公开的三条规则（[原文](https://www.alibabacloud.com/blog/594903)）：

1. **从 trunk 拉 feature 分支**：每个需求/缺陷一个 `feature/*`，不得直接改 trunk；
2. **用 feature 组合出 release 分支**：从 trunk 拉 `release/*`，把待发布的 feature 合进来；
   发布内容可随时重建（删掉 release 分支重拉、重新合入需要保留的 feature）；
3. **上线后 release 合回 trunk、打 tag、删除对应 feature**，保证 trunk 始终等于线上版本。

Hotfix 从 trunk 上的版本 tag 拉 `hotfix/*`，修完走 release 流程并合回 trunk。

### 分支命名

| 类型 | 格式 | 示例 |
|---|---|---|
| 功能 | `feat/<issue>-<slug>` | `feat/123-order-book` |
| 修复 | `fix/<issue>-<slug>` | `fix/456-null-deref` |
| 紧急修复 | `hotfix/<version>-<slug>` | `hotfix/1.2.1-settle` |
| 发布 | `release/<version>` | `release/1.3.0` |
| 文档/杂务 | `docs/...`、`chore/...` | `chore/bump-cmake` |

- **MUST** 全小写、kebab-case，不含空格/下划线/中文。
- **MUST** 合并后删除远端分支。

## 2. 提交信息（强制）

格式：

```
<type>(<scope>): <subject>

<body>

<footer>
```

- `type` 与 `subject` 必填；`scope` 可选；`body`、`footer` 可选。
- `type` **MUST** 取自下表；`scope` 用模块/子系统名（小写，如 `ring`、`config`、`api`）。
- `subject` **MUST** 用祈使句、现在时（“add” 而非 “added”），不含 `type/scope` 前缀时 ≤ 72 字符，结尾不加句号；整行 header ≤ 100 字符。
- `body` **SHOULD** 说明“为什么”和“影响”，每行 ≤ 72 字符；不必复述 diff。
- `footer` 用于 `BREAKING CHANGE:`、`Refs:`、`Closes:`、`Co-authored-by:` 等。
- 破坏性变更 **MUST** 用 `!`（如 `feat(api)!: ...`）或在 footer 写 `BREAKING CHANGE: ...`，二者至少其一。

### 类型表

| type | 含义 | 触发版本 |
|---|---|---|
| `feat` | 新功能 | MINOR |
| `fix` | 缺陷修复 | PATCH |
| `perf` | 性能优化（不改变行为） | PATCH |
| `refactor` | 重构（不新增功能、不修缺陷） | 无 |
| `docs` | 文档 | 无 |
| `test` | 测试 | 无 |
| `build` | 构建系统/依赖 | 无 |
| `ci` | CI 配置 | 无 |
| `style` | 纯格式（不改语义） | 无 |
| `chore` | 杂务（版本号、脚手架） | 无 |
| `revert` | 回滚 | PATCH |

> `style` 与 `refactor` 不得混入行为变更；格式化提交必须单独一个 commit，便于 review 与 blame。

### 示例

```
feat(ring): add SPSC ring buffer with per-consumer cursors

The producer only advances tail; each consumer owns its head. Slots carry
a sequence number so an overwritten slot is detected instead of read torn.

Refs: #123
```

```
fix(config): reject negative capacity

Capacity was parsed as int and used in a modulo, so -1 became a huge
allocation. Validate at parse time and fail with a clear message.

Closes: #456
```

```
feat(api)!: rename publish() to try_publish()

BREAKING CHANGE: publish() no longer blocks; callers must handle false.
```

反例（CI 会拒）：

```
update code                 # 无 type
fix: Fixed the bug.         # 过去式 + 句号
feat: add a lot of things   # 主题过大、不具体
wip                         # 禁止进 main
```

### 一次提交一件事

- **MUST** 一个 commit 只做一类变更；重构与功能、格式化与逻辑分开。
- **MUST** 每个 commit 可独立编译并通过测试（至少本地）。
- **MUST NOT** 提交 `WIP`、调试输出、注释掉的大段代码、临时文件。
- **SHOULD** 提交前 `git diff --staged` 自查；用 `git add -p` 拆分。

## 3. 同步与合并

- **MUST** 合并前把 `main` rebase 到功能分支（`git fetch && git rebase origin/main`），保持历史线性。
- **MUST NOT** rebase 已经推送且他人基于其工作的共享分支。
- **MUST** 功能分支合并用 Squash（trunk-based）或 `--no-ff`（release 分支），由仓库约定统一。
- **MUST** 冲突解决后重新跑全部测试，不得“看起来对”就提交。

## 4. Pull Request / Merge Request

- **MUST** 标题符合提交规范（Squash 后即成为 main 的提交信息）。
- **MUST** 描述包含：背景/目标、方案、测试证据、风险与回滚方式；使用模板。
- **SHOULD** 单个 PR 变更 ≤ 400 行（不含生成代码/测试数据）；超过则拆分。
- **MUST** 自己先 review 一遍 diff；禁止把明显问题丢给 reviewer。
- **MUST** CI 全绿（build / test / lint / commitlint）后才能合并。
- **MUST** 至少 1 个 approve；作者不得自行合并（紧急 hotfix 例外，需事后补 review）。
- **SHOULD** 24 小时内完成首轮 review；作者 24 小时内响应。

## 5. 代码评审

- 评审看：正确性、边界与错误处理、并发安全、测试有效性、安全、性能、可维护性、文档。
- 评论标级别：`blocker`（必须改）、`major`（应改）、`minor`（建议）、`nit`（吹毛求疵，可不改）。
- **MUST** 对事不对人；指出问题时给出理由或替代方案。
- **MUST** 作者逐条回应：已改 / 不改并说明理由；不得静默忽略。
- 详细清单见 [review-checklist.md](review-checklist.md)。

## 6. 版本与发布

- **MUST** 遵循 SemVer：破坏性 → MAJOR；新功能 → MINOR；修复 → PATCH。
- **MUST** 用 annotated tag：`git tag -a v1.3.0 -m "v1.3.0"`，tag 打在 `main` 上。
- **MUST** 维护 `CHANGELOG.md`（[Keep a Changelog](https://keepachangelog.com/) 格式），按 Added/Changed/Fixed/Removed/Security 分类。
- **SHOULD** 发布说明写清升级步骤与破坏性变更。
- **MUST** 发布产物可复现：记录编译器、依赖锁文件、构建命令。

## 7. Hotfix

1. 从线上版本 tag 拉 `hotfix/<version>-<slug>`；
2. 只改问题本身，附回归测试；
3. 走加速评审（至少 1 人），CI 必须全绿；
4. 打 PATCH tag 发布；
5. 合回 `main`，确认后续版本包含该修复。

## 8. 仓库保护与门禁

`main` 分支必须开启：

- 禁止直接 push、禁止 force push、禁止删除；
- 必需状态检查：`build`、`test`、`lint`、`commitlint`；
- 至少 1 个 approval，过期 approval 在新增提交后失效；
- 要求分支与 base 同步后再合并；
- 建议开启签名提交（`git commit -S`）与线性历史。

## 9. 提交前检查清单

- [ ] 只包含本次意图相关的文件；无临时文件、密钥、大二进制
- [ ] `git diff --staged` 自查通过
- [ ] 本地构建 + 测试 + lint 通过
- [ ] 提交信息符合 `<type>(<scope>): <subject>`，主题 ≤ 72 字符
- [ ] 破坏性变更已标注 `!` / `BREAKING CHANGE`
- [ ] 关联 issue（`Closes: #NNN`）
