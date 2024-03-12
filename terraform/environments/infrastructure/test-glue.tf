########################################################################################################################
### Upload main Glue Job script
########################################################################################################################
resource "aws_s3_object" "glue_script" {
  count          = local.in_production ? 0 : 1 #local.count_in_default
  bucket         = module.glue_scripts_bucket.s3_bucket
  key            = "artifact/${module.generic_labels.resource["glue-job"]["id"]}/main.py"
  content_base64 = filebase64("${path.module}/../../../etl/glue/demo_glue/main.py")

  tags = {
    ProjectID = var.project
  }
}


########################################################################################################################
### Test Glue job
########################################################################################################################
module "test_glue_job" {
  enable = true

  depends_on = [
    aws_s3_object.glue_script,
  ]

  source = "git::ssh://git@github.com/Mohamed-Amine-Dogui/tf-module-aws-glue-job.git?ref=tags/0.0.1"


  stage          = var.stage
  project        = var.project
  project_id     = var.project
  git_repository = var.git_repository

  #account_id             = data.aws_caller_identity.current.account_id
  region                 = var.aws_region
  job_name               = "etl-glue"
  glue_version           = "4.0"
  glue_number_of_workers = 2
  worker_type            = "G.1X"
  #connections               = local.in_production ? [""] : [aws_glue_connection.cc_redshift_conn[0].name]
  script_bucket             = module.glue_scripts_bucket.s3_bucket
  glue_job_local_path       = "${path.module}/../../../etl/glue/demo_glue/main.py"
  extra_py_files_source_dir = "${path.module}/../../../etl/glue/demo_glue/"
  create_kms_key            = false

  // This attribute is called like this in the module but we need to retreive the KMS-key of the Target bucket where it will write the files after processing
  target_bucket_kms_key_arn = module.glue_data_bucket.aws_kms_key_arn

  tags_kms = {
    ProjectID = "demo"
  }

  tags_role = {
    ProjectID = "demo"
  }

  default_arguments = {
    // Glue Native
    "--job-language"                     = "python"
    "--TempDir"                          = "s3://${module.glue_scripts_bucket.s3_bucket}/glue-job-tmp/"
    "--region"                           = var.aws_region
    "--enable-metrics"                   = ""
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-glue-datacatalog"          = "" # Spark will use Glue Catalog as Hive Metastore
    "--job-bookmark-option"              = "job-bookmark-enable"

    // User defined
    "--TARGET_BUCKET_NAME" = module.glue_data_bucket.s3_bucket
    "--STAGE"              = var.stage

  }

  timeout                  = 45
  enable_additional_policy = true
  additional_policy        = data.aws_iam_policy_document.glue_job_permissions.json
}


########################################################################################################################
###  cc glue job permissions
########################################################################################################################

data "aws_iam_policy_document" "glue_job_permissions" {
  statement {
    sid     = "AllowReadFromScriptBucket"
    effect  = "Allow"
    actions = ["s3:Get*", "s3:List*"]
    resources = [
      module.glue_scripts_bucket.s3_arn,
      "${module.glue_scripts_bucket.s3_arn}/*"
    ]
  }


  statement {
    sid    = "AllowReadWriteToBucket"
    effect = "Allow"
    actions = [
      "s3:Get*",
      "s3:Put*",
      "s3:Describe*",
      "s3:Delete*",
      "s3:RestoreObject",
      "s3:List*"
    ]
    resources = [
      module.glue_data_bucket.s3_arn,
      "${module.glue_data_bucket.s3_arn}/*",
    ]
  }

  statement {
    sid    = "AllowDecryptEncryptToBuckets"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:ReEncrypt*",
      "kms:ListKeys",
      "kms:Describe*"
    ]
    resources = [
      module.glue_scripts_bucket.aws_kms_key_arn,
      module.glue_data_bucket.aws_kms_key_arn,
    ]
  }

  statement {
    sid    = "AllowLogging"
    effect = "Allow"
    #checkov:skip=CKV_AWS_111:Skip reason - Resource not known before apply
    actions = [
      "logs:AssociateKmsKey",
      "logs:CreateLogGroup",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
      "logs:CreateLogStream"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    #checkov:skip=CKV_AWS_111:Skip reason - Resource not known before apply
    actions = [
      "ec2:DescribeNetworkInterfaces",
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
    ]

    resources = ["*"]
  }
}
