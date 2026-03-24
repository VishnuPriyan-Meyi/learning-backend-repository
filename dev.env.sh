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
  [BRANCH]="feat/sam-backend-pipeline-stack"
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

# =============================================================
# EXPORTS (Translates object properties back into flat strings 
# so AWS CodePipeline and setup.sh can officially read them)
# =============================================================
GITHUB_ORG_REPO="${GITHUB[ORG]}/${GITHUB[REPO]}"
GITHUB_BRANCH="${GITHUB[BRANCH]}"
GITHUB_CONNECTION_ARN="${GITHUB[CONNECTION_ARN]}"

AWS_REGION="${AWS[REGION]}"

LAMBDA_FUNCTION_NAME="${STACK[LAMBDA_NAME]}"
INFRA_STACK_NAME="${STACK[INFRA_NAME]}"
PIPELINE_STACK_NAME="${STACK[PIPELINE_NAME]}"

# ── Auto-filled by setup.sh — DO NOT EDIT MANUALLY ───────────
# These are populated automatically after setup.sh runs.
ARTIFACTS_BUCKET=learning-backend-pipeline-artifactsbucket-sibtvaonniqp
LAMBDA_NAME=learning-backend-function
API_ENDPOINT=https://2d257ibbo1.execute-api.us-east-1.amazonaws.com