#!/bin/bash
# versions-ubuntu.sh -- 打印 Ubuntu 侧工具链版本，供环境核对
echo "distro=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"')"
echo "kernel=$(uname -r)"
echo "gcc=$(gcc -dumpfullversion) g++=$(g++ -dumpfullversion)"
echo "cmake=$(cmake --version | head -1 | awk '{print $3}')"
echo "ninja=$(ninja --version)"
echo "git=$(git --version | awk '{print $3}')"
echo "node=$(node -v 2>/dev/null || echo MISSING)"
echo "npm=$(npm -v 2>/dev/null || echo MISSING)"
echo "clang=$(clang --version | head -1)"
echo "gdb=$(gdb --version | head -1)"
echo "make=$(make --version | head -1)"
echo "ccache=$(ccache --version | head -1)"
echo "python=$(python3 --version | awk '{print $2}')"
echo "pip=$(python3 -m pip --version | awk '{print $2}')"
echo "venv=$HOME/.venvs/dev"
"$HOME/.venvs/dev/bin/python" - <<'PY'
import duckdb, numpy, pandas, pyarrow, sys
print("venv-python", sys.version.split()[0])
print("numpy", numpy.__version__)
print("pandas", pandas.__version__)
print("pyarrow", pyarrow.__version__)
print("duckdb", duckdb.__version__)
PY
