#########################################################################################################################
####  KMS Key Policy for all fsag buckets
#########################################################################################################################
#data "aws_iam_policy_document" "fsag_Kms_Key_policy" {
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
#        local.in_development ? [module.sandbox_glue_job.iam_role_arn] : [],
#        [
#          module.fsag_cap_pull_lambda.aws_lambda_function_role_arn,
#          data.terraform_remote_state.cap_default.outputs.cap_redshift_cluster_base_role_arn,
#          data.aws_iam_role.PA_CAS_demo_DATA_SCIENTIST.arn,
#          data.aws_iam_role.PA_CAP_demo_DATA_SCIENTIST.arn
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
####  Bucket for fast track target  data after Glue
#########################################################################################################################
#
#module "fsag_target_data_bucket" {
#  enable = true #!local.in_production
#
#  source                            = "git::ssh://cap-tf-module-aws-s3-bucket/vwdfive/cap-tf-module-aws-s3-bucket//s3/s3-encrypted?ref=tags/0.5.2"
#  environment                       = var.stage
#  project                           = var.project
#  s3_bucket_name                    = var.s3_fsag_target_data_bucket
#  s3_bucket_acl                     = "private"
#  versioning_enabled                = false
#  transition_lifecycle_rule_enabled = false
#  expiration_lifecycle_rule_enabled = false
#  enforce_SSL_encryption_policy     = true
#  use_aes256_encryption             = false #if set to true, it don't allow the creation of a kms key and in our policy we use kms so it must be set to false
#  force_destroy                     = local.in_development
#  kst                               = var.tag_KST
#  wa_number                         = var.wa_number
#
#  lifecycle_rules = [
#    {
#      enabled                        = true
#      prefix                         = "processed_data"
#      expirations                    = [{ days = 30 }]
#      noncurrent_version_expirations = [{ days = 30 }]
#    },
#    {
#      enabled                        = true
#      prefix                         = "processed_data/tmp"
#      expirations                    = [{ days = 5 }]
#      noncurrent_version_expirations = [{ days = 5 }]
#    }
#
#  ]
#
#  object_ownership = "ObjectWriter"
#
#  tags_kms = {
#    ApplicationID = "demo_onetom_fast_track"
#    ProjectID     = "demo"
#  }
#
#  tags_s3 = {
#    ApplicationID = "demo_onetom_fast_track"
#    ProjectID     = "demo"
#    ModuleName    = "demo-${var.stage}-fsag_target_data_bucket"
#  }
#
#
#  git_repository              = var.git_repository
#  attach_custom_bucket_policy = true
#  policy                      = data.aws_iam_policy_document.fsag_target_data_bucket_policy_document.json
#  kms_policy_to_attach        = data.aws_iam_policy_document.fsag_Kms_Key_policy.json
#}
#
#########################################################################################################################
####  Fast track target  data Bucket Policy
#########################################################################################################################
#
#data "aws_iam_policy_document" "fsag_target_data_bucket_policy_document" {
#
#  statement {
#    sid    = "EnforceSSLFSAGBucket"
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
#    resources = ["${module.fsag_target_data_bucket.s3_arn}/*"]
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
#      type = "AWS"
#      identifiers = [
#        "arn:aws:iam::${local.account_id}:root"
#      ]
#    }
#
#    condition {
#      test = "ArnLike"
#      values = concat(local.access_arns,
#        !local.in_production ? [module.fsag_cap_pull_lambda.aws_lambda_function_role_arn] : [],
#        [
#          data.terraform_remote_state.cap_default.outputs.cap_redshift_cluster_base_role_arn,
#          data.aws_iam_role.PA_CAS_demo_DATA_SCIENTIST.arn,
#          data.aws_iam_role.PA_CAP_demo_DATA_SCIENTIST.arn,
#      ])
#      variable = "aws:PrincipalArn"
#    }
#    resources = [
#      "${module.fsag_target_data_bucket.s3_arn}/*",
#      module.fsag_target_data_bucket.s3_arn
#    ]
#  }
#}
