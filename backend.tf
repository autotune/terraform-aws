terraform {
  backend "s3" {
    bucket = "badams-foo-us-east-2"
    key    = "dev.tf"
    region = "us-west-2"
  }
} 

