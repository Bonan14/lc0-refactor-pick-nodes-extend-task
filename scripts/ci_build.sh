#!/bin/bash
set -e

# Function to detect package manager and install dependencies
install_deps() {
    echo "--- [1/6] Installing Build Tools ---"
    
    if command -v apt-get >/dev/null; then
        echo "Detected Debian/Ubuntu system"
        export DEBIAN_FRONTEND=noninteractive
        # Retry update for stability
        apt-get update || (sleep 5 && apt-get update) || (sleep 10 && apt-get update)
        # Install python3-venv for environment safety
        # Added zlib1g-dev to avoid meson fallback download
        apt-get install -y ninja-build curl binutils python3-pip python3-venv git libblas-dev libopenblas-dev zlib1g-dev
    
    elif command -v dnf >/dev/null; then
        echo "Detected Fedora/RHEL system"
        # Fedora usually has these packages
        # Added zlib-devel and libatomic
        dnf install -y ninja-build curl binutils python3-pip git blas-devel openblas-devel gcc-c++ zlib-devel libatomic
    
    elif command -v pacman >/dev/null; then
        echo "Detected Arch Linux system"
        # Sync and install
        # Added zlib
        pacman -Sy --noconfirm ninja curl binutils python-pip git blas openblas gcc zlib
    
    elif command -v zypper >/dev/null; then
        echo "Detected OpenSUSE system"
        # Added zlib-devel
        zypper --non-interactive install ninja curl binutils python3-pip git blas-devel openblas-devel gcc-c++ zlib-devel
    
    else
        echo "Error: Unsupported package manager. Cannot install dependencies."
        exit 1
    fi
}

# Run installation
install_deps

echo "--- [2/6] Setting up Python Virtual Environment ---"
# Create a venv to avoid "externally-managed-environment" errors
VENV_PATH="/opt/venv"
if [ ! -d "$VENV_PATH" ]; then
    python3 -m venv "$VENV_PATH"
fi

# Activate venv
source "$VENV_PATH/bin/activate"

# Update pip and install meson inside venv
pip install --upgrade pip
pip install meson==1.3.2

echo "--- [3/6] Setting up Git and Submodules ---"
# Safe directory configuration for git
git config --global --add safe.directory /workspace
git config --global --add safe.directory $(pwd)
git submodule sync --recursive
git submodule update --init --recursive

echo "--- [4/6] Configuring with Meson ---"
rm -rf build
# Meson is now available from the venv
meson setup --buildtype release build -Dblas=true -Dgtest=false -Dnative_arch=false

echo "--- [5/6] Building with Ninja ---"
ninja -C build -v

echo "--- [6/6] Testing (Benchmark) ---"
cd build
# Download the network file required for benchmarking
curl -L "https://training.lczero.org/get_network?sha=195b450999e874d07aea2c09fd0db5eff9d4441ec1ad5a60a140fe8ea94c4f3a" -o T79.pb.gz
# Touch to set timestamp as per workflow
touch -t 201801010000.00 T79.pb.gz

echo "Running lc0 benchmark..."
./lc0 benchmark --backend=blas --num-positions=2 --task-workers=3 --minibatch-size=7 --threads=2
