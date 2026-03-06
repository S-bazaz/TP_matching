#!/usr/bin/env bash

# Single entry point for TP_matching: venv, deps, Jupyter kernel, Elasticsearch (local) + index.
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
ES_VERSION="8.11.0"
BASE_URL="https://artifacts.elastic.co/downloads/elasticsearch"
ES_DIR="$REPO_ROOT/elasticsearch_local"
ES_DATA="$REPO_ROOT/es_data"

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

# --- Elasticsearch (local, no Docker): install, start, create index and bulk ---
case "$(uname -s)" in
  Linux*)   ARCH="linux-x86_64";;
  Darwin*)  ARCH="darwin-$(uname -m | sed 's/x86_64/x86_64/;s/arm64/aarch64/')";;
  *)        ARCH="";;
esac
if [ -n "$ARCH" ]; then
  TAR_NAME="elasticsearch-${ES_VERSION}-${ARCH}.tar.gz"
  DOWNLOAD_URL="$BASE_URL/$TAR_NAME"
  ES_HOME="$ES_DIR/elasticsearch-$ES_VERSION"
  if [ ! -d "$ES_HOME" ]; then
    echo "=== Downloading Elasticsearch $ES_VERSION ==="
    mkdir -p "$ES_DIR"
    (cd "$ES_DIR" && { curl -sSL -O "$DOWNLOAD_URL" || wget -q "$DOWNLOAD_URL"; })
    (cd "$ES_DIR" && tar -xzf "$TAR_NAME")
    rm -f "$ES_DIR/$TAR_NAME"
  fi
  CONFIG="$ES_HOME/config/elasticsearch.yml"
  if ! grep -q "xpack.security.enabled" "$CONFIG" 2>/dev/null; then
    echo "" >> "$CONFIG"
    echo "xpack.security.enabled: false" >> "$CONFIG"
    echo "discovery.type: single-node" >> "$CONFIG"
  fi
  echo "=== Starting Elasticsearch in background ==="
  (cd "$ES_HOME" && ./bin/elasticsearch -d)
  echo "Waiting for Elasticsearch on http://localhost:9200 ..."
  for i in $(seq 1 30); do
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:9200" 2>/dev/null | grep -q "200"; then break; fi
    [ "$i" -eq 30 ] && { echo "Elasticsearch did not become ready in time."; exit 1; }
    sleep 2
  done
  echo "=== Creating index 'products' and bulk indexing 4 products ==="
  curl -s -X PUT "http://localhost:9200/products" -H "Content-Type: application/json" -d "@${ES_DATA}/mapping_products.json"
  curl -s -X POST "http://localhost:9200/products/_bulk" -H "Content-Type: application/x-ndjson" --data-binary "@${ES_DATA}/products_bulk.ndjson"
  echo ""
  echo "Elasticsearch is running at http://localhost:9200 with index 'products' (4 products)."
else
  echo "Elasticsearch auto-install is supported only on Linux/macOS in this script. On Windows use install.ps1."
fi

echo
echo "Setup finished."
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
