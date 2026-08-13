resource "local_file" "myfile" {
  filename = "automation.txt"
  content  = "automation/kaaa boommmm"
}

resource "aws_s3_bucket" "developbucket" {
  bucket = "dev-saurabh-terraform"
}

resource "aws_s3_bucket" "developbucket1" {
  bucket = "dev-saurabh-terraform-101"
}