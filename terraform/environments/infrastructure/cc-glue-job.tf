#########################################################################################################################
#### Upload main Glue Job script
#########################################################################################################################
#resource "aws_s3_object" "cc_glue_script" {
#  count          = local.in_production ? 0 : 1 #local.count_in_default
#  bucket         = module.demo_glue_scripts_bucket.s3_bucket
#  key            = "artifact/${module.cc_labels.resource["glue-job"]["id"]}/main.py"
#  content_base64 = filebase64("${path.module}/../../../etl/glue/cc_glue/main.py")
#
#  tags = {
#    ApplicationID = "demo_onetom_campaign_cockpit"
#    ProjectID     = var.project
#  }
#}
#
#resource "aws_s3_object" "cc_glue_Campaign_schema" {
#  count          = local.in_production ? 0 : 1 #local.count_in_default
#  bucket         = module.demo_glue_scripts_bucket.s3_bucket
#  key            = "artifact/campaign_cockpit/schemas/Campaign.json"
#  content_base64 = filebase64("${path.module}/../../../etl/glue/cc_glue/schemas/Campaign.json")
#  #etag = "${md5(file("${path.module}/../../../etl/glue/cc_glue/schemas/Campaign.json"))}"
#
#  tags = {
#    ApplicationID = "demo_onetom_campaign_cockpit"
#    ProjectID     = var.project
#  }
#}
#
#resource "aws_s3_object" "cc_glue_Automated_Send_schema" {
#  count          = local.in_production ? 0 : 1 #local.count_in_default
#  bucket         = module.demo_glue_scripts_bucket.s3_bucket
#  key            = "artifact/campaign_cockpit/schemas/et4ae5__Automated_Send__c.json"
#  content_base64 = filebase64("${path.module}/../../../etl/glue/cc_glue/schemas/et4ae5__Automated_Send__c.json")
#
#  tags = {
#    ApplicationID = "demo_onetom_campaign_cockpit"
#    ProjectID     = var.project
#  }
#}
#
#
#resource "aws_s3_object" "cc_glue_ContactPointTypeConsent_schema" {
#  count          = local.in_production ? 0 : 1 #local.count_in_default
#  bucket         = module.demo_glue_scripts_bucket.s3_bucket
#  key            = "artifact/campaign_cockpit/schemas/ContactPointTypeConsent.json"
#  content_base64 = filebase64("${path.module}/../../../etl/glue/cc_glue/schemas/ContactPointTypeConsent.json")
#
#  tags = {
#    ApplicationID = "demo_onetom_campaign_cockpit"
#    ProjectID     = var.project
#  }
#}
#
#resource "aws_s3_object" "cc_glue_Individual_schema" {
#  count          = local.in_production ? 0 : 1 #local.count_in_default
#  bucket         = module.demo_glue_scripts_bucket.s3_bucket
#  key            = "artifact/campaign_cockpit/schemas/Individual.json"
#  content_base64 = filebase64("${path.module}/../../../etl/glue/cc_glue/schemas/Individual.json")
#
#  tags = {
#    ApplicationID = "demo_onetom_campaign_cockpit"
#    ProjectID     = var.project
#  }
#}
#
#resource "aws_s3_object" "cc_glue_Lead_schema" {
#  count          = local.in_production ? 0 : 1 #local.count_in_default
#  bucket         = module.demo_glue_scripts_bucket.s3_bucket
#  key            = "artifact/campaign_cockpit/schemas/Lead.json"
#  content_base64 = filebase64("${path.module}/../../../etl/glue/cc_glue/schemas/Lead.json")
#
#  tags = {
#    ApplicationID = "demo_onetom_campaign_cockpit"
#    ProjectID     = var.project
#  }
#}
#
#########################################################################################################################
#### connection to redshift
#########################################################################################################################
#resource "aws_glue_connection" "cc_redshift_conn" {
#  count           = local.in_production ? 0 : 1 #local.count_in_default
#  connection_type = "JDBC"
#  name            = "${module.cc_labels.resource["redshift-conn"]["id"]}-cc"
#  connection_properties = {
#    JDBC_CONNECTION_URL = "jdbc:redshift://${data.terraform_remote_state.cap_default.outputs.cap_redshift_cluster_hostname}:${data.terraform_remote_state.cap_default.outputs.cap_redshift_cluster_port}/${var.redshift_database_name}"
#    PASSWORD            = data.aws_ssm_parameter.redshift_lambda_user_pw.value
#    USERNAME            = var.redshift_database_lambda_user
#  }
#  physical_connection_requirements {
#    # There is no easy way to retrieve subnet IDs from the redshift subnet id group
#    availability_zone      = data.aws_subnet.cap_redshift_single_subnet.availability_zone
#    security_group_id_list = [data.terraform_remote_state.cap_default.outputs.cap_redshift_cluster_base_security_group_id]
#    subnet_id              = data.aws_subnet.cap_redshift_single_subnet.id
#  }
#
#  tags = {
#    ApplicationID = "demo_onetom_campaign_cockpit"
#    ProjectID     = var.project
#  }
#
#}
#
#########################################################################################################################
#### create the Glue job to process onecrm data
#########################################################################################################################
#module "cc_glue_job" {
#  enable = local.in_development #local.in_default_workspace
#
#  depends_on = [
#    aws_s3_object.cc_glue_script,
#    aws_s3_object.cc_glue_Lead_schema,
#    aws_s3_object.cc_glue_Individual_schema,
#    aws_s3_object.cc_glue_ContactPointTypeConsent_schema,
#    aws_s3_object.cc_glue_Automated_Send_schema,
#    aws_s3_object.cc_glue_Campaign_schema,
#    aws_glue_connection.cc_redshift_conn
#  ]
#
#  source                    = "git::ssh://cap-tf-module-aws-glue-job/vwdfive/cap-tf-module-aws-glue-job?ref=tags/0.5.1"
#  stage                     = var.stage
#  project                   = var.project
#  project_id                = var.project
#  account_id                = data.aws_caller_identity.current.account_id
#  region                    = var.aws_region
#  job_name                  = "cc-etl-glue"
#  glue_version              = "4.0"
#  glue_number_of_workers    = 2
#  worker_type               = "G.1X"
#  connections               = local.in_production ? [""] : [aws_glue_connection.cc_redshift_conn[0].name]
#  script_bucket             = module.demo_glue_scripts_bucket.s3_bucket
#  glue_job_local_path       = "${path.module}/../../../etl/glue/cc_glue/main.py"
#  extra_py_files_source_dir = "${path.module}/../../../etl/glue/cc_glue/"
#
#  // This attribute is called like this in the module but we need to retreive the KMS-key of the Target bucket where it will write the files after processing
#  target_bucket_kms_key_arn = module.cc_target_data_bucket.aws_kms_key_arn
#
#  tags_kms = {
#    ApplicationID = "demo_onetom_campaign_cockpit"
#    ProjectID     = "demo"
#  }
#
#  tags_role = {
#    ApplicationID = "demo_onetom_campaign_cockpit"
#    ProjectID     = "demo"
#    ModuleName    = "demo-${var.stage}-onecrm-cc-glue"
#  }
#
#  default_arguments = {
#    // Glue Native
#    "--job-language"                     = "python"
#    "--TempDir"                          = "s3://${module.demo_glue_scripts_bucket.s3_bucket}/glue-job-tmp/"
#    "--region"                           = var.aws_region
#    "--enable-metrics"                   = ""
#    "--enable-continuous-cloudwatch-log" = "true"
#    "--enable-glue-datacatalog"          = "" # Spark will use Glue Catalog as Hive Metastore
#    "--job-bookmark-option"              = "job-bookmark-enable"
#
#    // User defined
#    "--TARGET_PATH"        = "s3://${module.cc_target_data_bucket.s3_bucket}/${var.cc_target_bucket_directory_name}"
#    "--TARGET_BUCKET_NAME" = module.cc_target_data_bucket.s3_bucket
#
#    "--SOURCE_BUCKET_NAME" = data.terraform_remote_state.vwd_default_infrastructure.outputs.onecrm_bucket_name
#    "--SOURCE_BUCKET_PATH" = "s3://${data.terraform_remote_state.vwd_default_infrastructure.outputs.onecrm_bucket_name}"
#
#    "--SCHEMAS_PATH"            = local.in_production ? "" : "s3://${module.demo_glue_scripts_bucket.s3_bucket}/artifact/campaign_cockpit/schemas/"
#    "--CATALOG_CONNECTION_NAME" = local.in_production ? "" : aws_glue_connection.cc_redshift_conn[0].name
#    "--REDSHIFT_IAM_ROLE_ARN"   = data.terraform_remote_state.cap_default.outputs.cap_redshift_cluster_base_role_arn
#    "--REDSHIFT_DB_NAME"        = var.redshift_database_name
#    "--REDSHIFT_SCHEMA"         = var.redshift_data_loader_campaign_cockpit_demo_db_schema
#    "--STAGE"                   = var.stage
#    "--SNS_ARN"                 = aws_sns_topic.pt_monitoring_sns_topic.arn
#  }
#
#  timeout                  = 45
#  enable_additional_policy = true
#  additional_policy        = data.aws_iam_policy_document.cc_glue_job_permissions.json
#}
#
#
#########################################################################################################################
####  cc glue job permissions
#########################################################################################################################
#
#data "aws_iam_policy_document" "cc_glue_job_permissions" {
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
#  statement {
#    sid     = "AllowReadFromOneCrmBucket"
#    effect  = "Allow"
#    actions = ["s3:Get*", "s3:List*"]
#    resources = [
#      data.terraform_remote_state.vwd_default_infrastructure.outputs.onecrm_bucket_arn,
#      "${data.terraform_remote_state.vwd_default_infrastructure.outputs.onecrm_bucket_arn}/*"
#    ]
#  }
#
#  statement {
#    sid    = "AllowWriteToTargetBucket"
#    effect = "Allow"
#    actions = [
#      "s3:Get*",
#      "s3:Put*",
#      "s3:Describe*",
#      "s3:Delete*",
#      "s3:RestoreObject"
#    ]
#    resources = [
#      module.cc_target_data_bucket.s3_arn,
#      "${module.cc_target_data_bucket.s3_arn}/*",
#    ]
#  }
#
#  statement {
#    sid    = "AllowDecryptEncryptToBuckets"
#    effect = "Allow"
#    actions = [
#      "kms:Decrypt",
#      "kms:Encrypt",
#      "kms:GenerateDataKey",
#      "kms:ReEncrypt*",
#      "kms:ListKeys",
#      "kms:Describe*"
#    ]
#    resources = [
#      module.demo_glue_scripts_bucket.aws_kms_key_arn,
#      module.cc_target_data_bucket.aws_kms_key_arn,
#      data.terraform_remote_state.vwd_default_infrastructure.outputs.onecrm_bucket_kms_key_arn
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
#
#    effect = "Allow"
#
#    actions = [
#      "sns:Publish",
#      "sns:Subscribe"
#    ]
#
#    resources = [aws_sns_topic.pt_monitoring_sns_topic.arn]
#  }
#}
