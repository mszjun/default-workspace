## 背景与目标

<!-- 为什么要做这个改动？关联 issue：Closes #123 -->

## 改动内容

<!-- 一句话概括方案；列出关键文件/模块 -->

## 测试证据

<!-- 贴命令与输出摘要，而不是“已测试” -->

```
cmake --build build && ctest --test-dir build --output-on-failure
pytest -q
```

## 风险与回滚

<!-- 可能影响面、兼容性、如何回滚 -->

## 自查清单

- [ ] 只包含本 PR 相关改动，无临时文件/密钥/大二进制
- [ ] 本地构建、测试、lint 通过
- [ ] 新增/修改逻辑有测试；缺陷修复有回归测试
- [ ] 公共 API/行为变更已更新文档与 CHANGELOG
- [ ] 破坏性变更已在标题用 `!` 或 footer 标注
- [ ] 提交信息符合 Conventional Commits
