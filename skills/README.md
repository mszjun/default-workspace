# DSH Skills

这里存放本工作区对外提供的 DeepSeek Harness 技能源文件。安装脚本会把每个目录复制到
用户级 `~/.dsh/skills/`，因此**任意工作区**都能加载，不需要把本仓库复制进目标项目。

| Skill | 触发场景 | 依赖 |
|---|---|---|
| `dev-env-bootstrap` | 环境检查/安装、命令找不到 | `install/`、`toolchain/` |
| `project-quality-gate` | 代码规范检查、提交前自检 | `standards/`、`toolchain/` |
| `cmake-build` | 构建、编译报错、跑 ctest | `toolchain/devshell.ps1` |

## 安装 / 更新

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\toolchain\install-skills.ps1          # -WhatIf 预览，-Devkit 指定仓库位置
```

脚本会把 `skills\*` 复制到 `%USERPROFILE%\.dsh\skills\`，设置用户环境变量
`DSH_DEVKIT` 指向本仓库，并写入 `%USERPROFILE%\.dsh\devkit.path` 作为回退
（已启动的会话看不到新环境变量时，skill 会读这个文件）。skill 内部用 `<devkit>`
表示该路径，**不要写死当前工作目录**。

DSH 会在文件变化后自动刷新 catalog，无需重启；修改后重新运行安装脚本即可。

## 目录结构

```
skills/
└── <skill-name>/
    ├── SKILL.md          # 必需，frontmatter + 指令
    └── references/       # 可选，按需加载的长文档
```

顶层只扫描 `<name>/SKILL.md`，不支持嵌套 `**/SKILL.md`。技能也可以写成扁平的
`<name>.md`，但本仓库统一用目录包，便于附带参考文件。

## frontmatter 规则

```yaml
---
name: my-skill
description: "One sentence for the catalog. Quote it if it contains a colon."
whenToUse: "When the user asks ..."
---
```

- `name`、`description` 必填；`description` 是模型决定是否加载的唯一依据，写清触发场景。
- 值里出现 `: `（冒号+空格）**必须加引号**，否则 YAML 解析失败，整个 skill 会被静默丢弃。
- 可选 `disable-model-invocation: true`（只允许人工调用）、`user-invocable: false`。
- 指令用英文写（模型指令遵循更稳），面向用户的说明可以中文。

## 编写原则

1. **路径可移植**：先解析 `DSH_DEVKIT`，再回退到本机绝对路径；不要假设 cwd 是 devkit。
2. **只做一件事**：环境、规范、构建分开；跨技能用文字引用（如“构建交给 cmake-build”）。
3. **先读后写**：检查类 skill 默认只读；修复前必须征得用户同意。
4. **不重复规范正文**：引用 `standards/*.md` 的章节，避免两份规则漂移。
5. **给出可执行命令**：每条结论附命令与输出，而不是“应该没问题”。

## 验证

```powershell
# 1) 语法：frontmatter 必须能被 YAML 解析
python -c "import yaml,pathlib; [yaml.safe_load(p.read_text(encoding='utf-8').split('---')[1]) for p in pathlib.Path('skills').glob('*/SKILL.md')]"

# 2) 发现：安装后新开一个会话，skill catalog 里应出现对应名称
.\toolchain\install-skills.ps1
```
