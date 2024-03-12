########################################################################################################################
###  Project generic vars
########################################################################################################################
variable "stage" {
  description = "Specify to which project this resource belongs, no default value to allow proper validation of project setup"
  default     = "dev"
}

variable "aws_region" {
  description = "Default Region"
  default     = "eu-west-1"
}

variable "project" {
  description = "Specify to which project this resource belongs"
  default     = "demo"
}

variable "wa_number" {
  description = "wa number for billing"
  default     = "Not set"
}

variable "project_id" {
  description = "project ID for billing"
  default     = "demo"
}

variable "git_repository" {
  description = "The current GIT repository used to keep track of the origin of resources in AWS"
  default     = "github.com/Mohamed-Amine-Dogui/data-eng-project"
}

variable "tag_KST" {
  description = "Kosten Stelle, tags"
  default     = "not set"
}

#########################################################################################################################
####  Network
#########################################################################################################################
#
#variable "redshift_security_group" {
#  description = "The security group of the redshift instance"
#  default = {
#    dev : ["sg-048df475abbac627b", "sg-0c374e1ab00e1f3c4"],
#    int : ["sg-025b8ceca852a0895", "sg-0ef2ed96d700bed76"],
#    prd : ["sg-031ee976c2e91fa66", "sg-0a5135bf414d1bc8e"],
#  }
#}
#
#variable "alb_account_id" {
#  description = "https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-access-logs.html"
#  default = {
#    "eu-west-1" : "156460612806"
#  }
#}
#
#
#########################################################################################################################
####  Sagemaker notebook variables
#########################################################################################################################
#
#variable "ds_notebook_instance_type" {
#  description = "Notebook's instance type"
#  default = {
#    dev : "ml.t2.medium",
#    int : "ml.t2.medium",
#    prd : "ml.t2.medium"
#  }
#}
#
#########################################################################################################################
####  s3 generic
#########################################################################################################################
#
#variable "s3_bucket_log" {
#  description = "The name of the S3 bucket into which the other buckets log."
#  default     = "log-bucket"
#  type        = string
#}
#
#variable "s3_bucket_source_code" {
#  description = "The name of the S3 bucket into source code for lambda and glue is stored."
#  default     = "lambda-source-code-bucket"
#  type        = string
#}
#
#variable "demo_glue_scripts_s3_bucket_name" {
#  description = "Name of the s3 bucket for glue scripts"
#  default     = "glue-scripts"
#}
#
#########################################################################################################################
####  fsag variables
#########################################################################################################################
#
#variable "s3_fsag_target_data_bucket" {
#  description = "Bucket for proessed data after the glue job"
#  default     = "fsag-target-data"
#  type        = string
#}
#

#
#variable "fsag_account_bucket_name" {
#  description = "s3 bucket name in the fsag account"
#  type        = map(string)
#  default = {
#    "dev" = "io-vwfs-int-fast-track-group-brand-exchange"
#    "int" = "io-vwfs-int-fast-track-group-brand-exchange"
#    "prd" = "io-vwfs-prod-fast-track-group-brand-exchange"
#  }
#}
#
#variable "fsag_account_bucket_arn" {
#  description = "s3 bucket arn in the fsag account"
#  type        = map(string)
#  default = {
#    "dev" = "arn:aws:s3:::io-vwfs-int-fast-track-group-brand-exchange"
#    "int" = "arn:aws:s3:::io-vwfs-int-fast-track-group-brand-exchange"
#    "prd" = "arn:aws:s3:::io-vwfs-prod-fast-track-group-brand-exchange"
#  }
#}
#
#variable "fsag_kms_keys" {
#  description = "kms key pro stages in fsag account"
#  type        = map(string)
#  default = {
#    "dev" = "arn:aws:kms:eu-central-1:576891737164:key/0c44a538-4699-46f2-8ee4-f80420fc9a4d"
#    "int" = "arn:aws:kms:eu-central-1:576891737164:key/0c44a538-4699-46f2-8ee4-f80420fc9a4d"
#    "prd" = "arn:aws:kms:eu-central-1:251248739271:key/90aef144-c117-4219-9972-58868f441adf"
#  }
#}
#
variable "fsag_label" {
  description = "fsag label context"
  default     = "fsag-etl"
}
#
#########################################################################################################################
####  Redshift variables
#########################################################################################################################
#
#variable "redshift_database_lambda_user" {
#  description = "DB user to use to connect to Redshift via Lambda function (that issues S3 copy command)"
#  default     = "vwanalytics"
#}
#
#variable "redshift_database_name" {
#  description = "Name of the Database"
#  default     = "vwredshift"
#}
#
#
#variable "redshift_data_loader_fsag_db_schema" {
#  description = "Name of schema"
#  default     = "fasttrack_demo"
#}
#
#variable "redshift_data_loader_campaign_cockpit_demo_db_schema" {
#  description = "Name of schema"
#  default     = "campaign_cockpit_demo"
#}
#
#########################################################################################################################
####  onecrm_campaign_cockpit variables
#########################################################################################################################
#variable "s3_cc_target_data_bucket" {
#  description = "Bucket for writing data after the glue"
#  default     = "onecrm-campaign-cockpit-target-data"
#  type        = string
#}
variable "cc_label" {
  description = "cc label context"
  default     = "cc-etl"
}
#
#
#variable "cc_target_bucket_directory_name" {
#  description = "Name of the directory inside the campaign_cockpit target bucket"
#  default     = "processed_data"
#}
#
#########################################################################################################################
####  fstream variables
#########################################################################################################################
variable "fstream_label" {
  description = "fstream label context"
  default     = "fstream"

}
#variable "fstream_s3_bucket" {
#  description = "Bucket for storing the sent messages through sqs"
#  default     = "fstream-api-data-bucket"
#  type        = string
#}
#
#variable "default_fstream_lambda_handler" {
#  description = "The name of the function handler inside the fstream lambda main file"
#  default     = "lambda_handler"
#}
#
#
#variable "fstream_sqs_s3_lambda_name" {
#  description = "The unique name of the fstream lambda"
#  default     = "fstream-sqs-s3"
#}
#
#
#variable "fstream_target_bucket_directory_name" {
#  description = "Name of the directory inside the fstream bucket"
#  default     = "processed_data"
#}
#
#variable "redshift_data_loader_fstream_db_schema" {
#  description = "Name of schema"
#  default     = "ifa_demo"
#}
#
########################################################################################################################
####  fasttrack monitoring variables
#########################################################################################################################
variable "fasttrack_monitoring_label" {
  description = "fasttrack monitoring label context"
  default     = "fasttrack-monitoring"
}
#
#
#
#variable "fstream-sns-arn" {
#  description = "arn of fstream SNS topic "
#  default = {
#    dev : "arn:aws:sns:eu-west-1:683778616801:PrepareProductionStack-MessageRouterTopic6FDF6F03-LMH1Y9604T9K",
#    int : "arn:aws:sns:eu-west-1:683778616801:PrepareProductionStack-MessageRouterTopic6FDF6F03-LMH1Y9604T9K",
#    prd : "arn:aws:sns:eu-west-1:683778616801:PrepareProductionStack-MessageRouterTopic6FDF6F03-LMH1Y9604T9K",
#  }
#}


variable "default_lambda_handler" {
  description = "The name of the function handler inside main.py file"
  default     = "lambda_handler"
}

variable "layer_rebuild_trigger" {
  description = "Trigger to rebuild lambda layer"
  type        = string
  default     = "1"
}
