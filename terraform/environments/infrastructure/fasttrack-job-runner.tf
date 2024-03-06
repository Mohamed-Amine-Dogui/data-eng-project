#########################################################################################################################
## State machine of FSAG Step Function
#########################################################################################################################
#locals {
#  state_machine_def_fsag = {
#    "Comment" : "Invokes the Lambda to do etl for fsag",
#    "StartAt" : "InvokeLambdaFunction ft_contract_data",
#    "States" : {
#      "InvokeLambdaFunction ft_contract_data" : {
#        "Type" : "Task",
#        "Resource" : "arn:aws:states:::lambda:invoke",
#        "Parameters" : {
#          "FunctionName" : local.in_default_workspace ? module.fsag_cap_pull_lambda.aws_lambda_function_arn : "",
#          "Payload" : {
#            #TODO add regex for the files --> demo/DE/[0-9]{8}_demo_DE_Checkout\\.csv
#            "regex_filter" : "demo/DE/[0-9]{8}_demo_DE_Checkout\\.csv",
#            "columns" : [
#              "vehicleIdentificationNumber",
#              "subscriptionVehicleCategory",
#              "product",
#              "inceptionDate",
#              "contractEndDate",
#              "duration"
#            ]
#          }
#        },
#        "End" : true
#      }
#    }
#  }
#}
#
#########################################################################################################################
#### Permissions of the Step Function for FSAG
#########################################################################################################################
#data "aws_iam_policy_document" "fsag_step_functions_permissions" {
#
#  statement {
#    sid     = "AllowInvokeLambdaFunction"
#    effect  = "Allow"
#    actions = ["lambda:InvokeFunction"]
#    resources = [
#      module.fsag_cap_pull_lambda.aws_lambda_function_arn,
#    ]
#  }
#}
#
#########################################################################################################################
#### Step Function instance to orchestrate the fsag_cap_pull_lambda
#########################################################################################################################
#module "fsag_step_function" {
#  enable                           = true
#  source                           = "git::ssh://cap-tf-module-step-function/vwdfive/cap-tf-module-step-function.git?ref=tags/0.3.7"
#  project                          = var.project
#  kst                              = var.tag_KST
#  git_repository                   = var.git_repository
#  stage                            = var.stage
#  state_machine_description        = "Trigger lambda to pull data from FSAG account"
#  aws_sfn_state_machine_definition = jsonencode(local.state_machine_def_fsag)
#  state_machine_name               = "fsag-cap-sync"
#
#  state_machine_schedule = [{
#    name        = "Schedule",
#    description = "state machine schedule",
#    expression  = "cron(0 3 * * ? *)",
#    input       = ""
#  }]
#
#  additional_policy        = data.aws_iam_policy_document.fsag_step_functions_permissions.json
#  attach_additional_policy = true
#  tags_sfn = {
#    KST           = var.tag_KST
#    ApplicationID = "demo_fast_track"
#    ProjectID     = "demo"
#    ModuleName    = "demo-${var.stage}-fsag_step_function"
#  }
#}
