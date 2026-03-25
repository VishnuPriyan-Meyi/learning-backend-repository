#!/bin/bash

# =============================================================
# init.sh — Setup Prerequisites
#
# Contains all prerequisite setup and validation logic.
# This file is sourced by setup.sh to prepare the environment.
# =============================================================

set -e  # Exit on any error

# ── Load configuration environment dynamically ─────────
ENV_PREFIX="${1:-dev}"
ENV_FILE="${ENV_PREFIX}.env.sh"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: $ENV_FILE not found in the repo root."
  echo "Usage: ./devops/setup.sh [environment] (default: dev)"
  exit 1
fi

# Export all variables from the env script natively
set -a
# shellcheck disable=SC1090
source <(sed -e 's/\r$//' "$ENV_FILE")
set +a

# ── Dynamic File Paths ───────────────────────────────────────
PIPELINE_TEMPLATE="devops/templates/pipeline.yaml"
BACKEND_TEMPLATE="devops/templates/backend_template.yaml"
SAM_BUILT_TEMPLATE="packaged.yaml"

# ── Source Utility Functions ──────────────────────────────────
if [ ! -f "devops/utils.sh" ]; then
  echo "ERROR: devops/utils.sh not found."
  exit 1
fi
source <(sed -e 's/\r$//' devops/utils.sh)

# Validate required config vars are filled in
REQUIRED_VARS=(GITHUB AWS ENVIRONMENT STACK BOOTSTRAP)

validate_required_vars "${REQUIRED_VARS[@]}"

# ──────────────────────────────────────────────────────────────

validate_aws_cli
