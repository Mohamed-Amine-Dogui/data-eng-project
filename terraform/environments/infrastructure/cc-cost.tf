#module "cc_epic_budget_alert" {
#  source = "git::ssh://cap-tf-module-aws-cost-alert-by-tag/vwdfive/cap-tf-module-aws-cost-alert-by-tag.git?ref=tags/0.2.0"
#
#  enable = local.in_production || local.in_integration
#
#  git_repository = var.git_repository
#  stage          = var.stage
#  project        = var.project
#
#  ProjectID     = "demo"
#  ApplicationID = "demo_onetom_campaign_cockpit"
#
#
#  limit_amount = 13.6
#  threshold    = 100
#
#  number_of_years   = 1
#  start_date        = "2023-11-01"
#  notification_type = "ACTUAL"
#
#  subscriber_email_addresses = ["exempl@gmail.com"]
#
#
#}
#
#module "cc_kms_budget_alert" {
#  source = "git::ssh://cap-tf-module-aws-cost-alert-by-tag/vwdfive/cap-tf-module-aws-cost-alert-by-tag.git?ref=tags/0.2.0"
#
#  enable = local.in_production || local.in_integration
#
#  git_repository = var.git_repository
#  stage          = var.stage
#  project        = var.project
#
#  ProjectID     = "demo"
#  ApplicationID = "demo_onetom_campaign_cockpit"
#
#  service_acronym = "kms"
#  service_type    = "AWS Key Management Service"
#
#
#  limit_amount = 7.4
#  threshold    = 100
#
#  number_of_years   = 1
#  start_date        = "2023-11-01"
#  notification_type = "ACTUAL"
#
#  subscriber_email_addresses = ["exempl@gmail.com"]
#
#}
#
#module "cc_glue_budget_alert" {
#  source = "git::ssh://cap-tf-module-aws-cost-alert-by-tag/vwdfive/cap-tf-module-aws-cost-alert-by-tag.git?ref=tags/0.2.0"
#
#  enable = local.in_production || local.in_integration
#
#  git_repository = var.git_repository
#  stage          = var.stage
#  project        = var.project
#
#  ProjectID     = "demo"
#  ApplicationID = "demo_onetom_campaign_cockpit"
#
#  service_acronym = "glue"
#  service_type    = "AWS Glue"
#
#
#  limit_amount = 0.75
#  threshold    = 100
#
#  number_of_years   = 1
#  start_date        = "2023-11-01"
#  notification_type = "ACTUAL"
#
#  subscriber_email_addresses = ["exempl@gmail.com"]
#
#}
#
#module "cc_s3_budget_alert" {
#  source = "git::ssh://cap-tf-module-aws-cost-alert-by-tag/vwdfive/cap-tf-module-aws-cost-alert-by-tag.git?ref=tags/0.2.0"
#
#  enable = local.in_production || local.in_integration
#
#  git_repository = var.git_repository
#  stage          = var.stage
#  project        = var.project
#
#  ProjectID     = "demo"
#  ApplicationID = "demo_onetom_campaign_cockpit"
#
#  service_acronym = "s3"
#  service_type    = "Amazon Simple Storage Service"
#
#
#  limit_amount = 0.02
#  threshold    = 100
#
#  number_of_years   = 1
#  start_date        = "2023-11-01"
#  notification_type = "ACTUAL"
#
#  subscriber_email_addresses = ["exempl@gmail.com"]
#
#}
