##
## The Step function that coordinates the execution of deletion lambda
##
#locals {
#  state_machine_def_cc_deletion = {
#    "Comment" : "Invokes the Lambda to do etl for cc deletion lambda",
#    "StartAt" : "InvokeLambdaFunction cc_deletion",
#    "States" : {
#      "InvokeLambdaFunction cc_deletion" : {
#        "Type" : "Task",
#        "Resource" : "arn:aws:states:::lambda:invoke",
#        "Parameters" : {
#          "FunctionName" : module.cc_deletion_lambda.aws_lambda_function_arn,
#          "Payload" : {
#            "schema" : var.redshift_data_loader_campaign_cockpit_demo_db_schema,
#            "general_duration" : 700,
#            "columns" : {}
#          }
#        },
#        "End" : true
#      }
#    }
#  }
#}
#
#########################################################################################################################
#### Step Function for cc_deletion permissions
#########################################################################################################################
#data "aws_iam_policy_document" "cc_deletion_step_functions_permissions" {
#
#  statement {
#    sid     = "AllowInvokeLambdaFunction"
#    effect  = "Allow"
#    actions = ["lambda:InvokeFunction"]
#    resources = [
#      module.cc_deletion_lambda.aws_lambda_function_arn,
#    ]
#  }
#}
#
#########################################################################################################################
#### Step Function instance to orchestrate the cc deletion lambda
#########################################################################################################################
#module "cc_deletion_step_function" {
#  enable                           = !local.in_production
#  source                           = "git::ssh://cap-tf-module-step-function/vwdfive/cap-tf-module-step-function.git?ref=tags/0.3.7"
#  git_repository                   = var.git_repository
#  stage                            = var.stage
#  project                          = var.project
#  kst                              = var.tag_KST
#  state_machine_description        = "Trigger cc deletion lambda"
#  aws_sfn_state_machine_definition = jsonencode(local.state_machine_def_cc_deletion)
#  state_machine_name               = "cc_deletion"
#
#  state_machine_schedule = [{
#    name        = "Schedule",
#    description = "state machine schedule",
#    expression  = "cron(0 5 * * ? *)",
#    input       = ""
#  }]
#
#  additional_policy        = data.aws_iam_policy_document.cc_deletion_step_functions_permissions.json
#  attach_additional_policy = true
#  tags_sfn = {
#    KST           = var.tag_KST
#    ApplicationID = "demo_onetom_campaign_cockpit"
#    ProjectID     = "demo"
#    ModuleName    = "demo-${var.stage}-cc_deletion_step_function"
#  }
#}
