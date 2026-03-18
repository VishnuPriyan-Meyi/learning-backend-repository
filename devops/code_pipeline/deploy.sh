#!/bin/bash

# deploy.sh — Lambda Function Code Update
#
# Called by the LambdaDeploy CodeBuild project (via deploy_buildspec.yaml).
# This is the Lambda equivalent of the frontend's CloudFront invalidation step.
#
# Input artifacts received by the Deploy CodeBuild action:
#   SourceOutput  (PRIMARY)   — full repo source, contains this script
#   BuildOutput   (SECONDARY) — contains lambda-deployment.zip
#
# CodeBuild mounts the secondary artifact at: $CODEBUILD_SRC_DIR_BuildOutput

set -e  # Exit immediately on any error

echo "─────────────────────────────────────────────────"
echo " Lambda Deployment"
echo "─────────────────────────────────────────────────"

# ── Validate required environment variable ────────────────────
if [ -z "$LAMBDA_FUNCTION_NAME" ]; then
  echo "ERROR: LAMBDA_FUNCTION_NAME environment variable is not set."
  exit 1
fi

echo "Function name: $LAMBDA_FUNCTION_NAME"

# ── Locate the ZIP from the secondary BuildOutput artifact ────
# When CodeBuild receives multiple input artifacts, the secondary ones
# are extracted to $CODEBUILD_SRC_DIR_<ArtifactName>.
ZIP_PATH="${CODEBUILD_SRC_DIR_BuildOutput}/lambda-deployment.zip"

if [ ! -f "$ZIP_PATH" ]; then
  echo "ERROR: lambda-deployment.zip not found at: $ZIP_PATH"
  echo "Files in BuildOutput dir:"
  ls -la "${CODEBUILD_SRC_DIR_BuildOutput}/" 2>/dev/null || echo "(directory not found)"
  exit 1
fi

echo "ZIP path: $ZIP_PATH"
echo "ZIP size: $(du -sh "$ZIP_PATH" | cut -f1)"

# ── Update Lambda function code ───────────────────────────────
echo "Updating Lambda function code..."
aws lambda update-function-code \
  --function-name "$LAMBDA_FUNCTION_NAME" \
  --zip-file "fileb://$ZIP_PATH" \
  --output json

# ── Wait for the update to complete ──────────────────────────
# Lambda updates are asynchronous. Wait until the function state is Active
# so the next pipeline run doesn't collide with an in-progress update.
echo "Waiting for Lambda update to complete..."
aws lambda wait function-updated \
  --function-name "$LAMBDA_FUNCTION_NAME"

echo "─────────────────────────────────────────────────"
echo "✔  Lambda deployment complete!"
echo "─────────────────────────────────────────────────"
