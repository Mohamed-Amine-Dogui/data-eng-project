########################################################################################################################
#### Bucket for the logs
########################################################################################################################
module "logs_bucket" {

  enable = true
  source = "git::ssh://git@github.com/Mohamed-Amine-Dogui/tf-module-aws-s3-bucket//s3/s3-encrypted?ref=tags/0.0.1"

  environment                       = var.stage
  project                           = var.project
  s3_bucket_name                    = "my-test-log-bucket"
  s3_bucket_acl                     = "log-delivery-write"
  object_ownership                  = "ObjectWriter"
  versioning_enabled                = false
  transition_lifecycle_rule_enabled = false
  expiration_lifecycle_rule_enabled = false
  enforce_SSL_encryption_policy     = false
  use_aes256_encryption             = true
  force_destroy                     = local.in_development
  kst                               = var.tag_KST
  wa_number                         = var.wa_number
  git_repository                    = var.git_repository

}



#######################################################################################################################
#resource "aws_s3_bucket" "my_bucket" {
#  #checkov:skip=CKV_AWS_144:Skip reason
#  #checkov:skip=CKV_AWS_145:Skip reason
#  #checkov:skip=CKV_AWS_19:Skip reason
#  #checkov:skip=CKV_AWS_52:Skip reason
#  #checkov:skip=CKV_AWS_21:Skip reason
#  #checkov:skip=CKV_AWS_18:Skip reason
#  bucket = module.generic_labels.resource["my-test-new-bucket"]["id"]
#}


###########################################################################################################################
####   Bucket for Lambda deployment
#########################################################################################################################
#module "source_code_bucket" {
#  source = "git::ssh://cap-tf-module-aws-s3-bucket/vwdfive/cap-tf-module-aws-s3-bucket//s3/s3-logging-encrypted?ref=tags/0.5.0"
#
#  enable                        = true
#  environment                   = var.stage
#  project                       = var.project
#  s3_bucket_name                = "my-test-new-bucket"
#  s3_bucket_acl                 = "private"
#  target_bucket_id              = module.logs_bucket.s3_bucket
#  versioning_enabled            = true
#  enforce_SSL_encryption_policy = true
#  force_destroy                 = local.in_development
#  kst                           = var.tag_KST
#  wa_number                     = var.wa_number
#  git_repository                = "github.com/Mohamed-Amine-Dogui/data-eng-project"
#
#}
