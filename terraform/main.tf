provider "aws" {
  region = "eu-central-1"
}

resource "aws_s3_bucket" "mein_bucket" {
  bucket = "mehdi-terraform-projekt5-2026"

  tags = {
    Name    = "Terraform Test Bucket"
    Projekt = "Projekt 5"
  }
}