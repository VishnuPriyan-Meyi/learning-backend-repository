#!/bin/bash

# =============================================================
# setup.sh — Automated Infrastructure Bootstrap
#
# Bootstraps the AWS SAM backend architecture and CI/CD CodePipeline.
# Run this once locally to seed your AWS environment and dynamically
# extract the deployed API URLs back into your local configuration.
#
# Usage:
#   ./devops/setup.sh [environment] (default: dev)
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
REQUIRED_VARS=(GITHUB AWS STACK SHARED_ARTIFACT_BUCKET_NAME)

validate_required_vars "${REQUIRED_VARS[@]}"

# ──────────────────────────────────────────────────────────────

validate_aws_cli

# Deploys CodePipeline, CodeBuild, S3 Artifacts, and IAM Security Roles.
echo "[ Step 2 ] Deploying pipeline stack: ${STACK[PIPELINE_NAME]}"
info "This creates IAM roles, CodeBuild projects, the Artifacts bucket, and the pipeline..."
info "(The pipeline will be PENDING until after Step 4 deploys the Lambda function.)"

sam deploy \
  --template-file "$PIPELINE_TEMPLATE" \
  --stack-name "${STACK[PIPELINE_NAME]}" \
  --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
  --parameter-overrides \
    GitHubOrgRepo="${GITHUB[ORG]}/${GITHUB[REPO]}" \
    GitHubBranch="${GITHUB[BRANCH]}" \
    InfraStackName="${STACK[INFRA_NAME]}" \
    GitHubConnectionArn="${GITHUB[CONNECTION_ARN]}" \
    BootstrapStackName="${BOOTSTRAP[STACK_NAME]}" \
  --no-fail-on-empty-changeset \
  --region "${AWS[REGION]}"

ok "Pipeline stack deployed."
divider

echo "[ Step 3 ] Fetching pipeline stack outputs..."

ARTIFACTS_BUCKET=$(aws cloudformation describe-stacks \
  --stack-name "${STACK[PIPELINE_NAME]}" \
  --region "${AWS[REGION]}" \
  --query "Stacks[0].Outputs[?OutputKey=='ArtifactsBucketName'].OutputValue" \
  --output text)

ok "Artifacts Bucket: $ARTIFACTS_BUCKET"

info "Updating .env with auto-filled values..."
update_env_var "ARTIFACTS_BUCKET" "$ARTIFACTS_BUCKET"
ok ".env updated."
divider

echo "[ Step 4 ] Deploying infrastructure stack: ${STACK[INFRA_NAME]}"
info "Building and packaging the SAM application natively..."

# Compiles local codebase securely to AWS SAM Managed S3 buckets
sam package \
  --template-file "$BACKEND_TEMPLATE" \
  --resolve-s3 \
  --output-template-file "$SAM_BUILT_TEMPLATE"

info "Deploying SAM application natively..."

sam deploy \
  --template-file "$SAM_BUILT_TEMPLATE" \
  --stack-name "${STACK[INFRA_NAME]}" \
  --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
  --parameter-overrides LambdaFunctionName="${STACK[LAMBDA_NAME]}" \
  --no-fail-on-empty-changeset \
  --region "${AWS[REGION]}"

ok "Infrastructure stack deployed."
divider

echo "[ Step 5 ] Fetching infrastructure stack outputs..."

LAMBDA_NAME=$(aws cloudformation describe-stacks \
  --stack-name "${STACK[INFRA_NAME]}" \
  --region "${AWS[REGION]}" \
  --query "Stacks[0].Outputs[?OutputKey=='LambdaFunctionName'].OutputValue" \
  --output text)

API_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name "${STACK[INFRA_NAME]}" \
  --region "${AWS[REGION]}" \
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
echo "  Pipeline Stack:  ${STACK[PIPELINE_NAME]}"
echo ""
echo -e "${CYAN}  Push your code to trigger the pipeline:${NC}"
echo ""
echo "    git add ."
echo "    git commit -m \"initial deploy\""
echo "    git push origin ${GITHUB[BRANCH]}"
echo ""
echo "  Monitor pipeline:"
echo "  https://${AWS[REGION]}.console.aws.amazon.com/codesuite/codepipeline/pipelines"
echo ""
echo -e "${YELLOW}  ⚠ If the GitHub connection is PENDING, complete OAuth here:${NC}"
echo "  https://${AWS[REGION]}.console.aws.amazon.com/codesuite/settings/connections"
echo ""
