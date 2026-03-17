#!/bin/bash

# =============================================================
# setup.sh — Fully Automated Prerequisites Setup Script
#
# Run this ONCE before anything else. It will:
#
#   1.  Validate AWS CLI + credentials
#   2.  Deploy pipeline.yaml → creates IAM roles, CodeBuild
#       projects, GitHub connection reference, Artifacts S3 bucket
#       and the CodePipeline itself (all in one CloudFormation stack)
#   3.  Fetch the Artifacts bucket name → auto-fill .env
#   4.  Deploy backend_template.yaml → creates the Lambda function
#       (with IAM execution role) + API Gateway HTTP API
#   5.  Fetch outputs → auto-fill .env with Lambda name + API URL
#   6.  Remind you to complete GitHub OAuth if needed
#
# NOTE: Pipeline stack is deployed FIRST so the Artifacts bucket
#       exists before backend_template.yaml needs its S3 location.
#
# Usage (Git Bash or WSL on Windows):
#   chmod +x devops/setup.sh
#   ./devops/setup.sh
# =============================================================

set -e  # Exit on any error

# ── Load configuration from .env ─────────────────────────────
ENV_FILE=".env"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: .env file not found in the repo root."
  exit 1
fi

# Export all variables from .env (strip comments and blank lines)
set -a
# shellcheck disable=SC1090
source <(grep -v '^\s*#' "$ENV_FILE" | grep -v '^\s*$' | sed 's/[[:space:]]*#.*//')
set +a

# Validate required config vars are filled in
REQUIRED_VARS=(GITHUB_ORG_REPO GITHUB_BRANCH
               LAMBDA_FUNCTION_NAME
               INFRA_STACK_NAME PIPELINE_STACK_NAME
               AWS_REGION GITHUB_CONNECTION_ARN)

for VAR in "${REQUIRED_VARS[@]}"; do
  VALUE="${!VAR}"
  if [ -z "$VALUE" ] || [[ "$VALUE" == *"ORG/REPO"* ]]; then
    echo "ERROR: '$VAR' is not set in .env. Please fill in all config values."
    exit 1
  fi
done

# ── Helper: safely update a single key in .env ───────────────
update_env_var() {
  local KEY="$1"
  local VALUE="$2"
  if grep -q "^${KEY}=" "$ENV_FILE"; then
    sed -i "s|^${KEY}=.*|${KEY}=${VALUE}|" "$ENV_FILE"
  else
    echo "${KEY}=${VALUE}" >> "$ENV_FILE"
  fi
}

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

# ──────────────────────────────────────────────────────────────

# ── Step 1: Validate AWS CLI ─────────────────────────────────
echo "[ Step 1 ] Validating AWS CLI..."

command -v aws &>/dev/null \
  || fail "AWS CLI not installed. Visit: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text 2>/dev/null) \
  || fail "AWS CLI not configured. Run: aws configure"

ok "AWS CLI OK. Account: $AWS_ACCOUNT_ID | Region: $AWS_REGION"
divider

# ── Step 2: Deploy Pipeline Stack (creates Artifacts bucket first) ──
# pipeline.yaml defines EVERYTHING in one CloudFormation stack:
#   - IAM roles (BackendCodePipelineRole, BackendCodeBuildRole)
#   - Artifacts S3 bucket (also stores Lambda ZIPs)
#   - CodeBuild projects (build + deploy)
#   - The CodePipeline itself
echo "[ Step 2 ] Deploying pipeline stack: $PIPELINE_STACK_NAME"
info "This creates IAM roles, CodeBuild projects, the Artifacts bucket, and the pipeline..."
info "(The pipeline will be PENDING until after Step 4 deploys the Lambda function.)"

aws cloudformation deploy \
  --template-file devops/code_pipeline/pipeline.yaml \
  --stack-name "$PIPELINE_STACK_NAME" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    GitHubOrgRepo="$GITHUB_ORG_REPO" \
    GitHubBranch="$GITHUB_BRANCH" \
    LambdaFunctionName="$LAMBDA_FUNCTION_NAME" \
    GitHubConnectionArn="$GITHUB_CONNECTION_ARN" \
  --region "$AWS_REGION"

ok "Pipeline stack deployed."
divider

