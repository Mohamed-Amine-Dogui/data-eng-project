#!/bin/bash
set -e

LAMBDA_LAYER_DIR="/home/runner/work/data-eng-project/data-eng-project/etl/lambdas"
echo "Lambda Layer Directory: ${LAMBDA_LAYER_DIR}"
REQUIREMENTS_FILE="${LAMBDA_LAYER_DIR}/layer_requirements.txt"
BUCKET_NAME=$1  # First argument to the script is the S3 bucket name

# Create a virtual environment
python3 -m venv lambda-layer-env
source lambda-layer-env/bin/activate

# Install dependencies
pip install -r $REQUIREMENTS_FILE

# Prepare the ZIP package
mkdir python
cd python
cp -R ${LAMBDA_LAYER_DIR}/lambda-layer-env/lib/python3.9/site-packages/* .
zip -r9 ${LAMBDA_LAYER_DIR}/lambda-layer.zip .

# Upload the ZIP file to S3
aws s3 cp ${LAMBDA_LAYER_DIR}/lambda-layer.zip s3://${BUCKET_NAME}/lambda-layer.zip

# Cleanup
deactivate
rm -rf lambda-layer-env
rm -rf python
