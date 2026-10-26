# 贡献指南

本仓库及其孵化出的所有项目，统一遵循 [standards/](standards/README.md) 中的工程规范。
开始写代码前，至少读完与你的语言相关的部分：

- C++：[standards/cpp.md](standards/cpp.md)
- Python：[standards/python.md](standards/python.md)
- Git 与提交信息：[standards/git.md](standards/git.md)
- 评审清单：[standards/review-checklist.md](standards/review-checklist.md)

## 工作流

1. 从最新 `main` 拉短生命周期分支：`feat/123-order-book`、`fix/456-null-deref`；
2. 小步提交，每个 commit 只做一件事，可独立编译；
3. 提交信息遵循 Conventional Commits：

   ```
   <type>(<scope>): <subject>

   <body>

   <footer>
   ```

4. 推送前 rebase 到最新 `main`，跑完本地检查；
5. 开 PR，填模板，附测试证据；CI 全绿 + 至少 1 个 approve 才能合并；
6. 合并后删除远端分支。

## 本地检查

C++：

```bash
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
cmake --build build
ctest --test-dir build --output-on-failure
clang-format --dry-run --Werror $(git ls-files '*.h' '*.hpp' '*.cc' '*.cpp')
clang-tidy -p build src/*.cpp
```

Python：

```bash
ruff check .
ruff format --check .
mypy src
pytest -q
```

一次性安装门禁：`pre-commit install`（配置见 `standards/templates/.pre-commit-config.yaml`）。

## 硬性要求

- 不提交密钥、令牌、私钥、生产配置与大二进制；
- 新代码零编译警告，CI 以 `-Werror` / `/WX` 构建；
- 公共 API 必须有测试与文档；缺陷修复必须先有复现测试；
- 破坏性变更用 `!` 或 `BREAKING CHANGE:` 标注，并更新 CHANGELOG；
- 评审意见按 `blocker` / `major` / `minor` / `nit` 标注级别。

## 规范变更

规范本身接受 PR：修改需说明动机、影响面与迁移方式；破坏性调整按 SemVer 升 MAJOR，
并在 `standards/README.md` 记录。争议走 ADR（`docs/adr/NNNN-*.md`），不在 PR 评论里长期拉锯。
