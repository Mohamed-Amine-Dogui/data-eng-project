#########################################################################################################################
####  KMS Key Policy for F-stream s3 bucket
#########################################################################################################################
#data "aws_iam_policy_document" "fstream_bucket_kms_Key_policy" {
#  #checkov:skip=CKV_AWS_109: Ensure IAM policy does not allow permission management / resource exposure without constraints: Check fails since of resources = ["*"] which is mandatory in KMS key policies
#  #checkov:skip=CKV_AWS_111: Ensure IAM policy does not allow write access without constraints: Check fails since of resources = ["*"] which is mandatory in KMS key policies
#
#  statement {
#    sid     = "AllwOnlyThisArns"
#    effect  = "Allow"
#    actions = ["kms:*"]
#    principals {
#      identifiers = ["*"]
#      type        = "AWS"
#    }
#    condition {
#      test = "ArnLike"
#      values = concat(local.access_arns,
#        [
#          module.fstream_sqs_s3_lambda.aws_lambda_function_role_arn,
#          module.fstream_glue_job.iam_role_arn,
#          data.terraform_remote_state.cap_default.outputs.cap_redshift_cluster_base_role_arn,
#          data.aws_iam_role.PA_CAS_demo_DATA_SCIENTIST.arn,
#          data.aws_iam_role.PA_CAP_demo_DATA_SCIENTIST.arn,
#          module.prepare_data_notebook.ni_aws_iam_role_arn
#      ])
#      variable = "aws:PrincipalArn"
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
#
#}
#
#########################################################################################################################
####   Bucket Policy for F-stream s3
#########################################################################################################################
#data "aws_iam_policy_document" "fstream_bucket_policy_document" {
#  statement {
#    sid    = "EnforceSSLBucket"
#    effect = "Deny"
#
#    actions = ["s3:*"]
#
#
#    principals {
#      type        = "AWS"
#      identifiers = ["*"]
#    }
#
#    condition {
#      test     = "Bool"
#      variable = "aws:SecureTransport"
#      values   = ["false"]
#    }
#
#    resources = ["${module.fstream_api_data_bucket.s3_arn}/*"]
#  }
#
#
#  statement {
#    sid    = "AllwOnlyThisArns"
#    effect = "Allow"
#
#    actions = ["s3:*"]
#
#    principals {
#      type        = "AWS"
#      identifiers = ["*"]
#    }
#
#    condition {
#      test = "ArnLike"
#      values = concat(local.access_arns,
#        [
#          module.fstream_sqs_s3_lambda.aws_lambda_function_role_arn,
#          module.fstream_glue_job.iam_role_arn,
#          data.terraform_remote_state.cap_default.outputs.cap_redshift_cluster_base_role_arn,
#          module.prepare_data_notebook.ni_aws_iam_role_arn
#      ])
#      variable = "aws:PrincipalArn"
#    }
#    resources = [
#      "${module.fstream_api_data_bucket.s3_arn}/*",
#      module.fstream_api_data_bucket.s3_arn
#    ]
#  }
#
#}
#
#########################################################################################################################
####  Bucket to store the SNS Messages
#########################################################################################################################
#
#module "fstream_api_data_bucket" {
#  enable = true
#
#  source                        = "git::ssh://cap-tf-module-aws-s3-bucket/vwdfive/cap-tf-module-aws-s3-bucket//s3/s3-encrypted?ref=tags/0.5.2"
#  environment                   = var.stage
#  project                       = var.project
#  s3_bucket_name                = var.fstream_s3_bucket
#  s3_bucket_acl                 = "private"
#  versioning_enabled            = true
#  enforce_SSL_encryption_policy = true
#  use_aes256_encryption         = false #if set to true, it don't allow the creation of a kms key and in our policy we use kms so it must be set to false
#  force_destroy                 = true
#  kst                           = var.tag_KST
#  wa_number                     = var.wa_number
#
#  object_ownership = "ObjectWriter"
#
#  tags_kms = {
#    ApplicationID = "demo_onetom_prod_tracker"
#    ProjectID     = "demo"
#  }
#
#  tags_s3 = {
#    ApplicationID = "demo_onetom_prod_tracker"
#    ProjectID     = "demo"
#    ModuleName    = "demo-${var.stage}-fstream_api_data_bucket"
#  }
#
#  lifecycle_rules = [
#    {
#      enabled                        = true
#      prefix                         = "processed_data/tmp"
#      expirations                    = [{ days = 5 }]
#      noncurrent_version_expirations = [{ days = 5 }]
#    },
#    {
#      enabled                        = true
#      prefix                         = "DE/"
#      expirations                    = [{ days = 31 }]
#      noncurrent_version_expirations = [{ days = 31 }]
#    }
#  ]
#
#  git_repository              = var.git_repository
#  attach_custom_bucket_policy = true
#  policy                      = data.aws_iam_policy_document.fstream_bucket_policy_document.json
#  kms_policy_to_attach        = data.aws_iam_policy_document.fstream_bucket_kms_Key_policy.json
#}
