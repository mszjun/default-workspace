#!/usr/bin/env bash
# install-ubuntu.sh -- one-click Ubuntu/WSL dev toolchain
#
# Installs: build-essential (gcc/g++), clang, cmake, ninja, make, git, gdb,
# ccache, pkg-config, Python 3 + venv + data stack, Node.js 24.22.1 LTS.
#
# Usage:
#   sudo bash install/install-ubuntu.sh
#   sudo bash install/install-ubuntu.sh --skip-node
#   sudo bash install/install-ubuntu.sh --user alice
#
# Notes:
#   * Switches apt to the Aliyun mirror (keeps a one-time backup) because
#     archive.ubuntu.com is slow from mainland China. Use --keep-sources to
#     leave sources untouched.
#   * Idempotent: apt is happy to re-run, Node is skipped when the pinned
#     version is already present, the venv is reused.
#   * Installs Node from the official binary tarball (npmmirror CDN) so that
#     Windows and Linux run the exact same Node version, instead of whatever
#     the distro ships.
#   * Creates the Python venv as the invoking user, not root.

set -euo pipefail

NODE_VERSION="${NODE_VERSION:-24.22.1}"
PY_PACKAGES="numpy pandas pyarrow duckdb pytest"
SKIP_APT=0
SKIP_NODE=0
SKIP_PYTHON=0
KEEP_SOURCES=0
TARGET_USER="${SUDO_USER:-}"

usage() {
    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
}

while [ $# -gt 0 ]; do
    case "$1" in
        --skip-apt) SKIP_APT=1 ;;
        --skip-node) SKIP_NODE=1 ;;
        --skip-python) SKIP_PYTHON=1 ;;
        --keep-sources) KEEP_SOURCES=1 ;;
        --user) TARGET_USER="${2:?--user needs a name}"; shift ;;
        --node-version) NODE_VERSION="${2:?--node-version needs a value}"; shift ;;
        -h|--help) usage ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

if [ "$(id -u)" -ne 0 ]; then
    echo "Re-running with sudo..."
    exec sudo -E bash "$0" "$@"
fi

# Resolve the human user that should own the venv / npm config.
if [ -z "${TARGET_USER}" ]; then
    TARGET_USER="$(awk -F: '$3 >= 1000 && $3 < 65534 { print $1; exit }' /etc/passwd)"
fi
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
if [ -z "${TARGET_HOME}" ] || [ ! -d "${TARGET_HOME}" ]; then
    echo "cannot resolve home directory for user '${TARGET_USER}'" >&2
    exit 1
fi

step() { printf '\n==> %s\n' "$1"; }
ok()   { printf '    [ok] %s\n' "$1"; }
warn() { printf '    [warn] %s\n' "$1"; }

run_as_user() {
    sudo -u "$TARGET_USER" -H "$@"
}

step "Ubuntu $(. /etc/os-release && echo "$PRETTY_NAME")"
echo "    target user : ${TARGET_USER} (${TARGET_HOME})"
echo "    node        : v${NODE_VERSION}"

# ---------------------------------------------------------------------------
# apt mirror + packages
# ---------------------------------------------------------------------------
if [ "$SKIP_APT" -eq 0 ]; then
    step 'apt sources + packages'
    SOURCES=/etc/apt/sources.list.d/ubuntu.sources
    if [ "$KEEP_SOURCES" -eq 0 ] && [ -f "$SOURCES" ]; then
        if [ ! -f "${SOURCES}.toolchain.bak" ]; then
            cp "$SOURCES" "${SOURCES}.toolchain.bak"
            ok "backed up sources to ${SOURCES}.toolchain.bak"
        fi
        . /etc/os-release
        CODENAME="${VERSION_CODENAME:-noble}"
        cat > "$SOURCES" <<EOF
Types: deb
URIs: https://mirrors.aliyun.com/ubuntu/
Suites: ${CODENAME} ${CODENAME}-updates ${CODENAME}-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: https://mirrors.aliyun.com/ubuntu/
Suites: ${CODENAME}-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
        ok "apt mirror -> mirrors.aliyun.com (${CODENAME})"
    fi

    export DEBIAN_FRONTEND=noninteractive
    if ! apt-get update -qq; then
        warn 'apt update failed, restoring original sources and retrying'
        if [ -f "${SOURCES}.toolchain.bak" ]; then
            cp "${SOURCES}.toolchain.bak" "$SOURCES"
            apt-get update -qq
        else
            exit 10
        fi
    fi

    apt-get install -y -qq --no-install-recommends \
        build-essential gcc g++ make \
        cmake ninja-build ccache pkg-config \
        git curl wget unzip zip xz-utils ca-certificates \
        gdb clang clang-tidy clang-format lldb \
        python3 python3-dev python3-pip python3-venv python3-full \
        libboost-dev libssl-dev zlib1g-dev
    ok "apt packages installed"
