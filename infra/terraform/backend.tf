terraform {
  backend "s3" {
    bucket         = "capstone-phoenix-tfstate-agdevops"
    key            = "capstone/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "capstone-phoenix-lock"
    encrypt        = true
  }
}
