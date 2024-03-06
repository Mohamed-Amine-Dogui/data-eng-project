#data "aws_iam_policy_document" "prepare_data_notebook_policy" {
#  statement {
#    effect = "Allow"
#
#    actions = [
#      "s3:GetBucketLocation",
#      "s3:ListAllMyBuckets",
#    ]
#
#    resources = ["*", ]
#  }
#
#  statement {
#    sid    = "AllowAccessTodemoBucket"
#    effect = "Allow"
#    actions = [
#      "s3:Get*",
#      "s3:List*",
#      "s3:Describe*",
#      "s3:PutObject",
#      "s3:RestoreObject"
#    ]
#    resources = [
#      "arn:aws:s3:::*demo*",
#      "arn:aws:s3:::*demo*/*",
#    ]
#  }
#  statement {
#    effect = "Allow"
#
#    actions = [
#      "kms:ListKeys",
#      "kms:Encrypt",
#      "kms:Decrypt",
#      "kms:DescribeKey",
#      "kms:GenerateDataKey",
#    ]
#
#    resources = compact([
#      "arn:aws:s3:::*demo*",
#    ])
#  }
#
#  statement {
#    sid    = "AllowSageMakerToAcessS3"
#    effect = "Allow"
#    actions = [
#      "s3:Get*",
#      "s3:List*",
#      "s3:Describe*",
#      "s3:PutObject",
#      "s3:RestoreObject",
#    ]
#    resources = [
#      "arn:aws:s3:::*demo*",
#      "arn:aws:s3:::*demo*/*",
#    ]
#  }
#
#  statement {
#    sid    = "AllowAccessToParameterStoreForLotApiToken"
#    effect = "Allow"
#    actions = [
#      "ssm:GetParameter*",
#      "ssm:DescribeParameter*",
#    ]
#    resources = concat([
#    data.terraform_remote_state.cap_default.outputs.redshift_lambda_db_password_ssm_arn])
#  }
#
#  /*
#https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html
#checkov:skip=CKV_AWS_111:Skip reason - DescribeStatement requires (*) in the policy. See the link below for more information:
#checkov:skip=CKV_AWS_107:Skip reason - Credentials are not suspended.
#Source: https://docs.aws.amazon.com/kms/latest/developerguide/kms-api-permissions-reference.html
#*/
#  statement {
#    effect = "Allow"
#    sid    = "RetrieveSecrets"
#    actions = [
#      "secretsmanager:DescribeSecret",
#      "secretsmanager:GetSecretValue",
#    ]
#    resources = [
#      aws_secretsmanager_secret.ro_demo_notebook_user_pw.arn,
#    ]
#  }
#
#  statement {
#    sid    = "AllowNotebookDecryptParameter"
#    effect = "Allow"
#    actions = [
#      "kms:ListKeys",
#      "kms:Encrypt",
#      "kms:Decrypt",
#      "kms:DescribeKey",
#    ]
#
#    resources = concat([
#      data.terraform_remote_state.cap_default.outputs.redshift_lambda_db_password_ssm_arn,
#      data.terraform_remote_state.cap_default.outputs.redshift_secrets_key_arn
#    ])
#
#  }
#  /*
#https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html
#checkov:skip=CKV_AWS_111:Skip reason - DescribeStatement requires (*) in the policy. See the link below for more information:
#checkov:skip=CKV_AWS_107:Skip reason - Credentials are not suspended.
#Source: https://docs.aws.amazon.com/kms/latest/developerguide/kms-api-permissions-reference.html
#*/
#  statement {
#
#    sid    = "AllowTriggerRedshiftQuery"
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
#}
#
#########################################################################################################################
####  KMS Key Policy for notebook bucket
#########################################################################################################################
#data "aws_iam_policy_document" "notebook_data_Kms_Key_policy" {
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
#          data.terraform_remote_state.cap_default.outputs.cap_redshift_cluster_base_role_arn,
#          module.prepare_data_notebook.ni_aws_iam_role_arn,
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
####  notebook  data Bucket Policy
#########################################################################################################################
#
#data "aws_iam_policy_document" "notebook_data_bucket_policy_document" {
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
#    resources = ["${module.notebook_storage.s3_arn}/*"]
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
#        [
#          module.prepare_data_notebook.ni_aws_iam_role_arn,
#          data.terraform_remote_state.cap_default.outputs.cap_redshift_cluster_base_role_arn,
#          data.aws_iam_role.PA_CAP_demo_DATA_SCIENTIST.arn,
#      ])
#      variable = "aws:PrincipalArn"
#    }
#    resources = [
#      "${module.notebook_storage.s3_arn}/*",
#      module.notebook_storage.s3_arn
#    ]
#  }
#}
#
###########################################################################################################################
####   Bucket for notebook storage deployment
#########################################################################################################################
#module "notebook_storage" {
#  source = "git::ssh://cap-tf-module-aws-s3-bucket/vwdfive/cap-tf-module-aws-s3-bucket//s3/s3-encrypted?ref=tags/0.5.2"
#
#  enable                        = true #!local.in_production
#  environment                   = var.stage
#  project                       = var.project
#  s3_bucket_name                = "notebook-storage"
#  s3_bucket_acl                 = "private"
#  versioning_enabled            = true
#  enforce_SSL_encryption_policy = true
#  use_aes256_encryption         = false #if set to true, it don't allow the creation of a kms key and in our policy we use kms so it must be set to false
#  force_destroy                 = local.in_development
#  kst                           = var.tag_KST
#  wa_number                     = var.wa_number
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
#    ModuleName    = "demo-${var.stage}-notebook_data_bucket"
#  }
#
#  git_repository              = var.git_repository
#  attach_custom_bucket_policy = true
#  policy                      = data.aws_iam_policy_document.notebook_data_bucket_policy_document.json
#  kms_policy_to_attach        = data.aws_iam_policy_document.notebook_data_Kms_Key_policy.json
#}
#
#########################################################################################################################
## This notebook will be deployed in prd
#########################################################################################################################
#
#module "prepare_data_notebook" {
#  enable     = true
#
#  source                   = "git::ssh://cap-tf-module-aws-sagemaker/vwdfive/cap-tf-module-aws-sagemaker?ref=tags/0.3.6"
#  region                   = var.aws_region
#  stage                    = var.stage
#  project                  = var.project
#  sagemaker_notebook_name  = "prepare-data-notebook"
#  instance_type            = var.ds_notebook_instance_type[var.stage]
#  disk_size                = "20"
#  root_access_enabled      = false
#  vpc_id                   = data.terraform_remote_state.cap_default.outputs.vpc_id_gen_2
#  subnet_id                = element(data.terraform_remote_state.cap_default.outputs.private_subnet_ids_gen_2, 1)
#  external_security_groups = var.redshift_security_group[var.stage]
#  #create_sagemaker_unique_sg = true
#  additional_policy      = data.aws_iam_policy_document.prepare_data_notebook_policy.json
#  direct_internet_access = false # set to false to use the VPC's networking
#  platform_identifier    = "notebook-al2-v1"
#
#  kst       = var.tag_KST
#  wa_number = var.wa_number
#  on_start_script = templatefile("${path.module}/../../templates/notebook_on_startup_script.sh", {
#    requirements      = file("${path.module}/../../../tests/requirements.txt"),
#    notebook_contents = ""
#  })
#
#  tags_kms = {
#    ApplicationID = "demo_onetom_generic"
#    ProjectID     = "demo"
#    ModuleName    = "${var.project}-${var.stage}-prepare_data_notebook-kms"
#
#  }
#
#  tags_sm = {
#    ApplicationID = "demo_onetom_generic"
#    ProjectID     = "demo"
#    ModuleName    = "${var.project}-${var.stage}-prepare_data_notebook"
#  }
#
#}
