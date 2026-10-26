# 工程规范（C++ / Python / Git）

**规范版本：1.0.0**（2026-10-25）

本目录是本工作区所有项目的**统一工程规范**。新项目从第一天起按此执行；存量项目按
[adoption.md](adoption.md) 渐进靠拢。规范本身也接受 PR，修改需说明理由。


## 1. 效力等级

采用 RFC 2119 的关键词：

| 级别 | 含义 | 违反后果 |
|---|---|---|
| **MUST** | 强制。CI 或评审必须拦截 | 阻塞合并 |
| **SHOULD** | 默认执行；有正当理由可例外 | 评审中说明并记录 |
| **MAY** | 可选 | 无 |

例外必须写在 PR 描述里（原因、影响、偿还计划）；涉及架构取舍的，追加一份 `docs/adr/NNNN-*.md`。

## 2. 文档地图

| 文档 | 内容 |
|---|---|
| [cpp.md](cpp.md) | C++20 语言、所有权、并发、错误处理、性能、安全 |
| [python.md](python.md) | Python 3.12+ 风格、类型、结构、依赖、测试、安全 |
| [git.md](git.md) | 分支模型、提交信息、PR、评审、版本与发布 |
| [review-checklist.md](review-checklist.md) | 评审清单与严重级别定义 |
| [adoption.md](adoption.md) | 新项目接入步骤、存量项目迁移路径 |
| [templates/](templates/) | 可直接复制的格式化/lint/CI/提交模板 |

配套工具链：`clang-format` + `clang-tidy`（C++），`ruff` + `mypy` + `pytest`（Python），
`pre-commit` + `commitlint`（提交门禁）。模板见 `templates/`。

## 3. 公开来源与引用边界

| 主题 | 公开来源 | 本文如何使用 |
|---|---|---|
| C++ 风格 | [Google C++ Style Guide](https://google.github.io/styleguide/cppguide.html) | 头文件、命名、所有权、注释、C++20 目标 |
| C++ 正确性 | [C++ Core Guidelines](https://isocpp.github.io/CppCoreGuidelines/) | 生命周期、类型安全、资源管理 |
| Python 风格 | [PEP 8](https://peps.python.org/pep-0008/)、[Google Python Style Guide](https://google.github.io/styleguide/pyguide.html) | 命名、导入、文档字符串 |
| Python 类型 | [PEP 484](https://peps.python.org/pep-0484/)、[PEP 526](https://peps.python.org/pep-0526/)、[PEP 604](https://peps.python.org/pep-0604/) | 类型注解与 `X \| None` |
| 提交信息 | [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) | 类型、scope、BREAKING CHANGE、footer |
| 版本号 | [Semantic Versioning 2.0.0](https://semver.org/) | MAJOR/MINOR/PATCH 判定 |
| 变更日志 | [Keep a Changelog](https://keepachangelog.com/) | CHANGELOG 结构 |
| 分支模型 | [Alibaba AoneFlow](https://www.alibabacloud.com/blog/594903) | 多环境发布时的三分支模型 |
| C/C++ 安全 | [腾讯代码安全指南 Tencent/secguide](https://github.com/Tencent/secguide)（[介绍](https://cloud.tencent.com.cn/developer/article/1828061)） | 缓冲区、整数、UAF、注入等安全条款 |
| 审查实践 | Google Engineering Practices（[代码评审指南](https://google.github.io/eng-practices/review/)） | 评审粒度、严重级别、响应时效 |

字节跳动的公开仓库（如 [bitsail](https://github.com/bytedance/bitsail)、[flutter_ume](https://github.com/bytedance/flutter_ume)）
只提供了贡献指南，没有可核实的官方 C++/Python 编码规范，因此本文不标注字节的具体条款来源。

## 4. 强制基线（所有项目）

1. 仓库根目录必须有 `README.md`、`CONTRIBUTING.md`、`.gitignore`、`.editorconfig`；
2. C++ 项目必须有 `CMakeLists.txt`、`.clang-format`、`.clang-tidy`，能被 GCC/Clang/MSVC 至少两套编译；
3. Python 项目必须有 `pyproject.toml`、`ruff` 与 `mypy` 配置、`tests/`；
4. 提交信息必须符合 Conventional Commits（见 [git.md](git.md)），由 CI 的 commitlint 校验；
5. `main` 分支受保护：禁止直接 push，必须 PR + 至少 1 个 approve + CI 全绿；
6. 密钥、令牌、私钥、生产配置一律不得入库；用 `.env` + 环境变量，`.env` 必须在 `.gitignore`；
7. 新代码不得引入编译器警告；CI 以 `-Werror` / `/WX` 构建；
8. 新增公共 API 必须有测试与文档；缺陷修复必须先有能复现的测试。

## 5. 工具链版本基线

| 工具 | 版本 | 说明 |
|---|---|---|
| C++ 标准 | C++20 | 不使用 C++23 及编译器扩展 |
| 编译器 | MSVC 19.51 / GCC 15 / Clang 21 | 三者至少两套通过 CI |
| CMake | ≥ 3.25 | target-based，禁止全局 `include_directories` |
| clang-format / clang-tidy | 18+（推荐 21） | 版本写入 `.pre-commit-config.yaml` |
| Python | ≥ 3.12 | 与本工作区 Windows 侧一致 |
| ruff | ≥ 0.6 | 同时负责 lint 与 format |
| mypy | ≥ 1.11 | 新项目 `strict = true` |
| pytest | ≥ 8 | 统一测试入口 |

## 6. 规范如何落地

- **本地**：`pre-commit install`，提交时自动跑 format/lint/大文件检查；
- **提交**：`commitlint` 在 CI 校验提交信息，`git log` 可直接生成 CHANGELOG；
- **合并**：`main` 保护 + 必需检查（build / test / lint / commitlint）+ 1 个 review；
- **发布**：SemVer + annotated tag + CHANGELOG；
- **度量**：覆盖率、告警数、PR 平均评审时长，按季度回看，不追求一次性完美。

## 7. 维护

- 规范版本遵循 SemVer：破坏性改名/收紧规则 → MAJOR；新增规则 → MINOR；措辞澄清 → PATCH；
- 每条规则尽量给出“为什么”，避免只写“必须”；
- 规则冲突时：安全 > 正确性 > 可维护性 > 性能 > 风格；
- 争议走 ADR（模板见 [templates/adr.md](templates/adr.md)），不在 PR 评论里长期拉锯。
