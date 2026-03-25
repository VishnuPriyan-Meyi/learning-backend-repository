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

# ── Load prerequisites ───────────────────────────────────────
source <(sed -e 's/\r$//' devops/init.sh)

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
  --no-fail-on-empty-changeset \
  --region "${AWS[REGION]}"

ok "Infrastructure stack deployed."
divider

echo "[ Step 5 ] Fetching infrastructure stack outputs..."

API_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name "${STACK[INFRA_NAME]}" \
  --region "${AWS[REGION]}" \
  --query "Stacks[0].Outputs[?OutputKey=='ApiEndpoint'].OutputValue" \
  --output text)

ok "API Endpoint:    $API_ENDPOINT"
divider

# ── Done ─────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}  ╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}  ║         Setup Complete! 🎉                 ║${NC}"
echo -e "${GREEN}  ╚════════════════════════════════════════════╝${NC}"
echo ""
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
