# =============================================================
# .env — Backend Lambda Pipeline Configuration
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

declare -A ENVIRONMENT=(
  [ENV]="dev"
)
# ── Stack Config Object ────────────────────────────────────────
declare -A STACK=(
  [INFRA_NAME]="learning-backend-infra"
  [PIPELINE_NAME]="learning-backend-pipeline"
)

# ── Bootstrap Config Object ────────────────────────────────────
declare -A BOOTSTRAP=(
  [STACK_NAME]="shared-${ENVIRONMENT[ENV]}-artifact-bootstrap"
  [BUCKET_NAME]="shared-${ENVIRONMENT[ENV]}-artifact-bucket"
)

# ── Additional Config ───────────────────────────────────────────
# Use bootstrap bucket instead of hardcoded
SHARED_ARTIFACT_BUCKET_NAME="${BOOTSTRAP[BUCKET_NAME]}"