else
    warn 'skipping apt (--skip-apt)'
fi

# ---------------------------------------------------------------------------
# Node.js (official binary, same version on Windows and Linux)
# ---------------------------------------------------------------------------
if [ "$SKIP_NODE" -eq 0 ]; then
    step "Node.js v${NODE_VERSION}"
    if command -v node >/dev/null 2>&1 && [ "$(node -v)" = "v${NODE_VERSION}" ]; then
        ok "already installed: $(node -v)"
    else
        case "$(uname -m)" in
            x86_64) NODE_ARCH=x64 ;;
            aarch64|arm64) NODE_ARCH=arm64 ;;
            *) echo "unsupported arch: $(uname -m)" >&2; exit 11 ;;
        esac
        TARBALL="node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz"
        TMP="$(mktemp -d)"
        trap 'rm -rf "$TMP"' EXIT
        curl -L --fail --retry 3 -o "${TMP}/${TARBALL}" \
            "https://npmmirror.com/mirrors/node/v${NODE_VERSION}/${TARBALL}"
        mkdir -p /usr/local/lib/nodejs
        rm -rf "/usr/local/lib/nodejs/node-v${NODE_VERSION}-linux-${NODE_ARCH}"
        tar -xJf "${TMP}/${TARBALL}" -C /usr/local/lib/nodejs
        for bin in node npm npx corepack; do
            ln -sf "/usr/local/lib/nodejs/node-v${NODE_VERSION}-linux-${NODE_ARCH}/bin/${bin}" "/usr/local/bin/${bin}"
        done
        ok "installed: $(node -v) / npm $(npm -v)"
    fi

    run_as_user npm config set registry https://registry.npmmirror.com >/dev/null 2>&1 || true
    ok "npm registry -> $(run_as_user npm config get registry 2>/dev/null || echo 'npmmirror')"
else
    warn 'skipping Node (--skip-node)'
fi

# ---------------------------------------------------------------------------
# Python venv + data stack
# ---------------------------------------------------------------------------
if [ "$SKIP_PYTHON" -eq 0 ]; then
    step "Python venv (${TARGET_USER})"
    if [ ! -f /etc/pip.conf ] || ! grep -q 'mirrors.aliyun.com' /etc/pip.conf; then
        cat > /etc/pip.conf <<'EOF'
[global]
index-url = https://mirrors.aliyun.com/pypi/simple/
trusted-host = mirrors.aliyun.com
EOF
        ok 'pip mirror -> mirrors.aliyun.com'
    else
        ok 'pip mirror already configured'
    fi

    VENV="${TARGET_HOME}/.venvs/dev"
    if [ ! -x "${VENV}/bin/python" ]; then
        run_as_user python3 -m venv "$VENV"
        ok "created venv: $VENV"
    else
        ok "reusing venv: $VENV"
    fi
    run_as_user "${VENV}/bin/pip" install -q --upgrade pip
    run_as_user "${VENV}/bin/pip" install -q $PY_PACKAGES
    ok "python packages: $(run_as_user "${VENV}/bin/python" -c 'import numpy,pandas,pyarrow,duckdb;print("numpy",numpy.__version__,"pandas",pandas.__version__,"pyarrow",pyarrow.__version__,"duckdb",duckdb.__version__)')"
else
    warn 'skipping Python venv (--skip-python)'
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
step 'Installed versions'
printf '  gcc    : %s\n' "$(gcc -dumpfullversion)"
printf '  g++    : %s\n' "$(g++ -dumpfullversion)"
printf '  clang  : %s\n' "$(clang --version | head -1)"
printf '  cmake  : %s\n' "$(cmake --version | head -1 | awk '{print $3}')"
printf '  ninja  : %s\n' "$(ninja --version)"
printf '  git    : %s\n' "$(git --version | awk '{print $3}')"
printf '  gdb    : %s\n' "$(gdb --version | head -1)"
printf '  node   : %s\n' "$(node -v 2>/dev/null || echo MISSING)"
printf '  npm    : %s\n' "$(npm -v 2>/dev/null || echo MISSING)"
printf '  python : %s\n' "$(python3 --version | awk '{print $2}')"
if [ "$SKIP_PYTHON" -eq 0 ]; then
    printf '  venv   : %s\n' "$VENV"
fi

echo ''
echo 'INSTALL_UBUNTU=DONE'
