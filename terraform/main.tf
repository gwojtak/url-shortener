terraform {}

provider "aws" {
  #  required_version = "~> 4.8.0"
  region = "us-east-2"
  default_tags {
    tags = {
      Terraform = "local"
    }
  }
}
