########################################################################################################################
###  Test lambda
########################################################################################################################
module "test_lambda" {
  source = "git::ssh://git@github.com/Mohamed-Amine-Dogui/tf-module-aws-lambda-vpc.git?ref=tags/0.0.1"

  enable     = true
  depends_on = [module.test_kms_key]
  stage      = var.stage
  project    = var.project
  region     = var.aws_region


  additional_policy        = data.aws_iam_policy_document.test_lambda_policy.json
  attach_additional_policy = true

  lambda_unique_function_name = "my-first"
  artifact_bucket_name        = module.source_code_bucket.s3_bucket
  runtime                     = "python3.9"
  handler                     = var.default_lambda_handler
  main_lambda_file            = "main"
  lambda_base_dir             = "${abspath(path.cwd)}/../../../etl/lambdas/demo"
  lambda_source_dir           = "${abspath(path.cwd)}/../../../etl/lambdas/demo/src"
  memory_size                 = 1000
  timeout                     = 800
  logs_kms_key_arn            = module.test_kms_key.kms_key_arn
  git_repository              = var.git_repository

  lambda_env_vars = {
    stage                   = var.stage
    TARGET_DATA_BUCKET_NAME = module.source_code_bucket.s3_bucket #  bucket where we will put the raw data
  }

  tags_lambda = {
    GitRepository = var.git_repository
    ProjectID     = "demo"
  }
}

########################################################################################################################
### Policy of test lambda
########################################################################################################################
data "aws_iam_policy_document" "test_lambda_policy" {
  /*
https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html
 checkov:skip=CKV_AWS_111:Skip reason - DescribeStatement requires (*) in the policy. See the link below for more information:
 checkov:skip=CKV_AWS_107:Skip reason - Credentials are not suspended.
Source: https://docs.aws.amazon.com/kms/latest/developerguide/kms-api-permissions-reference.html
*/
  statement {
    sid    = "AllowReadWriteS3"
    effect = "Allow"
    actions = [
      "s3:Get*",
      "s3:List*",
      "s3:Describe*",
      "s3:Put*",
      "s3:Delete*",
      "s3:RestoreObject"
    ]
    resources = [
      module.source_code_bucket.s3_arn,
      "${module.source_code_bucket.s3_arn}/*",
    ]
  }

  statement {
    sid    = "AllowDecryptEncrypt"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:ReEncrypt*",
      "kms:ListKeys",
      "kms:Describe*"
    ]
    resources = [
      module.test_kms_key.kms_key_arn
    ]
  }

  statement {

    sid    = "AllowLambdaAccessRedshift"
    effect = "Allow"
    actions = [
      "redshift-data:CancelStatement",
      "redshift:GetClusterCredentials",
      "redshift-data:DescribeStatement",
      "redshift-data:ExecuteStatement",
      "redshift-data:GetStatementResult"
    ]
    resources = [
      "*"
    ]
  }

  statement {

    sid    = "AllowPutCustomMetrics"
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricData",
      "cloudwatch:PutMetricAlarm"
    ]
    resources = [
      "*"
    ]
  }
}

########################################################################################################################
###   Allows to grant permissions to lambda to use the specified KMS key
########################################################################################################################
resource "aws_kms_grant" "test_lambda_grant_kms_key" {
  count             = local.count_in_default
  name              = module.generic_labels.resource["grant"]["id"]
  key_id            = module.test_kms_key.kms_key_id
  grantee_principal = module.test_lambda.aws_lambda_function_role_arn
  operations = [
    "Decrypt",
    "Encrypt",
    "GenerateDataKey",
    "DescribeKey"
  ]
}
