# 跨平台开发环境：Windows 11 + WSL2 Ubuntu

一套可复制、可验证的 **C++20 / Python / Node.js** 工具链，用来把 Windows 和 WSL2 Ubuntu 快速准备成可以直接开新项目的状态。
两条命令分别把 Windows 和 Ubuntu 装到同一状态，国内网络可用，Windows 侧**不需要管理员权限**。

> 本文是“怎么装、怎么复刻”；当前这台机器的实际安装记录见 [ENV.md](ENV.md)。

---

## 开发规范（所有项目必须遵循）

从本工作区孵化出的项目，统一遵循 [standards/](standards/README.md)：

- 语言规范：[C++](standards/cpp.md)、[Python](standards/python.md)
- 协作规范：[Git 分支与提交信息](standards/git.md)、[代码评审清单](standards/review-checklist.md)
- 落地方式：[接入指南](standards/adoption.md) 与 [可复制模板](standards/templates/)（clang-format / ruff / mypy / commitlint / CI）
- 提交信息使用 Conventional Commits；`main` 受保护；CI 必须全绿
- 规范的来源与引用边界见 [standards/README.md](standards/README.md#3-公开来源与引用边界)：
  公开标准与工程共识的整合，**不是**任何公司内部文档的复制

---

## 0. 前置条件与边界

| 项目 | 要求 |
|---|---|
| Windows | Windows 10/11 x64；**已安装 Visual Studio 2022/2026，勾选“使用 C++ 的桌面开发”**（脚本不装 VS，只装周边工具） |
| Ubuntu | Ubuntu 22.04+ 或 WSL2；有 sudo 权限 |
| 网络 | 能访问 npm/apt 镜像；访问 GitHub 慢时准备一个 HTTP 代理（如 `127.0.0.1:7890`） |
| 磁盘 | Windows 约 1.5 GB（含 MinGW 约 2.5 GB）；Ubuntu 约 2 GB |

脚本**不做**的事：不装 IDE、不改系统级 PATH、不装 vcpkg/Docker（按需自行安装）。

---

## 1. 版本矩阵

### Windows

| 组件 | 版本 | 安装方式 | 位置 |
|---|---|---|---|
| Visual Studio / MSVC | VS 2026 18.11 / cl 19.51 | 手动安装 VS（前置条件） | `C:\Program Files\Microsoft Visual Studio\18\Community` |
| Windows SDK | 10.0.26100 | 随 VS 安装 | 同上 |
| CMake | 4.1.2 | 官方 zip（便携） | `C:\Tools\cmake` |
| Ninja | 1.13.2 | GitHub zip（便携） | `C:\Tools\ninja` |
| Git | 2.56.0（MinGit） | npmmirror zip（便携） | `C:\Tools\git` |
| Node.js | 24.22.1 LTS | npmmirror zip（便携） | `C:\Tools\node` |
| npm | 11.19.1 | 随 Node | 同上，registry=npmmirror |
| Python | 3.12.10 | 官方安装包 / 华为镜像，用户级静默安装 | `%LOCALAPPDATA%\Programs\Python\Python312` |
| Python 数据栈 | numpy 2.5.4、pandas 3.1.0、pyarrow 26.0.0、duckdb 2.0.0、pytest | pip（阿里云） | 同上 |
| MinGW-w64 g++ | 16.2.0（可选） | WinLibs zip（便携） | `C:\Tools\mingw64` |

### Ubuntu 26.04 LTS（WSL2）

| 组件 | 版本 | 安装方式 |
|---|---|---|
| gcc / g++ | 15.2.0 | apt（阿里云镜像） |
| clang / clang-tidy / clang-format | 21.1.8 | apt |
| CMake | 4.2.3 | apt |
| Ninja | 1.13.2 | apt |
| GNU Make | 4.4.1 | apt（build-essential） |
| Git | 2.53.0 | apt |
| GDB | 17.1 | apt |
| ccache | 4.12.3 | apt |
| Node.js / npm | 24.22.1 / 11.19.1 | 官方 linux-x64 tar.xz（npmmirror）→ `/usr/local/lib/nodejs` + `/usr/local/bin` 软链 |
| Python | 3.14.4（系统） | apt |
| Python venv | `~/.venvs/dev`，同版本数据栈 | venv + pip（阿里云） |

> 两边 **Node 版本刻意保持一致**；Python 因发行版默认版本不同（3.12 vs 3.14）存在差异，
> 但数据栈版本一致。对版本敏感的项目建议用 venv/uv 固定解释器。

---

## 2. 一键安装

### Windows

在仓库根目录打开 PowerShell：

```powershell
# 标准安装（系统代理已开启时自动识别；否则直连）
powershell -ExecutionPolicy Bypass -File .\install\install-windows.ps1 -Proxy auto

# 国内网络、没有系统代理时：显式指定代理
powershell -ExecutionPolicy Bypass -File .\install\install-windows.ps1 -Proxy http://127.0.0.1:7890

# 还需要 Windows 版 g++
powershell -ExecutionPolicy Bypass -File .\install\install-windows.ps1 -WithMinGW -Proxy auto
```

| 参数 | 默认 | 说明 |
|---|---|---|
| `-InstallRoot` | `C:\Tools` | 不可写时自动回退到 `%LOCALAPPDATA%\Tools` |
| `-Proxy` | `auto` | `auto` 读系统代理；`none` 直连；或 `http://host:port` |
| `-WithMinGW` | 关 | 额外安装 WinLibs g++ 16.2.0（约 263 MB） |
| `-Force` | 关 | 已安装也重新下载覆盖 |
| `-KeepArchives` | 关 | 保留下载的安装包 |

脚本做的事：下载/解包 CMake、Ninja、MinGit、Node、Python（可选 MinGW）→ 写入**用户级** PATH →
配置 npm/pip 国内镜像 → 设置 `CurrentUser` 执行策略为 RemoteSigned → 打印版本。
全程不触发 UAC。

### Ubuntu / WSL2

```bash
sudo bash install/install-ubuntu.sh

# 只补工具链，不动 Node
sudo bash install/install-ubuntu.sh --skip-node

# 保留原有 apt 源
sudo bash install/install-ubuntu.sh --keep-sources
```

| 参数 | 说明 |
|---|---|
| `--skip-apt` | 跳过 apt 换源与安装（适合已经装好编译器的机器） |
| `--skip-node` | 跳过 Node |
| `--skip-python` | 跳过 venv 与 Python 包 |
| `--keep-sources` | 不修改 `/etc/apt/sources.list.d/ubuntu.sources` |
| `--user NAME` | 指定 venv/npm 配置归属用户（默认取第一个 UID≥1000 的用户） |
| `--node-version V` | 覆盖 Node 版本（默认 24.22.1） |

脚本做的事：备份并切换 apt 到阿里云 → 安装编译/调试/Python 工具链 → 用 npmmirror 安装固定版本 Node →
配置 npm/pip 镜像 → 为目标用户创建 `~/.venvs/dev` 并安装数据栈。可重复执行。

---

## 3. 验证

```powershell
# Windows：一次检查编译器、构建工具、Node、Python（并顺带打印 Ubuntu 侧版本）
# 某些宿主终端对脚本有额外限制，先只放开当前会话；不影响系统设置。
Set-ExecutionPolicy -Scope Process Bypass -Force
.\toolchain\verify.ps1
```

```bash
# Ubuntu 单独看版本
bash toolchain/versions-ubuntu.sh
```

期望结尾是 `ALL CHECKS PASSED`（Windows）与 `INSTALL_UBUNTU=DONE`（Ubuntu 安装脚本）。

仓库里还有一个最小工程用来证明“能编能跑”，不依赖任何项目代码：

```powershell
. .\toolchain\devshell.ps1
cmake -S toolchain/smoke -B toolchain/smoke/build-win -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build toolchain/smoke/build-win
.\toolchain\smoke\build-win\smoke.exe    # 输出 SMOKE=PASS
```

---

## 4. 手工复刻（不用脚本时）

### Windows

```powershell
# CMake（官方 zip，解压后把 bin 加进用户 PATH）
#   https://cmake.org/files/v4.1/cmake-4.1.2-windows-x86_64.zip
# Ninja
#   https://github.com/ninja-build/ninja/releases/download/v1.13.2/ninja-win.zip
# Git（MinGit，免安装）
#   https://registry.npmmirror.com/-/binary/git-for-windows/v2.56.0.windows.3/MinGit-2.56.0.3-64-bit.zip
# Node（官方 zip，解压即用）
#   https://npmmirror.com/mirrors/node/v24.22.1/node-v24.22.1-win-x64.zip
# Python（用户级静默安装，不要用管理员）
#   https://mirrors.huaweicloud.com/python/3.12.10/python-3.12.10-amd64.exe
#   参数：/quiet InstallAllUsers=0 PrependPath=1 Include_pip=1
# MinGW（可选，WinLibs）
#   https://github.com/brechtsanders/winlibs_mingw/releases/  (gcc 16.2.0 posix-seh ucrt)
```

要点：
- 全部解压到**用户可写目录**（如 `C:\Tools`），再把对应 `bin` 目录加入**用户 PATH**；
- `cl.exe` 不要手动加 PATH，它依赖 `vcvars64.bat` 注入的 `INCLUDE/LIB/LIBPATH`，统一用 `toolchain\devshell.ps1`；
- pip 镜像：`python -m pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/`；
- npm 镜像：`npm config set registry https://registry.npmmirror.com`。

### Ubuntu

```bash
# 1) apt 换源（可选）
sudo cp /etc/apt/sources.list.d/ubuntu.sources{,.bak}
sudo sed -i 's|http://archive.ubuntu.com/ubuntu|https://mirrors.aliyun.com/ubuntu|g' /etc/apt/sources.list.d/ubuntu.sources
sudo apt update

# 2) 工具链
sudo apt install -y build-essential gcc g++ make cmake ninja-build ccache pkg-config \
  git curl wget unzip zip xz-utils ca-certificates gdb clang clang-tidy clang-format lldb \
  python3 python3-dev python3-pip python3-venv python3-full libboost-dev libssl-dev zlib1g-dev

# 3) Node（固定版本，避免发行版版本漂移）
curl -L -o /tmp/node.tar.xz https://npmmirror.com/mirrors/node/v24.22.1/node-v24.22.1-linux-x64.tar.xz
sudo mkdir -p /usr/local/lib/nodejs
sudo tar -xJf /tmp/node.tar.xz -C /usr/local/lib/nodejs
for b in node npm npx corepack; do
  sudo ln -sf /usr/local/lib/nodejs/node-v24.22.1-linux-x64/bin/$b /usr/local/bin/$b
done

# 4) Python venv
python3 -m venv ~/.venvs/dev
~/.venvs/dev/bin/pip install numpy pandas pyarrow duckdb pytest
```

---

## 5. 日常使用

### Windows

```powershell
cd C:\path\to\repo

# 若提示“未数字签名/禁止运行脚本”，先只放开当前会话（退出即失效）
Set-ExecutionPolicy -Scope Process Bypass -Force

# 默认 MSVC
. .\toolchain\devshell.ps1
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build

# 想用 MinGW g++
. .\toolchain\devshell.ps1 -Gcc
```

`devshell.ps1` 只影响当前会话：注入 vcvars 环境、把便携工具目录放到 PATH 最前面。

### Ubuntu

```bash
cd /path/to/repo
source ~/.venvs/dev/bin/activate     # 需要 Python 数据栈时
cmake -S . -B build-linux -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build-linux
```

> 源码放在 `/mnt/c/...` 时 I/O 较慢；大项目建议放 `~/work`，或至少把 build 目录放到 Linux 侧。

---

## 6. 在任意工作区使用（DSH Skills）

技能源文件在 `skills/`，安装到**用户级**后所有工作区都能用，不依赖当前目录：

| Skill | 什么时候触发 | 做什么 |
|---|---|---|
| `dev-env-bootstrap` | “检查/准备开发环境”、命令找不到 | 验证 → 只补缺失 → 复验版本 |
| `project-quality-gate` | “检查代码规范”、提交前 | clang-format/clang-tidy、ruff/mypy/pytest、提交信息校验 |
| `cmake-build` | “构建/编译/跑测试”、编译报错 | CMake 配置、构建、ctest（MSVC / MinGW / Ubuntu） |

安装或更新（本机已装好，换机时执行）：

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\toolchain\install-skills.ps1          # 加 -WhatIf 可预览
```

脚本做两件事：把 `skills\*` 复制到 `%USERPROFILE%\.dsh\skills\`，并把用户环境变量
`DSH_DEVKIT` 指向本仓库；同时写入 `%USERPROFILE%\.dsh\devkit.path` 作为回退，供
已启动（尚未继承新环境变量）的会话读取。skill 里的 `<devkit>` 都通过它解析，因此在
新的工作区里也能找到 `standards/`、`install/`、`toolchain/`，不会退化成当前目录相对路径。

DSH 的扫描规则（来自 `dsh-skill-filesystem`）：

| 优先级 | 来源 | 路径 |
|---|---|---|
| 100 | project-dsh | `<projectRoot>/.dsh/skills` |
| 200 | project-agents | `<projectRoot>/.agents/skills` |
| 400 | user-dsh | `<dshHome>/skills`（默认 `~/.dsh/skills`） |
| 500 | user-agents | `~/.agents/skills` |

skill 是**目录包** `<name>/SKILL.md`，frontmatter 必填 `name`、`description`（值里含
`: ` 时必须加引号，否则整个 skill 会被丢弃）。项目根 = 最近的含 `.git` 的祖先目录；
没有 `.git` 时就是当前工作目录。

本仓库不再保留项目级 `.dsh/skills`，只维护 `skills/` 一份源文件，避免副本漂移。
修改 skill 后重新运行安装脚本即可，catalog 会自动刷新，无需重启会话。
新增/修改 skill 的约定见 [skills/README.md](skills/README.md)。

新工作区里的用法：直接说“按 devkit 检查这个项目的代码规范”或“构建并跑测试”，
模型会加载对应 skill；也可以在会话里显式调用 skill 工具。

---

## 7. 常见问题

**Q: `cl.exe` 找不到？**
它是故意不进全局 PATH 的。执行 `. .\toolchain\devshell.ps1`（注意开头的点），它会把 `vcvars64.bat` 的环境变量导入当前会话。

**Q: PowerShell 报“禁止运行脚本 / 未数字签名”？**
优先只放开当前会话，退出终端即失效：
```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
```
需要长期生效可用 `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`；单次运行脚本可用
`powershell -ExecutionPolicy Bypass -File ...`。
注意：某些宿主终端（IDE、agent 内置终端）即使 `CurrentUser` 已是 RemoteSigned 仍会拦截，
这时以进程级 Bypass 为准。

**Q: 下载很慢 / 超时？**
GitHub 直连在国内可能只有几十 KB/s。先确认系统代理是否开启：
```powershell
Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' | Select ProxyEnable,ProxyServer
```
若 `ProxyEnable=0`，显式传 `-Proxy http://127.0.0.1:7890`。脚本里 Node/Git 走 npmmirror、Python 走华为镜像，本身已避开 GitHub。

**Q: WSL 提示“检测到 localhost 代理配置，但未能将其镜像到 WSL”？**
只是警告。apt/pip/npm 都走国内镜像，不依赖代理；确需在 WSL 内用 Windows 代理，可在 `%USERPROFILE%\.wslconfig` 设 `networkingMode=mirrored`（会改变 WSL 网络模型，非必要不动）。

**Q: Windows 和 WSL 能共用同一块共享内存吗？**
不能。两边是独立内核，Windows 的命名段（`Local\...`）与 Linux 的 `/dev/shm` 互不可见，
管道、信号量也不能跨边界。需要协作时用文件或 TCP，或者把整套进程放在同一侧运行。

**Q: 怎么升级版本？**
改 `install/install-windows.ps1` 顶部的 `$V` 哈希，或 `install/install-ubuntu.sh` 的 `NODE_VERSION`；`-Force` 重装。Ubuntu 的 apt 工具版本跟随发行版。

**Q: 为什么 Windows 没有 `make`？**
统一用 Ninja；MinGW 包内自带 `mingw32-make`，需要时可直接用。

---

## 8. 目录结构

```
.
├── README.md                      # 本文：复刻指南
├── ENV.md                         # 当前机器的实际安装记录
├── CONTRIBUTING.md                # 贡献指南（指向 standards/）
├── standards/                     # 工程规范与可复制模板
│   ├── README.md                  # 总纲、效力等级、公开来源
│   ├── cpp.md                     # C++20 规范
│   ├── python.md                  # Python 3.12+ 规范
│   ├── git.md                     # 分支、提交信息、PR、发布
│   ├── review-checklist.md        # 评审清单
│   ├── adoption.md                # 新项目接入与存量迁移
│   └── templates/                 # clang-format / clang-tidy / ruff / commitlint / CI
├── install/
│   ├── install-windows.ps1        # Windows 一键安装（免管理员、幂等）
│   └── install-ubuntu.sh          # Ubuntu 一键安装（换源、Node、venv）
├── toolchain/
│   ├── devshell.ps1               # MSVC / MinGW 开发会话入口
│   ├── verify.ps1                 # 双系统自检
│   ├── versions-ubuntu.sh         # Ubuntu 版本清单
│   ├── install-skills.ps1         # 安装用户级 DSH skills，设置 DSH_DEVKIT
│   └── smoke/                     # 最小 C++20 构建验证工程
└── skills/                        # DSH skill 源文件（安装到 ~/.dsh/skills）
    ├── dev-env-bootstrap/
    ├── project-quality-gate/
    └── cmake-build/
```
