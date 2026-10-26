# C++ 工程规范（C++20）

适用范围：本工作区所有 C++ 项目。条款级别见 [README.md](README.md#1-效力等级)。
风格基线参考 [Google C++ Style Guide](https://google.github.io/styleguide/cppguide.html)，
正确性基线参考 [C++ Core Guidelines](https://isocpp.github.io/CppCoreGuidelines/)；与二者不同之处会在文中注明。

## 1. 标准与编译器

- **MUST** 使用 C++20；不得使用 C++23 特性或编译器扩展（`-pedantic` / `/permissive-` 必须通过）。
- **MUST** 在 CI 中用 `-Wall -Wextra -Wpedantic -Werror`（GCC/Clang）或 `/W4 /WX /permissive- /Zc:__cplusplus /utf-8`（MSVC）构建。
- **MUST** 至少两套编译器通过（Windows MSVC + Linux GCC/Clang）。
- **SHOULD** 新增代码在 ASan + UBSan 下跑通测试；并发代码额外跑 TSan。
- **MUST NOT** 依赖未定义行为（有符号溢出、越界、空指针解引用、严格别名违规、数据竞争）。

## 2. 目录结构

```
project/
├── CMakeLists.txt
├── cmake/                  # 自定义 Find*.cmake / helper
├── include/<pkg>/*.hpp     # 对外公共头文件
├── src/*.cpp               # 实现
├── tests/*_test.cpp        # 单元测试（GoogleTest）
├── benchmarks/             # 性能基准（可选）
└── third_party/            # 仅在没有包管理器时使用
```

- **MUST** 公共头文件放 `include/<pkg>/`，实现细节头文件放 `src/`。
- **MUST** 头文件用 `.hpp`，源文件用 `.cpp`；文件名 `snake_case`。
- **SHOULD** 一个类一个头文件；`internal` 命名空间或 `detail/` 目录承载实现细节。

## 3. 命名

| 实体 | 规则 | 示例 |
|---|---|---|
| 文件/目录 | `snake_case` | `ring_buffer.hpp` |
| 类型/类/结构体/enum | `PascalCase` | `OrderBook` |
| 函数/方法 | `PascalCase` | `PublishTick()` |
| 局部变量/参数 | `snake_case` | `best_bid` |
| 成员变量 | `snake_case_`（尾下划线） | `capacity_` |
| 编译期常量 | `kPascalCase` | `kCacheLine` |
| 宏 | `UPPER_SNAKE`，带项目前缀 | `MYLIB_ASSERT` |
| 命名空间 | 小写、短、无缩写歧义 | `mylib::detail` |

- **MUST** 布尔量用 `is_` / `has_` / `can_` 前缀。
- **MUST NOT** 在头文件或全局作用域写 `using namespace`；源文件中也不得 `using namespace std;`。
- **SHOULD** 名字表达意图，不用 `data`、`tmp`、`foo`；缩写仅限 `id`、`url`、`dns` 等公认词。

## 4. 头文件

- **MUST** 自包含：单独包含即可编译；包含它所需的一切头文件。
- **MUST** 使用 `#pragma once`（本工作区约定；Google 用宏守卫，二者均可，但同一仓库必须统一）。
- **MUST** 遵循 IWYU：用到什么就包含什么，不依赖传递包含。
- **SHOULD** 包含顺序：自身头文件 → C 标准库 → C++ 标准库 → 第三方 → 本项目；各组之间空一行，组内字母序。
- **MUST NOT** 在头文件中定义非 inline 的全局函数/变量。
- **SHOULD** 优先包含而非前向声明；仅对自有类型、且确有编译期收益时使用前向声明。

## 5. 格式

格式由 `.clang-format`（`standards/templates/.clang-format`）唯一决定，不再人工争论。

- 4 空格缩进，禁用 Tab；行宽 100；LF；文件末尾留一个换行；去除行尾空格。
- 指针/引用靠左：`int* p`、`const Foo& f`。
- 左花括号不换行（Attach）；`namespace` 内容不缩进。
- **MUST** CI 执行 `clang-format --dry-run --Werror`，不通过即失败。

## 6. 类型与初始化

- **MUST** 用 `nullptr`，不用 `NULL` / `0`。
- **MUST** 用 `enum class`，不用裸 `enum`。
- **MUST** 用 C++ 风格转换（`static_cast` 等），禁止 C 风格转换与 `reinterpret_cast` 滥用。
- **MUST** 变量声明即初始化；优先 `{}` 初始化，避免 Most Vexing Parse。
- **SHOULD** 能用 `const` / `constexpr` 就用；成员函数能 `const` 就 `const`。
- **SHOULD** 只读字符串参数用 `std::string_view`，只读数组用 `std::span`。
- **MAY** 在类型显而易见或避免重复冗长类型时用 `auto`；不得用 `auto` 隐藏关键类型（如 `auto x = f()` 返回值语义不明时写全）。
- **MUST NOT** 使用隐式窄化转换；`{}` 初始化会报错，不要用 `()` 绕过。

## 7. 所有权与生命周期

- **MUST** 遵循 RAII：资源在构造函数获取、析构函数释放；不得裸露 `new` / `delete`（容器/智能指针内部除外）。
- **MUST** 默认用 `std::unique_ptr` 表达独占所有权；`std::shared_ptr` 仅在确实共享所有权时使用。
- **MUST NOT** 使用拥有所有权的裸指针；函数参数中的裸指针/引用一律视为**不拥有**。
- **MUST** 遵循 Rule of Zero；需要自定义析构/拷贝/移动时，五个特殊成员一起考虑（Rule of Five）。
- **SHOULD** 引用表示非空，指针表示可能为空；跨调用保存的引用必须在注释中写明生命周期要求。
- **MUST NOT** 返回指向局部对象的引用/指针，或让 `string_view` / `span` 指向已销毁的临时对象。

## 8. 错误处理

项目必须在启动时二选一，并写入 README，**不得混用**：

**Profile A（默认，推荐用于应用/服务）**

- 异常只用于“真正异常”的情况（构造失败、资源耗尽、不可恢复的 IO 错误）；
- 可预期的业务失败用 `std::optional<T>` 或 `Result<T, E>`（自定义或 `tl::expected`）表达；
- **MUST** 在 ABI/线程/回调边界捕获异常，不让其逃逸到 C 接口或第三方回调；
- **MUST NOT** 用异常做正常控制流；不得 `catch (...)` 后静默吞掉。

**Profile B（`-fno-exceptions`，用于硬实时/嵌入式/低延迟内核）**

- 所有失败通过返回值/状态码传播，构造失败用工厂函数 + `std::optional`；
- 禁止任何第三方库把异常带入（编译期检查）。

共同要求：

- `assert` 只用于内部不变量，不用于校验用户输入；Release 下不得依赖 `assert` 的副作用。
- 移动构造/移动赋值/`swap`/析构函数 **MUST** `noexcept`。
- 错误信息必须包含上下文（操作、对象、错误码），不得只返回 `false`。

## 9. 并发

- **MUST** 每个类在头文件注释中声明线程安全级别（thread-safe / externally synchronized / not thread-safe）。
- **MUST** 用 `std::mutex` + `std::lock_guard` / `std::unique_lock`；禁止手写 `lock()`/`unlock()`。
- **MUST** 原子操作显式指定 `memory_order`，默认 `seq_cst` 只在确实需要时使用；有性能诉求时注释说明顺序理由。
- **MUST NOT** 用 `volatile` 做线程同步。
- **SHOULD** 避免多把锁嵌套；必须嵌套时用 `std::scoped_lock` 并固定加锁顺序。
- **SHOULD** 用 `std::jthread` / `std::stop_token` 做可取消的后台任务。
- **MUST** 识别伪共享：高频写的计数器/指针按 cache line 对齐隔离。

## 10. 性能

- **MUST** 先测量再优化：提交性能改动时附 benchmark 数据（前后对比、环境、样本量）。
- **MUST NOT** 在热路径做堆分配、加锁、日志格式化、异常抛出、虚函数间接调用（除非已测量可接受）。
- **SHOULD** 用 `reserve` 预分配；用移动而非拷贝；小对象按值传递，大对象按 `const&`。
- **SHOULD** 优先连续内存与缓存友好布局；避免指针追逐。
- **MAY** 使用 `[[likely]]` / `[[unlikely]]`，但必须基于 profile 数据。

## 11. 日志与可观测性

- **MUST** 使用项目统一日志库，禁止 `std::cout` / `printf` 作为生产日志（工具与示例除外）。
- **MUST** 日志分级（TRACE/DEBUG/INFO/WARN/ERROR），默认级别可配置。
- **MUST NOT** 记录密钥、令牌、完整身份证/账号、未脱敏的个人信息。
- **SHOULD** 热路径日志异步化或采样；错误日志包含可检索的上下文与错误码。

## 12. 测试

- **MUST** 使用 GoogleTest；测试文件 `*_test.cpp`，测试名 `SuiteName.Behavior`。
- **MUST** 每个测试只验证一个行为；测试必须确定性（禁止裸 `sleep`、依赖真实网络/时钟）。
- **MUST** 缺陷修复先写失败测试，再修复。
- **SHOULD** 新代码行覆盖率 ≥ 80%，核心模块 ≥ 90%；覆盖率不达标需在 PR 说明。
- **SHOULD** 并发代码用 TSan；内存/UB 用 ASan + UBSan；CI 至少跑一套 sanitizer。

## 13. 安全（参考腾讯 secguide）

- **MUST** 所有外部输入校验长度、范围、编码；不得信任网络/文件/环境变量。
- **MUST** 整数运算防溢出（尤其是长度、索引、分配大小）；比较前确认类型与符号。
- **MUST** 数组/缓冲区访问做边界检查；禁止 `strcpy` / `sprintf` / `gets` 等不安全 API。
- **MUST** 格式化字符串使用固定字面量，不得把用户输入当 format。
- **MUST** 防止 UAF/双重释放：对象销毁后置空、明确所有权、用 sanitizer 验证。
- **MUST NOT** 反序列化不可信数据时使用不安全的二进制强转；校验 magic/version/length。
- **MUST** 密钥只从环境变量/密钥管理读取，不入库、不出现在日志。

## 14. 构建与依赖

- **MUST** 使用 CMake ≥ 3.25，target-based：`target_link_libraries` / `target_include_directories` / `target_compile_features`。
- **MUST NOT** 使用全局 `include_directories`、`link_libraries`、`CMAKE_CXX_FLAGS` 污染所有 target。
- **MUST** 开启 `CMAKE_EXPORT_COMPILE_COMMANDS`（供 clang-tidy 使用）。
- **SHOULD** 依赖用 vcpkg/conan 之一并锁定版本；提交 manifest 与 lockfile。
- **MUST** 公共库导出时提供 `install` / `export` 规则与版本兼容策略。

## 15. 评审红线（出现即阻塞）

1. 未定义行为、数据竞争、悬垂引用；
2. 拥有所有权的裸指针、未配对的 `new/delete`；
3. 未检查的数组/缓冲区写入、整数溢出导致的分配；
4. 吞掉错误或异常、错误码不检查；
5. 热路径无依据的分配/锁/日志；
6. 新增编译器警告；
7. 无测试的公共 API 或缺陷修复；
8. 密钥/令牌入库。
