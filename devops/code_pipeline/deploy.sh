#!/bin/bash

# deploy.sh — Lambda Function Code Update
#
# Called by the LambdaDeploy CodeBuild project (via deploy_buildspec.yaml).
# This is the Lambda equivalent of the frontend's CloudFront invalidation step.
#
# The Build stage has already produced lambda-deployment.zip and placed it
# in the CodePipeline artifacts bucket. CodePipeline passes it to this project
# as the BuildOutput input artifact (extracted into the working directory).

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

# ── Confirm the ZIP exists in the working directory ───────────
if [ ! -f "lambda-deployment.zip" ]; then
  echo "ERROR: lambda-deployment.zip not found in working directory."
  echo "Files present:"
  ls -la
  exit 1
fi

echo "ZIP size: $(du -sh lambda-deployment.zip | cut -f1)"

# ── Update Lambda function code ───────────────────────────────
# --zip-file fileb:// uploads the ZIP directly from the local filesystem.
# CodePipeline has already extracted the artifact ZIP into this directory.
echo "Updating Lambda function code..."
aws lambda update-function-code \
  --function-name "$LAMBDA_FUNCTION_NAME" \
  --zip-file fileb://lambda-deployment.zip \
  / --output json/

# ── Wait for the update to complete ──────────────────────────
# Lambda updates are asynchronous. Wait until the function state is Active
# so the next pipeline run doesn't collide with an in-progress update.
echo "Waiting for Lambda update to complete..."
aws lambda wait function-updated \
  --function-name "$LAMBDA_FUNCTION_NAME"

echo "─────────────────────────────────────────────────"
echo "✔  Lambda deployment complete!"
echo "─────────────────────────────────────────────────"
