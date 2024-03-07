resource "aws_s3_bucket" "my_bucket" {
  #checkov:skip=CKV_AWS_144:Skip reason
  #checkov:skip=CKV_AWS_145:Skip reason
  #checkov:skip=CKV_AWS_19:Skip reason
  #checkov:skip=CKV_AWS_52:Skip reason
  #checkov:skip=CKV_AWS_21:Skip reason
  #checkov:skip=CKV_AWS_18:Skip reason
  bucket = "my-test-new-bucket-1"
}
