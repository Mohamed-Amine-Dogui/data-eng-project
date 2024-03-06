#########################################################################################################################
#### Cloudwatch Rules For The StepFunction
#########################################################################################################################
#
#resource "aws_cloudwatch_event_rule" "fasttrack_step_function_states" {
#  depends_on = [
#    module.sns_push_lambda.aws_lambda_function_arn,
#    module.fsag_step_function.aws_sfn_state_machine_arn
#  ]
#
#  name        = module.fasttrack_monitoring_labels.resource["fast_track_step_func_event_rule"]["id"]
#  description = "Capture Step Functions Execution Status Change"
#
#
#  tags = {
#    ApplicationID = "demo_onetom_fast_track"
#    ProjectID     = "demo"
#    ModuleName    = "demo-${var.stage}-fast_track_step_func_event_rule"
#  }
#
#  event_pattern = <<PATTERN
#{
#  "detail-type": [
#    "Step Functions Execution Status Change"
#  ],
#  "source": [
#    "aws.states"
#  ],
#  "detail": {
#    "status": ["FAILED"],
#    "stateMachineArn": [
#      "${module.fsag_step_function.aws_sfn_state_machine_arn}"
#    ]
#  }
#}
#PATTERN
#}
#
#########################################################################################################################
#### Cloudwatch Event Target For The StepFunction
#########################################################################################################################
#resource "aws_cloudwatch_event_target" "fasttrack_step_function_states_target" {
#
#  depends_on = [
#    aws_cloudwatch_event_rule.fasttrack_step_function_states
#  ]
#  arn  = module.sns_push_lambda.aws_lambda_function_arn
#  rule = aws_cloudwatch_event_rule.fasttrack_step_function_states.name
#
#
#  input_transformer {
#    input_paths = {
#      "name" : "$.detail.stateMachineArn",
#      "event" : "$.detail.status",
#      "region" : "$.region",
#      "executionArn" : "$.detail.executionArn"
#    }
#
#    input_template = <<EOF
#    {
#      "name": <name>,
#      "event": <event>,
#      "region": <region>,
#      "executionArn": <executionArn>,
#      "subject": "${upper(var.stage)}-DE-Fast Track Monitoring",
#      "country": "DE",
#      "stage": "${var.stage}",
#      "resource": "StepFunction"
#    }
#    EOF
#  }
#
#}
#
#########################################################################################################################
#### Cloud Watch Metric Alarm for Lambda functions
#########################################################################################################################
#resource "aws_cloudwatch_metric_alarm" "fasttrack_lamda_function_failure" {
#  #for_each            = local.fasttrack_lambda_trigger_map
#  #alarm_name          = module.fasttrack_monitoring_labels.resource["${each.key}"]["id"]
#  alarm_name          = module.fsag_cap_pull_lambda.aws_lambda_function_name
#  alarm_description   = "Lambda function Failures"
#  comparison_operator = "GreaterThanOrEqualToThreshold"
#  evaluation_periods  = "1"
#  metric_name         = "Errors"
#  namespace           = "AWS/Lambda"
#  period              = "900" # seconds = 15 minutes
#  statistic           = "Sum"
#  threshold           = "1"
#  #  dimensions = {
#  #    FunctionName = each.value
#  #  }
#  dimensions = {
#    FunctionName = module.fsag_cap_pull_lambda.aws_lambda_function_name
#  }
#  treat_missing_data = "notBreaching"
#  actions_enabled    = true
#
#  tags = {
#    ApplicationID = "demo_onetom_fast_track"
#    ProjectID     = var.project
#    ModuleName    = "demo-${var.stage}-fsag_pull_lambda_metric_alarm"
#  }
#
#
#  depends_on = [
#    module.fsag_cap_pull_lambda
#  ]
#}
#
#########################################################################################################################
#### Cloudwatch Rules For Lambda
#########################################################################################################################
#resource "aws_cloudwatch_event_rule" "fasttrack_lambda_alarm_states" {
#  name        = module.fasttrack_monitoring_labels.resource["fast_track_lambda_alarm_event_rule"]["id"] # Preprocessing job state changes
#  description = "Capture CloudWatch Metric Alarm State Change"
#
#  tags = {
#    ApplicationID = "demo_onetom_fast_track"
#    ProjectID     = "demo"
#    ModuleName    = "events"
#  }
#
#  event_pattern = jsonencode({
#    detail-type = [
#      "CloudWatch Alarm State Change"
#    ]
#    source = [
#      "aws.cloudwatch"
#    ]
#    detail = {
#      "state" : {
#        "value" : ["ALARM"]
#      },
#      "alarmName" : [aws_cloudwatch_metric_alarm.fasttrack_lamda_function_failure.alarm_name] #[for metric_alarm in aws_cloudwatch_metric_alarm.fasttrack_lamda_function_failure : metric_alarm.alarm_name]
#    }
#  })
#}
#
#########################################################################################################################
#### Cloudwatch Event Target For Lambda
#########################################################################################################################
#resource "aws_cloudwatch_event_target" "fasttrack_lambda_alarm_states_target" {
#  arn  = module.sns_push_lambda.aws_lambda_function_arn
#  rule = aws_cloudwatch_event_rule.fasttrack_lambda_alarm_states.name
#
#
#  input_transformer {
#    input_paths = {
#      "event" : "$.detail.state.value",
#      "metricname" : "$.detail.configuration.metrics[0].metricStat.metric.name",
#      "name" : "$.detail.configuration.metrics[0].metricStat.metric.dimensions.FunctionName",
#      "namespace" : "$.detail.configuration.metrics[0].metricStat.metric.namespace"
#    }
#
#    input_template = <<EOF
#    {
#      "event": <event>,
#      "metricname": <metricname>,
#      "name": <name>,
#      "namespace": <namespace>,
#      "subject": "${upper(var.stage)}-DE-Fast Track Monitoring",
#      "country": "DE",
#      "stage": "${var.stage}",
#      "resource": "Lambda"
#    }
#    EOF
#  }
#
#  depends_on = [
#    aws_cloudwatch_event_rule.fasttrack_lambda_alarm_states
#  ]
#}
