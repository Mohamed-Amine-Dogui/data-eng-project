
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
  ]

  encrypt_decrypt_arns = [
    data.aws_caller_identity.current.arn,
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
  statement {
    sid    = "Allow Describe KMS Key"
    effect = "Allow"
    actions = [
      "kms:DescribeKey",
      "kms:GetKeyPolicy",
      "kms:ListResourceTags",
      "kms:GetKeyRotationStatus",
      "kms:Delete*"
    ]
    resources = ["*"]
    principals {
      identifiers = [
        data.aws_caller_identity.current.arn,
        "arn:aws:iam::683603511960:user/dogui",
        "arn:aws:iam::683603511960:root"
      ]
      type = "AWS"
    }
  }

}
