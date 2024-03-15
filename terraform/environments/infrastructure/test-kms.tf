
########################################################################################################################
###  KMS Key
########################################################################################################################

module "test_kms_key" {
  source = "git::ssh://git@github.com/Mohamed-Amine-Dogui/tf-module-aws-kms-key.git?ref=tags/0.0.1"

  enable = true

  enable_config_recorder = false

  description = "Test KMS Key"

  git_repository = var.git_repository
  project        = var.project
  project_id     = var.project_id
  stage          = var.stage
  name           = "test_key"

  additional_tags = {
    ProjectID = "demo"
  }

  key_admins = [
    data.aws_caller_identity.current.arn,
    "arn:aws:iam::${local.account_id}:root",
    "arn:aws:iam::${local.account_id}:user/dogui",
  ]

  encrypt_decrypt_arns = [
    data.aws_caller_identity.current.arn,
    "arn:aws:iam::${local.account_id}:root",
    "arn:aws:iam::${local.account_id}:user/dogui",
  ]

  aws_service_configurations = [
    {
      simpleName  = "Logs"
      identifiers = ["logs.${var.aws_region}.amazonaws.com"]
      values      = ["arn:aws:logs:${var.aws_region}:${local.account_id}:*"]
      variable    = "kms:EncryptionContext:aws:logs:arn"
    }
  ]
  custom_policy = data.aws_iam_policy_document.test_kms_key_policy.json
}

########################################################################################################################
###  KMS Key policy document
########################################################################################################################
data "aws_iam_policy_document" "test_kms_key_policy" {

  #checkov:skip=CKV_AWS_111:Skip reason
  #checkov:skip=CKV_AWS_109:Skip reason
  statement {
    sid       = "Enable IAM User Permissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      identifiers = [
        data.aws_caller_identity.current.arn,
        "arn:aws:iam::${local.account_id}:root",
        "arn:aws:iam::${local.account_id}:user/dogui",
      ]
      type = "AWS"
    }
  }

  statement {
    sid    = "Allow administration of the key"
    effect = "Allow"
    actions = [
      "kms:Create*",
      "kms:Describe*",
      "kms:Enable*",
      "kms:List*",
      "kms:Put*",
      "kms:Update*",
      "kms:Revoke*",
      "kms:Disable*",
      "kms:Get*",
      "kms:Delete*",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion",
      "kms:DeleteImportedKeyMaterial"
    ]
    resources = ["*"]
    principals {
      identifiers = [
        data.aws_caller_identity.current.arn,
        "arn:aws:iam::${local.account_id}:root",
        "arn:aws:iam::${local.account_id}:user/dogui",
      ]
      type = "AWS"
    }
  }

  statement {
    sid    = "Allow AWS Glue to use the key"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
    principals {
      identifiers = ["glue.amazonaws.com"]
      type        = "Service"
    }
  }

  statement {
    sid    = "Allow AWS Lambda to use the key"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
    principals {
      identifiers = ["arn:aws:lambda:${var.aws_region}:${local.account_id}:function:${var.redshift_schema_lambda_unique_function_name}"]
      type        = "AWS"
    }
  }

  statement {
    sid    = "Allow AWS S3 to use the key"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
    principals {
      identifiers = ["s3.amazonaws.com"]
      type        = "Service"
    }
  }

}
