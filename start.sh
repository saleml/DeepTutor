#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if [[ ! -L ./data ]]; then
  echo "ERROR: ./data is not a symlink." >&2
  echo "See CLAUDE.md step 2 — point ./data at the synced workspace before launching." >&2
  exit 1
fi

if [[ ! -e ./data ]]; then
  echo "ERROR: ./data symlink is broken (target missing)." >&2
  echo "Target: $(readlink ./data)" >&2
  echo "Check that the cloud sync client is running and fully synced." >&2
  exit 1
fi

if [[ ! -r ./data/user/settings/model_catalog.json ]]; then
  echo "ERROR: ./data/user/settings/model_catalog.json not readable." >&2
  echo "Launching now would trigger the Setup Tour and may overwrite synced settings." >&2
  echo "Wait for the cloud sync to finish, then retry." >&2
  exit 1
fi

CONDA_BASE="$(conda info --base 2>/dev/null)" || {
  echo "ERROR: 'conda' not found on PATH." >&2
  exit 1
}
# shellcheck disable=SC1091
source "$CONDA_BASE/etc/profile.d/conda.sh"

if ! conda env list | awk '{print $1}' | grep -qx deeptutor; then
  echo "ERROR: conda env 'deeptutor' does not exist." >&2
  echo "See CLAUDE.md step 3 to create it." >&2
  exit 1
fi

conda activate deeptutor
exec python scripts/start_web.py
