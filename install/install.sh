#!/usr/bin/env bash

# Single entry point for TP_matching: venv, deps, Jupyter kernel.
# Optionally skips starting Jupyter (e.g. in devcontainer). With pyenv, set local version first.
# Run from repo root: ./install/install.sh [--no-jupyter]

set -euo pipefail

START_JUPYTER=true
for arg in "$@"; do
  if [ "$arg" = "--no-jupyter" ]; then
    START_JUPYTER=false
    break
  fi
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REQUIREMENTS="${SCRIPT_DIR}/requirements.txt"
ENV_NAME=".venv"

if command -v pyenv >/dev/null 2>&1; then
  DESIRED_VERSION="3.11.9"
  PYENV_VERSIONS="$(pyenv versions --bare 2>/dev/null || true)"
  if printf '%s\n' "$PYENV_VERSIONS" | grep -qx "$DESIRED_VERSION"; then
    echo "pyenv detected: setting local version to $DESIRED_VERSION"
    pyenv local "$DESIRED_VERSION"
  else
    echo "pyenv is detected but Python $DESIRED_VERSION is not installed for this project."
    echo "Run the following commands once, then rerun this script:"
    echo "  cd $(pwd)"
    echo "  pyenv install $DESIRED_VERSION"
    echo "  pyenv local $DESIRED_VERSION"
    exit 1
  fi
fi

if command -v py >/dev/null 2>&1; then
  PY_CMD="py"
  PY_ARGS_PREFIX=(-3)
else
  PY_CMD="python"
  PY_ARGS_PREFIX=()
fi

echo "=== Using Python via '${PY_CMD} ${PY_ARGS_PREFIX[*]}' ==="

echo "=== Creating virtual environment (${ENV_NAME}) ==="
"${PY_CMD}" "${PY_ARGS_PREFIX[@]}" -m venv "${ENV_NAME}"

echo "=== Activating virtual environment ==="
# shellcheck disable=SC1091
source "${ENV_NAME}/Scripts/activate" 2>/dev/null || source "${ENV_NAME}/bin/activate"

echo "=== Upgrading pip (inside venv) ==="
python -m pip install --upgrade pip

echo "=== Installing dependencies from install/requirements.txt (inside venv) ==="
python -m pip install -r "$REQUIREMENTS"

echo "=== Registering Jupyter kernel 'tp_matching_kernel' (inside venv) ==="
python -m ipykernel install --user --name tp_matching_kernel --display-name tp_matching_kernel

echo
echo "Setup finished (venv + dépendances + kernel Jupyter)."
echo "To reuse the environment:"
echo "  source ${ENV_NAME}/Scripts/activate    # Windows Git Bash"
echo "  source ${ENV_NAME}/bin/activate        # Linux / macOS"
echo

if [ "$START_JUPYTER" = true ]; then
  echo "Starting Jupyter Lab with kernel 'tp_matching_kernel'..."
  python -m jupyter lab
else
  echo "Skipping Jupyter Lab (--no-jupyter). Run 'python -m jupyter lab' when needed."
fi
