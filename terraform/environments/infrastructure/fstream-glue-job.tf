#########################################################################################################################
####  fstream glue job permissions
#########################################################################################################################
#
#data "aws_iam_policy_document" "fstream_glue_job_permissions" {
#  statement {
#    sid     = "AllowReadFromScriptBucket"
#    effect  = "Allow"
#    actions = ["s3:Get*", "s3:List*"]
#    resources = [
#      module.demo_glue_scripts_bucket.s3_arn,
#      "${module.demo_glue_scripts_bucket.s3_arn}/*"
#    ]
#  }
#
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
#
#
#  statement {
#    sid    = "AllowReadWriteToBucket"
#    effect = "Allow"
#    actions = [
#      "s3:Get*",
#      "s3:Put*",
#      "s3:Describe*",
#      "s3:Delete*",
#      "s3:RestoreObject",
#      "s3:List*",
#    ]
#    resources = [
#      module.fstream_api_data_bucket.s3_arn,
#      "${module.fstream_api_data_bucket.s3_arn}/*",
#      "arn:aws:s3:::demo-prd-fstream-api-data-bucket",
#      "arn:aws:s3:::demo-prd-fstream-api-data-bucket/*"
#    ]
#  }
#
#  statement {
#    sid    = "AllowDecryptEncryptToBuckets"
#    effect = "Allow"
#    actions = [
#      "kms:*",
#      "kms:Decrypt",
#      "kms:Encrypt",
#      "kms:GenerateDataKey",
#      "kms:ReEncrypt*",
#      "kms:ListKeys",
#      "kms:Describe*"
#    ]
#    resources = [
#      data.terraform_remote_state.cap_default.outputs.redshift_secrets_key_arn,
#      module.demo_glue_scripts_bucket.aws_kms_key_arn,
#      module.fstream_api_data_bucket.aws_kms_key_arn,
#      "arn:aws:kms:eu-west-1:146090038381:key/b1ebfd0f-fb85-480a-a885-557bc6bcfa4d",
#    ]
#  }
#
#  statement {
#    sid    = "AllowLogging"
#    effect = "Allow"
#    #checkov:skip=CKV_AWS_111:Skip reason - Resource not known before apply
#    actions = [
#      "logs:AssociateKmsKey",
#      "logs:CreateLogGroup",
#      "logs:PutLogEvents",
#      "logs:DescribeLogStreams",
#      "logs:DescribeLogGroups",
#      "logs:CreateLogStream"
#    ]
#    resources = ["*"]
#  }
#
#  statement {
#    effect = "Allow"
#    #checkov:skip=CKV_AWS_111:Skip reason - Resource not known before apply
#    actions = [
#      "ec2:DescribeNetworkInterfaces",
#      "ec2:CreateNetworkInterface",
#      "ec2:DeleteNetworkInterface",
#    ]
#
#    resources = ["*"]
#  }
#
#  statement {
#    sid    = "allowGetParam"
#    effect = "Allow"
#    actions = [
#      "ssm:GetParameter*"
#    ]
#    resources = [
#      data.terraform_remote_state.cap_default.outputs.redshift_lambda_db_password_ssm_arn
#    ]
#  }
#}
#
#resource "aws_s3_object" "fstream_GENERAL_INFORMATION_schema" {
#  #count          = local.in_production ? 0 : 1 #local.count_in_default
#  bucket         = module.demo_glue_scripts_bucket.s3_bucket
#  key            = "artifact/${module.fstream_labels.resource["glue-job"]["id"]}/GENERAL_INFORMATION.json"
#  content_base64 = filebase64("${path.module}/../../../etl/glue/fstream_glue/schemas/GENERAL_INFORMATION.json")
#
#  tags = {
#    ApplicationID = "demo_onetom_prod_tracker"
#    ProjectID     = "demo"
#  }
#}
#
#resource "aws_s3_object" "fstream_CHECKPOINT_schema" {
#  #count          = local.in_production ? 0 : 1 #local.count_in_default
#  bucket         = module.demo_glue_scripts_bucket.s3_bucket
#  key            = "artifact/${module.fstream_labels.resource["glue-job"]["id"]}/CHECKPOINT.json"
#  content_base64 = filebase64("${path.module}/../../../etl/glue/fstream_glue/schemas/CHECKPOINT.json")
#
#  tags = {
#    ApplicationID = "demo_onetom_prod_tracker"
#    ProjectID     = "demo"
#  }
#}
#
#resource "aws_s3_object" "fstream_PARTS_schema" {
#  #count          = local.in_production ? 0 : 1 #local.count_in_default
#  bucket         = module.demo_glue_scripts_bucket.s3_bucket
#  key            = "artifact/${module.fstream_labels.resource["glue-job"]["id"]}/PARTS.json"
#  content_base64 = filebase64("${path.module}/../../../etl/glue/fstream_glue/schemas/PARTS.json")
#
#  tags = {
#    ApplicationID = "demo_onetom_prod_tracker"
#    ProjectID     = "demo"
#  }
#}
#
#########################################################################################################################
#### connection to redshift
#########################################################################################################################
#resource "aws_glue_connection" "fstream_redshift_conn" {
#  #count           = local.count_in_default
#  connection_type = "JDBC"
#  name            = "${module.fstream_labels.resource["redshift-conn"]["id"]}-fstream"
#  connection_properties = {
#    JDBC_CONNECTION_URL = "jdbc:redshift://${data.terraform_remote_state.cap_default.outputs.cap_redshift_cluster_hostname}:${data.terraform_remote_state.cap_default.outputs.cap_redshift_cluster_port}/${var.redshift_database_name}"
#    PASSWORD            = data.aws_ssm_parameter.redshift_lambda_user_pw.value
#    USERNAME            = var.redshift_database_lambda_user
#  }
#
#  physical_connection_requirements {
#    # There is no easy way to retrieve subnet IDs from the redshift subnet id group
#    availability_zone      = data.aws_subnet.cap_redshift_single_subnet.availability_zone
#    security_group_id_list = [data.terraform_remote_state.cap_default.outputs.cap_redshift_cluster_base_security_group_id]
#    subnet_id              = data.aws_subnet.cap_redshift_single_subnet.id
#  }
#  tags = {
#    ApplicationID = "demo_onetom_prod_tracker"
#    ProjectID     = "demo"
#  }
#}
#
#########################################################################################################################
#### create the Glue job to process fstream data
#########################################################################################################################
#module "fstream_glue_job" {
#  enable = true
#
#  depends_on = [
#    aws_s3_object.fstream_GENERAL_INFORMATION_schema,
#    aws_s3_object.fstream_CHECKPOINT_schema,
#    aws_s3_object.fstream_PARTS_schema,
#    aws_glue_connection.fstream_redshift_conn
#  ]
#
#  source                    = "git::ssh://cap-tf-module-aws-glue-job/vwdfive/cap-tf-module-aws-glue-job?ref=tags/0.5.1"
#  stage                     = var.stage
#  project                   = var.project
#  project_id                = var.project
#  account_id                = data.aws_caller_identity.current.account_id
#  region                    = var.aws_region
#  job_name                  = "fstream-etl"
#  glue_version              = "4.0"
#  glue_number_of_workers    = 2
#  worker_type               = "G.1X"
#  connections               = [aws_glue_connection.fstream_redshift_conn.name]
#  script_bucket             = module.demo_glue_scripts_bucket.s3_bucket
#  glue_job_local_path       = "${path.module}/../../../etl/glue/fstream_glue/main.py"
#  extra_py_files_source_dir = "${path.module}/../../../etl/glue/fstream_glue/"
#  additional_python_modules = ["boto3==1.26.6"]
#  max_concurrent_runs       = 2
#
#  tags_kms = {
#    ApplicationID = "demo_onetom_prod_tracker"
#    ProjectID     = "demo"
#  }
#
#  tags_role = {
#    ApplicationID = "demo_onetom_prod_tracker"
#    ProjectID     = "demo"
#    ModuleName    = "demo-${var.stage}-fstream-glue"
#  }
#
#  // This attribute is called like this in the module but we need to retrieve the KMS-key of the Target bucket where it will write the files after processing
#  target_bucket_kms_key_arn = module.fstream_api_data_bucket.aws_kms_key_arn
#
#  default_arguments = {
#    // Glue Native
#    "--job-language"                     = "python"
#    "--TempDir"                          = "s3://${module.demo_glue_scripts_bucket.s3_bucket}/glue-job-tmp/"
#    "--region"                           = var.aws_region
#    "--enable-metrics"                   = ""
#    "--enable-continuous-cloudwatch-log" = "true"
#    "--enable-glue-datacatalog"          = ""                     # Spark will use Glue Catalog as Hive Metastore
#    "--job-bookmark-option"              = "job-bookmark-disable" #"job-bookmark-enable"
#
#
#    // User defined
#    "--TARGET_PATH"                             = "s3://${module.fstream_api_data_bucket.s3_bucket}/${var.fstream_target_bucket_directory_name}"
#    "--BUCKET_NAME"                             = var.stage == "int" ? "demo-prd-fstream-api-data-bucket" : module.fstream_api_data_bucket.s3_bucket
#    "--BUCKET_PATH"                             = var.stage == "int" ? "s3://demo-prd-fstream-api-data-bucket" : "s3://${module.fstream_api_data_bucket.s3_bucket}"
#    "--fstream_GENERAL_INFORMATION_SCHEMA_PATH" = "s3://${module.demo_glue_scripts_bucket.s3_bucket}/${aws_s3_object.fstream_GENERAL_INFORMATION_schema.key}"
#    "--fstream_CHECKPOINT_SCHEMA_PATH"          = "s3://${module.demo_glue_scripts_bucket.s3_bucket}/${aws_s3_object.fstream_CHECKPOINT_schema.key}"
#    "--fstream_PARTS_SCHEMA_PATH"               = "s3://${module.demo_glue_scripts_bucket.s3_bucket}/${aws_s3_object.fstream_PARTS_schema.key}"
#
#    "--CATALOG_CONNECTION_NAME" = aws_glue_connection.fstream_redshift_conn.name
#
#    "--REDSHIFT_IAM_ROLE_ARN" = data.terraform_remote_state.cap_default.outputs.cap_redshift_cluster_base_role_arn
#    "--REDSHIFT_DB_NAME"      = var.redshift_database_name
#    "--REDSHIFT_SCHEMA"       = var.redshift_data_loader_fstream_db_schema
#    "--CLUSTER_ID"            = data.aws_redshift_cluster.cap.cluster_identifier
#    "--REDSHIFT_USER"         = var.redshift_database_lambda_user
#    #"--date_prefix"           = var.prefix
#    "--CONNECTION_URL"    = "jdbc:redshift://${data.terraform_remote_state.cap_default.outputs.cap_redshift_cluster_hostname}:${data.terraform_remote_state.cap_default.outputs.cap_redshift_cluster_port}/${var.redshift_database_name}"
#    "--REDSHIFT_PW_PARAM" = data.terraform_remote_state.cap_default.outputs.redshift_lambda_db_password_ssm_name
#    "--REDSHIFT_NAME"     = var.redshift_database_name
#
#  }
#
#  timeout                  = 45
#  enable_additional_policy = true
#  additional_policy        = data.aws_iam_policy_document.fstream_glue_job_permissions.json
#}
