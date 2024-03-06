#########################################################################################################################
####  PULL lambda to pull data from FSAG Data Bucket and push them in the source Data Bucket
#########################################################################################################################
#module "fsag_cap_pull_lambda" {
#  source = "git::ssh://cap-tf-module-aws-lambda-vpc/vwdfive/cap-tf-module-aws-lambda-vpc.git?ref=tags/0.4.1"
#
#  enable     = true
#  depends_on = [module.fsag_cap_pull_lambda_kms_key]
#  stage      = var.stage
#  project    = var.project
#  region     = var.aws_region
#
#
#  additional_policy        = data.aws_iam_policy_document.fsag-cap-sync-policy.json
#  attach_additional_policy = true
#
#  lambda_unique_function_name = "fsag-pull"
#  artifact_bucket_name        = module.source_code_bucket.s3_bucket
#  runtime                     = "python3.9"
#  handler                     = var.default_lambda_handler
#  main_lambda_file            = "main"
#  lambda_base_dir             = "${abspath(path.cwd)}/../../../etl/lambdas/fsag"
#  lambda_source_dir           = "${abspath(path.cwd)}/../../../etl/lambdas/fsag/src"
#  memory_size                 = 1000
#  timeout                     = 800
#  logs_kms_key_arn            = module.fsag_cap_pull_lambda_kms_key.kms_key_arn
#
#  lambda_env_vars = {
#
#    FSAG_DATA_BUCKET_NAME   = var.fsag_account_bucket_name[var.stage]            # the bucket of the fsag account
#    TARGET_DATA_BUCKET_NAME = module.fsag_target_data_bucket.s3_bucket           # the demo bucket where we will copy the raw fsag data
#    TARGET_DATA_BUCKET_PATH = "s3://${module.fsag_target_data_bucket.s3_bucket}" # FSAG target bucket path
#    CLUSTER_ID              = data.aws_redshift_cluster.cap.cluster_identifier
#    REDSHIFT_DB_NAME        = var.redshift_database_name
#    REDSHIFT_USER           = var.redshift_database_lambda_user
#    REDSHIFT_SCHEMA         = var.redshift_data_loader_fsag_db_schema
#    REDSHIFT_IAM_ROLE       = data.terraform_remote_state.cap_default.outputs.cap_redshift_cluster_base_role_arn
#    sns_arn                 = aws_sns_topic.pt_monitoring_sns_topic.arn
#    stage                   = var.stage
#  }
#
#  tags_lambda = {
#    KST           = var.tag_KST
#    GitRepository = var.git_repository
#    ApplicationID = "demo_onetom_fast_track"
#    ProjectID     = "demo"
#    ModuleName    = "demo-${var.stage}-fsag_cap_pull_lambda"
#  }
#}
#
#########################################################################################################################
#### Policy of FSAG PULL lambda
#########################################################################################################################
#data "aws_iam_policy_document" "fsag-cap-sync-policy" {
#  /*
#https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html
# checkov:skip=CKV_AWS_111:Skip reason - DescribeStatement requires (*) in the policy. See the link below for more information:
# checkov:skip=CKV_AWS_107:Skip reason - Credentials are not suspended.
#Source: https://docs.aws.amazon.com/kms/latest/developerguide/kms-api-permissions-reference.html
#*/
#  statement {
#    sid    = "AllowReadWriteS3"
#    effect = "Allow"
#    actions = [
#      "s3:Get*",
#      "s3:List*",
#      "s3:Describe*",
#      "s3:Put*",
#      "s3:Delete*",
#      "s3:RestoreObject"
#    ]
#    resources = [
#      var.fsag_account_bucket_arn[var.stage],
#      "${var.fsag_account_bucket_arn[var.stage]}/*",
#      module.fsag_target_data_bucket.s3_arn,
#      "${module.fsag_target_data_bucket.s3_arn}/*",
#      "arn:aws:s3:::io-vwfs-int-fast-track-group-brand-exchange",
#      "arn:aws:s3:::io-vwfs-int-fast-track-group-brand-exchange/*"
#    ]
#  }
#
#  statement {
#    sid    = "AllowDecryptEncryptToFSAGAccountBuckets"
#    effect = "Allow"
#    actions = [
#      "kms:Decrypt",
#      "kms:Encrypt",
#      "kms:GenerateDataKey",
#      "kms:ReEncrypt*",
#      "kms:ListKeys",
#      "kms:Describe*"
#    ]
#    resources = [
#      var.fsag_kms_keys[var.stage],
#      "arn:aws:kms:eu-central-1:576891737164:key/0c44a538-4699-46f2-8ee4-f80420fc9a4d"
#    ]
#  }
#
#  statement {
#
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
#  statement {
#
#    sid    = "AllowPutCustomMetrics"
#    effect = "Allow"
#    actions = [
#      "cloudwatch:PutMetricData",
#      "cloudwatch:PutMetricAlarm"
#    ]
#    resources = [
#      "*"
#    ]
#  }
#
#}
#
#
#########################################################################################################################
####  KMS Key for the pull-lambda
#########################################################################################################################
#
#module "fsag_cap_pull_lambda_kms_key" {
#  source = "git::ssh://cap-tf-module-aws-kms-key/vwdfive/cap-tf-module-aws-kms-key?ref=tags/0.0.1"
#  enable = true
#
#  description = "KMS key for the fsag-pull lambda"
#
#  git_repository = var.git_repository
#  project        = var.project
#  project_id     = var.project_id
#  stage          = var.stage
#  name           = "fsag_cap_pull_lambda_key"
#
#  additional_tags = {
#    ApplicationID = "demo_onetom_fast_track"
#    ProjectID     = "demo"
#    ModuleName    = "demo-${var.stage}-fsag_cap_pull_lambda_kms_key"
#  }
#
#  key_admins = [
#    data.aws_caller_identity.current.arn,
#    data.aws_iam_role.PA_LIMITEDDEV.arn,
#    data.aws_iam_role.PA_CAS_demo_DATA_SCIENTIST.arn,
#    data.aws_iam_role.PA_CAP_demo_DATA_SCIENTIST.arn,
#    data.aws_iam_role.PA_DEVELOPER.arn
#  ]
#
#  encrypt_decrypt_arns = [
#    data.aws_caller_identity.current.arn,
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
#  custom_policy = data.aws_iam_policy_document.fsag_cap_pull_lambda_kms_key_policy.json
#}
#
#########################################################################################################################
####  KMS Key policy document
#########################################################################################################################
#data "aws_iam_policy_document" "fsag_cap_pull_lambda_kms_key_policy" {
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
#
#}
#
#
#########################################################################################################################
####   Allows to grant permissions to lambda to use the specified KMS key
#########################################################################################################################
#resource "aws_kms_grant" "fsag_data_bucket_kms_grant_pull" {
#  count             = local.count_in_default #local.in_production ? 0 : 1
#  name              = module.fsag_labels.resource["grant"]["id"]
#  key_id            = module.fsag_target_data_bucket.aws_kms_key_id
#  grantee_principal = module.fsag_cap_pull_lambda.aws_lambda_function_role_arn
#  operations = [
#    "Decrypt",
#    "Encrypt",
#    "GenerateDataKey",
#    "DescribeKey"
#  ]
#}
