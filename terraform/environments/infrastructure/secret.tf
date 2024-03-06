#########################################################################################################################
####  MMO Secrets
#########################################################################################################################
#resource "aws_secretsmanager_secret" "lot_api_token" {
#  name                    = module.mmo_labels.resource["lot-api-token"]["id"]
#  description             = "token of api to pull lot data"
#  recovery_window_in_days = 0
#
#  policy = data.aws_iam_policy_document.mmo_secrets_manager_policy.json
#
#  tags = {
#    ApplicationID = "demo_onetom_mmo"
#    ProjectID     = "demo"
#    ModuleName    = "${var.project}-${var.stage}-lot_api_token-secret"
#  }
#
#}
#
#########################################################################################################################
####  mmo secret in secret manager policy document
#########################################################################################################################
#
#data "aws_iam_policy_document" "mmo_secrets_manager_policy" {
#  /*
#https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html
# checkov:skip=CKV_AWS_111:Skip reason - DescribeStatement requires (*) in the policy. See the link below for more information:
# checkov:skip=CKV_AWS_107:Skip reason - Credentials are not suspended.
# checkov:skip=CKV_AWS_108: IAM policies does not allow data exfiltration
# checkov:skip=CKV_AWS_109: IAM policies does not allow permissions management / resource exposure without constraints
#Source: https://docs.aws.amazon.com/kms/latest/developerguide/kms-api-permissions-reference.html
#*/
#
#  statement {
#    sid     = "AllwOnlyThisArns"
#    effect  = "Allow"
#    actions = ["secretsmanager:*"]
#    principals {
#      identifiers = ["*"]
#      type        = "AWS"
#    }
#    condition {
#      test = "ArnLike"
#      values = concat(local.access_arns, [
#      ])
#      variable = "aws:PrincipalArn"
#    }
#    resources = ["*"]
#  }
#
#}
#
#
#
#
#########################################################################################################################
####  OKM OEM MOD Secrets
#########################################################################################################################
#
#resource "aws_secretsmanager_secret" "salesforce_user_name" {
#  name                    = module.okm_oem_labels.resource["secret-salesforce-user-name"]["id"]
#  recovery_window_in_days = 0
#  policy                  = data.aws_iam_policy_document.okm_oem_mod_secrets_manager_policy.json
#
#  tags = {
#    ApplicationID = "demo_onetom_okm_oem"
#    ProjectID     = "demo"
#    ModuleName    = "${var.project}-${var.stage}-salesforce_user_name-secret"
#  }
#}
#
#resource "aws_secretsmanager_secret" "salesforce_pwd" {
#  name                    = module.okm_oem_labels.resource["secret-salesforce-pwd"]["id"]
#  recovery_window_in_days = 0
#  policy                  = data.aws_iam_policy_document.okm_oem_mod_secrets_manager_policy.json
#
#  tags = {
#    ApplicationID = "demo_onetom_okm_oem"
#    ProjectID     = "demo"
#    ModuleName    = "${var.project}-${var.stage}-salesforce_pwd-secret"
#  }
#}
#
#resource "aws_secretsmanager_secret" "salesforce_token" {
#  name                    = module.okm_oem_labels.resource["secret-salesforce-token"]["id"]
#  recovery_window_in_days = 0
#  policy                  = data.aws_iam_policy_document.okm_oem_mod_secrets_manager_policy.json
#
#  tags = {
#    ApplicationID = "demo_onetom_okm_oem"
#    ProjectID     = "demo"
#    ModuleName    = "${var.project}-${var.stage}-salesforce_token-secret"
#  }
#}
#
#########################################################################################################################
####  pde_automatic_subscription secret in secret manager policy document
#########################################################################################################################
#
#data "aws_iam_policy_document" "okm_oem_mod_secrets_manager_policy" {
#  /*
#https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html
# checkov:skip=CKV_AWS_111:Skip reason - DescribeStatement requires (*) in the policy. See the link below for more information:
# checkov:skip=CKV_AWS_107:Skip reason - Credentials are not suspended.
# checkov:skip=CKV_AWS_108: IAM policies does not allow data exfiltration
# checkov:skip=CKV_AWS_109: IAM policies does not allow permissions management / resource exposure without constraints
#Source: https://docs.aws.amazon.com/kms/latest/developerguide/kms-api-permissions-reference.html
#*/
#
#  statement {
#    sid     = "AllwOnlyThisArns"
#    effect  = "Allow"
#    actions = ["secretsmanager:*"]
#    principals {
#      identifiers = ["*"]
#      type        = "AWS"
#    }
#    condition {
#      test = "ArnLike"
#      values = concat(local.access_arns, [
#      ])
#      variable = "aws:PrincipalArn"
#    }
#    resources = ["*"]
#  }
#
#}
#
#
#########################################################################################################################
####  pde_automatic_subscription secret in secret manager policy document
#########################################################################################################################
#
#data "aws_iam_policy_document" "pde_automatic_subscription_secrets_manager_policy" {
#  /*
#https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html
# checkov:skip=CKV_AWS_111:Skip reason - DescribeStatement requires (*) in the policy. See the link below for more information:
# checkov:skip=CKV_AWS_107:Skip reason - Credentials are not suspended.
# checkov:skip=CKV_AWS_108: IAM policies does not allow data exfiltration
# checkov:skip=CKV_AWS_109: IAM policies does not allow permissions management / resource exposure without constraints
#Source: https://docs.aws.amazon.com/kms/latest/developerguide/kms-api-permissions-reference.html
#*/
#
#  statement {
#    sid     = "AllwOnlyThisArns"
#    effect  = "Allow"
#    actions = ["secretsmanager:*"]
#    principals {
#      identifiers = ["*"]
#      type        = "AWS"
#    }
#    condition {
#      test = "ArnLike"
#      values = concat(local.access_arns, [
#      ])
#      variable = "aws:PrincipalArn"
#    }
#    resources = ["*"]
#  }
#
#}
#


#data "aws_iam_policy_document" "demo_notebook_user_policy" {
#  /*
#https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html
# checkov:skip=CKV_AWS_111:Skip reason - DescribeStatement requires (*) in the policy. See the link below for more information:
# checkov:skip=CKV_AWS_107:Skip reason - Credentials are not suspended.
# checkov:skip=CKV_AWS_108: IAM policies does not allow data exfiltration
# checkov:skip=CKV_AWS_109: IAM policies does not allow permissions management / resource exposure without constraints
#Source: https://docs.aws.amazon.com/kms/latest/developerguide/kms-api-permissions-reference.html
#*/
#
#  statement {
#    sid     = "AllwOnlyThisArns"
#    effect  = "Allow"
#    actions = ["secretsmanager:*"]
#    principals {
#      identifiers = ["*"]
#      type        = "AWS"
#    }
#    condition {
#      test = "ArnLike"
#      values = concat(local.access_arns, [
#        module.prepare_data_notebook.ni_aws_iam_role_arn
#      ])
#      variable = "aws:PrincipalArn"
#    }
#    resources = ["*"]
#  }
#
#}
#
#resource "aws_secretsmanager_secret" "ro_demo_notebook_user_pw" {
#  name                    = module.generic_labels.resource["notebook_user_pw"]["id"]
#  description             = "password to ro_demo_notebook_user"
#  recovery_window_in_days = 0
#
#  policy = data.aws_iam_policy_document.demo_notebook_user_policy.json
#
#}
