#########################################################################################################################
#### Creation of SQS Queue: (Germany)
#########################################################################################################################
#resource "aws_sqs_queue" "fstream_queue" {
#
#  count = 1
#  depends_on = [
#    module.fstream_queue_kms_key
#  ]
#
#  name                       = module.fstream_labels.resource["sqs"]["id"]
#  visibility_timeout_seconds = 43200
#  message_retention_seconds  = 1209600
#  max_message_size           = 262144
#  delay_seconds              = 1
#  receive_wait_time_seconds  = 10
#  policy                     = data.aws_iam_policy_document.fstream_sqs_policy.json
#  kms_master_key_id          = module.fstream_queue_kms_key.kms_key_id # use this when we want to use our own created key
#
#  fifo_queue = false
#  #sqs_managed_sse_enabled    = true # use this when we want to use a sqs managed key, not possible to use kms_master_key_id in this case
#
#
#  tags = {
#    ApplicationID = "demo_onetom_prod_tracker"
#    ProjectID     = "demo"
#    ModuleName    = "${var.project}-${var.stage}-fstream_queue"
#  }
#}
#
#
#########################################################################################################################
#### Add Lambda trigger from sqs (Germany)
#########################################################################################################################
#resource "aws_lambda_event_source_mapping" "map_fstream_lambda_sqs" {
#
#  count = 1
#  depends_on = [
#    aws_sqs_queue.fstream_queue[0],
#    module.fstream_sqs_s3_lambda
#  ]
#
#  batch_size       = 10
#  event_source_arn = aws_sqs_queue.fstream_queue[0].arn
#  enabled          = true
#  function_name    = module.fstream_sqs_s3_lambda.aws_lambda_function_arn
#
#}
#
#########################################################################################################################
####  Fstream SQS Policy (Germany)
#########################################################################################################################
#
#data "aws_iam_policy_document" "fstream_sqs_policy" {
#  /*
#checkov:skip=CKV_AWS_111:Skip reason - EventSourceMapping_Permission affect only a specific lambda
#*/
#
#  statement {
#    sid    = "AllowSNSToSendToSQS"
#    effect = "Allow"
#    actions = [
#      "sqs:SendMessage",
#      "sqs:SendMessageBatch"
#    ]
#    principals {
#      identifiers = ["sns.amazonaws.com"]
#      type        = "Service"
#    }
#    condition {
#      test = "ArnEquals"
#      values = [
#        var.fstream-sns-arn[var.stage]
#      ]
#      variable = "aws:SourceArn"
#    }
#    resources = [
#      "arn:aws:sqs:${var.aws_region}:${local.account_id}:${module.fstream_labels.resource["sqs"]["id"]}",
#    ]
#  }
#
#  ## TODO
#  statement {
#    sid    = "AllowActionOnKmsKey"
#    effect = "Allow"
#    actions = [
#      "kms:Decrypt",
#      "kms:Encrypt",
#      "kms:GenerateDataKey",
#      "kms:ReEncrypt*",
#      "kms:ListKeys",
#      "kms:Describe*",
#    ]
#    resources = [
#      module.fstream_queue_kms_key.kms_key_arn
#    ]
#  }
#
#  ## TODO
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
#    resources = ["*"]
#  }
#}
#
########################################################################################################################
###  KMS Key for the Fstream SQS Queue (Germany)
########################################################################################################################
#
#module "fstream_queue_kms_key" {
#  source = "git::ssh://cap-tf-module-aws-kms-key/vwdfive/cap-tf-module-aws-kms-key?ref=tags/0.0.1"
#
#  enable      = true
#  description = "KMS key for the fstream-sqs-queue"
#
#  git_repository = var.git_repository
#  project        = var.project
#  project_id     = var.project_id
#  stage          = var.stage
#  name           = "fstream_queue_kms_key"
#
#  additional_tags = {
#    ApplicationID = "demo_onetom_prod_tracker"
#    ProjectID     = "demo"
#    ModuleName    = "${var.project}-${var.stage}-fstream_queue_kms_key"
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
#    data.aws_iam_role.PA_DEVELOPER.arn,
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
#  custom_policy = data.aws_iam_policy_document.fstream_queue_Kms_Key_policy.json
#}
#
#data "aws_iam_policy_document" "fstream_queue_Kms_Key_policy" {
#  #checkov:skip=CKV_AWS_109: Ensure IAM policy does not allow permission management / resource exposure without constraints: Check fails since of resources = ["*"] which is mandatory in KMS key policies
#  #checkov:skip=CKV_AWS_111: Ensure IAM policy does not allow write access without constraints: Check fails since of resources = ["*"] which is mandatory in KMS key policies
#
#  statement {
#    sid    = "AllwOnlyThisArns"
#    effect = "Allow"
#    actions = [
#      "kms:Decrypt",
#      "kms:GenerateDataKey*"
#    ]
#    principals {
#      identifiers = ["sns.amazonaws.com"]
#      type        = "Service"
#    }
#    condition {
#      test = "ArnEquals"
#      values = [
#        var.fstream-sns-arn[var.stage]
#      ]
#      variable = "aws:SourceArn"
#    }
#    resources = ["*"]
#  }
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
#locals {
#  fstream_queue_arn                     = "arn:aws:sqs:${var.aws_region}:${local.account_id}:*"
#  fstream_lambda_sqs_arn                = "arn:aws:lambda:${var.aws_region}:${local.account_id}:function:*${var.project}-${var.stage}-${var.fstream_sqs_s3_lambda_name}-lambda"
#  fstream_lambda_sqs_execution_role_arn = "arn:aws:iam::${local.account_id}:role/${var.project}-${var.stage}-${var.fstream_sqs_s3_lambda_name}-lambda-role"
#}
#
#########################################################################################################################
####  grant access for the lambda to fstream sqs
#########################################################################################################################
#resource "aws_kms_grant" "fstream_sqs_lambda_kms_grant_pull" {
#  count             = local.count_in_default #local.in_production ? 0 : 1
#  name              = module.fstream_labels.resource["grant"]["id"]
#  key_id            = aws_sqs_queue.fstream_queue[0].kms_master_key_id
#  grantee_principal = module.fstream_sqs_s3_lambda.aws_lambda_function_role_arn
#  operations = [
#    "Decrypt",
#    "Encrypt",
#    "GenerateDataKey",
#    "DescribeKey"
#  ]
#}
