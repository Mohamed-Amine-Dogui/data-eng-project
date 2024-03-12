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

# Dynamically find the site-packages directory
SITE_PACKAGES=$(python -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())")
echo "Site-packages directory: ${SITE_PACKAGES}"

# Prepare the ZIP package
mkdir -p "${LAMBDA_LAYER_DIR}/python/lib/python3.9/site-packages"
cp -R ${SITE_PACKAGES}/* "${LAMBDA_LAYER_DIR}/python/lib/python3.9/site-packages/"

pushd "${LAMBDA_LAYER_DIR}"
zip -r9 lambda-layer.zip python
popd

# Upload the ZIP file to S3
aws s3 cp ${LAMBDA_LAYER_DIR}/lambda-layer.zip s3://${BUCKET_NAME}/lambda-layer.zip

# Cleanup
deactivate
rm -rf lambda-layer-env
rm -rf "${LAMBDA_LAYER_DIR}/python"
