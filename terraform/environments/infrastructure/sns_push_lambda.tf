#
#locals {
#  event_rules = merge(
#    {
#      fasttrack_step_function_states_event_rule : aws_cloudwatch_event_rule.fasttrack_step_function_states.arn,
#      fasttrack_lambda_rule : aws_cloudwatch_event_rule.fasttrack_lambda_alarm_states.arn
#    },
#    local.in_development ?
#    {} : {}
#  )
#}
#
#module "sns_push_lambda" {
#
#  enable                      = true
#  source                      = "git::ssh://cap-tf-module-aws-lambda-vpc/vwdfive/cap-tf-module-aws-lambda-vpc.git?ref=tags/0.3.7"
#  project                     = var.project
#  stage                       = var.stage
#  lambda_unique_function_name = "sns_push"
#  runtime                     = "python3.9"
#  handler                     = var.default_lambda_handler
#  logs_kms_key_arn            = module.source_code_bucket.aws_kms_key_arn
#  artifact_bucket_name        = module.source_code_bucket.s3_bucket
#  lambda_base_dir             = "${path.cwd}/../../../etl/lambdas/sns_push"
#  lambda_env_vars = {
#    SNS_TOPIC_ARN = aws_sns_topic.pt_monitoring_sns_topic.arn
#  }
#
#  additional_policy        = data.aws_iam_policy_document.sns_push_lambda_permission.json
#  attach_additional_policy = true
#
#  # tags
#  tags_lambda = {
#    KST           = var.tag_KST
#    GitRepository = var.git_repository
#    ApplicationID = "demo_onetom_generic"
#
#    ProjectID  = "demo"
#    ModuleName = "demo-${var.stage}-sns_push_lambda"
#  }
#
#}
#
#data "aws_iam_policy_document" "sns_push_lambda_permission" {
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
#
#resource "aws_lambda_permission" "allow_cloudwatch_to_invoke_sns_push" {
#  for_each      = local.event_rules
#  statement_id  = "AllowExecutionFrom-${each.key}"
#  action        = "lambda:InvokeFunction"
#  function_name = module.sns_push_lambda.aws_lambda_function_name
#  principal     = "events.amazonaws.com"
#  source_arn    = each.value
#}
