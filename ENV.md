# 编译环境说明

目标：在 **Windows 11 + WSL2 Ubuntu 26.04** 上同时具备 C++、Python 和 Node.js 的完整开发/构建能力。
本文件记录已安装的工具、版本、怎么用，以及几个使用上的注意点。

---

## 一、已安装清单

### Windows

| 工具 | 版本 | 位置 / 用法 |
|---|---|---|
| Visual Studio | 2026 Community 18.11 | 自带 MSVC 19.51、Windows SDK 10.0.26100 |
| MSVC cl.exe | 19.51.36260 (x64) | **不在全局 PATH**，由 `toolchain\devshell.ps1` 注入 |
| MinGW-w64 gcc/g++ | 16.2.0 (UCRT, POSIX threads) | `C:\Tools\mingw64\bin`，全局 PATH 可用 |
| CMake | 4.1.2 | `C:\Tools\cmake\bin`，全局 PATH |
| Ninja | 1.13.2 | `C:\Tools\ninja`，全局 PATH |
| Git | 2.56.0 | `C:\Tools\git\cmd`，全局 PATH |
| Node.js | 24.22.1 LTS (Krypton) | `C:\Tools\node`，全局 PATH |
| npm | 11.19.1 | 同上，registry 已指向 npmmirror |
| Python | 3.12.10 | 用户级安装，`python` / `pip` 直接可用 |
| Python 库 | numpy 2.5.4 / pandas 3.1.0 / pyarrow 26.0.0 / duckdb 2.0.0 / pytest 9.1.1 | 同上 |
| Docker | 29.9.2 | Docker Desktop，可用于 Linux 镜像构建 |
| Windows SDK | 10.0.26100.0 | VS 自带 |

### Ubuntu 26.04.1 LTS（WSL2）

| 工具 | 版本 |
|---|---|
| gcc / g++ | 15.2.0 |
| clang / clang-tidy / clang-format | 21.1.8 |
| CMake | 4.2.3 |
| Ninja | 1.13.2 |
| GNU Make | 4.4.1 |
| Git | 2.53.0 |
| Node.js / npm | 24.22.1 LTS / 11.19.1（`/usr/local/lib/nodejs`，软链到 `/usr/local/bin`） |
| GDB | 17.1 |
| ccache | 4.12.3 |
| Python | 3.14.4（系统）+ venv `~/.venvs/dev` |
| venv 库 | numpy 2.5.4 / pandas 3.1.0 / pyarrow 26.0.0 / duckdb 2.0.0 |

apt 源与 pip 源均已切换到阿里云镜像（`/etc/apt/sources.list.d/ubuntu.sources`、`/etc/pip.conf`），
Windows 侧 pip 也写入了 `%APPDATA%\pip\pip.ini`。

---

## 二、怎么用

### Windows（MSVC，生产构建）

```powershell
cd C:\path\to\devkit

# 某些宿主终端会拦截脚本，先只放开当前会话（退出即失效）
Set-ExecutionPolicy -Scope Process Bypass -Force

# 注意开头的点：在当前会话注入 vcvars64 环境（cl / INCLUDE / LIB / LIBPATH）
. .\toolchain\devshell.ps1

cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
ctest --test-dir build --output-on-failure
```

### Windows（MinGW g++，验证跨编译器可移植性）

```powershell
. .\toolchain\devshell.ps1 -Gcc
cmake -S . -B build-gcc -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build-gcc
```

> 普通新终端里 `cmake / ninja / git / python / g++` 都直接可用；
> 只有 `cl.exe` 必须经过 devshell（它依赖 vcvars 设置的一整套环境变量，单加 PATH 编不过）。

### Ubuntu（WSL）

```bash
wsl -d Ubuntu
source ~/.venvs/dev/bin/activate     # Python 数据栈

cd /mnt/c/path/to/devkit
cmake -S . -B build-linux -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build-linux
ctest --test-dir build-linux --output-on-failure
```

> `/mnt/c` 下的 I/O 比 Ubuntu 原生文件系统慢，大项目建议把源码放在 `~/work` 下，
> 或让 CMake 的 build 目录落在 Linux 侧。

---

## 三、已验证

`toolchain/smoke` 是一个最小 C++20 工程（线程 + 原子 + chrono + 64 字节对齐），
在三条链路上均编译并运行通过：

| 链路 | 编译器 | 结果 |
|---|---|---|
| Windows + CMake + Ninja + MSVC | cl 19.51 | PASS |
| Windows + CMake + Ninja + MinGW | g++ 16.2.0 | PASS |
| Ubuntu + CMake + Ninja + GCC | g++ 15.2.0 | PASS |

随时可重跑自检：

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\toolchain\verify.ps1
```

---

## 四、三个使用注意点

1. **WSL2 与 Windows 不共享内核对象。**
   两边是独立内核，命名共享内存（Windows 的 `Local\` 段与 Linux 的 `/dev/shm`）互不可见，
   管道、信号量也不能跨边界。需要跨边界协作时用文件或 TCP，或者把整套进程放在同一侧运行。

2. **`cl.exe` 不在全局 PATH。**
   它依赖 `vcvars64.bat` 注入的 `INCLUDE/LIB/LIBPATH`，每个开发会话先执行
   `. .\toolchain\devshell.ps1`；只把 `cl.exe` 目录加进 PATH 是编不过的。

3. **WSL 的 localhost 代理警告**（`检测到 localhost 代理配置，但未能将其镜像到 WSL`）
   不影响使用：apt/pip/npm 都走国内直连镜像。若确实需要在 WSL 内使用 Windows 代理，
   要在 `%USERPROFILE%\.wslconfig` 里开 `networkingMode=mirrored`，这会改变 WSL 网络模型，非必要不动。

---

## 五、暂未安装（按需再加）

- **vcpkg**：依赖管理。当前工作区不依赖第三方 C++ 库，故未装；
  需要 fmt/spdlog/gtest/arrow 时再加，Windows/Linux 共用一份 manifest 即可。
- **Windows 版 LLVM/Clang**：MSVC 和 MinGW 已覆盖两种编译器风格，需要 clang-cl 时再装。
- **Valgrind / perf**：Linux 下用 `-fsanitize=address,undefined` 已足够；MSVC 侧自带 ASan。

---

## 六、目录约定

```
README.md                复刻指南（版本矩阵、一键安装、排错）
ENV.md                   当前机器的实际安装记录（本文）
CONTRIBUTING.md          贡献指南（指向 standards/）
standards/               工程规范与可复制模板
skills/                  DSH skill 源文件（环境/规范/构建 3 个）
install/
  install-windows.ps1    Windows 一键安装（免管理员、幂等）
  install-ubuntu.sh      Ubuntu 一键安装（换源、Node、venv）
toolchain/
  devshell.ps1           Windows 开发环境入口（MSVC 默认 / -Gcc 切换）
  verify.ps1             双系统工具链自检
  versions-ubuntu.sh     Ubuntu 侧版本清单
  install-skills.ps1     安装用户级 DSH skills，设置 DSH_DEVKIT
  smoke/                 跨平台最小构建验证工程
```
