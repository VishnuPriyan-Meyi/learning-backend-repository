#!/bin/bash

# =============================================================
# devops/utils.sh — Setup Utility Functions
# =============================================================

# ── Colours ───────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

ok()      { echo -e "${GREEN}  ✔ $1${NC}"; }
info()    { echo -e "${CYAN}  ► $1${NC}"; }
warn()    { echo -e "${YELLOW}  ⚠ $1${NC}"; }
fail()    { echo -e "${RED}  ✘ $1${NC}"; exit 1; }
divider() { echo ""; echo "─────────────────────────────────────────────────"; echo ""; }

# ── Validation ────────────────────────────────────────────────
# Validates that required environment variables are present and not default
validate_required_vars() {
  local vars=("$@")
  for VAR in "${vars[@]}"; do
    VALUE="${!VAR}"
    if [ -z "$VALUE" ] || [[ "$VALUE" == *"ORG/REPO"* ]]; then
      fail "ERROR: '$VAR' is not set properly. Please fill in all config values in the environment file."
    fi
  done
}

# ── Environment Variables ──────────────────────────────────────
# Safely updates a single key in the global ENV_FILE
update_env_var() {
  local KEY="$1"
  local VALUE="$2"
  
  if [ -z "$ENV_FILE" ]; then
    fail "update_env_var requires ENV_FILE to be exported globally."
  fi

  if grep -q "^${KEY}=" "$ENV_FILE" 2>/dev/null || grep -q "^export ${KEY}=" "$ENV_FILE" 2>/dev/null; then
    sed -i "s|^${KEY}=.*|${KEY}=${VALUE}|g; s|^export ${KEY}=.*|export ${KEY}=${VALUE}|g" "$ENV_FILE"
  else
    echo "export ${KEY}=${VALUE}" >> "$ENV_FILE"
  fi
}
