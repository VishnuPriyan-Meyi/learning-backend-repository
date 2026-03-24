#!/bin/bash

# =============================================================
# deploy.sh — Shared Artifact Bootstrap Deployer
#
# Generates a highly secure S3 bucket dedicated exclusively
# to providing shared storage for various CodePipeline artifacts.
#
# Usage: ./deploy.sh [env_prefix] [custom_bucket_name]
# =============================================================

set -e  # Exit on error

ENV_PREFIX="${1:-dev}"
ENV_FILE="../../${ENV_PREFIX}.env.sh"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: $ENV_FILE not found in the repo root..."
  exit 1
fi

set -a
# shellcheck disable=SC1090
source <(sed -e 's/\r$//' "$ENV_FILE")
set +a

TEMPLATE_FILE="artifact-bootstrap.yaml"

# Prioritize passing a static bucket name natively via terminal arguments.
# If nothing is passed, fallback to the dynamic epoch generated in dev.env.sh.
BUCKET_NAME="${2:-${BOOTSTRAP[BUCKET_NAME]}}"

echo "Deploying Bootstrap Stack natively via SAM..."
echo "Stack Name : ${BOOTSTRAP[STACK_NAME]}"
echo "Region     : ${AWS[REGION]}"
echo "Bucket     : $BUCKET_NAME"

echo "Validating CloudFormation template..."
aws cloudformation validate-template \
  --template-body "file://$TEMPLATE_FILE" \
  --region "${AWS[REGION]}"

echo "Executing stack updates natively..."
sam deploy \
  --template-file "$TEMPLATE_FILE" \
  --stack-name "${BOOTSTRAP[STACK_NAME]}" \
  --parameter-overrides BucketName="$BUCKET_NAME" \
  --capabilities CAPABILITY_NAMED_IAM \
  --region "${AWS[REGION]}" \
  --no-fail-on-empty-changeset

echo "Fetching stack outputs..."

aws cloudformation describe-stacks \
  --stack-name "${BOOTSTRAP[STACK_NAME]}" \
  --region "${AWS[REGION]}" \
  --query "Stacks[0].Outputs"

echo ""
echo "Bootstrap deployment perfectly finalized!"