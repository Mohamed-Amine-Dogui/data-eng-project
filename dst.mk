#
# Data Eng Template
#

.ONESHELL:
SHELL := /bin/bash
AWS_GLUE_LIBS = ./awsglue
CUR_DIR=${PWD}

#
# Convenience targets for running tests and ensuring awsglue exists.
#

.PHONY: pyclean
pyclean:
	@find . -type d -name "__pycache__" -exec rm -rf "{}" \;

tfclean:
	@find . -type d -name ".terraform" -exec rm -rf "{}" \;

clean: pyclean tfclean
	@echo "Removed temporary directories/files"

$(AWS_GLUE_LIBS):
	@echo "Local copy of awsglue not found."
	@echo "Cloning AWS Glue Libraries for local testing."
	@cd /tmp && \
		git clone https://github.com/awslabs/aws-glue-libs && \
		cd aws-glue-libs && \
		git checkout glue-1.0 && \
		cp -r awsglue $(CUR_DIR)
	@rm -rf /tmp/aws-glue-libs