# ── Step 3: Fetch Artifacts Bucket name + Update .env ─────────
echo "[ Step 3 ] Fetching pipeline stack outputs..."

ARTIFACTS_BUCKET=$(aws cloudformation describe-stacks \
  --stack-name "$PIPELINE_STACK_NAME" \
  --region "$AWS_REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='ArtifactsBucketName'].OutputValue" \
  --output text)

ok "Artifacts Bucket: $ARTIFACTS_BUCKET"

info "Updating .env with auto-filled values..."
update_env_var "ARTIFACTS_BUCKET" "$ARTIFACTS_BUCKET"
ok ".env updated."
divider

# ── Step 4: Deploy Infrastructure (Lambda + API Gateway) ──────
echo "[ Step 4 ] Deploying infrastructure stack: $INFRA_STACK_NAME"
info "This creates the Lambda function, IAM execution role, and API Gateway HTTP API..."
info "Note: Lambda needs an initial empty placeholder ZIP in S3 to create successfully."

# Ensure 'zip' is available — install it if missing (WSL/Ubuntu minimal)
if ! command -v zip &>/dev/null; then
  info "'zip' not found — installing..."
  sudo apt-get install -y zip -q
  ok "zip installed."
fi

# Create a minimal placeholder ZIP so CloudFormation can create the Lambda function.
# The first pipeline run will immediately replace this with the real code.
echo 'exports.handler = async () => ({ statusCode: 200, body: "pending first deploy" });' > /tmp/index.js
cd /tmp && zip lambda-deployment.zip index.js && cd -

aws s3 cp /tmp/lambda-deployment.zip \
  "s3://${ARTIFACTS_BUCKET}/lambda-deployment.zip"

ok "Placeholder ZIP uploaded to s3://${ARTIFACTS_BUCKET}/lambda-deployment.zip"

aws cloudformation deploy \
  --template-file devops/template_file/backend_template.yaml \
  --stack-name "$INFRA_STACK_NAME" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    LambdaFunctionName="$LAMBDA_FUNCTION_NAME" \
    LambdaCodeS3Bucket="$ARTIFACTS_BUCKET" \
    LambdaCodeS3Key="lambda-deployment.zip" \
  --region "$AWS_REGION"

ok "Infrastructure stack deployed."
divider

# ── Step 5: Fetch Lambda + API Gateway Outputs + Update .env ──
echo "[ Step 5 ] Fetching infrastructure stack outputs..."

LAMBDA_NAME=$(aws cloudformation describe-stacks \
  --stack-name "$INFRA_STACK_NAME" \
  --region "$AWS_REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='LambdaFunctionName'].OutputValue" \
  --output text)

API_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name "$INFRA_STACK_NAME" \
  --region "$AWS_REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='ApiEndpoint'].OutputValue" \
  --output text)

ok "Lambda Function: $LAMBDA_NAME"
ok "API Endpoint:    $API_ENDPOINT"

info "Updating .env with auto-filled values..."
update_env_var "LAMBDA_NAME"   "$LAMBDA_NAME"
update_env_var "API_ENDPOINT"  "$API_ENDPOINT"
ok ".env updated."
divider

# ── Done ─────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}  ╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}  ║         Setup Complete! 🎉                 ║${NC}"
echo -e "${GREEN}  ╚════════════════════════════════════════════╝${NC}"
echo ""
echo "  Lambda Function: $LAMBDA_NAME"
echo "  API Endpoint:    $API_ENDPOINT"
echo "  Pipeline Stack:  $PIPELINE_STACK_NAME"
echo ""
echo -e "${CYAN}  Push your code to trigger the pipeline:${NC}"
echo ""
echo "    git add ."
echo "    git commit -m \"initial deploy\""
echo "    git push origin $GITHUB_BRANCH"
echo ""
echo "  Monitor pipeline:"
echo "  https://$AWS_REGION.console.aws.amazon.com/codesuite/codepipeline/pipelines"
echo ""
echo -e "${YELLOW}  ⚠ If the GitHub connection is PENDING, complete OAuth here:${NC}"
echo "  https://$AWS_REGION.console.aws.amazon.com/codesuite/settings/connections"
echo ""
