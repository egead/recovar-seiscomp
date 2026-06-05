#!/bin/bash
# install.sh — Install RECOVAR SeisComP integration.
#
# What this script does:
#   1. Installs system packages (requires sudo)
#   2. Creates the Python venv and installs dependencies
#   3. Installs the recovar_pick_filter daemon into SeisComP
#
# Prerequisites (done manually beforehand):
#   - SeisComP installed and set up (seiscomp setup)
#   - scmaster started (seiscomp start scmaster)
#   - Station inventory loaded and bindings configured (see README.md)

set -e

SEISCOMP_ROOT="${SEISCOMP_ROOT:-$HOME/seiscomp}"
VENV="${RECOVAR_VENV:-$HOME/.venv-recovar-seiscomp}"
PYTHON="${PYTHON:-python3.10}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== RECOVAR SeisComP Integration Installer ==="
echo "  SEISCOMP_ROOT : $SEISCOMP_ROOT"
echo "  venv          : $VENV"
echo "  repo          : $REPO"
echo ""

# ── Step 1: system packages ───────────────────────────────────────────────────
echo "[1/3] Installing system packages..."
sudo apt-get install -y libboost-program-options1.74.0 mariadb-server mariadb-client
sudo systemctl start mariadb
sudo systemctl enable mariadb
echo "      system packages OK"

# ── Step 2: Python venv ───────────────────────────────────────────────────────
if ! command -v "$PYTHON" >/dev/null 2>&1; then
    echo "ERROR: '$PYTHON' not found. TensorFlow 2.14.0 needs CPython 3.9-3.11."
    echo "       Install python3.10 or set PYTHON=<interpreter> and re-run."
    exit 1
fi
echo "[2/3] Creating venv at $VENV (using $PYTHON)..."
"$PYTHON" -m venv "$VENV"
# numpy pinned ==1.26.0: TF 2.14 has no numpy<2 ceiling and crashes (ABI) under numpy 2.x.
"$VENV/bin/pip" install --quiet "tensorflow==2.14.0" "numpy==1.26.0" scipy obspy pymysql matplotlib
echo "      venv OK"

# ── Step 3: install binaries and daemon ──────────────────────────────────────
echo "[3/3] Installing binaries..."

cp "$REPO/seiscomp_integration/recovar_pick_filter.py" "$SEISCOMP_ROOT/bin/recovar_pick_filter"
sed -i "1s|.*|#!$VENV/bin/python3|" "$SEISCOMP_ROOT/bin/recovar_pick_filter"
chmod +x "$SEISCOMP_ROOT/bin/recovar_pick_filter"
echo "      recovar_pick_filter installed"

cp "$REPO/seiscomp_integration/recovar_pick_filter.py.init" "$SEISCOMP_ROOT/etc/init/recovar_pick_filter.py"
seiscomp enable recovar_pick_filter
echo "      recovar_pick_filter enabled as SeisComP daemon"

# ── Update ~/.bashrc ──────────────────────────────────────────────────────────
MARKER="# SeisComP + RECOVAR environment"
if grep -q "$MARKER" "$HOME/.bashrc"; then
    echo "      ~/.bashrc already configured, skipped"
else
    cat >> "$HOME/.bashrc" << EOF

$MARKER
export SEISCOMP_ROOT=$SEISCOMP_ROOT
export PATH=/usr/bin:\$SEISCOMP_ROOT/bin:\$PATH
export LD_LIBRARY_PATH=\$SEISCOMP_ROOT/lib
export PYTHONPATH=\$SEISCOMP_ROOT/lib/python:$REPO:$REPO/seiscomp_integration
EOF
    echo "      appended to ~/.bashrc"
fi

# ── Verify ────────────────────────────────────────────────────────────────────
echo ""
echo "=== Verifying imports ==="
export LD_LIBRARY_PATH="$SEISCOMP_ROOT/lib"
export PYTHONPATH="$SEISCOMP_ROOT/lib/python:$REPO:$REPO/seiscomp_integration"

"$VENV/bin/python3" -c "
import numpy, seiscomp.client, seiscomp.datamodel, seiscomp.io
import tensorflow
from recovar.representation_learning_models import RepresentationLearningMultipleAutoencoder
from recovar.classifier_models import ClassifierMultipleAutoencoder
assert numpy.__version__.startswith('1.'), 'numpy must be <2 for TF 2.14 (got ' + numpy.__version__ + ')'
print('All imports OK — tensorflow', tensorflow.__version__, '— numpy', numpy.__version__)
" && echo "Verification passed." || echo "Verification FAILED — check output above."

echo ""
echo "=== Done ==="
echo "See seiscomp_integration/README.md for usage."
