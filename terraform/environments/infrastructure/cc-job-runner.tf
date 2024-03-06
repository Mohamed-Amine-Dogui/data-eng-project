#########################################################################################################################
####  The Step function that coordinates the execution of all the resources in the current ETL environment
#########################################################################################################################
#locals {
#  onecrm_campaign_cockpit_state_machine_def = {
#    "Comment" : "run the onecrm_campaign_cockpit glue job once a day",
#    "StartAt" : "Run_onecrm_campaign_cockpit_GlueJob",
#    "States" : {
#      "Run_onecrm_campaign_cockpit_GlueJob" : {
#        "Type" : "Task",
#        "Resource" : "arn:aws:states:::glue:startJobRun.sync",
#        "Parameters" : {
#          "JobName" : module.onecrm_campaign_cockpit_glue_job.aws_glue_job_name
#        },
#        "End" : true
#      }
#    }
#  }
#}
#
#output "onecrm_campaign_cockpit_state_machine_def" {
#  value = jsonencode(local.onecrm_campaign_cockpit_state_machine_def)
#}
#
#########################################################################################################################
## ETL Step Function for onecrm_campaign_cockpit instance
#########################################################################################################################
#module "onecrm_campaign_cockpit_step_function" {
#  enable = local.in_development
#
#  source                           = "git::ssh://cap-tf-module-step-function/vwdfive/cap-tf-module-step-function.git?ref=tags/0.3.7"
#  project                          = var.project
#  kst                              = var.tag_KST
#  git_repository                   = var.git_repository
#  stage                            = var.stage
#  state_machine_description        = "run okm campaign cokpit glue job"
#  aws_sfn_state_machine_definition = jsonencode(local.onecrm_campaign_cockpit_state_machine_def)
#  state_machine_name               = "run-okm_campaign_cokpit-glue"
#
#  state_machine_schedule = [{
#    name        = "Schedule",
#    description = "state machine schedule",
#    expression  = "cron(0 3 * * ? *)",
#    input       = ""
#  }]
#
#  additional_policy        = data.aws_iam_policy_document.onecrm_campaign_cockpit_step_functions_permissions.json
#  attach_additional_policy = true
#  tags_sfn = {
#    KST           = var.tag_KST
#    ApplicationID = "demo_onetom_campaign_cockpit"
#    ProjectID     = "demo"
#    ModuleName    = "demo-${var.stage}-onecrm_cc_step_function"
#  }
#}
#
#########################################################################################################################
#### Step Function for onecrm_campaign_cockpit permissions
#########################################################################################################################
#data "aws_iam_policy_document" "onecrm_campaign_cockpit_step_functions_permissions" {
#
#  statement {
#    sid    = "AllowInvokeGlueJob"
#    effect = "Allow"
#    actions = [
#      "glue:StartJobRun",
#      "glue:GetJobRun",
#      "glue:GetJobRuns",
#      "glue:BatchStopJobRun",
#    ]
#    resources = [
#      module.onecrm_campaign_cockpit_glue_job.aws_glue_job_arn
#    ]
#  }
#}
