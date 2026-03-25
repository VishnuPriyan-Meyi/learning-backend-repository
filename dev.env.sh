# =============================================================
# .env — Backend Lambda Pipeline Configuration
#
# Fill in ALL values before running devops/setup.sh.
# Lines beginning with # are comments and are ignored.
# =============================================================

# ── GitHub Config Object ───────────────────────────────────────
declare -A GITHUB=(
  [ORG]="VishnuPriyan-Meyi"
  [REPO]="learning-backend-repository"
  [BRANCH]="feat/bootstrap-bakend-pipeline"
  [CONNECTION_ARN]="arn:aws:codeconnections:ap-south-1:369606757523:connection/08feb4da-3348-4e18-9a1f-22a144db6021"
)

# ── AWS Config Object ──────────────────────────────────────────
declare -A AWS=(
  [REGION]="us-east-1"
)

# ── Stack Config Object ────────────────────────────────────────
declare -A STACK=(
  [LAMBDA_NAME]="learning-backend-function"
  [INFRA_NAME]="learning-backend-infra"
  [PIPELINE_NAME]="learning-backend-pipeline"
)

# ── Bootstrap Config Object ────────────────────────────────────
declare -A BOOTSTRAP=(
  [STACK_NAME]="shared-artifact-bootstrap"
  [BUCKET_NAME]="shared-artifact-bucket-$(date +%s)"
)

# ── Additional Config ───────────────────────────────────────────
# Use bootstrap bucket instead of hardcoded
SHARED_ARTIFACT_BUCKET_NAME="${BOOTSTRAP[BUCKET_NAME]}"

# ── Auto-filled by setup.sh — DO NOT EDIT MANUALLY ───────────
# These are populated automatically after setup.sh runs.
ARTIFACTS_BUCKET=${BOOTSTRAP[BUCKET_NAME]}
LAMBDA_NAME=learning-backend-function
API_ENDPOINT=https://bzn6tpyzb2.execute-api.us-east-1.amazonaws.com/Prod/
