########################################################################################################################
###  Terraform and Providers setup
########################################################################################################################
terraform {
  required_version = "= 0.14.8"
  backend "s3" {
    bucket = "data-eng-terraform-backend"
    key    = "statefile.tfstate"
    region = "eu-west-1"
  }

  required_providers {
    aws = {
      version = "= 4.19"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.1.1"
    }

  }
}

provider "null" {
  # Configuration options
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      OrgScope        = "Not Set"
      FunctionalScope = "Not Set"
      Environment     = "Not Set"
      ModuleName      = "Not Set"
      GitRepository   = "github.com/Mohamed-Amine-Dogui/data-eng-project"
      ProjectID       = var.project
    }
  }
}



########################################################################################################################
###  General locals
########################################################################################################################
locals {
  in_default_workspace  = terraform.workspace == "default"
  in_production         = var.stage == "prd"
  in_development        = var.stage == "dev"
  in_integration        = var.stage == "int"
  count_in_production   = local.in_production ? 1 : 0
  count_in_default      = local.in_default_workspace ? 1 : 0
  workspace_arn_prefix  = terraform.workspace != "default" && var.stage == "dev" ? "*" : ""
  project_stage_pattern = "${local.workspace_arn_prefix}${var.project}-${var.stage}*"
  account_id            = data.aws_caller_identity.current.account_id
  access_arns           = [data.aws_caller_identity.current.arn, "arn:aws:iam::683603511960:user/dogui"]
}

#########################################################################################################################
####  Remote state retrieval cap-consumer-ap
#########################################################################################################################
#data "terraform_remote_state" "cap_default" {
#  backend   = "s3"
#  workspace = "default"
#  config = {
#    // var.stage must be in ["prd", "int", "dev"]
#    bucket = "cap-${var.stage}-terraform-backend"
#    key    = "analytics-vpc-${var.aws_region}/cap/cap.tfstate"
#    region = var.aws_region
#  }
#  defaults = {}
#}
#
########################################################################################################################
###  Remote state retrieval vwd
########################################################################################################################
#data "terraform_remote_state" "vwd_default_infrastructure" {
#  backend = "s3"
#  //  comment out if working on base resources that need to be in the feature
#  //  workspace/branch.
#  workspace = "default"
#  config = {
#    bucket = "vwd-dp-${var.stage}-terraform-backend"
#    key    = "analytics-vpc-${var.aws_region}/infrastructure/infrastructure.tfstate"
#    region = var.aws_region
#  }
#}

########################################################################################################################
###  Convenience data retrieval
########################################################################################################################
data "aws_caller_identity" "current" {}

########################################################################################################################
###  generic resources Labels
########################################################################################################################
module "generic_labels" {
  source         = "git::ssh://git@github.com/Mohamed-Amine-Dogui/tf-module-label.git?ref=tags/0.0.1"
  git_repository = var.git_repository
  project        = var.project
  stage          = var.stage
  layer          = var.stage
  project_id     = var.project_id
  kst            = var.tag_KST
  wa_number      = var.wa_number

  additional_tags = {
    ApplicationID = "demo_onetom_generic"
    ProjectID     = "demo"
  }

  resources = [
    "monitoring_topic",
    "notebook_user_pw",
    "my-test-new-bucket",
    "grant",
    "glue-job"
  ]
}

########################################################################################################################
###  fsag Labels
########################################################################################################################
module "fsag_labels" {
  source = "git::ssh://git@github.com/Mohamed-Amine-Dogui/tf-module-label.git?ref=tags/0.0.1"

  project        = var.project
  stage          = var.stage
  name           = var.fsag_label
  layer          = var.stage
  project_id     = var.project_id
  kst            = var.tag_KST
  wa_number      = var.wa_number
  git_repository = var.git_repository

  additional_tags = {
    ApplicationID = "demo_onetom_fast_track"
    ProjectID     = "demo"
  }
  resources = [
    "policy",
    "glue-job",
    "takeout-glue-job",
    "redshift-conn",
    "dlq-sns-topic",
    "takeout-redshift-connection",
    "secret",
    "grant",
    "kms"
  ]
}

########################################################################################################################
###  cc Labels
########################################################################################################################
module "cc_labels" {
  source = "git::ssh://git@github.com/Mohamed-Amine-Dogui/tf-module-label.git?ref=tags/0.0.1"

  project        = var.project
  stage          = var.stage
  name           = var.cc_label
  layer          = var.stage
  project_id     = var.project_id
  kst            = var.tag_KST
  wa_number      = var.wa_number
  git_repository = var.git_repository

  additional_tags = {
    ApplicationID = "demo_onetom_campaign_cockpit"
    ProjectID     = "demo"
  }

  resources = [
    "policy",
    "glue-job",
    "takeout-glue-job",
    "redshift-conn",
    "dlq-sns-topic",
    "takeout-redshift-connection",
  ]
}

########################################################################################################################
###  fstream Labels
########################################################################################################################
module "fstream_labels" {
  source = "git::ssh://git@github.com/Mohamed-Amine-Dogui/tf-module-label.git?ref=tags/0.0.1"

  project        = var.project
  stage          = var.stage
  name           = var.fstream_label
  layer          = var.stage
  project_id     = var.project_id
  kst            = var.tag_KST
  wa_number      = var.wa_number
  git_repository = var.git_repository
  additional_tags = {
    ApplicationID = "demo_onetom_prod_tracker"
    ProjectID     = "demo"
  }

  resources = [
    "policy",
    "glue-job",
    "redshift-conn",
    "takeout-redshift-connection",
    "sqs",
    "grant",
    "kms",
    "lambda"
  ]
}

########################################################################################################################
###  fasttrack Monitoring Labels
########################################################################################################################
#module "fasttrack_monitoring_labels" {
#  source = "git::ssh://git@github.com/Mohamed-Amine-Dogui/tf-module-label.git?ref=tags/0.0.1"
#
#  project        = var.project
#  stage          = var.stage
#  name           = var.fasttrack_monitoring_label
#  layer          = var.stage
#  project_id     = var.project_id
#  kst            = var.tag_KST
#  wa_number      = var.wa_number
#  git_repository = var.git_repository
#
#  additional_tags = {
#    ApplicationID = "demo_onetom_fast_track"
#    ProjectID     = "demo"
#  }
#
#  resources = [
#    "fast_track_lambda_alarm_event_rule",
#    "fast_track_step_func_event_rule"
#  ]
#
#}

########################################################################################################################
###  Redshift
########################################################################################################################
#data "aws_security_group" "cap_redshift" {
#  count = local.count_in_default
#  id    = data.terraform_remote_state.cap_default.outputs.cap_redshift_cluster_base_security_group_id
#}
#
#data "aws_redshift_cluster" "cap" {
#  cluster_identifier = data.terraform_remote_state.cap_default.outputs.cap_redshift_cluster_identifier
#}
#
#data "aws_subnet" "cap_redshift_single_subnet" {
#  id = split(",", data.terraform_remote_state.cap_default.outputs.cap_redshift_cluster_subnet_ids)[1]
#}
#
#data "aws_ssm_parameter" "redshift_lambda_user_pw" {
#  name = data.terraform_remote_state.cap_default.outputs.redshift_lambda_db_password_ssm_name
#}
