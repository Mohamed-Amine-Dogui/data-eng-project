#########################################################################################################################
#### SNS Topic
#########################################################################################################################
#
#resource "aws_sns_topic" "pt_monitoring_sns_topic" {
#  #checkov:skip=CKV_AWS_26:Skip reason - failure messages only
#  name = module.generic_labels.resource["monitoring_topic"]["id"]
#  tags = {
#    ModuleName = "demo-${var.stage}-monitoring_topic-sns"
#  }
#}
#
#data "aws_iam_policy_document" "sns_monitoring_topic_policy" {
#  statement {
#    sid    = "SNSPublishToEndpoints"
#    effect = "Allow"
#    principals {
#      type        = "Service"
#      identifiers = ["events.amazonaws.com"]
#    }
#    actions   = ["sns:Publish"]
#    resources = [aws_sns_topic.pt_monitoring_sns_topic.arn]
#  }
#}
#
#resource "aws_sns_topic_policy" "monitoring_topic_policy" {
#  arn    = aws_sns_topic.pt_monitoring_sns_topic.arn
#  policy = data.aws_iam_policy_document.sns_monitoring_topic_policy.json
#}
#
#
