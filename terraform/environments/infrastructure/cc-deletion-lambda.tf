#locals {
#  cc_deletion_lambda_env_variables = {
#
#    CLUSTER_ID       = data.aws_redshift_cluster.cap.cluster_identifier
#    REDSHIFT_DB_NAME = var.redshift_database_name
#    REDSHIFT_USER    = var.redshift_database_lambda_user
#  }
#}
#
#########################################################################################################################
####  lambda to delete data based on gdpr
#########################################################################################################################
#module "cc_deletion_lambda" {
#  source = "git::ssh://cap-tf-module-aws-lambda-vpc/vwdfive/cap-tf-module-aws-lambda-vpc.git?ref=tags/0.4.1"
#
#  enable  = !local.in_production
#  stage   = var.stage
#  project = var.project
#  region  = var.aws_region
#
#  depends_on = [
#    module.cc_deletion_lambda_kms_key
#  ]
#
#  additional_policy        = data.aws_iam_policy_document.cc_deletion-lambda-policy.json
#  attach_additional_policy = true
#
#  lambda_unique_function_name = "cc-deletion"
#  artifact_bucket_name        = module.source_code_bucket.s3_bucket
#  runtime                     = "python3.9"
#  handler                     = var.default_lambda_handler
#  main_lambda_file            = "main"
#  lambda_base_dir             = "${abspath(path.cwd)}/../../../etl/lambdas/cc_deletion_lambda"
#  lambda_source_dir           = "${abspath(path.cwd)}/../../../etl/lambdas/cc_deletion_lambda/src"
#  memory_size                 = 1000
#  timeout                     = 800
#  lambda_env_vars             = local.cc_deletion_lambda_env_variables
#  logs_kms_key_arn            = module.cc_deletion_lambda_kms_key.kms_key_arn
#
#  tags_lambda = {
#    KST           = var.tag_KST
#    ApplicationID = "demo_onetom_campaign_cockpit"
#    ProjectID     = "demo"
#    ModuleName    = "demo-${var.stage}-cc_deletion_lambda"
#  }
#}
#
#data "aws_iam_policy_document" "cc_deletion-lambda-policy" {
#  /*
#https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html
# checkov:skip=CKV_AWS_111:Skip reason - DescribeStatement requires (*) in the policy. See the link below for more information:
# checkov:skip=CKV_AWS_107:Skip reason - Credentials are not suspended.
#Source: https://docs.aws.amazon.com/kms/latest/developerguide/kms-api-permissions-reference.html
#*/
#
#  statement {
#    sid    = "AllowLambdaAccessRedshift"
#    effect = "Allow"
#    actions = [
#      "redshift-data:CancelStatement",
#      "redshift:GetClusterCredentials",
#      "redshift-data:DescribeStatement",
#      "redshift-data:ExecuteStatement",
#      "redshift-data:GetStatementResult"
#    ]
#    resources = [
#      "*"
#    ]
#  }
#
#}
#
#module "cc_deletion_lambda_kms_key" {
#  source = "git::ssh://cap-tf-module-aws-kms-key/vwdfive/cap-tf-module-aws-kms-key?ref=tags/0.0.1"
#
#  enable      = !local.in_production
#  description = "KMS key for the compaign cockpit deletion lambda"
#
#  git_repository = var.git_repository
#  project        = var.project
#  project_id     = var.project_id
#  stage          = var.stage
#  name           = "cc_deletion_lambda_key"
#
#  additional_tags = {
#    ApplicationID = "demo_onetom_campaign_cockpit"
#    ProjectID     = "demo"
#    ModuleName    = "demo-${var.stage}-cc_deletion_lambda_kms_key"
#  }
#
#  key_admins = [
#    data.aws_caller_identity.current.arn,
#    data.aws_iam_role.PA_LIMITEDDEV.arn,
#    data.aws_iam_role.PA_CAS_demo_DATA_SCIENTIST.arn,
#    data.aws_iam_role.PA_CAP_demo_DATA_SCIENTIST.arn,
#    data.aws_iam_role.PA_DEVELOPER.arn
#  ]
#  encrypt_decrypt_arns = [
#    data.aws_caller_identity.current.arn,
#    data.aws_iam_role.PA_LIMITEDDEV.arn,
#    data.aws_iam_role.PA_CAS_demo_DATA_SCIENTIST.arn,
#    data.aws_iam_role.PA_CAP_demo_DATA_SCIENTIST.arn,
#    data.aws_iam_role.PA_DEVELOPER.arn
#  ]
#
#  aws_service_configurations = [
#    {
#      simpleName  = "Logs"
#      identifiers = ["logs.${var.aws_region}.amazonaws.com"]
#      values      = ["arn:aws:logs:${var.aws_region}:${local.account_id}:*"]
#      variable    = "kms:EncryptionContext:aws:logs:arn"
#    }
#  ]
#  custom_policy = data.aws_iam_policy_document.cc_deletion_lambda_kms_key_policy.json
#}
#
#########################################################################################################################
####  KMS Key policy document
#########################################################################################################################
#data "aws_iam_policy_document" "cc_deletion_lambda_kms_key_policy" {
#
#  statement {
#    sid    = "Allow Describe Key to AWS Config role and PA_DEVELOPER"
#    effect = "Allow"
#    actions = [
#      "kms:DescribeKey",
#      "kms:GetKeyPolicy",
#      "kms:ListResourceTags",
#      "kms:GetKeyRotationStatus"
#    ]
#    resources = ["*"]
#    principals {
#      identifiers = [
#        data.aws_iam_role.PA_DEVELOPER.arn,
#        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/bplz-config-recorder-eu-west-1"
#      ]
#      type = "AWS"
#    }
#  }
#}
#
#########################################################################################################################
####  Allow deletion lambda to use the KMS key
#########################################################################################################################
#resource "aws_kms_grant" "kms_grant_cc_deletion_lambda" {
#  count             = local.in_development ? 1 : 0
#  name              = module.cc_deletion_lambda_labels.resource["grant"]["id"]
#  key_id            = module.cc_deletion_lambda_kms_key.kms_key_id
#  grantee_principal = module.cc_deletion_lambda.aws_lambda_function_role_arn
#  operations = [
#    "Decrypt",
#    "Encrypt",
#    "GenerateDataKey",
#    "DescribeKey"
#  ]
#}
