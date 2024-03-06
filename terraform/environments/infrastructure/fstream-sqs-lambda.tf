#locals {
#  fstream_lambda_env_variables = {
#    FSTREAM_S3_BUCKET = module.fstream_api_data_bucket.s3_bucket
#  }
#}
#
#########################################################################################################################
####   fstream_sqs_s3_lambda to store the message send by SQS in S3
#########################################################################################################################
#module "fstream_sqs_s3_lambda" {
#  source = "git::ssh://cap-tf-module-aws-lambda-vpc/vwdfive/cap-tf-module-aws-lambda-vpc.git?ref=tags/0.4.1"
#
#  enable = true
#  depends_on = [
#    module.fstream_sqs_s3_lambda_kms_key,
#    module.fstream_api_data_bucket.s3_bucket,
#    aws_sqs_queue.fstream_queue[0]
#  ]
#
#  stage   = var.stage
#  project = var.project
#  region  = var.aws_region
#
#  lambda_unique_function_name = var.fstream_sqs_s3_lambda_name
#  artifact_bucket_name        = module.source_code_bucket.s3_bucket
#  runtime                     = "python3.9"
#  handler                     = var.default_fstream_lambda_handler
#  main_lambda_file            = "main"
#  lambda_base_dir             = "${abspath(path.cwd)}/../../../etl/lambdas/fstream_sqs"
#  lambda_source_dir           = "${abspath(path.cwd)}/../../../etl/lambdas/fstream_sqs/src"
#  memory_size                 = 1000
#  timeout                     = 800
#
#  logs_kms_key_arn         = module.fstream_sqs_s3_lambda_kms_key.kms_key_arn
#  lambda_env_vars          = local.fstream_lambda_env_variables
#  attach_additional_policy = true
#  additional_policy        = data.aws_iam_policy_document.fstream_sqs_s3_lambda_permission.json
#
#  tags_lambda = {
#    KST           = var.tag_KST
#    GitRepository = var.git_repository
#    ApplicationID = "demo_onetom_prod_tracker"
#    ProjectID     = "demo"
#    ModuleName    = "demo-${var.stage}-fstream_sqs_s3_lambda"
#  }
#}
#
#########################################################################################################################
####  Fstream lambda policy document
#########################################################################################################################
#data "aws_iam_policy_document" "fstream_sqs_s3_lambda_permission" {
#
#  statement {
#    sid     = "AllowAcessFstreamS3"
#    effect  = "Allow"
#    actions = ["s3:*"]
#    resources = [
#      module.fstream_api_data_bucket.s3_arn,
#      "${module.fstream_api_data_bucket.s3_arn}/*",
#
#    ]
#  }
#
#  statement {
#    sid     = "AllowAccessFstreamSQS"
#    effect  = "Allow"
#    actions = ["sqs:*"]
#
#    condition {
#      test = "ArnLike"
#      values = [
#        module.fstream_sqs_s3_lambda.aws_lambda_function_role_arn,
#        module.fstream_sqs_s3_lambda.aws_lambda_function_arn
#      ]
#      variable = "aws:PrincipalArn"
#    }
#
#    resources = [
#      local.in_development ? aws_sqs_queue.fstream_queue[0].arn : "*"
#    ]
#  }
#
#
#  statement {
#    sid     = "AllowLambdaToUseKMS"
#    effect  = "Allow"
#    actions = ["kms:*"]
#    resources = [
#      module.fstream_sqs_s3_lambda_kms_key.kms_key_arn,
#      module.fstream_api_data_bucket.aws_kms_key_arn,
#    ]
#  }
#
#  statement {
#    sid     = "AllowInvokeLambdaFunction"
#    effect  = "Allow"
#    actions = ["lambda:InvokeFunction"]
#
#    condition {
#      test = "ArnLike"
#      values = concat(local.in_development ? [aws_sqs_queue.fstream_queue[0].arn] : [],
#        [
#          data.aws_caller_identity.current.arn,
#          data.aws_iam_role.PA_CAS_demo_DATA_SCIENTIST.arn,
#          data.aws_iam_role.PA_CAP_demo_DATA_SCIENTIST.arn,
#          data.aws_iam_role.PA_DEVELOPER.arn,
#        ]
#      )
#      variable = "aws:PrincipalArn"
#    }
#
#    resources = [
#      module.fstream_sqs_s3_lambda.aws_lambda_function_role_arn,
#      module.fstream_sqs_s3_lambda.aws_lambda_function_arn,
#      module.fstream_sqs_s3_lambda.aws_lambda_function_invoke_arn
#    ]
#  }
#
#
#  statement {
#    sid    = "EventSourceMappingPermission"
#    effect = "Allow"
#    actions = [
#      "lambda:CreateEventSourceMapping",
#      "lambda:UpdateEventSourceMapping",
#      "lambda:DeleteEventSourceMapping",
#      "lambda:GetEventSourceMapping",
#      "lambda:ListEventSourceMappings"
#    ]
#
#    condition {
#      test = "ArnLike"
#      values = concat(local.in_development ? [aws_sqs_queue.fstream_queue[0].arn] : [],
#        [
#          data.aws_caller_identity.current.arn,
#          data.aws_iam_role.PA_CAS_demo_DATA_SCIENTIST.arn,
#          data.aws_iam_role.PA_CAP_demo_DATA_SCIENTIST.arn,
#          data.aws_iam_role.PA_DEVELOPER.arn,
#        ]
#      )
#      variable = "aws:PrincipalArn"
#    }
#
#    resources = [
#      module.fstream_sqs_s3_lambda.aws_lambda_function_role_arn,
#      module.fstream_sqs_s3_lambda.aws_lambda_function_arn
#    ]
#  }
#}
#
#########################################################################################################################
####  KMS Key for the stream_sqs_s3_lambda
#########################################################################################################################
#
#module "fstream_sqs_s3_lambda_kms_key" {
#  source = "git::ssh://cap-tf-module-aws-kms-key/vwdfive/cap-tf-module-aws-kms-key?ref=tags/0.0.1"
#  enable = true
#
#  description = "KMS key for the fstream_sqs_s3_lambda"
#
#  git_repository = var.git_repository
#  project        = var.project
#  project_id     = var.project_id
#  stage          = var.stage
#  name           = "fstream_sqs_s3_lambda_kms_key"
#
#  additional_tags = {
#    ApplicationID = "demo_onetom_prod_tracker"
#    ProjectID     = "demo"
#    ModuleName    = "demo-${var.stage}-fstream_sqs_s3_lambda_kms_key"
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
#
#  custom_policy = data.aws_iam_policy_document.fstream_sqs_s3_lambda_kms_key_policy.json
#}
#
#########################################################################################################################
####  KMS Key policy document
#########################################################################################################################
#data "aws_iam_policy_document" "fstream_sqs_s3_lambda_kms_key_policy" {
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
#########################################################################################################################
####  Allows to grant permissions to lambda to use the specified KMS key
#########################################################################################################################
#resource "aws_kms_grant" "grant_fstream_sqs_lambda_to_use_kms_fstream_s3_bucket" {
#  depends_on = [module.fstream_sqs_s3_lambda]
#
#  count             = local.count_in_default
#  name              = module.fstream_labels.resource["grant"]["id"]
#  key_id            = module.fstream_api_data_bucket.aws_kms_key_id
#  grantee_principal = module.fstream_sqs_s3_lambda.aws_lambda_function_role_arn
#  operations = [
#    "Decrypt",
#    "Encrypt",
#    "GenerateDataKey",
#    "DescribeKey"
#  ]
#}
