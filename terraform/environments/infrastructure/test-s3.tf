########################################################################################################################
#### Bucket for the logs
########################################################################################################################
module "logs_bucket" {
  #checkov:skip=CKV_TF_1:Skip reason
  enable = true
  source = "git::ssh://git@github.com/Mohamed-Amine-Dogui/tf-module-aws-s3-bucket//s3/s3-encrypted?ref=tags/0.0.1"

  environment                       = var.stage
  project                           = var.project
  s3_bucket_name                    = "my-test-log-bucket"
  s3_bucket_acl                     = "log-delivery-write"
  object_ownership                  = "ObjectWriter"
  versioning_enabled                = false
  transition_lifecycle_rule_enabled = false
  expiration_lifecycle_rule_enabled = false
  enforce_SSL_encryption_policy     = false
  use_aes256_encryption             = true
  force_destroy                     = local.in_development
  kst                               = var.tag_KST
  wa_number                         = var.wa_number
  git_repository                    = var.git_repository

  attach_custom_bucket_policy = true
  policy                      = data.aws_iam_policy_document.log_bucket_policy_document.json
  kms_policy_to_attach        = data.aws_iam_policy_document.test_kms_key_policy.json
}


########################################################################################################################
###  Log Bucket Policy
########################################################################################################################

data "aws_iam_policy_document" "log_bucket_policy_document" {

  statement {
    sid    = "EnforceSSL"
    effect = "Deny"

    actions = ["s3:*"]


    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }

    resources = ["${module.logs_bucket.s3_arn}/*"]
  }


  statement {
    sid    = "AllwOnlyThisArns"
    effect = "Allow"

    actions = ["s3:*"]

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${local.account_id}:root"
      ]
    }

    condition {
      test = "ArnLike"
      values = concat(local.access_arns,
        !local.in_production ? [data.aws_caller_identity.current.arn] : [],
        [
          data.aws_caller_identity.current.arn
      ])
      variable = "aws:PrincipalArn"
    }
    resources = [
      "${module.logs_bucket.s3_arn}/*",
      module.logs_bucket.s3_arn
    ]
  }
}

#########################################################################################################################
####   Bucket for Lambda deployment
#########################################################################################################################
#module "source_code_bucket" {
#  source = "git::ssh://git@github.com/Mohamed-Amine-Dogui/tf-module-aws-s3-bucket//s3/s3-logging-encrypted?ref=tags/0.0.1"
#
#  enable                        = true
#  environment                   = var.stage
#  project                       = var.project
#  s3_bucket_name                = "my-test-source-code-bucket"
#  s3_bucket_acl                 = "private"
#  target_bucket_id              = module.logs_bucket.s3_bucket
#  versioning_enabled            = true
#  enforce_SSL_encryption_policy = true
#  force_destroy                 = local.in_development
#  kst                           = var.tag_KST
#  wa_number                     = var.wa_number
#  git_repository                = "github.com/Mohamed-Amine-Dogui/data-eng-project"
#
#}
#
#
########################################################################################################################
###   Bucket for glue scripts
########################################################################################################################
module "glue_scripts_bucket" {
  source = "git::ssh://git@github.com/Mohamed-Amine-Dogui/tf-module-aws-s3-bucket//s3/s3-logging-encrypted?ref=tags/0.0.1"

  enable                        = true
  environment                   = var.stage
  project                       = var.project
  s3_bucket_name                = "glue-scripts-bucket"
  s3_bucket_acl                 = "private"
  target_bucket_id              = module.logs_bucket.s3_bucket
  versioning_enabled            = true
  enforce_SSL_encryption_policy = true
  force_destroy                 = local.in_development
  kst                           = var.tag_KST
  wa_number                     = var.wa_number
  git_repository                = "github.com/Mohamed-Amine-Dogui/data-eng-project"

}

########################################################################################################################
###   Bucket for glue data
########################################################################################################################
module "glue_data_bucket" {

  #checkov:skip=CKV_TF_1:Skip reason
  enable = true
  source = "git::ssh://git@github.com/Mohamed-Amine-Dogui/tf-module-aws-s3-bucket//s3/s3-encrypted?ref=tags/0.0.1"

  depends_on = [
    module.test_kms_key
  ]

  environment                       = var.stage
  project                           = var.project
  git_repository                    = var.git_repository
  s3_bucket_name                    = "glue-data-bucket"
  s3_bucket_acl                     = "private"
  object_ownership                  = "ObjectWriter"
  versioning_enabled                = false
  transition_lifecycle_rule_enabled = false
  expiration_lifecycle_rule_enabled = false
  enforce_SSL_encryption_policy     = false
  use_aes256_encryption             = false
  force_destroy                     = local.in_development
  kst                               = var.tag_KST
  wa_number                         = var.wa_number
  create_kms_key                    = false
  kms_key_arn                       = module.test_kms_key.kms_key_arn


  attach_custom_bucket_policy = true
  policy                      = data.aws_iam_policy_document.glue_data_bucket_policy_document.json
  kms_policy_to_attach        = data.aws_iam_policy_document.test_kms_key_policy.json
}

########################################################################################################################
###  Glue Data Bucket Policy
########################################################################################################################

data "aws_iam_policy_document" "glue_data_bucket_policy_document" {

  statement {
    sid    = "EnforceSSL"
    effect = "Deny"

    actions = ["s3:*"]


    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }

    resources = ["${module.glue_data_bucket.s3_arn}/*"]
  }

  statement {
    sid    = "AllwOnlyThisArns"
    effect = "Allow"

    actions = ["s3:*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test = "ArnLike"
      values = concat(local.access_arns,
        !local.in_production ? [data.aws_caller_identity.current.arn] : [],
        [
          data.aws_caller_identity.current.arn,
          "arn:aws:iam::683603511960:user/dogui",
          "arn:aws:iam::683603511960:root",
          module.test_glue_job.iam_role_arn,
      ])
      variable = "aws:PrincipalArn"
    }
    resources = [
      "${module.glue_data_bucket.s3_arn}/*",
      module.glue_data_bucket.s3_arn
    ]
  }
}
