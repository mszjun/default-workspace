# Python 工程规范（3.12+）

适用范围：本工作区所有 Python 项目、脚本与数据管道。条款级别见 [README.md](README.md#1-效力等级)。
风格基线为 [PEP 8](https://peps.python.org/pep-0008/) 与 [Google Python Style Guide](https://google.github.io/styleguide/pyguide.html)，
类型系统参考 [PEP 484](https://peps.python.org/pep-0484/)、[PEP 526](https://peps.python.org/pep-0526/)、[PEP 604](https://peps.python.org/pep-0604/)。

## 1. 版本与工具链

- **MUST** 支持 Python ≥ 3.12（本工作区 Windows 侧基线；Ubuntu 侧 3.14 兼容）。
- **MUST** 使用 `ruff` 做 lint 与 format，`mypy` 做类型检查，`pytest` 做测试。
- **SHOULD** 用 `uv` 管理虚拟环境与依赖；至少必须使用 venv，禁止装进系统 Python。
- **MUST** 每个仓库提交 `pyproject.toml`；依赖声明与工具配置集中在此。
- **MUST** 提交锁文件（`uv.lock` / `requirements.lock`），保证可复现安装。

## 2. 项目结构

```
project/
├── pyproject.toml
├── README.md
├── src/<package>/
│   ├── __init__.py
│   └── module.py
├── tests/
│   ├── conftest.py
│   └── test_module.py
└── scripts/            # 一次性/运维脚本，不参与打包
```

- **MUST** 使用 `src/` 布局，避免测试时误导入工作目录下的同名包。
- **MUST** 包名 `snake_case`，与目录名一致；测试文件 `test_*.py`。
- **SHOULD** 模块职责单一；单文件超过 500 行时考虑拆分。

## 3. 风格

- 4 空格缩进；行宽 100（由 `ruff format` 统一，不再人工对齐）。
- 双引号字符串；import 按标准库/第三方/本地分组，组内字母序（ruff `I`）。
- **MUST NOT** 使用通配符导入（`from x import *`）。
- **MUST** 文件末尾一个换行；无行尾空格；UTF-8 **无 BOM**；LF。
  Windows 下用 PowerShell 的 `Set-Content -Encoding utf8` 会写入 BOM（PS 5.1），
  应改用 `[IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))`。
- **MUST** CI 执行 `ruff check` 与 `ruff format --check`。

## 4. 命名

| 实体 | 规则 | 示例 |
|---|---|---|
| 模块/包 | `snake_case` | `order_book.py` |
| 函数/变量 | `snake_case` | `best_bid()` |
| 类/异常 | `PascalCase` | `OrderBook` |
| 常量 | `UPPER_SNAKE` | `MAX_RETRY` |
| 私有成员 | 单下划线前缀 | `_cache` |
| 类型别名 | `PascalCase` | `Price = Decimal` |

- **MUST** 布尔量用 `is_` / `has_` / `can_` 前缀。
- **MUST NOT** 用 `l`、`O`、`I` 作为单字符变量名。
- **SHOULD** 避免双下划线名称改写（name mangling），除非确实需要。

## 5. 类型注解

- **MUST** 所有公共函数/方法标注参数与返回类型；新增代码 `mypy --strict` 通过。
- **MUST** 用内置泛型：`list[str]`、`dict[str, int]`、`X | None`（PEP 585/604），不用 `typing.List`。
- **MUST NOT** 无理由使用 `Any`；必须用时写注释说明原因，并尽量在边界处收窄。
- **SHOULD** 用 `Protocol` 表达结构化接口，用 `dataclass` / `NamedTuple` 表达数据载体。
- **MAY** 用 `from __future__ import annotations` 延迟求值，简化前向引用。

## 6. 文档字符串

- **MUST** 公共模块、类、函数有 docstring；采用 Google 风格（Args / Returns / Raises）。
- **SHOULD** docstring 说明“做什么、为什么”，不复述签名。
- **MUST** 对外 API 在 README 或 `docs/` 有可运行示例。

示例：

```python
def load_ticks(path: Path, *, start_ns: int | None = None) -> list[Tick]:
    """Load ticks from a CSV file.

    Args:
        path: CSV file path.
        start_ns: Only return ticks at or after this timestamp.

    Returns:
        Ticks in ascending timestamp order.

    Raises:
        FileNotFoundError: If ``path`` does not exist.
        ValueError: If a row cannot be parsed.
    """
```

## 7. 错误处理

- **MUST** 只捕获预期的具体异常，禁止裸 `except:` 与 `except Exception: pass`。
- **MUST** 重新抛出时保留因果链：`raise ConfigError(...) from exc`。
- **MUST** 自定义异常继承项目基类（如 `class AppError(Exception)`），便于统一处理。
- **MUST NOT** 用异常做正常控制流。
- **SHOULD** 在进程边界（CLI、服务入口）统一捕获并转成退出码/HTTP 错误，附上下文日志。

## 8. 并发与异步

- **MUST** IO 密集用 `asyncio` 或线程池；CPU 密集用多进程，不用线程硬扛 GIL。
- **MUST** 所有阻塞调用设置超时；不得无限等待。
- **MUST NOT** 在 `async` 函数里调用阻塞 IO（除非 `asyncio.to_thread`）。
- **SHOULD** 共享可变状态加锁或用消息传递；优先不可变数据。
- **MUST** 线程池/进程池显式关闭（`with` 或 `shutdown`）。

## 9. 依赖管理

- **MUST** 依赖写进 `pyproject.toml`，带版本下限（`>=x.y`）；生产环境锁定精确版本。
- **MUST** 引入新依赖前评估：维护状态、许可证、体积、安全公告。
- **MUST NOT** 从不可信源安装包；使用公司/官方镜像并校验。
- **SHOULD** 定期跑 `pip-audit` / `uv pip audit`，高危漏洞必须修复后发布。

## 10. 日志

- **MUST** 用 `logging`，禁止 `print` 作为生产日志（CLI 面向用户的输出除外）。
- **MUST** 日志包含时间、级别、logger 名、消息；结构化场景用 JSON formatter。
- **MUST NOT** 记录密钥、令牌、密码、完整个人敏感信息。
- **SHOULD** 库代码只创建 logger，不配置 handler；配置交给应用入口。

## 11. 测试

- **MUST** 使用 pytest；测试放 `tests/`，文件名 `test_*.py`。
- **MUST** 每个测试只验证一个行为；用 `pytest.mark.parametrize` 覆盖边界。
- **MUST** 测试确定性：用 `tmp_path`、`monkeypatch`、假时钟；禁止真实网络与裸 `sleep`。
- **MUST** 缺陷修复先写失败测试。
- **SHOULD** 新代码行覆盖率 ≥ 80%；核心逻辑 ≥ 90%。
- **MAY** 用 `pytest-cov` 生成报告，CI 上传。

## 12. 安全

- **MUST** 校验所有外部输入（类型、范围、长度、路径）；路径拼接用 `pathlib` 并限制根目录。
- **MUST** 调用外部命令用列表参数且 `shell=False`；禁止拼接 shell 字符串。
- **MUST NOT** 对不可信数据使用 `pickle` / `eval` / `exec` / `yaml.load`（用 `safe_load`）。
- **MUST** 密钥从环境变量或密钥管理读取，不入库、不入日志、不进镜像。
- **SHOULD** 处理不可信压缩包时防 zip-slip；限制解压大小与文件数。

## 13. 性能

- **MUST** 先 profile（`cProfile` / `py-spy` / `scalene`）再优化，PR 附数据。
- **SHOULD** 数值计算用 numpy/pandas 向量化，避免 Python 级循环。
- **SHOULD** 避免在热循环里重复属性查找、字符串拼接、正则编译。
- **MAY** 用 `functools.lru_cache` / `functools.cache`，注意内存与失效策略。

## 14. 打包与发布

- **MUST** 用 `pyproject.toml` 的 `[build-system]`（hatchling 或 setuptools），可 `pip install -e .`。
- **MUST** 版本遵循 SemVer；发布打 annotated tag 并更新 `CHANGELOG.md`。
- **SHOULD** 提供 `console_scripts` 入口，而不是让用户 `python path/to/script.py`。
- **MUST NOT** 在包内写死绝对路径或依赖当前工作目录。

## 15. 评审红线

1. 裸 `except`、吞异常、错误只打日志不处理；
2. 无类型注解的公共 API，或 `Any` 泛滥；
3. 把密钥/令牌写进代码或配置；
4. 不可信输入直接进 `eval` / `pickle` / SQL 字符串 / shell；
5. 测试依赖真实网络、真实时间、执行顺序；
6. 在系统 Python 里装依赖、无锁文件；
7. 阻塞调用无超时。
