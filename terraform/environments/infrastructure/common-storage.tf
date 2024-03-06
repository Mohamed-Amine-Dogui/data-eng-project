#########################################################################################################################
##### Bucket for the logs
#########################################################################################################################
#module "logs_bucket" {
#  enable = true #!local.in_production #local.in_default_workspace
#
#  source                            = "git::ssh://cap-tf-module-aws-s3-bucket/vwdfive/cap-tf-module-aws-s3-bucket//s3/s3-encrypted?ref=tags/0.5.0"
#  environment                       = var.stage
#  project                           = var.project
#  s3_bucket_name                    = var.s3_bucket_log
#  s3_bucket_acl                     = "log-delivery-write"
#  object_ownership                  = "ObjectWriter"
#  versioning_enabled                = false
#  transition_lifecycle_rule_enabled = false
#  expiration_lifecycle_rule_enabled = false
#  enforce_SSL_encryption_policy     = false
#  use_aes256_encryption             = true
#  force_destroy                     = local.in_development
#  kst                               = var.tag_KST
#  wa_number                         = var.wa_number
#  git_repository                    = var.git_repository
#
#  tags_kms = {
#    ApplicationID = "demo_onetom_generic"
#    ProjectID     = "demo"
#    ModuleName    = "demo-${var.stage}-logs_bucket"
#  }
#
#  tags_s3 = {
#    ApplicationID = "demo_onetom_generic"
#    ProjectID     = "demo"
#    ModuleName    = "demo-${var.stage}-logs_bucket"
#  }
#}
#
#data "aws_iam_policy_document" "allow_alb_logs" {
#  count = module.logs_bucket.enabled ? 1 : 0
#  statement {
#    effect    = "Deny"
#    actions   = ["s3:*"]
#    resources = ["${module.logs_bucket.s3_arn}/*"]
#    principals {
#      type        = "AWS"
#      identifiers = ["*"]
#    }
#    condition {
#      test     = "Bool"
#      variable = "aws:SecureTransport"
#      values   = ["false"]
#    }
#  }
#
#  statement {
#    effect = "Allow"
#    principals {
#      identifiers = ["arn:aws:iam::${var.alb_account_id[var.aws_region]}:root"]
#      type        = "AWS"
#    }
#    actions   = ["s3:PutObject"]
#    resources = ["${module.logs_bucket.s3_arn}/*"]
#  }
#
#  statement {
#    effect = "Allow"
#    principals {
#      identifiers = ["delivery.logs.amazonaws.com"]
#      type        = "Service"
#    }
#    actions   = ["s3:PutObject"]
#    resources = ["${module.logs_bucket.s3_arn}/*"]
#    condition {
#      test     = "StringEquals"
#      values   = ["bucket-owner-full-control"]
#      variable = "s3:x-amz-acl"
#    }
#  }
#
#  statement {
#    effect = "Allow"
#    principals {
#      identifiers = ["delivery.logs.amazonaws.com"]
#      type        = "Service"
#    }
#    actions   = ["s3:GetBucketAcl"]
#    resources = [module.logs_bucket.s3_arn]
#  }
#}
#
#resource "aws_s3_bucket_policy" "allow_alb_logs" {
#  depends_on = [module.logs_bucket]
#  count      = module.logs_bucket.enabled ? 1 : 0
#
#  bucket = module.logs_bucket.s3_id
#  policy = data.aws_iam_policy_document.allow_alb_logs[count.index].json
#}
#########################################################################################################################
####  S3 Bucket for Glue Scripts
#########################################################################################################################
#module "demo_glue_scripts_bucket" {
#  enable = true #!local.in_production # local.in_default_workspace
#
#  source                            = "git::ssh://cap-tf-module-aws-s3-bucket/vwdfive/cap-tf-module-aws-s3-bucket//s3/s3-encrypted?ref=tags/0.5.2"
#  environment                       = var.stage
#  project                           = var.project
#  s3_bucket_name                    = var.demo_glue_scripts_s3_bucket_name
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
#  object_ownership = "ObjectWriter"
#
#  tags_kms = {
#    ApplicationID = "demo_onetom_generic"
#    ProjectID     = "demo"
#  }
#
#  tags_s3 = {
#    ApplicationID = "demo_onetom_generic"
#    ProjectID     = "demo"
#    ModuleName    = "demo-${var.stage}-demo_glue_scripts_bucket"
#  }
#
#  git_repository              = var.git_repository
#  attach_custom_bucket_policy = true
#  policy                      = data.aws_iam_policy_document.demo_glue_scripts_bucket_policy_document.json
#  kms_policy_to_attach        = data.aws_iam_policy_document.demo_glue_scripts_Kms_Key_policy.json
#
#}
#data "aws_iam_policy_document" "demo_glue_scripts_bucket_policy_document" {
#
#  statement {
#    sid    = "DenyAllExcept"
#    effect = "Deny"
#
#    actions = ["s3:*"]
#
#    principals {
#      type        = "AWS"
#      identifiers = ["*"]
#    }
#
#    condition {
#      test = "ArnNotLike"
#      values = concat(local.access_arns,
#        local.in_development ? [module.onecrm_campaign_cockpit_glue_job.iam_role_arn] : [],
#        [
#          module.fstream_glue_job.iam_role_arn,
#          data.aws_iam_role.PA_CAS_demo_DATA_SCIENTIST.arn,
#          data.aws_iam_role.PA_CAP_demo_DATA_SCIENTIST.arn,
#      ])
#      variable = "aws:PrincipalArn"
#    }
#    resources = [
#      "${module.demo_glue_scripts_bucket.s3_arn}/*",
#      module.demo_glue_scripts_bucket.s3_arn
#    ]
#  }
#}
#
#
#data "aws_iam_policy_document" "demo_glue_scripts_Kms_Key_policy" {
#  /*
#https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html
#checkov:skip=CKV_AWS_111:Skip reason - DescribeStatement requires (*) in the policy.
#checkov:skip=CKV_AWS_109:Skip reason - IAM policies does not exposure resource without constraints"
#See the link below for more information:
#Source: https://docs.aws.amazon.com/kms/latest/developerguide/kms-api-permissions-reference.html
#*/
#  statement {
#    sid    = "DenyAllExcept"
#    effect = "Allow"
#
#    actions = ["kms:*"]
#
#    principals {
#      type        = "AWS"
#      identifiers = ["*"]
#    }
#
#    condition {
#      test = "ArnLike"
#      values = concat(local.access_arns,
#        local.in_development ? [module.onecrm_campaign_cockpit_glue_job.iam_role_arn] : [],
#        [
#          module.fstream_glue_job.iam_role_arn,
#          data.aws_iam_role.PA_CAS_demo_DATA_SCIENTIST.arn,
#          data.aws_iam_role.PA_CAP_demo_DATA_SCIENTIST.arn,
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
#}
#
###########################################################################################################################
####   Bucket for Lambda deployment
#########################################################################################################################
#module "source_code_bucket" {
#  source = "git::ssh://cap-tf-module-aws-s3-bucket/vwdfive/cap-tf-module-aws-s3-bucket//s3/s3-logging-encrypted?ref=tags/0.5.0"
#
#  enable                        = true #!local.in_production
#  environment                   = var.stage
#  project                       = var.project
#  s3_bucket_name                = var.s3_bucket_source_code
#  s3_bucket_acl                 = "private"
#  target_bucket_id              = module.logs_bucket.s3_bucket
#  versioning_enabled            = true
#  enforce_SSL_encryption_policy = true
#  force_destroy                 = local.in_development
#  kst                           = var.tag_KST
#  wa_number                     = var.wa_number
#  git_repository                = "github.com/Mohamed-Amine-Dogui/data-eng-project"
#
#  tags_kms = {
#    ApplicationID = "demo_onetom_generic"
#    ProjectID     = "demo"
#  }
#
#  tags_s3 = {
#    ApplicationID = "demo_onetom_generic"
#    ProjectID     = "demo"
#    ModuleName    = "demo-${var.stage}-source_code_bucket"
#  }
#}
